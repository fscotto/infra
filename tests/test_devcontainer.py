"""Host-side generator regression tests; no engine or credentials required."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('generator', Path(__file__).resolve().parents[1] / 'scripts/devcontainer.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'host home'
        self.home.mkdir()
        self.project = self.root / 'project with spaces'
        self.project.mkdir()

    def test_every_profile_produces_valid_config(self):
        for profile in generator.PROFILES:
            with self.subTest(profile=profile):
                target = generator.generate(self.project, profile, self.home, [], force=True)
                config = json.loads((target / 'devcontainer.json').read_text())
                self.assertEqual(config['containerEnv']['HOME'], str(self.home))
                self.assertNotIn('postCreateCommand', config)
                self.assertTrue((target / 'Dockerfile').read_text().endswith('USER vscode\n'))

    def test_host_config_is_mounted_without_copying_secrets(self):
        (self.home / '.codex').mkdir()
        (self.home / '.codex/auth.json').write_text('secret-value')
        (self.home / '.gitconfig').write_text('[user]\nname = Test\n')
        target = generator.generate(self.project, 'python', self.home, ['codex'])
        text = (target / 'devcontainer.json').read_text()
        config = json.loads(text)
        self.assertNotIn('secret-value', text + (target / 'Dockerfile').read_text())
        git_mount = next(m for m in config['mounts'] if m['target'] == '/run/host-gitconfig')
        self.assertTrue(git_mount['readOnly'])
        agent_mount = next(m for m in config['mounts'] if m['target'] == str(self.home / '.codex'))
        self.assertFalse(agent_mount['readOnly'])
        self.assertIn('include.path /run/host-gitconfig', (target / 'Dockerfile').read_text())

    def test_refuses_existing_config(self):
        target = generator.generate(self.project, 'go', self.home, [])
        before = (target / 'devcontainer.json').read_bytes()
        with self.assertRaises(ValueError):
            generator.generate(self.project, 'rust', self.home, [])
        self.assertEqual(before, (target / 'devcontainer.json').read_bytes())

    def test_missing_agent_config_does_not_write(self):
        with self.assertRaises(ValueError):
            generator.generate(self.project, 'go', self.home, ['codex'])
        self.assertFalse((self.project / '.devcontainer').exists())

    def test_force_rejects_symlink_without_modifying_other_files(self):
        target = generator.generate(self.project, 'go', self.home, [])
        before = (target / 'Dockerfile').read_bytes()
        (target / 'devcontainer.json').unlink()
        victim = self.root / 'victim'
        victim.write_text('keep')
        (target / 'devcontainer.json').symlink_to(victim)
        with self.assertRaises(ValueError):
            generator.generate(self.project, 'rust', self.home, [], force=True)
        self.assertEqual(victim.read_text(), 'keep')
        self.assertEqual(before, (target / 'Dockerfile').read_bytes())
