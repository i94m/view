---
name: 开发站点预览
description: 用 git worktree + nginx 子域名搭/拆开发预览站点（自带 view-wt / host-preview 脚本）。容器内用 view-wt；不在容器内但装了 docker/podman 时用 host-preview 跑 ghcr.io/i94m/view:php8.4 起预览环境。子域名前缀默认取分支名、域名任意（默认 localhost），不碰主检出与主站点。
---

# 开发站点预览（自测）

当需要「在某个分支 / 当前 worktree 上自测、验证改动、跑 Playwright 复现」，而又不能动
主检出、不能改主站点时，用本 skill。

## 第 0 步：判断运行环境（决定用哪个脚本）

本 skill 自带两个脚本，二选一：

```bash
# 是否已在容器内（multica runtime）？
[ -x /run/site-init.sh ] && [ -d /opt/tk ] && echo "在容器内" || echo "不在容器内"
# 不在容器内时，宿主机是否有 docker/podman？
command -v docker podman
```

| 环境 | 判定 | 用哪个 |
|---|---|---|
| **容器内**（multica runtime） | `/run/site-init.sh` 可执行 且 `/opt/tk` 存在 | `view-wt`（方式 A，nginx 子域名多站点） |
| **宿主机 + docker/podman** | 不在容器内，但 `docker`/`podman` 可用 | `host-preview`（方式 B，用 php8.4 镜像起预览环境） |
| 都没有 | 二者皆无 | 提示用户：需 multica runtime 容器，或安装 Docker Desktop / podman |

---

## 方式 A：容器内（view-wt）—— nginx 子域名多站点

> 适用于：已经跑在 multica runtime 容器里。

### 安装脚本（首次）

```bash
install -m 0755 scripts/view-wt.sh /usr/local/bin/view-wt
```

### 使用

```bash
view-wt up                    # 基于当前目录/当前 worktree 快速建站（前缀取当前分支名）
view-wt up <分支|commit> [--name N] [--domain D] [--detach]   # 或从分支/提交新建 worktree
view-wt list                  # 查访问地址
view-wt down <name>           # 拆站
view-wt prune                 # 清失效元数据
```

- `up`（不带参）：基于**当前目录/当前 worktree**直接建站——生成站点根 `/opt/preview-<name>`、
  写 `/etc/nginx/conf.d/<name>.conf`（`server_name <name>.<domain>`、`listen 80`），
  加 `/etc/hosts` 解析，`nginx -t` 后 reload。
- `up <分支|commit>`：新建 worktree 到 `/opt/worktrees/<name>` 再建站。
- **子域名前缀**默认取当前分支名（`feature/foo` → `feature-foo`），提交/非分支退化为短 SHA，
  可用 `--name` 指定唯一前缀；**域名**用 `--domain` 任意指定，默认 `localhost`（`VIEW_WT_DOMAIN`）。
- `--detach`：分支已被别处检出时按提交检出。
- 结束后 `view-wt down <name>` 清理（站点根 / nginx 块 / hosts / 若有 worktree）。

### 访问方式

- **容器内自测**：`http://<name>.<domain>/`（已写 `/etc/hosts`）。
- **外部子域名**：`http://<name>.<domain>/`（不占端口，靠子域名区分）。前提：`*.<domain>`
  解析到宿主 IP，且宿主 80 端口转发到容器 80。

### 关键事实（别踩）

- `/opt/tk` 是主检出，**不要改它**；改动都在 worktree 里。
- 主站点 `server_name localhost` + `listen 80 default_server`；各站点都 `listen 80`，靠
  `server_name` 区分，Host 不匹配时回落主站点。
- 站点根由 `/run/site-init.sh` 以 `SITE`/`REPO` 覆盖生成（Laravel basePath 锚点必须是真实文件等）。
- 站点根 / conf / hosts / state 在容器临时层，容器重建即丢；`.git/worktrees` 元数据用
  `view-wt prune` 清。

---

## 方式 B：宿主机 + docker/podman（host-preview）—— 用 php8.4 镜像起预览环境

> 适用于：runtime 不在容器里，但本机装了 docker/podman。

### 安装脚本（首次）

```bash
install -m 0755 scripts/host-preview.sh /usr/local/bin/host-preview
```

### 使用

```bash
host-preview detect                                       # 探测 docker/podman
host-preview up                                           # 预览当前目录
host-preview up <分支|commit> [--port P] [--config PATH] [--detach]
host-preview list                                         # 列出预览容器
host-preview logs [<name>]                                # 看日志
host-preview down [<name>]                                # 拆站
```

- `up` 拉取基础镜像 `ghcr.io/i94m/view:php8.4`（debian13 + nginx + php8.4，内置 `/opt/preview`
  预览站点），把代码挂到 `/opt/tk`、站点 `config.php` 挂到 `/opt/site-config.php`（`--config`
  或 `VIEW_SITE_CONFIG`），映射端口（默认 8080）启动，访问 `http://localhost:<port>/`。
- `up <分支|commit>`：先在宿主机建 worktree 再挂载；不带参数则挂载当前目录（或 `--code`）。
- 环境变量：`VIEW_PREVIEW_IMAGE`（默认 `ghcr.io/i94m/view:php8.4`）、`VIEW_PREVIEW_PORT`（默认 8080）、
  `VIEW_SITE_CONFIG`（config.php 路径）。
- 这是**单容器端口映射**的轻量预览，不是子域名多站点；需要多站点时请用容器内的方式 A。

### 关键事实

- 镜像由 CI 发布（`docker/base/**` 变更时重建），本地 `docker pull ghcr.io/i94m/view:php8.4` 即可。
- 代码与 config.php 通过 bind mount 进容器；宿主机路径需绝对路径。
- 容器名 `dev-preview-<name>`，状态存在 `~/.dev-preview/`。

---

## 验收

- 能通过给出的地址访问站点（登录页 200/302，非 404/500）；
- 主站点（若在容器内）行为不变；
- 主仓库 `git status` 干净。
