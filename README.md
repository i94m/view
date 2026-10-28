# Multica Runtime

TKE VIEW 的容器化开发 / AI 运行环境。`ghcr.io/i94m/view:php8.4` 提供 PHP 8.4 + nginx 的本地预览站点
（仓库零改动，`/opt/preview` 自动生成）；`ghcr.io/i94m/view:php8.4-multica` 在其上内置 Node.js 24、
multica CLI、opencode、openspec、uv（Python）与 MySQL MCP，用于在本地/服务器上运行 multica daemon
托管的 agent 任务。agent 常用工具（`python3`、`jq`、`ripgrep`、`tini` 等）已一并装好。

## 架构

```
docker compose (bridge 网络，默认子网 172.16.10.0/24)
└── runtime        ghcr.io/i94m/view:php8.4-multica
    ├── nginx / php-fpm (EXPOSE 80，映射到宿主 8080:80)
    ├── 预览站点根 /opt/preview（启动时由 /run/site-init.sh 生成）
    ├── multica daemon (entrypoint 自启动)
    ├── opencode v2  (配置由使用者自行创建，见 docs/guide/opencode.md)
    ├── git + git-lfs (filter.lfs.* 已在镜像内配好)
    ├── uv / uvx (Python 包管理)
    └── MCP: Playwright / MySQL (均在 opencode.json 中定义)
```

容器内项目统一放在 `/opt` 下（`tk`、`ai_asset`、`air_platform`、`db_change_scripts`、
`auto_testing`）；其中 `/opt/tk` 同时是 `tk` 用户主目录、`WORKDIR` 与 PHP `include_path`。

**站点根不在仓库里**：`/opt/preview` 在容器启动时自动生成——不需要改的条目软链回
`/opt/tk`，需要改的少数文件（自动登录版 `login.php`、Laravel 的 `basePath` 锚点、
注释掉 redis sentinel 的 `database.php`）由镜像提供或启动时生成。所以仓库可以只读挂载，
`git status` 永远干净，也不需要再跑初始化脚本。

`runtime` 接在 bridge 网络 `multica_net` 上，子网在 `docker-compose.yml` 里写死
（`172.16.10.0/24`）。compose 把容器 80 端口映射到宿主 8080。

`runtime` 通过 `extra_hosts` 把 `git.ap.tkelevator.com` 固定解析到内网 IP
`10.251.68.173`（容器内 DNS 不走宿主 VPN 的 DNS）。需要时按同样方式补充其它内网域名。

## 目录结构

```
.
├── docker/                        # 镜像构建（两个独立构建上下文）
│   ├── base/                      # 基础镜像 → ghcr.io/i94m/view:php8.4
│   │   ├── Dockerfile             #   debian13 + nginx + php8.4 + pdflib
│   │   └── src/                   #   php.ini / nginx / xdebug / site-init.sh / preview/ / pdflib .so
│   ├── runtime/                   # 运行镜像 → ghcr.io/i94m/view:php8.4-multica
│   │   ├── Dockerfile            #   base + Node24 + git-lfs + multica/opencode/openspec + MySQL MCP
│   │   ├── entrypoint-multica.sh #   容器入口：配置 git 凭据 + 自启动 multica daemon
│   │   └── login.ts              #   Playwright 登录辅助（构建时放入 /opt/playwright/）
│   └── build.sh                   # 本地构建脚本（默认按本机架构 --load，不 push）
├── .github/workflows/package.yml  # CI：多架构构建并推送 GHCR
├── docker-compose.yml        # 运行编排：runtime（从 .example 复制）
├── .env.example              # 配置模板，复制为 .env 使用
├── .env                      # 实际配置（含密钥，已被 .gitignore 忽略）
├── docs/                     # VitePress 文档站点（本 README 的内容在这里）
├── multica-runtime/          # 精简运行目录（仅 compose + .env.example + README）
├── .multica/                 # multica 登录态持久化（挂载到 /root/.multica）
├── workspace/                # multica 任务工作目录（挂载到 /root/multica_workspaces）
├── opencode-config/          # opencode 全局配置（挂载到 /root/.config/opencode）
├── opencode-data/            # opencode 运行数据（挂载到 /root/.local/share/opencode）
└── README.md
```

> 构建相关文件在 `docker/`；运行相关文件在仓库根目录；文档站点在 `docs/`。

## 文档站点

完整文档在 `docs/`（VitePress，使用 pnpm）：

