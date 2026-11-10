# ecaas Java 11 dev container on deadalus

From the AnsiblePlaybook checkout **in Fedora WSL 2 on deadalus**:

```sh
ansible-playbook ansible/site.yml --limit deadalus --tags ecaas_devcontainer -K
```

This creates `~/Work/sipo/ecaas/.devcontainer/` and deploys `devcontainer.json`,
`Dockerfile` and `bashrc`, backing up previous versions if they change. It does
not clone or modify application sources, change VS Code's Windows settings, or
start Docker containers. The Docker context selection remains in the local
WSL/VS Code setup.

Confirm that `docker context show` is `default` and `docker info` shows the local
Fedora engine. Open `~/Work/ecaas` using `code .` from Fedora and select
**Dev Containers: Reopen in Container** (or **Rebuild Container** if already open).
Do not use the production context to build or open the workspace.

The container uses Java 11 for the application and Maven, and Java 21 only for
the Java and Spring language servers. VS Code installs the Java and Spring Boot
extension packs, XML, YAML and the VSCode Great Icons theme (selected as the
file icon theme) inside the container. The Java
pack includes Maven, the Java debugger and test integration. Prefer the project's
Maven wrapper where present. Node is provided for the Claude and Cline CLIs.

Git is installed in the container. The image uses the repository's portable Bash
configuration: prompt with Git status, aliases, history search, completion,
`fzf` and `zoxide`. The shared `.bashrc.aliases` is copied minus the
production `npm-tunnel` alias. The image
does not load the WSL host's production aliases or Bash history.
Run the deploy and rebuild the container to pick up changes to the shared Bash
configuration.

## Git, HTTPS, and SSH

The image provides Git, Git LFS, delta, OpenSSH and GnuPG. It includes the
managed workstation Git configuration from a read-only mount at runtime,
with VS Code rather than Bob as the diff and merge tool. Git identity and
signing configuration stay outside the workspace and image layers.

Before deploying, ensure the existing WSL certificate
`~/.local/share/certs/ecaas.datacenter.comune.roma.crt` is available. The
playbook checks and mounts that file read-only. It also mounts
`datacenter.comune.roma.crt` from the same directory if present. These files
are scoped to their GitLab URLs in Git; the image does not disable TLS
verification or add the internal certificates to its global trust store.
Recreate the container after replacing a certificate on the host.

Open the project from Fedora WSL so VS Code Dev Containers can reuse WSL's
HTTPS credential helper (including an existing `.git-credentials` used by
`credential.helper=store`) and forward the SSH agent if configured. GPG
signing remains enabled and needs the work key available through the GPG
agent. The WSL `~/.m2` (repository cache and `settings*.xml`, which may hold Maven
server credentials) is bind-mounted read-write at `/home/vscode/.m2`. No other
credential file, SSH private key, or GPG private key is copied or mounted by
the playbook. Do not forward a production SSH identity to this
development workspace.

To verify GitLab access from the container without changing the repo, run
`git ls-remote origin HEAD` after checking that `origin` is the expected
GitLab repository.

## Docker

The `docker-outside-of-docker` Dev Container feature installs the Docker CLI
and Compose plugin and shares the local Fedora WSL engine's socket
(`/var/run/docker.sock`) with the container. Containers started from inside are
siblings on the WSL engine, and bind-mount sources resolve on the WSL host.
The socket grants root-equivalent control of that engine, and the container
never sees the host's Docker contexts, so the production context is
unreachable. Verify with `docker info` and `docker compose version`.

## GitLab CLI

`glab` 1.114.0 is installed from the official `.deb` with a pinned SHA-256
checksum (amd64 and arm64). The WSL `~/.config/glab-cli` is bind-mounted
read-write at `/home/vscode/.config/glab-cli`, so hosts, API tokens and
`skip_tls_verify` settings are shared with the host and readable by anything in
the container; changes made by `glab` inside affect the WSL configuration.
`GITLAB_TOKEN` and similar variables from the host are not forwarded.

## Agent configuration and smoke test

Claude and Cline use the WSL configuration directly: `~/.claude` and `~/.cline`
are bind-mounted read-write at `/home/vscode/.claude` and `/home/vscode/.cline`,
and `~/.config/ai` read-only at `/home/vscode/.config/ai`. Settings, rules,
skills, MCP configuration, sessions and **credential stores** are therefore
shared with, and visible to, the container, and changes made inside it affect
the WSL home. Host paths and tools referenced by rules or skills may need
adaptation. The WSL login is the `ANTHROPIC_AUTH_TOKEN` exported by
`~/.bashrc.d/60-claude-code.sh`, not the OAuth file. `remoteEnv` forwards it with
`${localEnv:ANTHROPIC_AUTH_TOKEN}`: the value is never written to the repository
or the image, but it is visible to processes in the container. VS Code must
therefore be started from a WSL shell that exports it (`code .` after opening a
new terminal; fully close any running VS Code server first). The endpoint and
model come from the mounted `settings.json`. With `CLAUDE_CONFIG_DIR` set, Claude reads its account state from
`~/.claude/.claude.json` instead of `~/.claude.json`, so the playbook seeds the
missing `oauthAccount`, `hasCompletedOnboarding` and `userID` keys there from
the WSL file without overwriting existing keys (`~/.claude.json` itself is not
mounted); VS Code global storage is not shared
either, so legacy Cline settings kept only there are not migrated. The full
host home is not mounted. `~/.local/state/ecaas-devcontainer/` now holds only
the rendered Git configuration.


From the integrated terminal inside the Dev Container, verify:

```sh
java -version
mvn -v
git --version
delta --version
claude --version
cline --version
```

Both Java and Maven should report Java 11. Run the project's Maven tests and
check that the Spring Boot Dashboard, Java debugger and both AI panels open.
