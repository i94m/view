#!/bin/bash
# view-wt.sh —— 容器内用 git worktree 搭开发预览站点（自测用，不碰 /opt/tk 主检出）。
# 随 skill「dev-site-preview」分发（本脚本位于 skill 的 scripts/ 目录）。装到 PATH 即可用：
#   install -m 0755 scripts/view-wt.sh /usr/local/bin/view-wt
#
# 用法：
#   view-wt up [<分支|commit>] [--name N] [--domain D] [--detach]   # 带参=新建 worktree；不带参=基于当前目录
#   view-wt down <name>
#   view-wt list
#   view-wt prune
#
# 两种建站方式：
#   1) view-wt up <分支|commit>   新建 worktree 到 /opt/worktrees/<name> 再建站
#   2) view-wt up（不带参）       基于「当前目录/当前 worktree」直接建站，前缀取当前分支名
#
# 每个站点四件套：
#   站点根    /opt/preview-<name>            （SITE/REPO 覆盖后跑 /run/site-init.sh）
#   nginx 块  /etc/nginx/conf.d/<name>.conf  （server_name <name>.<domain>，listen 80）
#   宿主解析  /etc/hosts 增加 127.0.0.1 <name>.<domain> # view-wt
#   状态      /var/lib/view-worktrees/<name>.{domain,repo}
#
# 子域名前缀（name）默认取当前分支名；提交/非分支时退化为短 SHA，或用 --name 指定任意唯一前缀。
# 域名（domain）任意，默认 localhost（环境变量 VIEW_WT_DOMAIN 或 --domain 覆盖）。
# 所有站点都 listen 80，靠 server_name 路由；主站点 server_name localhost + default_server 兜底。
#
# 主站点与主检出 /opt/tk 全程不动。站点/conf/hosts/state 在容器临时层，容器重建后丢失；
# /opt/tk/.git/worktrees 元数据在 bind mount 上，重建后用 view-wt prune 清。
set -euo pipefail
# macOS/bash 会把全角字符（如 （）「」）的字节当字母，导致 `$var（` 被误解析成变量名
# `$var<乱码>` 而报 unbound variable；固定 C locale 让 isalnum 只认 ASCII，跨平台更稳。
export LC_ALL=C

MAIN_REPO=${MAIN_REPO:-/opt/tk}
WORKTREE_ROOT=${WORKTREE_ROOT:-/opt/worktrees}
PREVIEW_PREFIX=${PREVIEW_PREFIX:-/opt/preview}
NGINX_CONF_DIR=${NGINX_CONF_DIR:-/etc/nginx/conf.d}
SITE_INIT=${SITE_INIT:-/run/site-init.sh}
DOMAIN=${VIEW_WT_DOMAIN:-localhost}
HOSTS_FILE=${HOSTS_FILE:-/etc/hosts}
STATE_DIR=${STATE_DIR:-/var/lib/view-worktrees}

log() { printf '[view-wt] %s\n' "$*"; }
die() { printf '[view-wt] 错误：%s\n' "$*" >&2; exit 1; }

# 生成合法子域名标签：小写、字母数字与连字符，去头尾连字符，最长 63。
sanitize_name() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr '/[:space:]._' '-' \
    | tr -cd '[:alnum:]-' \
    | sed 's/-\{2,\}/-/g; s/^-//; s/-$//' \
    | cut -c1-63
}

# 前缀：--name 优先；否则是分支则用分支名；否则（commit/其它）用短 SHA。
resolve_name() {
  local ref=$1 given=$2 branch=""
  if [ -n "$given" ]; then
    sanitize_name "$given"
    return
  fi
  if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/$ref"; then
    branch=$ref
  elif git -C "$MAIN_REPO" show-ref --verify --quiet "refs/remotes/$ref"; then
    branch=${ref#*/}                       # 去掉 origin/ 等 remote 前缀
  fi
  if [ -n "$branch" ]; then
    sanitize_name "$branch"
    return
  fi
  local sha
  sha=$(git -C "$MAIN_REPO" rev-parse --short "$ref" 2>/dev/null) || sha=""
  if [ -n "$sha" ]; then
    printf '%s' "$sha"
  else
    sanitize_name "$ref"
  fi
}

# 当前目录的站点前缀：--name 优先；否则取当前分支名，退化为短 SHA。
current_name() {
  local given=$1 cwd branch=""
  if [ -n "$given" ]; then
    sanitize_name "$given"
    return
  fi
  cwd=$(pwd)
  branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null) || branch=""
  if [ -n "$branch" ]; then
    sanitize_name "$branch"
    return
  fi
  git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true
}

