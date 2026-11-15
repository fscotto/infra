#!/usr/bin/env python3
"""Generate a project devcontainer using host Git and coding-agent configuration."""
import argparse
import json
import os
from pathlib import Path
import shlex
import tempfile

PROFILES = {
    'c-cpp': ('mcr.microsoft.com/devcontainers/base:bookworm',
              'build-essential clang clangd cmake gdb valgrind universal-ctags cscope',
              ['ms-vscode.cpptools', 'ms-vscode.cmake-tools']),
    'go': ('mcr.microsoft.com/devcontainers/go:1.25-bookworm', '', ['golang.go']),
    'rust': ('mcr.microsoft.com/devcontainers/rust:1-bookworm', '', ['rust-lang.rust-analyzer']),
    'python': ('mcr.microsoft.com/devcontainers/python:3.13-bookworm', '',
               ['ms-python.python', 'charliermarsh.ruff']),
    'node': ('mcr.microsoft.com/devcontainers/javascript-node:22-bookworm', '', ['esbenp.prettier-vscode']),
    'java': ('mcr.microsoft.com/devcontainers/java:21-bookworm', 'maven', ['vscjava.vscode-java-pack']),
    'infra': ('mcr.microsoft.com/devcontainers/python:3.13-bookworm', 'shellcheck shfmt',
              ['redhat.ansible', 'redhat.vscode-yaml']),
}
AGENTS = {
    'codex': ('@openai/codex', ['.codex']),
    'cline': ('cline', ['.cline', '.agents']),
    'opencode': ('opencode-ai', ['.config/opencode', '.local/share/opencode', '.local/state/opencode']),
    'claude': ('@anthropic-ai/claude-code@2.1.312', ['.claude']),
    'gemini': ('@google/gemini-cli', ['.gemini']),
}


def generate(project, profile, home, agents, force=False):
    project, home = Path(project).resolve(), Path(home).resolve()
    if not project.is_dir():
        raise ValueError(f'Project directory does not exist: {project}')
    if home == Path('/') or any(c in str(home) for c in '\n\r$,'):
        raise ValueError('Unsupported host home path')
    target = project / '.devcontainer'
    if target.is_symlink():
        raise ValueError('Refusing a symlinked .devcontainer directory')
    if target.exists() and not force:
        raise ValueError('.devcontainer already exists; use --force to replace generated files')
    mount_paths = [('.gitconfig', True), ('.config/git', True), ('.gitignore_global', True),
                   ('.config/ai', True)]
    for agent in agents:
        for path in AGENTS[agent][1]:
            if not (home / path).is_dir():
                raise ValueError(f'Missing host directory for {agent}: {home / path}')
            mount_paths.append((path, False))
    # Claude uses both a config directory and a separate onboarding/account file.
    if 'claude' in agents:
        mount_paths.append(('.claude.json', False))
    mounts = []
    for path, readonly in mount_paths:
        if (home / path).exists():
            mounts.append({'type': 'bind', 'source': '${localEnv:HOME}/' + path,
                           'target': '/run/host-gitconfig' if path == '.gitconfig' else str(home / path),
                           'readOnly': readonly})
    base, packages, extensions = PROFILES[profile]
    dockerfile = f'''FROM {base}
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \\
    bash-completion ca-certificates curl fzf git git-lfs gnupg openssh-client ripgrep zoxide {packages} \\
    && rm -rf /var/lib/apt/lists/*
'''
    dockerfile += r'''RUN apt-get update \
    && arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
      amd64) sha256=ea4f0222950ee750a3d38dd80d03bce4cee07a3f63928fc47548383bcaf23093 ;; \
      arm64) sha256=0edc36cf514f1bd84becac3e94ee8ae9f8818c6a1f99f7b2ee67b362afa253d3 ;; \
      *) echo "Unsupported architecture for delta: $arch" >&2; exit 1 ;; \
    esac \
    && curl -fsSL --retry 3 "https://github.com/dandavison/delta/releases/download/0.19.2/git-delta_0.19.2_${arch}.deb" -o /tmp/git-delta.deb \
    && echo "$sha256  /tmp/git-delta.deb" | sha256sum -c - \
    && apt-get install -y --no-install-recommends /tmp/git-delta.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/git-delta.deb
'''
    # Preserve absolute references from host agent configuration without mounting the home.
    if home != Path('/home/vscode'):
        dockerfile += 'RUN usermod --home ' + shlex.quote(str(home)) + ' --move-home vscode\n'
    dockerfile += 'ENV HOME=' + shlex.quote(str(home)) + '\n'
    if profile in ('python', 'infra'):
        tools = 'uv ruff ty' if profile == 'python' else 'ansible-core ansible-lint yamllint'
        dockerfile += f'RUN python -m pip install --no-cache-dir {tools}\n'
    features = {}
    if agents and profile != 'node':
        features['ghcr.io/devcontainers/features/node:1'] = {'version': '22'}
    config = {
        'name': f'{project.name} — {profile}',
        'build': {'dockerfile': 'Dockerfile'},
        'remoteUser': 'vscode', 'updateRemoteUserUID': True,
        'containerEnv': {'HOME': str(home)},
        'mounts': mounts,
        'customizations': {'vscode': {'extensions': extensions}},
    }
    if agents:
        # Node feature is installed after the Dockerfile, so install CLIs at creation.
        npm = ' '.join(shlex.quote(AGENTS[a][0]) for a in agents)
        config['postCreateCommand'] = f'sudo npm install --global --no-audit --no-fund {npm}'
    if features:
        config['features'] = features
    if 'claude' in agents:
        config['remoteEnv'] = {'ANTHROPIC_AUTH_TOKEN': '${localEnv:ANTHROPIC_AUTH_TOKEN}'}
    dockerfile += 'USER vscode\n'
    if (home / '.gitconfig').exists():
        dockerfile += 'RUN git config --global include.path /run/host-gitconfig\n'
    for name, content in [('Dockerfile', dockerfile),
                          ('devcontainer.json', json.dumps(config, indent=2) + '\n')]:
        destination = target / name
        if destination.is_symlink():
            raise ValueError(f'Refusing symlink: {destination}')
    target.mkdir(exist_ok=True)
    for name, content in [('Dockerfile', dockerfile),
                          ('devcontainer.json', json.dumps(config, indent=2) + '\n')]:
        with tempfile.NamedTemporaryFile(mode='w', dir=target, delete=False) as stream:
            stream.write(content)
            temp = Path(stream.name)
        temp.chmod(0o644)
        os.replace(temp, target / name)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    parser.add_argument('--language', required=True, choices=PROFILES)
    parser.add_argument('--agents', default='auto',
                        help='Comma-separated codex,cline,opencode,claude,gemini; auto detects host config; none disables')
    parser.add_argument('--force', action='store_true', help='Replace the two generated files')
    args = parser.parse_args()
    home = Path.home()
    if args.agents == 'auto':
        agents = [a for a, (_, paths) in AGENTS.items() if all((home / p).is_dir() for p in paths)]
    else:
        agents = [] if args.agents == 'none' else list(dict.fromkeys(args.agents.split(',')))
    if any(a not in AGENTS for a in agents):
        parser.error('Unknown agent; choose ' + ', '.join(AGENTS))
    try:
        target = generate(args.project, args.language, home, agents, args.force)
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')
    print(f'Created {target}; agents: {", ".join(agents) or "none"}')
    print('Open the project in VS Code and choose Dev Containers: Reopen in Container.')


if __name__ == '__main__':
    main()
