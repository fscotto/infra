#!/usr/bin/python3
"""Read-only Atlas health probes with deduplicated 45Drives Alerts."""

import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path


CONFIG_PATH = Path("/etc/atlas-health-monitor.json")
STATE_DIR = Path("/var/lib/atlas-health-monitor")
STATE_PATH = STATE_DIR / "state.json"
GIB = 1024**3


def run(*argv, timeout=40):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)


def issue(issues, key, severity, message):
    issues[key] = {"severity": severity, "message": message}


def notify(config, event, severity, subject, message):
    now = datetime.now(timezone.utc)
    payload = {
        "timestamp": now.isoformat(timespec="seconds"),
        "unixtime": int(now.timestamp()),
        "event": event,
        "severity": severity,
        "subject": subject,
        "email_message": message,
    }
    result = run(config["notifier"], json.dumps(payload, ensure_ascii=False), timeout=30)
    if result.returncode:
        raise RuntimeError(f"45Drives notifier exited {result.returncode}: {result.stderr.strip()}")


def parse_fields(text):
    return dict(line.split("=", 1) for line in text.splitlines() if "=" in line)


def systemd_fields(unit, *properties):
    result = run("systemctl", "show", unit, *(f"-p{item}" for item in properties))
    if result.returncode:
        raise RuntimeError(f"systemctl show {unit} exited {result.returncode}")
    return parse_fields(result.stdout)


def unix_time(text):
    if not text or text == "n/a":
        return None
    result = run("date", "-d", text, "+%s")
    if result.returncode:
        raise ValueError(f"Cannot parse systemd timestamp: {text}")
    return int(result.stdout.strip())


def check_pool(config, issues, measurements):
    pool = config["pool"]
    listing = run("zpool", "list", "-H", "-p", "-o", "size,alloc,capacity,health", pool)
    if listing.returncode:
        issue(issues, "pool.probe", "critical", f"Cannot query ZFS pool {pool}")
        return
    try:
        size, alloc, capacity, health = listing.stdout.strip().split("\t")
        size, alloc, capacity = int(size), int(alloc), int(capacity)
    except (ValueError, TypeError):
        issue(issues, "pool.probe", "critical", "Invalid ZFS pool capacity response")
        return
    measurements.update(pool_size_bytes=size, pool_alloc_bytes=alloc, pool_capacity_percent=capacity)
    if health != "ONLINE":
        issue(issues, "pool.health", "critical", f"ZFS pool {pool} state is {health}")
    if capacity >= config["pool_critical_percent"]:
        issue(issues, "pool.capacity", "critical", f"ZFS pool {pool} is {capacity}% full")
    elif capacity >= config["pool_warning_percent"]:
        issue(issues, "pool.capacity", "warning", f"ZFS pool {pool} is {capacity}% full")

    status = run("zpool", "status", "-P", pool)
    if status.returncode:
        issue(issues, "pool.status", "critical", f"Cannot query detailed ZFS status for {pool}")
        return
    bad_vdevs = []
    for line in status.stdout.splitlines():
        match = re.match(r"^\s*(\S+)\s+(ONLINE|DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED)\s+(\d+)\s+(\d+)\s+(\d+)", line)
        if match:
            name, state, reads, writes, checksums = match.groups()
            if state != "ONLINE" or any(int(value) for value in (reads, writes, checksums)):
                bad_vdevs.append(f"{name}: {state}, READ={reads}, WRITE={writes}, CKSUM={checksums}")
    if bad_vdevs:
        issue(issues, "pool.vdevs", "critical", "ZFS vdev errors: " + "; ".join(bad_vdevs))
    errors = re.search(r"^errors:\s*(.*)$", status.stdout, re.MULTILINE)
    if not errors or errors.group(1).strip() != "No known data errors":
        issue(issues, "pool.data_errors", "critical", "ZFS status reports data errors; inspect zpool status -v")
    if re.search(r"^\s*scan:\s*resilver in progress", status.stdout, re.MULTILINE | re.IGNORECASE):
        issue(issues, "pool.resilver", "warning", "ZFS resilver is in progress; inspect zpool status")
    scan = re.search(r"^\s*scan:\s*(.*)$", status.stdout, re.MULTILINE)
    if scan and re.search(r"\bwith [1-9][0-9]* errors\b", scan.group(1)):
        issue(issues, "pool.scan_errors", "critical", f"ZFS scan reported errors: {scan.group(1)}")


