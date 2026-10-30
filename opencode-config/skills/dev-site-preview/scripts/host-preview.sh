#!/bin/bash
# host-preview.sh —— 在「宿主机」用 docker/podman 跑 ghcr.io/i94m/view:php8.4 起开发预览环境。
# 适用场景：runtime 不在容器里运行，但本机装了 docker/podman（容器管理工具）。
# 与 view-wt.sh 互斥：view-wt 跑在容器内，本脚本跑在宿主机。
#
# 用法：
#   host-preview up [<分支|commit>] [--name N] [--port P] [--code PATH] [--config PATH] [--detach]
#   host-preview down [<name>]
#   host-preview list
#   host-preview logs [<name>]
#   host-preview detect
#
# 原理：拉取基础镜像 php8.4（debian13 + nginx + php8.4 + pdflib，内置 /opt/preview 预览站点），
# 把代码挂到 /opt/tk、站点 config.php 挂到 /opt/site-config.php，映射端口即可访问。
set -euo pipefail
# macOS/bash 会把全角字符（如 （）「」）的字节当字母，导致 `$var（` 被误解析成变量名
# `$var<乱码>` 而报 unbound variable；固定 C locale 让 isalnum 只认 ASCII，跨平台更稳。
export LC_ALL=C

IMAGE=${VIEW_PREVIEW_IMAGE:-ghcr.io/i94m/view:php8.4}
STATE_DIR=${VIEW_PREVIEW_STATE:-$HOME/.dev-preview}
DEFAULT_PORT=${VIEW_PREVIEW_PORT:-8080}
CONFIG=${VIEW_SITE_CONFIG:-}

log() { printf '[host-preview] %s\n' "$*"; }
die() { printf '[host-preview] 错误：%s\n' "$*" >&2; exit 1; }

# 探测容器运行时：docker 优先，其次 podman；都不可用返回空。
detect_runtime() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    printf 'docker'
  elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    printf 'podman'
  else
    printf ''
  fi
}

sanitize_name() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr '/[:space:]._' '-' \
    | tr -cd '[:alnum:]-' \
    | sed 's/-\{2,\}/-/g; s/^-//; s/-$//' \
    | cut -c1-63
}

# 当前目录的 git 分支名（用于默认 name）。
branch_of() {
  local dir=$1 branch=""
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null) || branch=""
  [ -n "$branch" ] && { sanitize_name "$branch"; return; }
  git -C "$dir" rev-parse --short HEAD 2>/dev/null || true
}

cmd_detect() {
  local rt
  rt=$(detect_runtime)
  if [ -n "$rt" ]; then
    log "检测到容器运行时：$rt"
  else
    log "未检测到 docker/podman（或 daemon 未运行）"
    return 1
  fi
}

cmd_up() {
  local ref="" name="" port="$DEFAULT_PORT" code="" config="$CONFIG" detach=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)   name="${2:-}"; shift 2;;
      --port)   port="${2:-}"; shift 2;;
      --code)   code="${2:-}"; shift 2;;
      --config) config="${2:-}"; shift 2;;
      --detach) detach=1; shift;;
      -h|--help) usage; return 0;;
      -*) die "未知参数: $1";;
      *) [ -z "$ref" ] && { ref="$1"; shift; } || die "多余参数: $1";;
    esac
  done

  local rt
  rt=$(detect_runtime) || die "未检测到 docker/podman，无法起预览环境"
  [ -n "$port" ] || port="$DEFAULT_PORT"

  mkdir -p "$STATE_DIR/worktrees" "$STATE_DIR/state"

  # 解析代码目录：给分支/提交则建 worktree，否则用当前目录或 --code。
  local repo_dir="$code" wt_dir=""
  if [ -z "$repo_dir" ]; then repo_dir=$(pwd); fi
  repo_dir=$(cd "$repo_dir" && pwd)

  if [ -n "$ref" ]; then
    local root
    root=$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null) || root="$repo_dir"
    name=$(sanitize_name "${name:-$ref}")
    [ -n "$name" ] || die "无法从「$ref」生成合法名称，请用 --name 指定"
    wt_dir="$STATE_DIR/worktrees/$name"
    [ -e "$wt_dir" ] && die "worktree 已存在：$wt_dir（先 host-preview down $name）"
    log "创建 worktree：$wt_dir <- $ref"
    if [ "$detach" -eq 1 ]; then
      git -C "$root" worktree add --detach "$wt_dir" "$ref"
    else
      git -C "$root" worktree add "$wt_dir" "$ref" 2>/dev/null \
        || git -C "$root" worktree add --detach "$wt_dir" "$ref"
    fi
    repo_dir="$wt_dir"
  else
    name=$(sanitize_name "${name:-$(branch_of "$repo_dir")}")
    [ -n "$name" ] || name="dev"
  fi

  local cname="dev-preview-$name"
  if "$rt" ps -a --filter "name=^${cname}$" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    die "容器已存在：$cname（先 host-preview down $name）"
  fi

  log "拉取镜像：$IMAGE"
  "$rt" pull "$IMAGE" >/dev/null

  local -a run_args=(-d --name "$cname" -p "${port}:80" -v "${repo_dir}:/opt/tk")
  if [ -n "$config" ]; then
    [ -f "$config" ] || die "config 文件不存在：$config"
    run_args+=(-v "${config}:/opt/site-config.php:ro")
  else
    log "未提供 --config / VIEW_SITE_CONFIG：站点缺 config.php，可能无法正常访问"
  fi

  log "启动容器：$cname（端口 $port）"
  "$rt" run "${run_args[@]}" "$IMAGE" >/dev/null

  # 记录状态
  printf '%s\n' "$repo_dir" > "$STATE_DIR/state/$name.code"
  printf '%s\n' "$port"     > "$STATE_DIR/state/$name.port"
  printf '%s\n' "$rt"       > "$STATE_DIR/state/$name.rt"
  [ -n "$wt_dir" ] && printf '%s\n' "$wt_dir" > "$STATE_DIR/state/$name.wt"

  # 等 healthy（镜像自带 HEALTHCHECK：nginx 80 + php-fpm 9000）
  for _ in $(seq 1 30); do
    s=$("$rt" inspect --format '{{.State.Health.Status}}' "$cname" 2>/dev/null || printf '')
    [ "$s" = "healthy" ] && break
    sleep 2
  done

  log "完成：http://localhost:${port}/"
  log "拆站：host-preview down $name"
}