domain_of() {
  if [ -f "$STATE_DIR/$1.domain" ]; then
    cat "$STATE_DIR/$1.domain"
  else
    printf '%s' "$DOMAIN"
  fi
}

host_of() {
  local name=$1 domain
  domain=$(domain_of "$name")
  printf '%s.%s' "$name" "$domain"
}

host_line() { printf '127.0.0.1 %s # view-wt' "$1"; }

add_host() {
  local host=$1
  if ! grep -qxF "$(host_line "$host")" "$HOSTS_FILE"; then
    printf '%s\n' "$(host_line "$host")" >> "$HOSTS_FILE"
  fi
}

remove_host() {
  local host=$1 line
  line=$(host_line "$host")
  if grep -qxF "$line" "$HOSTS_FILE"; then
    # 注意：/etc/hosts 是 bind mount 文件，不能用 mv/rename 覆盖（会报 Device or resource busy），
    # 必须原地重写（cat > 覆盖同一 inode）。
    grep -vxF "$line" "$HOSTS_FILE" > "$HOSTS_FILE.tmp" || true
    cat "$HOSTS_FILE.tmp" > "$HOSTS_FILE"
    rm -f "$HOSTS_FILE.tmp"
  fi
}

# 从主 nginx.conf 提取唯一 server{} 块，改为站点的子域名：
#   去掉 default_server、server_name 换成 <host>、站点根换成 /opt/preview-<name>。
generate_server_block() {
  local name=$1 host=$2
  awk '
    /^[[:space:]]*server[[:space:]]*\{/ {p=1}
    p && /^}$/ {exit}
    p {print}
  ' /etc/nginx/nginx.conf \
    | sed -e 's/listen[[:space:]]*80[[:space:]]*default_server;/listen 80;/' \
          -e "s/server_name[[:space:]]*localhost;/server_name ${host};/" \
          -e "s#/opt/preview#/opt/preview-${name}#g"
}

apply_nginx() {
  if ! nginx -t; then return 1; fi
  nginx -s reload || return 1
}

# 建站共用收尾：写 state、生成站点根、写 nginx 块、写 hosts、reload、报地址。
setup_site() {
  local name=$1 repo=$2 domain=$3
  local site="$PREVIEW_PREFIX-$name" host

  printf '%s\n' "$domain" > "$STATE_DIR/$name.domain"
  printf '%s\n' "$repo"   > "$STATE_DIR/$name.repo"
  host=$(host_of "$name")

  log "生成站点根：$site（基于 $repo）"
  SITE="$site" REPO="$repo" "$SITE_INIT" || die "生成站点根失败"

  log "写入 nginx server 块：$NGINX_CONF_DIR/$name.conf（server_name $host）"
  generate_server_block "$name" "$host" > "$NGINX_CONF_DIR/$name.conf" \
    || die "生成 nginx 块失败"

  add_host "$host"

  if ! apply_nginx; then
    rm -f "$NGINX_CONF_DIR/$name.conf" "$STATE_DIR/$name.domain" "$STATE_DIR/$name.repo"
    remove_host "$host"
    die "nginx 校验失败，已回滚该 nginx 块（站点根仍在，view-wt down $name 清理）"
  fi

  log "完成：容器内 http://${host}/"
  log "      外部   http://${host}/"
  log "  （外部需把 *.${domain} 解析到宿主 IP，且宿主 80 端口转发到容器 80）"
  log "自测结束用：view-wt down $name"
}