def check_capacity(config, issues, measurements):
    pool = config["pool"]
    listing = run("zfs", "list", "-H", "-p", "-o", "name,usedbysnapshots", "-r", pool)
    if listing.returncode:
        issue(issues, "snapshot.probe", "warning", "Cannot query ZFS snapshot space")
    else:
        try:
            snapshots = sum(int(line.split("\t")[1]) for line in listing.stdout.splitlines())
            measurements["snapshots_bytes"] = snapshots
            size = measurements.get("pool_size_bytes")
            if size:
                percent = snapshots * 100 // size
                measurements["snapshots_percent"] = percent
                if percent >= config["snapshot_critical_percent"]:
                    issue(issues, "snapshot.capacity", "critical", f"Snapshots use {percent}% of pool size")
                elif percent >= config["snapshot_warning_percent"]:
                    issue(issues, "snapshot.capacity", "warning", f"Snapshots use {percent}% of pool size")
        except (ValueError, IndexError):
            issue(issues, "snapshot.probe", "warning", "Invalid ZFS snapshot-space response")
    backup = run("zfs", "list", "-H", "-p", "-o", "used", config["backup_dataset"])
    if backup.returncode:
        issue(issues, "backup.capacity_probe", "warning", "Cannot query local backup dataset space")
    else:
        try:
            measurements["backup_bytes"] = int(backup.stdout.strip())
        except ValueError:
            issue(issues, "backup.capacity_probe", "warning", "Invalid local backup space response")

    try:
        filesystem = os.statvfs("/")
        total = filesystem.f_blocks * filesystem.f_frsize
        available = filesystem.f_bavail * filesystem.f_frsize
        used_percent = (total - available) * 100 // total
        measurements["root_capacity_percent"] = used_percent
        if used_percent >= config["root_critical_percent"]:
            issue(issues, "root.capacity", "critical", f"Atlas system filesystem is {used_percent}% full")
        elif used_percent >= config["root_warning_percent"]:
            issue(issues, "root.capacity", "warning", f"Atlas system filesystem is {used_percent}% full")
    except (OSError, ZeroDivisionError):
        issue(issues, "root.capacity_probe", "warning", "Cannot query Atlas system filesystem space")


def check_remote_capacity(config, issues, measurements):
    """Query only the Storage Box quota; do not open or inspect the Borg repository."""
    remote = config["remote_capacity"]
    try:
        result = run("runuser", "-u", remote["run_as"], "--", remote["ssh_wrapper"],
                     f"{remote['user']}@{remote['host']}", "df", "-m", timeout=65)
        if result.returncode:
            raise ValueError(f"SSH df exited {result.returncode}")
        lines = result.stdout.strip().splitlines()
        if len(lines) != 2:
            raise ValueError("Unexpected Storage Box df output")
        fields = lines[1].split()
        if len(fields) < 5:
            raise ValueError("Incomplete Storage Box df output")
        total_mib, used_mib, available_mib = (int(value) for value in fields[1:4])
        percent = int(fields[4].rstrip("%"))
        if total_mib <= 0 or not 0 <= percent <= 100 or available_mib < 0:
            raise ValueError("Invalid Storage Box quota values")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        issue(issues, "remote.capacity_probe", "warning", "Cannot query Hetzner Storage Box quota via pinned-key SSH")
        return
    measurements.update(remote_capacity_percent=percent, remote_bytes=used_mib * 1024**2,
                        remote_available_bytes=available_mib * 1024**2)
    if percent >= remote["critical_percent"]:
        issue(issues, "remote.capacity", "critical", f"Hetzner Storage Box quota is {percent}% full")
    elif percent >= remote["warning_percent"]:
        issue(issues, "remote.capacity", "warning", f"Hetzner Storage Box quota is {percent}% full")


def check_smart(config, issues, measurements):
    for device in config["smart_devices"]:
        name, path = device["name"], device["path"]
        try:
            result = run("smartctl", "-j", "-a", path, timeout=60)
            data = json.loads(result.stdout)
            status = int(data.get("smartctl", {}).get("exit_status", result.returncode))
        except (subprocess.TimeoutExpired, json.JSONDecodeError, ValueError) as exc:
            issue(issues, f"smart.{name}.probe", "critical", f"SMART probe failed for {name}: {type(exc).__name__}")
            continue
        if status:
            severity = "critical" if status & 0b00001111 else "warning"
            issue(issues, f"smart.{name}.status", severity, f"SMART reported exit status {status} for {name}")
        passed = data.get("smart_status", {}).get("passed")
        if passed is False:
            issue(issues, f"smart.{name}.health", "critical", f"SMART self-assessment failed for {name}")
        elif passed is None:
            issue(issues, f"smart.{name}.health", "warning", f"SMART self-assessment unavailable for {name}")
        temperature = data.get("temperature", {}).get("current")
        if isinstance(temperature, (int, float)):
            measurements[f"smart_{name}_c"] = temperature
            if temperature >= device["critical_c"]:
                issue(issues, f"smart.{name}.temperature", "critical", f"{name} temperature is {temperature} C")
            elif temperature >= device["warning_c"]:
                issue(issues, f"smart.{name}.temperature", "warning", f"{name} temperature is {temperature} C")
        else:
            issue(issues, f"smart.{name}.temperature", "warning", f"Temperature unavailable for {name}")
        for attribute in data.get("ata_smart_attributes", {}).get("table", []):
            attribute_id = attribute.get("id")
            if attribute_id in (5, 187, 197, 198):
                raw = attribute.get("raw", {}).get("value", 0)
                if isinstance(raw, int) and raw > 0:
                    severity = "critical" if attribute_id in (197, 198) else "warning"
                    issue(issues, f"smart.{name}.ata_{attribute_id}", severity,
                          f"{name} SMART attribute {attribute_id} raw count is {raw}")
        nvme = data.get("nvme_smart_health_information_log", {})
        if isinstance(nvme, dict):
            if int(nvme.get("critical_warning", 0)):
                issue(issues, f"smart.{name}.nvme_warning", "critical", f"{name} NVMe critical warning is nonzero")
            if int(nvme.get("media_errors", 0)):
                issue(issues, f"smart.{name}.nvme_media", "critical", f"{name} NVMe media errors are nonzero")


