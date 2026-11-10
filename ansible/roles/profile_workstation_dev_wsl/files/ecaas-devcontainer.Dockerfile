ARG MAVEN_VERSION=3.9.16
FROM docker.io/library/maven:${MAVEN_VERSION}-eclipse-temurin-11 AS maven
FROM docker.io/library/node:22.23.4-bookworm-slim AS node
# Java 21 runs the language servers only. The final image keeps Java 11 on PATH.
FROM mcr.microsoft.com/devcontainers/java:21-bookworm AS ide
FROM mcr.microsoft.com/devcontainers/java:11-bookworm
USER root
COPY --from=ide /usr/lib/jvm/msopenjdk-current/ /opt/jdk-21/
COPY --from=maven /usr/share/maven/ /usr/share/maven/
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm/ /usr/local/lib/node_modules/npm/
RUN ln -s /usr/share/maven/bin/mvn /usr/local/bin/mvn \
    && ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && java -version \
    && /opt/jdk-21/bin/java -version \
    && mvn -v \
    && npm install --global --no-audit --no-fund @anthropic-ai/claude-code@2.1.312 cline@3.0.74 \
    && npm cache clean --force
RUN apt-get update \
    && apt-get install -y --no-install-recommends bash-completion ca-certificates curl fzf git git-lfs gnupg openssh-client zoxide \
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
ARG GLAB_VERSION=1.114.0
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
      amd64) sha256=6df680f88a2a45700d1dd6a08a44a74838473ef3dcc5cb1ad243f4d1fd704ad0 ;; \
      arm64) sha256=c2bcb44cc10d849cccb879e687f3b9e102a3415c3d02f0cecfd9ce1442519350 ;; \
      *) echo "Unsupported architecture for glab: $arch" >&2; exit 1 ;; \
    esac \
    && curl -fsSL --retry 3 "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${arch}.deb" -o /tmp/glab.deb \
    && echo "$sha256  /tmp/glab.deb" | sha256sum -c - \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/glab.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/glab.deb \
    && glab --version
COPY --chown=vscode:vscode bashrc /home/vscode/.bashrc
COPY --chown=vscode:vscode bashrc.aliases /home/vscode/.bashrc.aliases
USER vscode
# Keep this file writable so VS Code can register its Git credential helper.
RUN git config --file /home/vscode/.gitconfig include.path /run/ecaas-git/gitconfig
