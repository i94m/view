---
name: 开发站点预览
description: 仅容器内生效。在容器内用 git worktree + nginx 子域名搭/拆开发预览站点（本 skill 自带 view-wt 脚本），子域名前缀默认取分支名、域名任意（默认 localhost），支持容器内自测与外部子域名访问，不碰 /opt/tk 主检出与主站点。宿主机/容器外不适用。
---

# 开发站点预览（自测）

> **适用范围**：本 skill 依赖容器内的 nginx/php-fpm 环境（multica runtime 镜像内），
> **只在容器里生效**。若当前不在容器内（宿主机、CI、或没有 `/run/site-init.sh`），
> 本 skill 不适用——不要用宿主机的 git/nginx 硬套。

当需要「在某个分支 / 当前 worktree 上自测、验证改动、跑 Playwright 复现」，而又不能动
`/opt/tk` 主检出、不能改主站点时，用本 skill。

## 安装脚本（首次）

本 skill 自带脚本 `scripts/view-wt.sh`（路径相对本 skill 目录）。先装到 PATH 再用：

```bash
install -m 0755 scripts/view-wt.sh /usr/local/bin/view-wt
```

之后三步走：

```bash
view-wt up                    # 基于当前目录/当前 worktree 快速建站（前缀取当前分支名）
view-wt up <分支|commit> [--name N] [--domain D] [--detach]   # 或从分支/提交新建 worktree
view-wt list                  # 查访问地址
view-wt down <name>           # 拆站
view-wt prune                 # 清失效元数据
```

- `up`（不带参）：基于**当前目录/当前 worktree**直接建站——生成站点根 `/opt/preview-<name>`、
  写 `/etc/nginx/conf.d/<name>.conf`（`server_name <name>.<domain>`、`listen 80`），
  加 `/etc/hosts` 解析，`nginx -t` 后 reload。适合「已经在一个 worktree 里、想马上预览」的场景。
- `up <分支|commit>`：新建 worktree 到 `/opt/worktrees/<name>` 再建站。
- **子域名前缀**：默认取**当前分支名**（如 `feature/foo` → `feature-foo`）；提交/非分支
  退化为短 SHA；也可用 `--name` 指定任意唯一前缀。
- **域名**：`--domain D` 任意域名，默认 `localhost`（可用环境变量 `VIEW_WT_DOMAIN` 覆盖）。
- `--detach`：当目标分支已被 `/opt/tk` 等其它 worktree 检出时，按提交检出。
- 结束后务必 `view-wt down <name>` 清理（站点根 / nginx 块 / hosts / 若有 worktree）。

## 访问方式（容器内自测 / 外部子域名）

`view-wt up` 完成后会同时给出两种地址：

- **容器内自测**：`http://<name>.<domain>/` —— 已写 `/etc/hosts`，容器内 `curl` 或
  Playwright MCP 直接打开。
- **外部子域名**：`http://<name>.<domain>:<宿主端口>/`（宿主端口默认 8080，即 compose 的
  `8080:80`；`VIEW_WT_HOST_PORT` 可覆盖）。前提：外部把 `*.<domain>` 解析到宿主 IP
  （真实 DNS 泛解析，或在访问方机器加 hosts），且宿主端口已映射到容器 80。

## 关键事实（别踩）

- `/opt/tk` 是主检出，**不要改它**；改动都发生在 worktree（或你当前的检出目录）里。
- 主站点是 `server_name localhost` + `listen 80 default_server`；各站点都 `listen 80`，
  靠 `server_name <name>.<domain>` 区分，Host 头不匹配时回落到主站点。
- `/etc/hosts` 会写入 `127.0.0.1 <name>.<domain>`，让容器内按该子域名解析到本地 nginx；
  容器外访问走外部 DNS/hosts，不受这条影响。
- 站点根由 `/run/site-init.sh` 以 `SITE`/`REPO` 环境变量覆盖生成：`vivid/public/index.php`、
  `vivid/bootstrap/app.php` 必须是真实文件（Laravel basePath 锚点），`database.php` 会注释
  redis sentinel，`config.php` 取自 `/opt/site-config.php`（与主站点同环境）。
- 站点根 / conf / hosts / state 都在容器临时层，容器重建即丢；`/opt/tk/.git/worktrees`
  元数据残留用 `view-wt prune` 清。需要跨重建保留时，把 worktree 目录放到已挂载卷里。

## 验收

- `curl -s -o /dev/null -w '%{http_code}' http://<name>.<domain>/login.php` 返回 200；
- 主站点 `curl http://localhost/` 行为不变；
- `git -C /opt/tk status` 干净。

## 脚本未安装时的等价命令（兜底）

```bash
git -C /opt/tk worktree add /opt/worktrees/<n> <ref>            # 若基于当前目录则跳过
SITE=/opt/preview-<n> REPO=/opt/worktrees/<n> /run/site-init.sh # REPO 换成实际目录
# 从 /etc/nginx/nginx.conf 提取主 server 块，sed 改 server_name 与 /opt/preview 前缀
# 写入 /etc/nginx/conf.d/<n>.conf；echo "127.0.0.1 <n>.<domain> # view-wt" >> /etc/hosts
nginx -t && nginx -s reload
```
