#!/usr/bin/env python3
"""Read-only discovery and registry plan; never read stored login credentials."""

import configparser
import io
import json
from pathlib import Path
import re
import sys


def read_ini(path):
    result = configparser.RawConfigParser()
    result.optionxform = str
    if path.exists():
        with path.open() as source:
            result.read_file(source)
    return result


def preferences(path):
    if not path.exists():
        return {}
    result = {}
    for key, value in re.findall(
        r'^\s*user_pref\("([^"\n]+)",\s*(.*?)\);',
        path.read_text(), re.MULTILINE,
    ):
        try:
            result[key] = json.loads(value)
        except ValueError:
            continue
    return result


def has_account(path):
    # user.js alone is only a bootstrap, not an account used by Thunderbird.
    prefs = preferences(path / 'prefs.js')
    for account in str(prefs.get('mail.accountmanager.accounts', '')).split(','):
        server = prefs.get('mail.account.' + account.strip() + '.server')
        prefix = 'mail.server.' + str(server) + '.'
        if (prefs.get(prefix + 'type') in ('imap', 'pop3', 'nntp')
                and prefs.get(prefix + 'hostname')):
            return True
    return False


def profile_path(root, registry, section):
    value = registry.get(section, 'Path')
    return (root / value if registry.get(section, 'IsRelative', fallback='1') == '1'
            else Path(value)).resolve()


def render(registry):
    output = io.StringIO()
    registry.write(output, space_around_delimiters=False)
    return output.getvalue()


def plan(home, profile_dir, profile_name):
    home = Path(home)
    # A legacy directory takes precedence over the XDG registry on this build.
    roots = [home / '.thunderbird', home / '.config/thunderbird']
    root = next((p for p in roots if p.exists()), roots[1])
    registries = {p: read_ini(p / 'profiles.ini') for p in roots}
    candidates = []
    install_ids = set()
    for base, registry in registries.items():
        installs = read_ini(base / 'installs.ini')
        defaults = {registry.get(s, 'Default', fallback='')
                    for s in registry.sections() if s.startswith('Install')}
        defaults.update(installs.get(s, 'Default', fallback='')
                        for s in installs.sections())
        for section in registry.sections():
            if not re.fullmatch(r'Profile\d+', section):
                continue
            path = profile_path(base, registry, section)
            if has_account(path):
                candidates.append((registry.get(section, 'Path') not in defaults,
                                   base != root, str(path), path))
        # Reuse installation associations, including those in the other root.
        install_ids.update(s[7:] for s in registry.sections() if s.startswith('Install'))
        install_ids.update(installs.sections())
        # Also find unregistered profiles, without following arbitrary subtrees.
        if base.exists():
            for child in sorted(base.iterdir()):
                if child.is_dir() and has_account(child):
                    candidates.append((True, base != root, str(child.resolve()), child.resolve()))
    existing = bool(candidates)
    selected = min(candidates)[3] if existing else root / profile_dir
    if not existing:
        number = 0
        while selected.exists():
            bootstrap = selected / 'user.js'
            if (not (selected / 'prefs.js').exists() and bootstrap.exists()
                    and bootstrap.read_text().startswith('// Managed by Ansible from profile_desktop_gnome')):
                break
            number += 1
            selected = root / (profile_dir + '-' + str(number))
    registry = registries[root]
    section = next((s for s in registry.sections()
                    if re.fullmatch(r'Profile\d+', s)
                    and profile_path(root, registry, s) == selected), None)
    if section is None:
        number = 0
        while registry.has_section('Profile' + str(number)):
            number += 1
        section = 'Profile' + str(number)
        registry.add_section(section)
        registry.set(section, 'Name', profile_name if not existing else selected.name)
        registry.set(section, 'IsRelative', '0')
        registry.set(section, 'Path', str(selected))
    for other in registry.sections():
        if re.fullmatch(r'Profile\d+', other):
            registry.remove_option(other, 'Default')
    registry.set(section, 'Default', '1')
    if not registry.has_section('General'):
        registry.add_section('General')
    registry.set('General', 'StartWithLastProfile', '1')
    registry.set('General', 'Version', '2')
    value = registry.get(section, 'Path')
    installs = read_ini(root / 'installs.ini')
    for install in sorted(install_ids):
        # Do not redirect a separate installation with another configured account.
        defaults = []
        for base, source in registries.items():
            default = source.get('Install' + install, 'Default', fallback='')
            if not default:
                default = read_ini(base / 'installs.ini').get(install, 'Default', fallback='')
            if default:
                defaults.append((base / default).resolve())
        if any(p != selected and has_account(p) for p in defaults):
            continue
        for target, name in ((registry, 'Install' + install), (installs, install)):
            if not target.has_section(name):
                target.add_section(name)
            target.set(name, 'Default', value)
            target.set(name, 'Locked', '1')
    return dict(root=str(root), profile=str(selected), existing_account=existing,
                profiles_ini=render(registry), installs_ini=render(installs))


if __name__ == '__main__':
    print(json.dumps(plan(*sys.argv[1:])))
