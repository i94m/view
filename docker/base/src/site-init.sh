#!/bin/bash
# /run/site-init.sh —— 准备 /opt/preview 预览站点根（代码仓库零改动，不需要特权）。
#
# 背景：View 的 BASE_DIR 是 DOCUMENT_ROOT 去掉最后一段，所以 DocumentRoot 指向
# /opt/preview/web 时，代码会从 /opt/preview 找 sys / vivid / config.php。这里把
# /opt/tk（代码仓库）里不需要改的条目软链到 /opt/preview，需要改的少数文件用
# 镜像自带的版本或从仓库复制后改写。仓库一个字节都不写，git status 不会变。
#
# 设计目标是「日常改代码/加文件不用重建」：
#   /opt/preview/web、sys   → 整目录软链（新增页面/静态资源/库文件立即生效）
#   /opt/preview/vivid/app  → 整目录软链（新增模块/类立即生效）
#   /opt/preview/vivid      → 真实目录，子项软链
# 只有镜像必须落地文件的那几个目录，在「新增直接子项」时才需要重跑 /run/init.sh：
#   vivid/、vivid/config/、vivid/config/12.x/、vivid/public/、vivid/bootstrap/
# 日常新增页面、模块、类、静态资源都不用重建。
#
# 由 entrypoint 启动时执行；切分支 / 重新拉代码后重建：
#   docker exec -it <容器> /run/init.sh
#
# 镜像自带（/opt/preview-tpl）：
#   web/login.php           自动登录版 login（邮箱取环境变量 VIEW_USERNAME → user.Username）
#                           → 通过 nginx location = /login.php 生效，不往 docroot 塞文件
# 从仓库复制 / 改写（启动时生成）：
#   vivid/public/index.php、vivid/bootstrap/app.php   Laravel 的 basePath 锚点
#                                                    （否则 basePath 落回仓库，缓存会写脏 git）
#   vivid/config/12.x/database.php                   注释 redis sentinel
# 只建目录（内容由框架自己生成）：vivid/bootstrap/cache/12.x（viewApp 版本固定 12.x）
# 只读挂载：/opt/site-config.php（启动时以 www-data 可读权限落到 /opt/preview/config.php）
set -uo pipefail
umask 022

SITE=/opt/preview
REPO=/opt/tk
TPL=/opt/preview-tpl
CONFIG_SRC=/opt/site-config.php

# 需要落地真实文件（不软链）的路径
REAL_PATHS=" vivid/public/index.php vivid/bootstrap/app.php vivid/config/12.x/database.php vivid/bootstrap/cache logs cache overrides config.php log4php_config.xml "
# 需要真实目录、逐项软链的目录（其余目录/文件整体软链）
STRUCT_DIRS=" vivid vivid/config vivid/config/12.x vivid/public vivid/bootstrap "

log() { printf '[site-init] %s\n' "$*"; }
warn() { printf '[site-init] %s\n' "$*" >&2; }

is_real() { case "$REAL_PATHS" in *" $1 "*) return 0 ;; esac; return 1; }
is_structural() { case "$STRUCT_DIRS" in *" $1 "*) return 0 ;; esac; return 1; }

link_entry() {
  local target="$1" dst="$2"
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then rm -rf "$dst"; fi
  ln -sfn "$target" "$dst"
}

link_tree() {
  local rel_dir="$1"
  local src="$REPO/${rel_dir:+$rel_dir/}"
  local dst="$SITE/${rel_dir:+$rel_dir/}"
  local entry name rel
  for entry in "$src"* "$src".[!.]*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name=$(basename "$entry")
    # 仓库根目录的隐藏项（.git / .idea …）不进站点
    if [ -z "$rel_dir" ] && [ "${name#.}" != "$name" ]; then continue; fi
    rel="${rel_dir:+$rel_dir/}$name"
    is_real "$rel" && continue
    if [ -d "$entry" ] && [ ! -L "$entry" ] && is_structural "$rel"; then
      mkdir -p "$dst$name"
      link_tree "$rel"
    else
      mkdir -p "$dst"
      link_entry "$REPO/$rel" "$dst$name"
    fi
  done
}

