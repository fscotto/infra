import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

from jinja2 import Environment
import shlex

ROLE = Path(__file__).resolve().parents[1]


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.media = self.root / '.local/share/ai-media'
        for directory in ('input', 'output', 'models', 'state/facefusion', 'state/rvc'):
            (self.media / directory).mkdir(parents=True)
        environment = Environment()
        environment.filters['quote'] = shlex.quote
        self.launcher = self.root / 'ai-media'
        self.launcher.write_text(environment.from_string(
            (ROLE / 'templates/ai-media.j2').read_text()
        ).render(desktop_ai_media_root=str(self.media), desktop_ai_media_build_root=str(self.root)))
        (self.root / 'check_storage.py').write_text((ROLE / 'files/check_storage.py').read_text())
        self.log = self.root / 'podman.json'
        podman = self.root / 'podman'
        podman.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        podman.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.root) + ':' + os.environ['PATH'],
                        TEST_LOG=str(self.log), HOME=str(self.root))

    def launch(self, *args):
        return subprocess.run(['bash', str(self.launcher), *args], env=self.env,
                              capture_output=True, text=True)

    def test_cli_has_no_network_or_host_home(self):
        result = self.launch('facefusion', 'cli', '--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        for flag in ('--network=none', '--pull=never', '--read-only',
                     '--security-opt=no-new-privileges', '--cap-drop=ALL'):
            self.assertIn(flag, args)
        self.assertIn(str(self.media / 'input') + ':/work/input:ro,Z', args)
        self.assertNotIn('--privileged', args)
        self.assertNotIn('--security-opt', args)
        self.assertNotIn('label=disable', args)

    def test_gui_exposes_only_wayland_socket(self):
        self.env.update(XDG_RUNTIME_DIR=str(self.root), WAYLAND_DISPLAY='wayland-0')
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(self.root / 'wayland-0'))
            result = self.launch('rvc', '--foreground')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--network=none', args)
        self.assertIn(str(self.root / 'wayland-0') + ':/run/media/wayland-0:ro', args)
        self.assertIn('/run/media:rw,nosuid,nodev,size=1m,mode=1777', args)
        self.assertFalse(any('uid=' in arg or 'gid=' in arg for arg in args))
        self.assertNotIn('--publish', args)
        self.assertFalse(any('dbus' in arg for arg in args))

    def test_default_gui_uses_independent_user_service(self):
        self.env.update(XDG_RUNTIME_DIR=str(self.root), WAYLAND_DISPLAY='wayland-0')
        runner = self.root / 'systemd-run'
        runner.write_text('#!/usr/bin/python3\nimport json,os,sys\n'
                          'open(os.environ["TEST_LOG"], "w").write(json.dumps(sys.argv[1:]))\n')
        runner.chmod(0o755)
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(self.root / 'wayland-0'))
            result = self.launch('rvc')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.log.read_text())
        self.assertIn('--user', args)
        self.assertIn('--unit=ai-media-rvc', args)
        self.assertIn('--property=Restart=no', args)
        self.assertIn('--foreground', args)
        self.assertNotIn('--scope', args)
        self.assertNotIn('--pty', args)
        self.assertNotIn('--wait', args)

    def test_symlinked_input_is_rejected(self):
        (self.media / 'input').rmdir()
        (self.media / 'input').symlink_to(self.root)
        self.assertNotEqual(self.launch('facefusion', 'cli', '--help').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_synced_storage_is_rejected(self):
        directory = self.root / '.config/Nextcloud'
        directory.mkdir(parents=True)
        (directory / 'nextcloud.cfg').write_text(
            '[Accounts]\n0\\Folders\\1\\localPath=' + str(self.media) + '\n'
        )
        self.assertNotEqual(self.launch('facefusion', 'cli', '--help').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_invalid_tool_is_rejected(self):
        self.assertEqual(self.launch('--network=host').returncode, 2)
        self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
