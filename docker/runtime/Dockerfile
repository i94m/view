# 基础镜像由本仓库的 docker/base/ 构建（见 .github/workflows/package.yml），
# 默认取 CI 推送的 tag；本地可用 --build-arg BASE_IMAGE=... 覆盖。
ARG BASE_IMAGE=ghcr.io/i94m/view:php8.4
FROM ${BASE_IMAGE}

# 基础镜像默认 USER tk（本地开发用），这里换回 root：daemon、安装、git 凭据都需要 root
USER root

LABEL author="rt.wadewang" \
      description="View php8.4 (debian-13) with Node.js 24 + multica / opencode / openspec / uv / Python / MySQL MCP."

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

# uv 在容器里默认 copy（跨挂载点硬链接会失败）；pip 版本检查提示在固定版本镜像里没有意义。
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_LINK_MODE=copy

ARG NODE_VERSION=24.21.0
ARG MULTICA_VERSION=0.7.0
ARG OPENCODE_VERSION=2.1.4
ARG MYSQL_MCP_VERSION=2.0.9
ARG OPENSPEC_VERSION=1.14.3

# 1) apt packages + git-lfs.
#    git-lfs is extracted manually so its postinst (which execs the Go binary that
#    segfaults under QEMU emulation during multi-arch builds) is skipped; the LFS
#    filters are written with plain `git config`.
#    python3/tini/jq/rg 等与 app/multica 的 runtime 镜像保持能力对齐：agent 常用脚本
#    （python、jq 解析、rg 搜索）以及 tini 作为 PID 1 回收僵尸进程。
#    openssl / procps 基础镜像已有，不再重复安装。
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash-completion \
        curl \
        dnsutils \
        file \
        git \
        iproute2 \
        iputils-ping \
        jq \
        less \
        netcat-openbsd \
        openssh-client \
        python-is-python3 \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        rsync \
        tini \
        unzip \
        vim \
        xz-utils; \
    cd /tmp; \
    apt-get download git-lfs; \
    dpkg-deb -x git-lfs_*.deb /; \
    rm -f /tmp/git-lfs_*.deb; \
    git config --global filter.lfs.clean "git-lfs clean -- %f"; \
    git config --global filter.lfs.smudge "git-lfs smudge -- %f"; \
    git config --global filter.lfs.process "git-lfs filter-process"; \
    git config --global filter.lfs.required true

# 2) Node.js 24 (arch-aware; amd64 -> x64). Drop the bundled headers/man/docs
#    (~67MB) — they are only needed to compile native addons.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) NODE_ARCH=x64 ;; \
      arm64) NODE_ARCH=arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    rm -f /tmp/node.tar.xz; \
    curl --connect-timeout 15 --retry 3 --retry-delay 5 --retry-all-errors -fSL \
      "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
      -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f /tmp/node.tar.xz; \
    rm -rf /usr/local/include/node /usr/local/share/doc /usr/local/share/man \
           /usr/local/CHANGELOG.md /usr/local/LICENSE; \
    node -v && npm -v

