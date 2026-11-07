import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

from jinja2 import Environment


TEMPLATE = Path(__file__).resolve().parents[1] / "templates/ai-media.j2"
UUID = "6948c504-2d60-4cc8-9e7f-3ccdf28e80d7"


class StorageCommandsTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.media = self.root / "media"
        for directory in ("input", "output"):
            (self.media / directory).mkdir(parents=True)
        env = Environment()
        env.filters["quote"] = shlex.quote
        self.launcher = self.root / "ai-media"
        self.launcher.write_text(env.from_string(TEMPLATE.read_text()).render(
            desktop_ai_media_root=str(self.media),
            desktop_ai_media_build_root=str(self.root),
            desktop_ai_media_external_storage_enabled=True,
            desktop_ai_media_external_luks_uuid=UUID,
            desktop_ai_media_external_mountpoint="/run/media/test/Backup",
            desktop_ai_media_external_source="/run/media/test/Backup/ai-media",
        ))
        self.state = self.root / "state.json"
        self.log = self.root / "commands.jsonl"
        mock = self.root / "mock"
        mock.write_text('''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

cmd = Path(sys.argv[0]).name
args = sys.argv[1:]
state_file = Path(os.environ["STORAGE_TEST_STATE"])
state = json.loads(state_file.read_text())
root = os.environ["STORAGE_TEST_ROOT"]
external = "/run/media/test/Backup"
with open(os.environ["STORAGE_TEST_LOG"], "a") as log:
    log.write(json.dumps([cmd, *args]) + "\\n")
if cmd == "sudo":
    os.execvp(args[0], args)
elif cmd == "lsblk":
    if state.get("missing"):
        sys.exit(1)
    print("/dev/sda1 part 8:1")
    if state.get("unlocked"):
        print("/dev/dm-0 crypt 252:0")
elif cmd == "findmnt":
    if "--mountpoint" in args:
        target = args[args.index("--mountpoint") + 1]
        match = state.get("bind" if target == root else "mounted")
        if not match:
            sys.exit(1)
        print(match)
    elif "--source" in args:
        assert args[args.index("--source") + 1] == "252:0"
        mounts = ([external] if state.get("mounted") else []) + (
            [root] if state.get("bind") else []) + state.get("other_mounts", [])
        if not mounts:
            sys.exit(1)
        print(*mounts, sep="\\n")
    else:
        sys.exit(2)
elif cmd == "systemctl":
    if args[0] == "--user":
        if state.get("running"):
            print("ai-media-preset-test.service loaded active running")
    elif args[0] == "start":
        state["bind"] = "252:0 /ai-media"
    elif args[0] == "stop":
        state.pop("bind", None)
elif cmd == "podman":
    assert args[:3] == ["--remote=false", "ps", "-q"]
    if state.get("container"):
        print("abcdef")
elif cmd == "udisksctl":
    if args[0] == "unlock":
        state["unlocked"] = True
    elif args[0] == "mount":
        state["mounted"] = "252:0 /"
    elif args[0] == "unmount":
        if state.get("busy"):
            sys.exit("Device is busy")
        state.pop("mounted", None)
    elif args[0] == "lock":
        assert not state.get("mounted")
        state.pop("unlocked")
state_file.write_text(json.dumps(state))
''')
        mock.chmod(0o755)
        for command in ("lsblk", "findmnt", "systemctl", "podman", "udisksctl", "sudo"):
            (self.root / command).symlink_to(mock)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        STORAGE_TEST_STATE=str(self.state), STORAGE_TEST_LOG=str(self.log),
                        STORAGE_TEST_ROOT=str(self.media))

    def units(self):
        return [subprocess.check_output(["systemd-escape", "-p", "--suffix=" + suffix, "--", str(self.media)], text=True).strip()
                for suffix in ("automount", "mount")]

    def launch(self, *args, **state):
        self.state.write_text(json.dumps(state))
        self.log.write_text("")
        result = subprocess.run(["bash", str(self.launcher), *args], env=self.env,
                                capture_output=True, text=True, timeout=10)
        operations = [row[:2] if row[0] == "systemctl" else row
                      for line in self.log.read_text().splitlines()
                      if (row := json.loads(line))[0] in ("udisksctl", "systemctl", "sudo")]
        return result, operations

    def test_mount_unlocks_only_the_configured_volume_then_starts_bind(self):
        result, operations = self.launch("mount")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(operations, [
            ["udisksctl", "unlock", "--block-device", f"/dev/disk/by-uuid/{UUID}"],
            ["udisksctl", "mount", "--block-device", "/dev/dm-0"],
            ["sudo", "systemctl", "start", *self.units()],
            ["systemctl", "start"],
        ])

    def test_mount_does_not_reopen_already_mounted_volume(self):
        result, operations = self.launch("mount", unlocked=True, mounted="252:0 /")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(operations, [["sudo", "systemctl", "start", *self.units()], ["systemctl", "start"]])

    def test_umount_stops_bind_before_unmount_and_lock(self):
        result, operations = self.launch("umount", unlocked=True, mounted="252:0 /",
                                         bind="252:0 /ai-media")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(operations, [
            ["systemctl", "--user"], ["sudo", "systemctl", "stop", "ai-media-bind-restarter.service", *self.units()], ["systemctl", "stop"],
            ["udisksctl", "unmount", "--block-device", "/dev/dm-0"],
            ["udisksctl", "lock", "--block-device", f"/dev/disk/by-uuid/{UUID}"],
        ])

    def test_umount_refuses_running_jobs_and_containers(self):
        for condition in ("running", "container"):
            with self.subTest(condition=condition):
                result, operations = self.launch("umount", **{condition: True})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("running ai-media jobs", result.stderr)
                self.assertEqual(operations, [["systemctl", "--user"]])

    def test_umount_does_not_lock_if_busy(self):
        result, operations = self.launch("umount", unlocked=True, mounted="252:0 /", busy=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(operations[-1][:2], ["udisksctl", "unmount"])

    def test_umount_does_not_touch_other_mounts(self):
        result, operations = self.launch("umount", unlocked=True, mounted="252:0 /",
                                         other_mounts=["/mnt/other"])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(operations, [["systemctl", "--user"], ["sudo", "systemctl", "stop", "ai-media-bind-restarter.service", *self.units()], ["systemctl", "stop"]])

    def test_rejects_foreign_mount_missing_device_and_extra_arguments(self):
        for args, state in [
            (("mount",), {"mounted": "8:2 /"}),
            (("umount",), {"bind": "8:2 /ai-media"}),
            (("mount",), {"missing": True}),
            (("umount", "/dev/sdb"), {}),
        ]:
            with self.subTest(args=args, state=state):
                result, operations = self.launch(*args, **state)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(operations, [])

    def test_preset_refuses_local_fallback_when_bind_is_stopped(self):
        result, operations = self.launch("preset", "split", "test.mp4")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("run ai-media mount first", result.stderr)
        self.assertEqual(operations, [])