```bash
cd docs
pnpm install
pnpm dev        # 本地预览 http://localhost:5173/docs/
pnpm build      # 构建到 docs/.vitepress/dist
pnpm preview    # 预览构建产物
```

站点路径固定为 `/docs/`（`docs/.vitepress/config.mts` 里的 `base`），构建产物放到任意静态服务器的
`/docs/` 下即可访问。**不再发布到 GitHub Pages**（原 `docs.yml` 工作流已删除）。

## 前置要求

- Docker + Docker Compose v2
- 已构建/可拉取的 `ghcr.io/i94m/view:php8.4-multica` 镜像（私有包需先 `docker login ghcr.io`）
- 可访问 TKE 内网 Git、模型 API、multica server、MySQL

> 镜像已内置 **multica 与 opencode v2**（及 openspec、uv、MySQL MCP、python3/jq/ripgrep/tini），无需在宿主机或容器内另行安装。

## 快速开始

```bash
cp .env.example .env
# 编辑 .env：git 凭据、HOST_*_PATH 挂载路径、HOST_SITE_CONFIG（站点 config.php）、VIEW_USERNAME（自动登录邮箱）
docker compose up -d
docker logs -f multica-runtime
```

启动后预览站点即可访问（`http://127.0.0.1:8080`），不需要再执行任何初始化命令；
`/opt/preview` 由 entrypoint 里的 `/run/site-init.sh` 生成，仓库不会被修改。

镜像**不内置** opencode 的模型配置。**首次运行先给 opencode 配好模型服务**：

```bash
docker exec -it multica-runtime opencode
```

在界面里输入 `/connect`，按提示选择模型服务商、填入 API Key，保存后即可使用。

MCP（Playwright / MySQL）等配置写在容器的 `/root/.config/opencode/opencode.json`，
完整示例见 `docs/guide/opencode.md`。

分享给同事：把仓库复制过去（运行至少需要 `docker-compose.yml` + `.env.example`），
对方 `cp .env.example .env` 填好后 `docker compose up -d` 即可（镜像已在 registry，无需本地构建），
再首次 `/connect` 配置模型、按文档创建一次 `opencode.json`。

Web 入口：nginx 监听容器内 **80**，compose 映射到宿主 **8080**（`http://127.0.0.1:8080`）。

## 配置项（.env）

| 变量 | 说明 |
| --- | --- |
| `GIT_EMAIL` / `GIT_USERNAME` / `GIT_PASSWORD` | git 身份与凭据；密码含 `@ : / %` 需 URL 编码。entrypoint 会写入 `~/.git-credentials` |
| `GIT_VIEW_CODE` | 可选：仅当 Git 主机不是 `git.ap.tkelevator.com` 时用于推导 git host（`entrypoint-multica.sh`），缺省回退该地址 |
| （登录） | 登录态存于 `./.multica/config.json`（挂载持久化），首次进容器 `multica login --token mul_xxx` |
| `VIEW_USERNAME` | 自动登录邮箱（站点登录页读取；Playwright 也用这个账号） |
| `VIEW_PASSWORD` | Playwright 登录密码（`login.ts` 读取） |
| `HOST_SITE_CONFIG` | 站点配置 `config.php` 的宿主路径，只读挂载到 `/opt/site-config.php` |
| `MULTICA_SERVER_URL` | multica server 地址 |
| `MULTICA_DAEMON_DEVICE_NAME` | multica daemon 设备名；建议填 `"Your-Name's Runtime on Container"`；小队整队共用一个 runtime、一个设备名 |

> Playwright / MySQL MCP（数据库连接）的配置**不在 `.env`**，而在容器内的
> `opencode.json` 里直接填写，见 `docs/guide/opencode.md`。

## 挂载卷

数据与代码通过 bind mount 进容器。宿主路径用环境变量传入（默认值只是占位），
可直接写在 `.env` 里；对应的容器内路径由 `environment` 里的路径变量暴露给 opencode（`VIEW_CODE_PATH` 等）：

```bash
HOST_VIEW_PATH=/Users/you/tke/view
HOST_SITE_CONFIG=/Users/you/tke/sites/hk/config.php
HOST_ASSET_PATH=/Users/you/tke/asset
# …
```