def check_cpu(config, issues, measurements):
    sensors = []
    for hwmon in Path("/sys/class/hwmon").glob("hwmon*"):
        try:
            if (hwmon / "name").read_text().strip() != "coretemp":
                continue
            sensors.extend(int(path.read_text().strip()) / 1000 for path in hwmon.glob("temp*_input"))
        except (OSError, ValueError):
            continue
    if not sensors:
        issue(issues, "cpu.temperature_probe", "warning", "CPU temperature sensors are unavailable")
        return
    hottest = max(sensors)
    measurements["cpu_max_c"] = hottest
    if hottest >= config["cpu_critical_c"]:
        issue(issues, "cpu.temperature", "critical", f"CPU temperature is {hottest:g} C")
    elif hottest >= config["cpu_warning_c"]:
        issue(issues, "cpu.temperature", "warning", f"CPU temperature is {hottest:g} C")


def check_jobs(config, issues, measurements, now):
    for timer in config["timers"]:
        name = timer["name"]
        try:
            fields = systemd_fields(name, "ActiveState", "UnitFileState", "LastTriggerUSec", "ActiveEnterTimestamp")
            if fields.get("ActiveState") != "active" or fields.get("UnitFileState") != "enabled":
                issue(issues, f"timer.{name}", "critical", f"Timer {name} is not active and enabled")
            max_age = int(timer["max_age_hours"]) * 3600
            if max_age:
                last = unix_time(fields.get("LastTriggerUSec"))
                if last is None:
                    last = unix_time(fields.get("ActiveEnterTimestamp"))
                if last is not None and now - last > max_age:
                    issue(issues, f"timer.{name}.stale", "warning",
                          f"Timer {name} has not fired in {int((now-last)/3600)} hours")
        except (RuntimeError, ValueError, subprocess.TimeoutExpired):
            issue(issues, f"timer.{name}.probe", "warning", f"Cannot query timer {name}")
    for unit in config["failure_units"]:
        if unit.endswith("@.service"):
            continue
        try:
            fields = systemd_fields(unit, "ActiveState", "Result", "ExecMainStartTimestamp")
            state = fields.get("ActiveState")
            if state == "failed" or (state == "inactive" and fields.get("Result") not in (None, "", "success")):
                issue(issues, f"service.{unit}", "critical", f"Service {unit} failed: {fields.get('Result')}")
            if unit == "atlas-borg-backup.service" and fields.get("ActiveState") == "activating":
                started = unix_time(fields.get("ExecMainStartTimestamp"))
                if started is not None and now - started > config["borg_max_runtime_days"] * 86400:
                    issue(issues, "backup.borg_long_running", "warning",
                          "Borg has run longer than its configured limit")
        except (RuntimeError, ValueError, subprocess.TimeoutExpired):
            issue(issues, f"service.{unit}.probe", "warning", f"Cannot query service {unit}")


def check_growth(config, issues, measurements, samples, now):
    previous = [sample for sample in samples if 20 * 3600 <= now - sample.get("time", now) <= 48 * 3600]
    if previous:
        baseline = min(previous, key=lambda sample: abs(now - sample["time"] - 86400))
        days = (now - baseline["time"]) / 86400
        for name, threshold in (("snapshots", config["snapshot_growth_warning_gib_day"]),
                                ("backup", config["backup_growth_warning_gib_day"]),
                                ("remote", config["remote_capacity"]["growth_warning_gib_day"])):
            current, old = measurements.get(f"{name}_bytes"), baseline.get(f"{name}_bytes")
            if isinstance(current, int) and isinstance(old, int) and days > 0:
                growth_gib_day = (current - old) / GIB / days
                measurements[f"{name}_growth_gib_day"] = round(growth_gib_day, 1)
                if growth_gib_day >= threshold:
                    issue(issues, f"{name}.growth", "warning",
                          f"Local {name} usage grew {growth_gib_day:.1f} GiB/day over {days:.1f} days")


