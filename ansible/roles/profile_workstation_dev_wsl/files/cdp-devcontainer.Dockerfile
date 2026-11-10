ARG MAVEN_VERSION=3.9.16
ARG NODE_VERSION=20.18.3
FROM docker.io/library/maven:${MAVEN_VERSION}-eclipse-temurin-25 AS maven
FROM docker.io/library/node:${NODE_VERSION}-bookworm-slim AS node
# Java 25 runs both the application and the language servers.
FROM mcr.microsoft.com/devcontainers/java:25-bookworm
USER root
COPY --from=maven /usr/share/maven/ /usr/share/maven/
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm/ /usr/local/lib/node_modules/npm/
RUN ln -s /usr/share/maven/bin/mvn /usr/local/bin/mvn \
    && ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && java -version \
    && mvn -v \
    && node --version \
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
ARG KUBECTL_VERSION=1.37.1
ARG HELM_VERSION=4.2.2
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
      amd64) kubectl_sha=65691ff77eb6fa44c908b77a1082c9f092c3b9733b5cefabec0d1104890e21a8; helm_sha=9adafecab4d406853bba163a70e9f104f47dbbf65ce24b7653bae7e36150bcb6 ;; \
      arm64) kubectl_sha=ff749f4b78d9c4f1ec87307df9b50119ed819e2094aa9810cb9acffc3286c8c7; helm_sha=78803142087a0069fa4b50d3f32a84d3ef25c14d1ee8a40fbccf86a6216d2f36 ;; \
      *) echo "Unsupported architecture for kubectl/helm: $arch" >&2; exit 1 ;; \
    esac \
    && curl -fsSL --retry 3 "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" -o /tmp/kubectl \
    && echo "$kubectl_sha  /tmp/kubectl" | sha256sum -c - \
    && install -m 0755 /tmp/kubectl /usr/local/bin/kubectl \
    && curl -fsSL --retry 3 "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${arch}.tar.gz" -o /tmp/helm.tgz \
    && echo "$helm_sha  /tmp/helm.tgz" | sha256sum -c - \
    && tar -xzf /tmp/helm.tgz -C /tmp "linux-${arch}/helm" \
    && install -m 0755 "/tmp/linux-${arch}/helm" /usr/local/bin/helm \
    && rm -rf /tmp/kubectl /tmp/helm.tgz "/tmp/linux-${arch}" \
    && kubectl version --client \
    && helm version --short
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