| 宿主路径（变量） | 容器路径 | 变量 / 用途 |
| --- | --- | --- |
| `${HOST_VIEW_PATH}` | `/opt/tk` | `VIEW_CODE_PATH`（VIEW 代码仓库 / 工作目录 / tk 主目录） |
| `${HOST_ASSET_PATH}` | `/opt/ai_asset` | `AI_ASSET_PATH`（AI Asset 仓库） |
| `${HOST_AIR_PLATFORM_PATH}` | `/opt/air_platform` | `AIR_PLATFORM_PATH`（AIR Platform 仓库） |
| `${HOST_VIEW_SQL_PATH}` | `/opt/db_change_scripts` | `VIEW_SQL_PATH`（DB 变更脚本） |
| `${HOST_AUTO_TESTING_PATH}` | `/opt/auto_testing` | `AUTO_TESTING_PATH`（自动化测试） |
| `${HOST_SITE_CONFIG}` | `/opt/site-config.php`（只读） | 站点配置，启动时以 www-data 可读权限落到 `/opt/preview/config.php` |
| `./.multica` | `/root/.multica` | multica 登录态持久化 |
| `./workspace` | `/root/multica_workspaces` | multica 任务工作目录 |
| `./opencode-config` | `/root/.config/opencode` | opencode 全局配置（模型、MCP 等） |
| `./opencode-data` | `/root/.local/share/opencode` | opencode 运行数据 |

> 相对路径（`./.multica`、`./opencode-data` 等）相对于 `docker-compose.yml` 所在处。

## 常用命令

```bash
docker compose up -d                 # 启动
docker compose down                  # 停止
docker restart multica-runtime       # 重启（改完 opencode.json 后生效）
docker logs -f multica-runtime       # 查看日志
docker exec -it multica-runtime bash     # 进入容器
docker exec -it multica-runtime opencode   # 打开 opencode（首次运行 /connect 配置模型）
docker exec -it multica-runtime /run/init.sh   # 只重建 /opt/preview（切分支/重新拉代码后用，不写仓库）
docker compose config                # 校验并查看解析后的配置
```

> compose 用 `image:`（无 `build:`），所以 `docker compose up --build` 不会重建镜像；
> 需先用 buildx 构建/推送（见「镜像构建」），再 `docker compose pull && docker compose up -d`。

容器内 multica 相关：

```bash
multica version
multica daemon status
multica login --token <TOKEN>        # 手动登录
```

## 镜像构建

镜像分两层，各自有独立的构建上下文：

| 镜像 | 目录 | tag |
| --- | --- | --- |
| 基础镜像（debian13 + nginx + php8.4 + pdflib） | `docker/base` | `ghcr.io/i94m/view:php8.4` |
| 运行镜像（base + Node24 + multica/opencode/…） | `docker/runtime` | `ghcr.io/i94m/view:php8.4-multica` |

### 日常：CI 自动构建

push 到 `main` 后由 `.github/workflows/package.yml` 自动构建多架构（amd64 + arm64）并推送 GHCR：

- 改了 `docker/base/**` → 重建 base，并连带重建 runtime
- 只改 `docker/runtime/**` → 只重建 runtime（base 用现成 tag）
- push `v*` tag 或手动 `workflow_dispatch` → 忽略路径过滤，两个都重建

认证用 `GITHUB_TOKEN`（`permissions: packages: write`），**不需要配置任何 secret**。
首次发布请先手动触发一次并勾选 `build_base`，否则 runtime 找不到 base。

### 本地：只构建本机架构

```bash
./docker/build.sh              # 按本机架构构建 base → runtime，--load 到本地
./docker/build.sh --no-cache   # 忽略缓存
```

> 默认**不** `--push`：单平台 push 会覆盖 CI 推出的双平台 manifest，另一种架构的同事就拉不到了。
> 真要推多架构请用 `./docker/build.sh --platform linux/amd64,linux/arm64 --push`（arm64 Mac 上会走 QEMU，很慢）。

也可以手动执行（本地用 `docker build`，它用当前 context 的 docker driver，能直接 `FROM` 本地已有的 base 镜像）：

```bash
docker build --platform linux/arm64 -t ghcr.io/i94m/view:php8.4 docker/base
docker build --platform linux/arm64 -t ghcr.io/i94m/view:php8.4-multica \
  --build-arg BASE_IMAGE=ghcr.io/i94m/view:php8.4 docker/runtime
```

> 构建过程只使用官方源（Debian、nodejs.org、github.com、packages.sury.org），不使用任何镜像代理。

> 需要 BuildKit（`DOCKER_BUILDKIT=1`，Docker 23+ 默认开启）：Dockerfile 依赖 `ARG TARGETARCH`
> （pdflib / Node / multica 的架构分支）和 `--mount=type=cache`。多平台推送还需要 `docker-container`
> driver 的 builder：`docker buildx create --name multiarch --driver docker-container --use --bootstrap`。

