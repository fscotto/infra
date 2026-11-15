# Reusable project devcontainers

`scripts/devcontainer.py` is a Python 3 CLI (standard library only). Run it on
**the development host**, from an `infra` checkout, against an existing project:

```sh
python3 scripts/devcontainer.py ~/src/my-project --language go
python3 scripts/devcontainer.py ~/src/my-project --language python --agents codex,cline
python3 scripts/devcontainer.py ~/src/my-project --language c-cpp --agents none
```

Profiles: `c-cpp`, `go`, `rust`, `python`, `node`, `java`, `infra`. They generate
`.devcontainer/devcontainer.json` and `Dockerfile`. Open the project in local VS
Code (in Fedora WSL on deadalus) and choose **Reopen in Container**. The generator
never builds or starts a container, selects a Docker context, modifies application
sources, or removes host packages. Existing `.devcontainer` directories are refused;
`--force` replaces only the two generated files, so commit or back up edits first.

The definitions live centrally in the generator; generated files are standalone.
Regenerate explicitly to take updates. Profile images select a language version
or release family, not immutable digests; npm agents other than Claude currently
resolve the latest release at container creation, matching the host lifecycle.
Rebuilds are therefore not bit-for-bit reproducible. Pin image digests and agent
versions in generated project files when a project requires that guarantee.
Project-specific dependencies, ports, services and build commands belong in the
project configuration. The `infra` profile provides Ansible and linters; install
that project's collection requirements inside it separately.

## Shared Git and agents

Like the ecaas/cdp model, executables run inside the container and personal
configuration stays on the host. The generator detects existing configuration
paths without reading credentials. With `--agents auto` (the default), it selects
agents whose configuration directories already exist. Explicit agent selection
fails if required directories are missing. Supported agents: `codex`, `cline`,
`opencode`, `claude`, `gemini`. IBM Bob and desktop applications are not included.

Host `~/.gitconfig` is mounted read-only at `/run/host-gitconfig` and included from
a writable container Git config, allowing VS Code to register its credential
helper. Existing `~/.config/git` and `~/.gitignore_global` are mounted read-only.
Git, Git LFS, delta, OpenSSH and GnuPG are installed. VS Code Dev Containers handles
SSH-agent and HTTPS credential-helper forwarding; start VS Code from the host
session with its working agent. No SSH/GPG private-key directories are mounted.
GPG signing needs a functioning agent-forwarding setup and a test with your key;
the generator does not provision it. Host-specific helpers, `pinentry`, external
Git includes, conditional includes and CA paths still need container-compatible
configuration or additional narrowly scoped mounts. Recreate the container after
replacing a bind-mounted configuration file atomically on the host.

`~/.config/ai` is mounted read-only when present. Selected agents mount their host
configuration/state directories read-write, including credentials, sessions and
rules; changes inside the container affect the host. OpenCode also shares its
XDG data/state directories. The container user remains `vscode`, with its home set
to the **same absolute path as the generating host**, so Codex's absolute
`model_instructions_file` keeps working. This does not mount the full home.
For a different host home path, regenerate there. Host-only programs referenced
by agent settings are not made available automatically.

Claude also mounts `~/.claude.json` when present and forwards
`ANTHROPIC_AUTH_TOKEN` using `${localEnv:ANTHROPIC_AUTH_TOKEN}` as on deadalus.
Start VS Code from a shell that exports it; no token value is generated. Host
keyring-backed logins require separate integration; sharing a directory does not
forward the desktop keyring. VS Code extension storage is not shared.

Only existing paths are mounted. Regenerate after configuring an additional
agent. Generated files use `${localEnv:HOME}` for mount sources and contain no
credential contents, but do contain the host's absolute home path.

## Runtime and validation

Use a local development container engine. Docker CE is currently provisioned on
deadalus; ikaros explicitly has Podman, while nymph's runtime needs verification.
Podman requires VS Code's `dev.containers.dockerPath` and compatible rootless/UID
configuration; generation alone does not configure it. SELinux bind-mount access
must also be validated on Fedora. Do not recursively relabel the personal home.
No engine socket is mounted inside these containers by default; add access only
for projects that need to launch sibling containers.

Host-side regression checks:

```sh
python3 -m unittest discover -s tests -p test_devcontainer.py -v
```

On the target host, build/open a generated project, check the language toolchain,
`git config --show-origin --get user.email`, `git ls-remote origin HEAD` against
the expected development remote, and each selected agent's version/login.
Run project tests and verify signing if enabled. These runtime checks require the
real host and are separate from generator tests. Existing ecaas/cdp Ansible
provisioning is unchanged.