cmd_down() {
  local name="${1:-}"
  [ -n "$name" ] || die "用法：host-preview down <name>"
  name=$(sanitize_name "$name")
  local cname="dev-preview-$name" rt

  rt=$(detect_runtime)
  if [ -n "$rt" ]; then
    "$rt" rm -f "$cname" >/dev/null 2>&1 || true
  fi

  if [ -f "$STATE_DIR/state/$name.wt" ]; then
    local wt_dir
    wt_dir=$(cat "$STATE_DIR/state/$name.wt")
    git worktree remove --force "$wt_dir" >/dev/null 2>&1 || git worktree prune 2>/dev/null || true
  fi
  rm -f "$STATE_DIR/state/$name".* 2>/dev/null || true

  log "已移除 $name"
}

cmd_list() {
  local rt
  rt=$(detect_runtime) || { log "未检测到 docker/podman"; return 1; }
  "$rt" ps -a --filter "name=dev-preview-" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

cmd_logs() {
  local name="${1:-}" rt
  [ -n "$name" ] || die "用法：host-preview logs <name>"
  name=$(sanitize_name "$name")
  rt=$(detect_runtime) || { log "未检测到 docker/podman"; return 1; }
  "$rt" logs --tail 100 "dev-preview-$name"
}

usage() {
  cat <<'EOF'
host-preview —— 宿主机用 docker/podman + ghcr.io/i94m/view:php8.4 起开发预览环境

用法:
  host-preview up [<分支|commit>] [--name N] [--port P] [--code PATH] [--config PATH] [--detach]
      拉取基础镜像，把代码挂到 /opt/tk、config.php 挂到 /opt/site-config.php，
      映射端口（默认 8080）启动预览容器。给分支/提交时先在宿主建 worktree 再挂载；
      不带参数则挂载当前目录。
  host-preview down [<name>]   停止并删除容器（若有 worktree 一并移除）。
  host-preview list            列出预览容器。
  host-preview logs [<name>]   看容器日志。
  host-preview detect          探测 docker/podman。

环境变量:
  VIEW_PREVIEW_IMAGE  基础镜像（默认 ghcr.io/i94m/view:php8.4）
  VIEW_PREVIEW_PORT   默认端口（默认 8080）
  VIEW_SITE_CONFIG    站点 config.php 路径

例:
  host-preview up                                # 预览当前目录
  host-preview up feature/foo --port 8081        # 建 worktree 预览分支
  host-preview up feature/foo --config /path/to/config.php
  host-preview down feature-foo
EOF
}

case "${1:-}" in
  up)     shift; cmd_up "$@";;
  down)   shift; cmd_down "$@";;
  list)   cmd_list;;
  logs)   shift; cmd_logs "$@";;
  detect) cmd_detect;;
  -h|--help|help|"") usage;;
  *) die "未知子命令: ${1:-}（host-preview help 查看用法）";;
esac
