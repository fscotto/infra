"""Offline profile-selection regression tests; no real credentials or application."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

path = Path(__file__).resolve().parents[1] / 'ansible/roles/profile_desktop_gnome/files/thunderbird_profile.py'
spec = importlib.util.spec_from_file_location('profile', path)
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)

    def seed(self, root, directory, account=True, install='TEST'):
        base = self.home / root
        target = base / directory
        target.mkdir(parents=True)
        (base / 'profiles.ini').write_text(
            f'[Profile0]\nName=original\nPath={directory}\nIsRelative=1\nDefault=1\n'
            f'[Install{install}]\nDefault={directory}\nLocked=1\n')
        if account:
            prefs = {'mail.accountmanager.accounts': 'account7',
                     'mail.account.account7.server': 'server8',
                     'mail.server.server8.type': 'imap',
                     'mail.server.server8.hostname': 'imap.example.test'}
            (target / 'prefs.js').write_text('\n'.join(
                f'user_pref({json.dumps(k)}, {json.dumps(v)});' for k, v in prefs.items()))
        return target

    def plan(self):
        return profile.plan(self.home, 'managed.default-release', 'managed')

    def test_fresh_install(self):
        result = self.plan()
        self.assertFalse(result['existing_account'])
        self.assertEqual(result['root'], str(self.home / '.config/thunderbird'))
        self.assertIn('Default=1', result['profiles_ini'])
        self.assertEqual(list(self.home.iterdir()), [])  # Discovery is read-only.

    def test_xdg_account_wins_over_empty_legacy(self):
        old = self.seed('.config/thunderbird', 'original')
        self.seed('.thunderbird', 'empty', account=False)
        result = self.plan()
        self.assertTrue(result['existing_account'])
        self.assertEqual(result['profile'], str(old))
        self.assertIn('Path=empty', result['profiles_ini'])
        self.assertIn('Default=' + str(old), result['installs_ini'])

    def test_existing_legacy_account_is_untouched(self):
        old = self.seed('.thunderbird', 'original')
        before = (old / 'prefs.js').read_bytes()
        result = self.plan()
        self.assertEqual(result['profile'], str(old))
        self.assertEqual((old / 'prefs.js').read_bytes(), before)

    def test_user_js_is_not_evidence_of_an_existing_account(self):
        old = self.seed('.thunderbird', 'unused', account=False)
        (old / 'user.js').write_text('user_pref("mail.accountmanager.accounts", "account1");')
        self.assertFalse(self.plan()['existing_account'])

    def test_absolute_profile_path(self):
        old = self.seed('.config/thunderbird', 'original')
        registry = old.parent / 'profiles.ini'
        registry.write_text(registry.read_text().replace('IsRelative=1', 'IsRelative=0')
                            .replace('Path=original', 'Path=' + str(old)))
        self.assertEqual(self.plan()['profile'], str(old))

    def test_second_run_is_idempotent(self):
        self.seed('.config/thunderbird', 'original')
        self.seed('.thunderbird', 'empty', account=False)
        first = self.plan()
        root = Path(first['root'])
        (root / 'profiles.ini').write_text(first['profiles_ini'])
        (root / 'installs.ini').write_text(first['installs_ini'])
        second = self.plan()
        self.assertEqual(first, second)

    def test_registered_default_wins_over_unregistered_account(self):
        old = self.seed('.config/thunderbird', 'original')
        extra = old.parent / 'aaa-other'
        extra.mkdir()
        (extra / 'prefs.js').write_bytes((old / 'prefs.js').read_bytes())
        self.assertEqual(self.plan()['profile'], str(old))

    def test_new_profile_does_not_overwrite_an_unconfigured_profile(self):
        old = self.seed('.thunderbird', 'managed.default-release', account=False)
        (old / 'prefs.js').write_text('// Existing local preferences, no mail account.\n')
        self.assertEqual(self.plan()['profile'], str(old) + '-1')

    def test_pending_managed_bootstrap_is_reused(self):
        old = self.seed('.thunderbird', 'managed.default-release', account=False)
        (old / 'user.js').write_text('// Managed by Ansible from profile_desktop_gnome\n')
        self.assertEqual(self.plan()['profile'], str(old))

    def test_other_installation_with_its_own_account_is_preserved(self):
        old = self.seed('.thunderbird', 'original')
        other = old.parent / 'beta'
        other.mkdir()
        (other / 'prefs.js').write_bytes((old / 'prefs.js').read_bytes())
        registry = old.parent / 'profiles.ini'
        registry.write_text(registry.read_text() + '[InstallBETA]\nDefault=beta\nLocked=1\n')
        result = self.plan()
        self.assertIn('[InstallBETA]\nDefault=beta\nLocked=1', result['profiles_ini'])


if __name__ == '__main__':
    unittest.main()