def allowed_failure_unit(config, unit):
    for allowed in config["failure_units"]:
        if allowed == unit:
            return True
        if allowed.endswith("@.service") and unit.startswith(allowed[:-9] + "@") and unit.endswith(".service"):
            return True
    return False


def load_state():
    if not STATE_PATH.exists():
        return {"active": {}, "samples": []}
    with STATE_PATH.open(encoding="utf-8") as stream:
        state = json.load(stream)
    if not isinstance(state.get("active"), dict) or not isinstance(state.get("samples"), list):
        raise ValueError("Invalid Atlas monitor state; refusing to overwrite it")
    return state


def save_state(state):
    with tempfile.NamedTemporaryFile("w", dir=STATE_DIR, prefix=".state-", delete=False,
                                     encoding="utf-8") as stream:
        path = Path(stream.name)
        os.chmod(path, 0o600)
        json.dump(state, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(path, STATE_PATH)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="probe without notifications or state changes")
    parser.add_argument("--test-notification", action="store_true", help="submit a labelled test alert")
    parser.add_argument("--job-failed", metavar="UNIT", help="notify about a failed configured service")
    args = parser.parse_args()
    with CONFIG_PATH.open(encoding="utf-8") as stream:
        config = json.load(stream)
    if args.test_notification:
        notify(config, "atlas_monitor_test", "warning", "Test monitoraggio Atlas",
               "Notifica di prova: il monitoraggio Atlas raggiunge 45Drives Alerts. Non conferma l'invio email.")
        print("Atlas monitor test submitted to 45Drives Alerts; email delivery is not verified.")
        return 0
    if args.job_failed:
        if not allowed_failure_unit(config, args.job_failed):
            raise ValueError("Unconfigured Atlas failure unit")
        notify(config, "atlas_job_failed", "critical", f"Job Atlas fallito: {args.job_failed}",
               f"Il servizio {args.job_failed} e' fallito. Controlla: "
               f"sudo journalctl -u {args.job_failed} -n 100 --no-pager")
        print(f"Atlas job failure submitted to 45Drives Alerts: {args.job_failed}")
        return 0

    now = int(time.time())
    issues, measurements = {}, {}
    check_pool(config, issues, measurements)
    check_capacity(config, issues, measurements)
    check_remote_capacity(config, issues, measurements)
    check_smart(config, issues, measurements)
    check_cpu(config, issues, measurements)
    check_jobs(config, issues, measurements, now)
    if args.dry_run:
        print(json.dumps({"issues": issues, "measurements": measurements}, sort_keys=True))
        return 0

    STATE_DIR.mkdir(mode=0o700, exist_ok=True)
    with (STATE_DIR / "monitor.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        state = load_state()
        check_growth(config, issues, measurements, state["samples"], now)
        active, failed_notifications = state["active"], []
        for key, details in issues.items():
            old = active.get(key)
            if old is None or old.get("severity") != details["severity"]:
                try:
                    notify(config, "atlas_health_issue", details["severity"],
                           f"Atlas: {key}", details["message"])
                    active[key] = details
                    print(f"ALERT {details['severity']} {key}: {details['message']}", flush=True)
                except (RuntimeError, subprocess.TimeoutExpired) as exc:
                    failed_notifications.append(key)
                    print(f"NOTIFICATION FAILED {key}: {exc}", file=sys.stderr, flush=True)
        for key in set(active) - set(issues):
            print(f"RECOVERED {key}", flush=True)
            del active[key]
        state["samples"] = [sample for sample in state["samples"] if now - sample.get("time", 0) < 48 * 3600]
        state["samples"].append({"time": now, **{key: value for key, value in measurements.items()
                                                 if key in ("snapshots_bytes", "backup_bytes", "remote_bytes")}})
        save_state(state)
        print(f"Atlas health: issues={len(issues)} notifications_failed={len(failed_notifications)} "
              f"pool={measurements.get('pool_capacity_percent', 'unknown')}% "
              f"remote={measurements.get('remote_capacity_percent', 'unknown')}% "
              f"snapshots={measurements.get('snapshots_bytes', 'unknown')} bytes "
              f"backup={measurements.get('backup_bytes', 'unknown')} bytes", flush=True)
        return 1 if failed_notifications else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Atlas health monitor failed: {error}", file=sys.stderr)
        sys.exit(1)
