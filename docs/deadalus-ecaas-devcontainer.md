# ecaas Java 11 dev container on deadalus

From the AnsiblePlaybook checkout **in Fedora WSL 2 on deadalus**:

```sh
ansible-playbook ansible/site.yml --limit deadalus --tags ecaas_devcontainer -K
```

This creates `~/Work/ecaas/.devcontainer/` and deploys `devcontainer.json`,
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
extension packs, XML, YAML, Claude Code and Cline inside the container. The Java
pack includes Maven, the Java debugger and test integration. Prefer the project's
Maven wrapper where present. Node is provided for the Claude and Cline CLIs.

Git is installed in the container. The image uses the repository's portable Bash
configuration: prompt with Git status, aliases, history search, completion,
`fzf` and `zoxide`. The image
does not load the WSL host's Mise hook, production aliases, or Bash history.
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
agent. No credential file, SSH private key, or GPG private key is copied or
mounted by the playbook. Do not forward a production SSH identity to this
development workspace.

To verify GitLab access from the container without changing the repo, run
`git ls-remote origin HEAD` after checking that `origin` is the expected
GitLab repository.

## Agent configuration and smoke test

Claude and Cline seed only the supported settings, instructions, rules and
skills present in the Fedora home into `~/.local/state/ecaas-devcontainer/`
on the host. The initial import does not overwrite existing container settings
or synchronize later changes back to WSL. Rules and skills imported from WSL
must be trusted; host paths and tools referenced by them may need adaptation.
Dedicated credential stores, provider files, VS Code global storage, and MCP
configuration are not imported. Do not embed secrets in the settings or rules
being imported. Sign in or configure providers inside the container when
prompted; legacy Cline settings kept only in VS Code are not migrated.
The state directory is private and must not be committed. Neither the Docker
socket nor the full host home is mounted.

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
