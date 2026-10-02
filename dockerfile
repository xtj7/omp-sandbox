# syntax=docker/dockerfile:1
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System packages (web dev for TS/Go)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      git \
      openssh-client \
      tmux \
      htop \
      nano \
      less \
      build-essential \
      pkg-config \
      python3 \
      jq \
      ripgrep \
      unzip \
      sqlite3 \
      docker.io \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Node.js — latest stable, arch-aware (Apple Silicon + Intel)
# ---------------------------------------------------------------------------
RUN set -eux; \
    arch=$(dpkg --print-architecture); \
    case "$arch" in \
      amd64) node_arch=x64 ;; \
      arm64) node_arch=arm64 ;; \
      *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    node_tgz=$(curl -fsSL https://nodejs.org/dist/latest/ \
      | grep -oE "node-v[0-9]+\.[0-9]+\.[0-9]+-linux-${node_arch}\.tar\.xz" \
      | head -n1); \
    curl -fsSL "https://nodejs.org/dist/latest/${node_tgz}" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.xz

# ---------------------------------------------------------------------------
# Go — latest stable (queried from go.dev at build time)
# ---------------------------------------------------------------------------
RUN set -eux; \
    arch=$(dpkg --print-architecture); \
    case "$arch" in \
      amd64) go_arch=amd64 ;; \
      arm64) go_arch=arm64 ;; \
      *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    go_version=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n1 | tr -d '\r'); \
    curl -fsSL "https://go.dev/dl/${go_version}.linux-${go_arch}.tar.gz" -o /tmp/go.tar.gz; \
    tar -xzf /tmp/go.tar.gz -C /usr/local; \
    rm -f /tmp/go.tar.gz

# ---------------------------------------------------------------------------
# User + environment
# ---------------------------------------------------------------------------
RUN useradd -ms /bin/bash omp

ENV HOME=/home/omp \
    PATH=/home/omp/.local/bin:/home/omp/.npm-global/bin:/usr/local/go/bin:/home/omp/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GOPATH=/home/omp/go \
    PLAYWRIGHT_BROWSERS_PATH=/home/omp/.cache/ms-playwright

# .omp/agent exists so the models.yml bind mount has a target dir
RUN mkdir -p /home/omp/.omp/agent /home/omp/dev /home/omp/go/bin /home/omp/.npm-global \
    && chown -R omp:omp /home/omp

# Playwright + Chromium (needs root for apt deps)
USER root
RUN HOME=/root npm install -g playwright \
    && playwright install --with-deps chromium \
    && chown -R omp:omp /home/omp/.cache

# Expose the Playwright Chromium as a "system" browser for tools that only
# search PATH / PUPPETEER_EXECUTABLE_PATH (e.g. omp's browser tool, whose
# managed Chromium has no linux/arm64 build)
RUN CR=$(find /home/omp/.cache /root/.cache -path "*ms-playwright*" -name chrome -type f 2>/dev/null | head -n1) \
    && test -n "$CR" \
    && echo "Chromium found at: $CR" \
    && ln -s "$CR" /usr/local/bin/chromium \
    && ln -s "$CR" /usr/local/bin/google-chrome

# ---------------------------------------------------------------------------
# Dev tools as the omp user
# ---------------------------------------------------------------------------

# hand the browser cache back to the omp user (it was created by root above)
USER omp
RUN npm config set prefix /home/omp/.npm-global \
    && npm install -g \
       typescript \
       typescript-language-server \
       vscode-langservers-extracted \
    && go install golang.org/x/tools/gopls@latest \
    && git config --global --add safe.directory '*'

# oh-my-pi — official installer [3]. No bun in the image, so it takes the
# prebuilt-binary path and lands in $HOME/.local/bin (already on PATH).
RUN curl -fsSL https://omp.sh/install | sh

WORKDIR /home/omp/dev
CMD ["tmux", "new-session", "-A", "-s", "omp"]
