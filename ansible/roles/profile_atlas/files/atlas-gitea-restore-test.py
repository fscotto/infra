#!/usr/bin/python3
"""Rehearse a selective rootful-to-rootless Gitea restore, never a cutover."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sqlite3
import tarfile
import tempfile


SOURCE_PREFIX = PurePosixPath("opt/gitea/data")
HOST_KEYS = (
    "ssh_host_ed25519_key",
    "ssh_host_rsa_key",
    "ssh_host_ecdsa_key",
)
SERVER_SETTINGS = {
    "START_SSH_SERVER": "true",
    "SSH_PORT": "2222",
    "SSH_LISTEN_PORT": "2222",
    "SSH_SERVER_HOST_KEYS": ", ".join(
        f"/var/lib/gitea/ssh/{key}" for key in HOST_KEYS
    ),
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_digest(backup):
    checksum = (backup / "payload.sha256").read_text().strip().split()
    if len(checksum) != 2 or checksum[1] != "payload.tar":
        raise ValueError("Unexpected Prometheus backup checksum manifest")
    if not re.fullmatch(r"[0-9a-f]{64}", checksum[0]):
        raise ValueError("Invalid Prometheus backup SHA-256")
    return checksum[0]


def convert_config(config):
    original = config.read_text()
    output = []
    section = ""
    server_seen = set()
    server_found = False

    def append_missing_server_settings():
        for key, value in SERVER_SETTINGS.items():
            if key not in server_seen:
                output.append(f"{key} = {value}\n")

    for line in original.splitlines(keepends=True):
        match = re.match(r"^\s*\[([^]]+)\]\s*$", line)
        if match:
            if section == "server":
                append_missing_server_settings()
            section = match.group(1).lower()
            server_found |= section == "server"
            output.append(line)
            continue
        setting = re.match(r"^(\s*)([A-Z_]+)(\s*=\s*)(.*?)(\r?\n?)$", line)
        if setting and section == "server" and setting.group(2) in SERVER_SETTINGS:
            key = setting.group(2)
            server_seen.add(key)
            line = f"{setting.group(1)}{key}{setting.group(3)}{SERVER_SETTINGS[key]}{setting.group(5)}"
        else:
            line = line.replace("/data/", "/var/lib/gitea/")
        output.append(line)
    if section == "server":
        append_missing_server_settings()
    if not server_found:
        raise ValueError("Gitea server configuration missing")
    config.write_text("".join(output))
    config.chmod(0o600)


def extract_gitea(tar_path, staged_data):
    count = 0
    with tarfile.open(tar_path, mode="r") as archive:
        for member in archive:
            name = PurePosixPath(member.name)
            if name == SOURCE_PREFIX:
                continue
            if SOURCE_PREFIX not in name.parents:
                continue
            relative = name.relative_to(SOURCE_PREFIX)
            if not relative.parts or any(part in (".", "..") for part in relative.parts):
                raise ValueError("Unsafe Gitea backup path")
            if not (member.isdir() or member.isfile()):
                raise ValueError("Unexpected Gitea backup member type")
            destination = staged_data.joinpath(*relative.parts)
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
                destination.chmod(0o700)
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as source, destination.open("xb") as target:
                shutil.copyfileobj(source, target)
            destination.chmod(member.mode & 0o777)
            count += 1
    if count == 0:
        raise ValueError("No Gitea files in backup")


def validate(staged_data, staged_config):
    database = staged_data / "gitea/gitea.db"
    repositories = staged_data / "git/repositories"
    if not database.is_file() or not repositories.is_dir():
        raise ValueError("Missing SQLite database or Git repositories")
    with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as connection:
        if connection.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise ValueError("Gitea SQLite quick_check failed")
        if connection.execute("SELECT count(*) FROM repository").fetchone()[0] < 1:
            raise ValueError("Gitea backup contains no repository records")
    if not any(repositories.rglob("*.git")):
        raise ValueError("Gitea backup contains no Git repository directories")
    if not (staged_config / "app.ini").is_file():
        raise ValueError("Gitea app.ini missing")
    for name in HOST_KEYS:
        if not (staged_data / "ssh" / name).is_file():
            raise ValueError("Gitea SSH host key missing")


def chown_tree(root, uid, gid):
    for directory, dirs, files in os.walk(root):
        os.chown(directory, uid, gid)
        for name in dirs + files:
            os.chown(os.path.join(directory, name), uid, gid)


def replace_rehearsal(target, stage, digest, uid, gid):
    previous_data = target / ".previous-rehearsal-data"
    previous_config = target / ".previous-rehearsal-config"
    if previous_data.exists() or previous_config.exists():
        raise ValueError("An interrupted Gitea replacement needs manual recovery")
    os.rename(target / "data", previous_data)
    try:
        os.rename(target / "config", previous_config)
        os.rename(stage / "data", target / "data")
        os.rename(stage / "config", target / "config")
        final_marker = target / ".final-sha256"
        final_marker.write_text(digest + "\n")
        final_marker.chmod(0o600)
        os.chown(final_marker, uid, gid)
        (target / ".rehearsal-sha256").unlink()
    except Exception:
        for name, previous in (("data", previous_data), ("config", previous_config)):
            current = target / name
            if previous.exists():
                if current.exists():
                    shutil.rmtree(current)
                os.rename(previous, current)
        (target / ".final-sha256").unlink(missing_ok=True)
        raise
    shutil.rmtree(previous_data)
    shutil.rmtree(previous_config)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--uid", type=int, required=True)
    parser.add_argument("--gid", type=int, required=True)
    parser.add_argument("--replace-rehearsal", action="store_true")
    args = parser.parse_args()

    backup = args.backup.resolve(strict=True)
    target = args.target.resolve(strict=True)
    if not str(backup).startswith("/zpool/backup/hosts/prometheus/snapshots/"):
        raise ValueError("Refusing backup outside the Atlas Prometheus snapshots")
    if str(target) != "/zpool/services/data/gitea":
        raise ValueError("Refusing target outside the dedicated Gitea dataset")
    if args.uid != 1101 or args.gid != 1101:
        raise ValueError("Unexpected dedicated Gitea account IDs")
    expected = expected_digest(backup)
    if sha256(backup / "payload.tar") != expected:
        raise ValueError("Prometheus backup SHA-256 mismatch")

    marker = target / (".final-sha256" if args.replace_rehearsal else ".rehearsal-sha256")
    if marker.exists():
        if marker.read_text().strip() != expected:
            raise ValueError("A different Gitea restore already occupies this dataset")
        validate(target / "data", target / "config")
        print("unchanged")
        return
    if args.replace_rehearsal:
        metadata = json.loads((backup / "metadata.json").read_text())
        if metadata.get("purpose") != "gitea-cutover":
            raise ValueError("Final restore requires an explicit Gitea cutover export")
        if not (target / ".rehearsal-sha256").is_file():
            raise ValueError("Only a marked rehearsal may be replaced")
        if not all((target / name).is_dir() for name in ("data", "config")):
            raise ValueError("Prepared Gitea volume paths are missing")
    else:
        if (target / ".final-sha256").exists():
            raise ValueError("Refusing a rehearsal restore over final Gitea data")
        for name in ("data", "config"):
            directory = target / name
            if not directory.is_dir() or any(directory.iterdir()):
                raise ValueError("Gitea target is not empty; refusing overwrite")

    with tempfile.TemporaryDirectory(prefix=".rehearsal-", dir=target) as temporary:
        stage = Path(temporary)
        staged_data = stage / "data"
        staged_config = stage / "config"
        staged_data.mkdir()
        staged_config.mkdir()
        extract_gitea(backup / "payload.tar", staged_data)
        source_config = staged_data / "gitea/conf/app.ini"
        if not source_config.is_file():
            raise ValueError("Source Gitea app.ini missing")
        shutil.copy2(source_config, staged_config / "app.ini")
        source_config.unlink()
        convert_config(staged_config / "app.ini")
        validate(staged_data, staged_config)
        chown_tree(stage, args.uid, args.gid)
        if args.replace_rehearsal:
            replace_rehearsal(target, stage, expected, args.uid, args.gid)
        else:
            for name in ("data", "config"):
                (target / name).rmdir()
                os.rename(stage / name, target / name)
            marker.write_text(expected + "\n")
            marker.chmod(0o600)
            os.chown(marker, args.uid, args.gid)
    print("restored")


if __name__ == "__main__":
    main()
