# cdp Java 25 / Node 20 dev container on deadalus

Same toolset and mounts as the [ecaas container](deadalus-ecaas-devcontainer.md)
(Git configuration and GitLab CAs, Bash configuration, `~/.m2`, `~/.claude`,
`~/.cline`, `~/.config/ai`, Docker outside of Docker, Claude Code, Cline, delta,
Great Icons), with these differences:

- Java 25 (`mcr.microsoft.com/devcontainers/java:25-bookworm`) is the default JDK
  and also runs the Java and Spring language servers; there is no second JDK.
- Maven is `workstation_maven_version`; Node is
  `workstation_cdp_node_version` (20.18.3) from the official Node image, used by
  the Angular Module Federation front ends and the Claude/Cline CLIs.
- Angular Language Service and ESLint are added; forwarded ports are 4200, 4201,
  4202, 4210 (front ends) and 8083, 8084 (`mediation-ansc`, `ansc-allegati`).
- `kubectl` 1.37.1 and Helm 4.2.2 are installed from the official releases with
  pinned SHA-256 checksums (amd64 and arm64), and the Kubernetes VS Code
  extension is added. The WSL `~/.kube` is bind-mounted read-write at
  `/home/vscode/.kube`, so contexts, tokens and cached data are shared with the
  host; the current `config` embeds the Rancher CA and credentials, which are
  therefore readable by anything in the container. The Rancher endpoint must be
  reachable from the container (VPN). `KUBECONFIG` on the host is not forwarded.
- `glab` 1.114.0 (pinned checksum) is installed and `~/.config/glab-cli` is
  mounted read-write, as described in the ecaas document (tokens included).

Legacy `serv_roma-capitale-*` modules target Java 21 / Spring Boot 3.3.4 and
are not covered by this image's JDK.

The workspace is multi-repo and not a Git repository itself; open
`~/Work/sipo/cdp` from Fedora WSL. Maven needs the internal Nexus (VPN) and
`-s settings.xml`, as described in the workspace `AGENTS.md`.

```sh
ansible-playbook ansible/site.yml --limit deadalus --tags cdp_devcontainer -K
```

The deploy writes `~/Work/sipo/cdp/.devcontainer/` (`devcontainer.json`,
`Dockerfile`, `bashrc`, `bashrc.aliases`), backing up changed files. It shares
the rendered Git configuration in `~/.local/state/ecaas-devcontainer/git` with
the ecaas container and therefore also requires the ecaas GitLab CA. Then run
**Dev Containers: Reopen in Container**. The `ANTHROPIC_AUTH_TOKEN` forwarding
and credential caveats are the same as for ecaas.

Verify inside: `java -version`, `mvn -v`, `node -v` (v20.18.3), `docker info`.