cmd_up() {
  local ref="" name="" domain="$DOMAIN" detach=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)   name="${2:-}"; shift 2;;
      --domain) domain="${2:-}"; shift 2;;
      --detach) detach=1; shift;;
      -h|--help) usage; return 0;;
      -*) die "未知参数: $1";;
      *) [ -z "$ref" ] && { ref="$1"; shift; } || die "多余参数: $1";;
    esac
  done
  [ -n "$domain" ] || domain="$DOMAIN"

  local repo="" wt_dir=""
  if [ -n "$ref" ]; then
    # 方式一：从分支/提交新建 worktree
    name=$(resolve_name "$ref" "$name")
    [ -n "$name" ] || die "无法从「$ref」生成合法前缀，请用 --name 指定"
    wt_dir="$WORKTREE_ROOT/$name"
    repo="$wt_dir"
    [ -e "$wt_dir" ] && die "worktree 已存在：$wt_dir（先 view-wt down $name）"
  else
    # 方式二：基于当前目录（当前 worktree）快速搭建
    name=$(current_name "$name")
    [ -n "$name" ] || die "当前目录不是 git 仓库，无法确定前缀；请 cd 到 worktree 或加 --name"
    repo=$(pwd)
  fi

  local site="$PREVIEW_PREFIX-$name"
  [ -e "$site" ]  && die "站点根已存在：$site"
  [ -f "$NGINX_CONF_DIR/$name.conf" ] && die "nginx 配置已存在：$NGINX_CONF_DIR/$name.conf"

  mkdir -p "$WORKTREE_ROOT" "$NGINX_CONF_DIR" "$STATE_DIR"

  if [ -n "$ref" ]; then
    log "创建 worktree：$wt_dir <- $ref"
    local git_err="/tmp/view-wt.$$.err"
    if [ "$detach" -eq 1 ]; then
      git -C "$MAIN_REPO" worktree add --detach "$wt_dir" "$ref" 2>"$git_err" \
        || { sed 's/^/  /' "$git_err" >&2; rm -f "$git_err"; die "worktree add 失败"; }
    else
      git -C "$MAIN_REPO" worktree add "$wt_dir" "$ref" 2>"$git_err" \
        || { sed 's/^/  /' "$git_err" >&2; rm -f "$git_err"; die "worktree add 失败（若分支已被占用，加 --detach）"; }
    fi
    rm -f "$git_err"
  else
    log "基于当前目录：$repo"
  fi

  setup_site "$name" "$repo" "$domain"
}

cmd_down() {
  local name="${1:-}"
  [ -n "$name" ] || die "用法：view-wt down <name>"
  name=$(sanitize_name "$name")
  local wt_dir="$WORKTREE_ROOT/$name"
  local host
  host=$(host_of "$name")

  rm -f "$NGINX_CONF_DIR/$name.conf" "$STATE_DIR/$name.domain" "$STATE_DIR/$name.repo"
  rm -rf "$PREVIEW_PREFIX-$name"
  remove_host "$host"
  if ! git -C "$MAIN_REPO" worktree remove --force "$wt_dir" 2>/dev/null; then
    git -C "$MAIN_REPO" worktree prune 2>/dev/null || true
  fi

  apply_nginx || log "nginx 校验/reload 失败，请检查剩余 conf"
  log "已移除 $name"
}

cmd_list() {
  printf '%-20s %-34s %s\n' NAME HOST REPO
  printf '%-20s %-34s %s\n' ---- ---- ----
  if [ -d "$STATE_DIR" ]; then
    local f name host repo
    for f in "$STATE_DIR"/*.domain; do
      [ -f "$f" ] || continue
      name=$(basename "$f" .domain)
      host=$(host_of "$name")
      repo=""
      [ -f "$STATE_DIR/$name.repo" ] && repo=$(cat "$STATE_DIR/$name.repo")
      printf '%-20s %-34s %s\n' "$name" "$host" "$repo"
    done
  fi
  echo
  git -C "$MAIN_REPO" worktree list 2>/dev/null || true
}

cmd_prune() {
  git -C "$MAIN_REPO" worktree prune
  log "已清理失效 worktree 元数据"
}

usage() {
  cat <<'EOF'
view-wt —— 容器内用 git worktree 搭独立预览站点（自测用，不碰 /opt/tk 主检出）

用法:
  view-wt up [<分支|commit>] [--name N] [--domain D] [--detach]
      带参：新建 worktree 到 /opt/worktrees/<N> 再建站；
      不带参：基于当前目录（当前 worktree）快速建站。
      生成 /opt/preview-<N>，写 /etc/nginx/conf.d/<N>.conf（server_name <N>.<D>），
      加 /etc/hosts 解析，reload nginx。
      前缀 <N> 默认取分支名（提交/非分支退化为短 SHA），域名 <D> 默认 localhost。
      访问地址：http://<N>.<D>/（容器内直接可达；外部需 DNS 泛解析 + 宿主 80 转发到容器 80）
  view-wt down <name>    移除站点根 / nginx 块 / hosts 解析 /（若有）worktree，reload。
  view-wt list           列出站点（name / host / repo）。
  view-wt prune          清理失效 worktree 元数据（容器重建后）。

例:
  view-wt up                                # 基于当前目录，前缀取当前分支名
  view-wt up feature/foo                    # 新建 worktree，前缀 feature-foo
  view-wt up feature/foo --domain tke.example.com
  view-wt up a1b2c3d --name hotfix
  view-wt down feature-foo
EOF
}

case "${1:-}" in
  up)    shift; cmd_up "$@";;
  down)  shift; cmd_down "$@";;
  list)  cmd_list;;
  prune) cmd_prune;;
  -h|--help|help|"") usage;;
  *) die "未知子命令: ${1:-}（view-wt help 查看用法）";;
esac
