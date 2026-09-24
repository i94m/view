FROM registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4

LABEL author="rt.wadewang" \
      description="View php8.4 (debian-13) with Node.js 24 + multica / opencode / openspec / uv / MySQL MCP."

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

ARG NODE_VERSION=24.21.0
ARG MULTICA_VERSION=0.5.1
ARG MYSQL_MCP_VERSION=2.0.9

# 1) apt packages + git-lfs.
#    git-lfs is extracted manually so its postinst (which execs the Go binary that
#    segfaults under QEMU emulation during multi-arch builds) is skipped; the LFS
#    filters are written with plain `git config`.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl xz-utils git openssh-client less vim; \
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

# 3) global npm packages. openspec tracks latest; mcp-server-mysql pinned.
#    Strip runtime-dead cruft: demo media, source maps (~90MB), markdown docs and
#    TypeScript declarations (~16MB) — none are used when running the CLIs.
RUN --mount=type=cache,target=/root/.npm \
    npm install -g \
        "@fission-ai/openspec@latest" \
        "@benborla29/mcp-server-mysql@${MYSQL_MCP_VERSION}" && \
    rm -f /usr/local/lib/node_modules/@benborla29/mcp-server-mysql/assets/*.gif && \
    find /usr/local/lib/node_modules -type f \
        \( -name '*.map' -o -name '*.md' -o -name '*.d.ts' \) -delete

# 3b) opencode (v2, latest, npm package @opencode/cli).
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
    npm install -g --ignore-scripts "@opencode/cli@latest"; \
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
#    创建 opencode.json（见 docs/guide/opencode.md）。放在 /root 下可避开 /opt/tk 挂载。
COPY entrypoint-multica.sh /run/entrypoint-multica.sh
RUN chmod +x /run/entrypoint-multica.sh && \
    mkdir -p /opt/tk /opt/ai_asset /root/.config/opencode

# Playwright login helper (reads VIEW_USERNAME / VIEW_PASSWORD).
COPY login.ts /opt/playwright/login.ts

# 默认工作目录 = /opt/tk（仓库挂载点）。multica 任务工作目录不设 ENV，用其默认值
# $HOME/multica_workspaces（容器内 /root/multica_workspaces，compose 已挂载）。
# 注意别把工作目录设成 /opt/tk，否则 multica 会认为当前目录是「daemon 托管的任务目录」
# 而拒绝 daemon start。
WORKDIR /opt/tk

# Overrides the base image CMD (base has no ENTRYPOINT); the wrapper execs /run/entrypoint.sh.
# EXPOSE 80 is inherited.
CMD ["/run/entrypoint-multica.sh"]