> 多平台构建在 arm64 Mac 上会用 QEMU 模拟 amd64。runtime Dockerfile 已避免在构建期执行 Go/原生
> 二进制（git-lfs 用 `apt-get download`+`dpkg-deb -x` 安装以跳过 postinst；`multica version`
> 加了 `|| true`；opencode 用 `--ignore-scripts` 安装并手动接线平台二进制），否则 QEMU 下会 segfault。

### 拉取镜像

GHCR 包默认私有，二选一：

```bash
docker login ghcr.io          # 用 GitHub PAT（勾 read:packages）
# 或在 GitHub → Packages → view → Settings 里把可见性改成 public
```

### 关键构建参数

`docker/runtime/Dockerfile` 的 `ARG`（均可 `--build-arg` 覆盖）：`NODE_VERSION`、`MULTICA_VERSION`、
`OPENCODE_VERSION`、`MYSQL_MCP_VERSION`、`OPENSPEC_VERSION`、`BASE_IMAGE`。
所有版本均固定，构建可复现。

## 注意事项

- 镜像**不内置** opencode 的模型配置：首次运行先 `docker exec -it multica-runtime opencode`，在界面里
  用 `/connect` 配置模型服务。MCP 等配置写在 `/root/.config/opencode/opencode.json`
  （见 `docs/guide/opencode.md`）。
- **密钥**：`.env` 已被 `.gitignore` 和 `.dockerignore`（`.env*`）忽略，不会进 git 也不进镜像；
  数据库连接参数写在容器内的 `opencode.json` 里，注意不要把含密钥的它提交进仓库。
  `.env.bak` / `.env.bk` 等 `.env.*` 同样命中 `.gitignore` 的 `.env.*` 规则，不会入库。
- **网络**：`runtime` 接在 bridge 网络 `multica_net`（子网在 `docker-compose.yml` 里写死）。
  在 macOS Docker Desktop 上，宿主 `ppp0` 的 VPN 路由**不会**进入容器，跨宿主/内网访问用
  `extra_hosts`。
- **预览站点**：`/opt/preview` 每次容器启动都会重新生成（容器内临时目录，不持久化），
  仓库保持零改动。日常改代码即时生效；只有「仓库根目录新增文件」或「在 `vivid/`、
  `vivid/config/`、`vivid/config/12.x/`、`vivid/public/`、`vivid/bootstrap/` 下新增直接子项」，
  以及 `git pull` 改到那两个 Laravel 锚点/`database.php` 时，需要重启容器或执行 `/run/init.sh`。
- **自动登录**：站点登录页被镜像替换为自动登录版（`/login.php` 走 nginx location = /login.php），
  账号取环境变量 `VIEW_USERNAME`（邮箱）。
- **默认用户**：基础镜像默认以 `tk` 用户运行（`HOME=/opt/tk`，正好满足老代码里用
  `$_ENV['HOME']` 定位代码目录的习惯；需要 root 的启动动作由 entrypoint 用
  `sudo -E` 完成，`tk` 有免密 sudo）。multica 镜像则显式切回 `root`（daemon 与
  `/root/.multica` 依赖 root），需要以 tk 身份执行命令时用 `docker exec -u tk ...`。
- **multica 登录**：daemon 启动依赖 `./.multica/config.json`（挂载到 `/root/.multica`）；
  该文件不存在时 daemon 不会自启，需进容器手动 `multica login --token mul_xxx` 生成一次。
- **工作目录**：进容器的落脚目录由 compose 的 `working_dir: /opt/tk` 指定（覆盖镜像里的
  `WORKDIR /workspace`，改它不用重建镜像），所以 `docker exec -it ... bash` 直接落在代码仓库根。
  multica 任务目录则是另一个概念，固定用 `$HOME/multica_workspaces`（容器内
  `/root/multica_workspaces`，已挂载 `./workspace`），与 `working_dir` 无关；
  可用 `MULTICA_WORKSPACES_ROOT` / `daemon start --workspaces-root` 覆盖。唯一约束是工作区根
  不能是当前工作目录或包含当前工作目录，否则 multica 会拒绝 `daemon start/status`
  （`/opt/tk` 与 `/root/multica_workspaces` 互不包含，满足该约束）。
- 更换部署机器时改 `docker-compose.yml` 里的挂载路径即可（`./.multica` 等相对路径无需改），
  并重建一次 `opencode.json`。
