# syntax=docker/dockerfile:1.7

ARG NODE_IMAGE=node:24.15.0-bookworm
ARG RUNTIME_IMAGE=debian:12.12-slim

FROM ${NODE_IMAGE} AS build

ARG TARGETARCH
ARG CODE_SERVER_VERSION=4.123.0
ARG VSCODE_VERSION=1.123.0
ARG RUNE_SOURCE_REVISION=unknown
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DISABLE_V8_COMPILE_CACHE=1 \
    ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    npm_config_build_from_source=true

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    jq \
    libkrb5-dev \
    pkg-config \
    python3 \
    quilt \
    rsync \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN test -f lib/vscode/package.json \
  || { echo >&2 "lib/vscode is missing; initialize the pinned submodule before building"; exit 1; }
RUN test "$(jq -r .version lib/vscode/package.json)" = "${VSCODE_VERSION}" \
  || { echo >&2 "VSCODE_VERSION does not match the pinned lib/vscode version"; exit 1; }
RUN grep -Fq "## [${CODE_SERVER_VERSION}]" CHANGELOG.md \
  || { echo >&2 "CODE_SERVER_VERSION does not match CHANGELOG.md"; exit 1; }
RUN quilt push -a

# Match the upstream release build's VS Code bootstrap while avoiding test-only
# dependencies in this production image build.
RUN --mount=type=cache,target=/root/.npm \
    cd lib/vscode/build \
  && npm ci \
  && cd .. \
  && . ./build/azure-pipelines/linux/setup-env.sh \
  && node build/npm/preinstall.ts \
  && cd /src \
  && SKIP_SUBMODULE_DEPS=1 npm ci \
  && cd lib/vscode \
  && npm ci

RUN case "${TARGETARCH}" in \
      amd64) export VSCODE_TARGET=linux-x64 ;; \
      arm64) export VSCODE_TARGET=linux-arm64 ;; \
      *) echo >&2 "Unsupported target architecture: ${TARGETARCH}"; exit 1 ;; \
    esac \
  && export VERSION="${CODE_SERVER_VERSION}" \
  && export BUILD_SOURCEVERSION="${RUNE_SOURCE_REVISION}" \
  && npm run build \
  && npm run build:vscode \
  && KEEP_MODULES=1 npm run release

FROM ${RUNTIME_IMAGE} AS runtime

ARG CODE_SERVER_VERSION=4.123.0
ARG VSCODE_VERSION=1.123.0
ARG RUNE_SOURCE_REVISION=unknown
ARG RUNE_SOURCE_URL=""
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="Rune IDE" \
      org.opencontainers.image.description="Rune's patched code-server and VS Code distribution" \
      org.opencontainers.image.source="${RUNE_SOURCE_URL}" \
      org.opencontainers.image.revision="${RUNE_SOURCE_REVISION}" \
      org.opencontainers.image.version="${CODE_SERVER_VERSION}" \
      io.rune.code-server.version="${CODE_SERVER_VERSION}" \
      io.rune.vscode.version="${VSCODE_VERSION}"

ENV HOME=/home/coder \
    USER=coder \
    LANG=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    openssh-client \
    procps \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --uid 1000 --shell /bin/bash coder

COPY --from=build --chown=coder:coder /src/release /usr/lib/rune
COPY --chown=coder:coder customization/i18n/en.json /usr/lib/rune/customization/i18n/en.json
COPY --chown=coder:coder customization/extensions/ /usr/lib/rune/customization/extensions/

USER coder
WORKDIR /home/coder
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["/usr/lib/rune/lib/node", "-e", "const http=require('http');const req=http.get('http://127.0.0.1:8080/healthz',res=>{let body='';res.on('data',chunk=>body+=chunk);res.on('end',()=>{try{const health=JSON.parse(body);process.exit(res.statusCode===200&&health.status==='alive'?0:1)}catch{process.exit(1)}})});req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1)})"]

ENTRYPOINT ["/usr/lib/rune/bin/code-server"]
CMD ["--bind-addr", "0.0.0.0:8080", "--auth", "password", "--app-name", "Rune IDE", "--welcome-text", "Welcome to Rune IDE", "--i18n", "/usr/lib/rune/customization/i18n/en.json", "."]