# 3) global npm packages. 全部固定版本，保证构建可复现。
#    Strip runtime-dead cruft: demo media, source maps (~90MB), markdown docs and
#    TypeScript declarations (~16MB) — none are used when running the CLIs.
RUN --mount=type=cache,target=/root/.npm \
    npm install -g \
        "@fission-ai/openspec@${OPENSPEC_VERSION}" \
        "@benborla29/mcp-server-mysql@${MYSQL_MCP_VERSION}" && \
    rm -f /usr/local/lib/node_modules/@benborla29/mcp-server-mysql/assets/*.gif && \
    find /usr/local/lib/node_modules -type f \
        \( -name '*.map' -o -name '*.md' -o -name '*.d.ts' \) -delete

# 3b) opencode V2 (npm package @opencode/cli, version via OPENCODE_VERSION).
#     Its postinstall execs the freshly linked binary to self-verify; during a
#     multi-arch build the foreign-arch binary can't run under QEMU, so the script
#     fails. Install with --ignore-scripts and wire the arch-specific platform
#     binary in place ourselves (hardlink, so the nested copy costs no extra space).
RUN --mount=type=cache,target=/root/.npm \
    set -eux; \
    case "${TARGETARCH}" in \
      amd64) OPENCODE_PLATFORM=linux-x64 ;; \
      arm64) OPENCODE_PLATFORM=linux-arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    npm install -g --ignore-scripts "@opencode/cli@${OPENCODE_VERSION}"; \
    CLI_DIR=/usr/local/lib/node_modules/@opencode/cli; \
    SRC="${CLI_DIR}/node_modules/@opencode/cli-${OPENCODE_PLATFORM}/bin/opencode"; \
    test -x "${SRC}"; \
    ln -f "${SRC}" "${CLI_DIR}/bin/opencode.exe" 2>/dev/null || \
        cp "${SRC}" "${CLI_DIR}/bin/opencode.exe"; \
    chmod 0755 "${CLI_DIR}/bin/opencode.exe"; \
    grep -q ELF "${CLI_DIR}/bin/opencode.exe"

# 3c) uv (Python package/project manager) — binaries only (~47MB).
COPY --from=ghcr.io/astral-sh/uv:debian-slim /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

# 4) multica CLI pinned binary install
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) MULTICA_ARCH=amd64 ;; \
      arm64) MULTICA_ARCH=arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    rm -f /tmp/multica.tar.gz /tmp/multica; \
    for url in \
      "https://ghfast.top/https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/multica-cli-${MULTICA_VERSION}-linux-${MULTICA_ARCH}.tar.gz" \
      "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/multica-cli-${MULTICA_VERSION}-linux-${MULTICA_ARCH}.tar.gz" \
    ; do \
      if curl --connect-timeout 15 --retry 3 --retry-delay 5 --retry-all-errors -fSL "$url" -o /tmp/multica.tar.gz; then \
        break; \
      fi; \
      rm -f /tmp/multica.tar.gz; \
    done; \
    test -s /tmp/multica.tar.gz; \
    tar -xzf /tmp/multica.tar.gz -C /tmp multica; \
    install -m 0755 /tmp/multica /usr/local/bin/multica; \
    rm -f /tmp/multica.tar.gz /tmp/multica; \
    multica version || true  # Go binary segfaults under QEMU emulation (multi-arch build)

# 5) git env auto-apply wrapper (still execs the base image entrypoint)
#    opencode 不内置任何配置：/root/.config/opencode/ 只建目录，由使用者按文档自行
#    创建 opencode.json（见 docs/guide/opencode.md）。放在 /root 下，避开代码仓库挂载点。
COPY entrypoint-multica.sh /run/entrypoint-multica.sh
RUN chmod +x /run/entrypoint-multica.sh && \
    mkdir -p /opt/tk /opt/ai_asset /opt/air_platform /opt/db_change_scripts /opt/auto_testing \
             /workspace /root/.config/opencode

# Playwright login helper (reads VIEW_USERNAME / VIEW_PASSWORD).
COPY login.ts /opt/playwright/login.ts

# 默认工作目录 = /workspace（进容器的落脚目录）。项目统一挂在 /opt 下：
#   /opt/tk、/opt/ai_asset、/opt/air_platform、/opt/db_change_scripts、/opt/auto_testing
# 代码仓库 /opt/tk 与基础镜像的 WORKDIR / PHP include_path / tk 家目录一致；
# 预览站点根由基础镜像的 /run/site-init.sh 生成在 /opt/preview。
# multica 的「任务工作目录」与 WORKDIR 无关：它固定用工作区根
# $HOME/multica_workspaces（容器内 /root/multica_workspaces，compose 已挂载），
# 可用 --workspaces-root / MULTICA_WORKSPACES_ROOT 覆盖。
# 唯一约束：工作区根既不能设成当前工作目录，也不能包含当前工作目录，否则 multica 会
# 认为自己是「daemon 托管的任务」而拒绝 daemon start/status。/workspace 与
# /root/multica_workspaces 互不包含，天然满足该约束。
WORKDIR /workspace

# Overrides the base image CMD (base has no ENTRYPOINT); the wrapper execs /run/entrypoint.sh.
# tini 作为 PID 1：容器内会拉起 apache/php-fpm/redis/memcached + multica daemon，
# 没有 init 会留下僵死进程，且 docker stop 时信号无法正确转发。
# 只把 tini 放 ENTRYPOINT，保留 CMD 可覆盖（docker run <img> bash 仍然是 shell）。
# EXPOSE 80 is inherited.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run/entrypoint-multica.sh"]