prepare_site() {
  mkdir -p "$SITE/web" "$SITE/logs" "$SITE/cache" "$SITE/overrides"

  if [ ! -d "$REPO" ] || [ -z "$(ls -A "$REPO" 2>/dev/null)" ]; then
    warn "$REPO 为空：没有代码可挂，站点保持空目录。把 View 代码挂到 $REPO 后执行 /run/init.sh"
    return 0
  fi

  # ---- 1. 清掉上一轮的软链（保留镜像自带文件和 config.php） ----
  find "$SITE" -type l -delete 2>/dev/null || true

  # ---- 2. 按仓库结构铺软链 ----
  link_tree ""

  # ---- 3. 镜像自带的文件 ----
  cp -f "$TPL/web/login.php" "$SITE/overrides/login.php"      # nginx location = /login.php 用
  cp -f /opt/local/log4php_config.xml "$SITE/log4php_config.xml"

  # ---- 4. Laravel 缓存目录：只要目录骨架，内容由框架自己生成 ----
  rm -rf "$SITE/vivid/bootstrap/cache"
  mkdir -p "$SITE/vivid/bootstrap/cache/12.x"

  # ---- 5. Laravel 的路径锚点：必须是真实文件，否则 basePath 会落回仓库 ----
  mkdir -p "$SITE/vivid/public" "$SITE/vivid/bootstrap"
  [ -f "$REPO/vivid/public/index.php" ] && cp -f "$REPO/vivid/public/index.php" "$SITE/vivid/public/index.php"
  [ -f "$REPO/vivid/bootstrap/app.php" ] && cp -f "$REPO/vivid/bootstrap/app.php" "$SITE/vivid/bootstrap/app.php"

  # ---- 6. 需要改写才能跑的仓库文件：复制后 patch（产物只在 /opt/preview） ----
  mkdir -p "$SITE/vivid/config/12.x"
  if [ -f "$REPO/vivid/config/12.x/database.php" ]; then
    sed -e "s/'options' => array_merge/\/\/ 'options' => array_merge/" \
        -e "s/'default' => \$redisSentinel/\/\/ 'default' => \$redisSentinel/" \
        -e "s/'cache' => \$redisSentinel/\/\/ 'cache' => \$redisSentinel/" \
        "$REPO/vivid/config/12.x/database.php" > "$SITE/vivid/config/12.x/database.php"
  fi

  # ---- 7. 权限：nginx / php-fpm 以 www-data 运行，运行期目录必须可写 ----
  chown -R www-data:www-data \
    "$SITE/vivid/bootstrap/cache" "$SITE/logs" "$SITE/cache" 2>/dev/null || true
  chmod -R u+rwX,g+rwX "$SITE/vivid/bootstrap/cache" "$SITE/logs" "$SITE/cache" 2>/dev/null || true

  # ---- 8. 站点配置：只读挂载 → 以 www-data 可读的权限落到站点根 ----
  if [ -s "$CONFIG_SRC" ]; then
    if ! install -o root -g www-data -m 0640 "$CONFIG_SRC" "$SITE/config.php" 2>/dev/null; then
      cp -f "$CONFIG_SRC" "$SITE/config.php"
      chmod 0640 "$SITE/config.php" 2>/dev/null || true
      chgrp www-data "$SITE/config.php" 2>/dev/null || true
    fi
    log "config.php ← $CONFIG_SRC（只读挂载）"
  elif [ -s "$SITE/config.php" ]; then
    log "config.php 已直接挂载"
  else
    warn "未挂载 config.php：-v <sites>/<site>/config.php:/opt/site-config.php:ro"
  fi

  log "完成：DocumentRoot $SITE/web（软链 $(find "$SITE" -type l | wc -l | tr -d ' ') 个），仓库 $REPO 未写入"
}

prepare_site
