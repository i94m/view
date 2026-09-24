# Multica Runtime

TKE VIEW 的容器化 AI 开发运行环境。基于 `view:php8.4` 镜像，内置 Node.js 24、multica CLI、
opencode、openspec、uv（Python）与 MySQL MCP，用于在本地/服务器上运行 multica daemon
托管的 agent 任务。

## 架构

```
docker compose (project: multica，bridge 网络 multica_net，默认子网 172.31.250.0/24)
└── runtime        view:php8.4-multica-runtime
    ├── apache / php-fpm (EXPOSE 80，映射到宿主 8080:80)
    ├── multica daemon (entrypoint 自启动)
    ├── opencode  (配置由使用者自行创建，见 docs/guide/opencode.md)
    ├── git + git-lfs (filter.lfs.* 已在镜像内配好)
    ├── uv / uvx (Python 包管理)
    └── MCP: Playwright / MySQL (均在 opencode.json 中定义)
```

`runtime` 接在 bridge 网络 `multica_net` 上，子网在 `docker-compose.yml` 里写死
（`172.16.10.0/24`）。compose 把容器 80 端口映射到宿主 8080。

`runtime` 通过 `extra_hosts` 把 `git.ap.tkelevator.com` 固定解析到内网 IP
`10.251.68.173`（容器内 DNS 不走宿主 VPN 的 DNS）。需要时按同样方式补充其它内网域名。

## 目录结构

```
.
├── docker/                   # 构建镜像相关
│   ├── Dockerfile            # 镜像定义（Node24 + git/git-lfs + multica/opencode/openspec + MySQL MCP）
│   ├── entrypoint-multica.sh # 容器入口：配置 git 凭据 + 自启动 multica daemon
│   ├── login.ts              # Playwright 登录辅助（构建时放入 /opt/playwright/）
│   └── .dockerignore
├── docker-compose.yml        # 运行编排：runtime
├── .env.example              # 配置模板，复制为 .env 使用
├── .env                      # 实际配置（含密钥，已被 .gitignore 忽略）
├── docs/                     # VitePress 文档站点（本 README 的内容在这里）
├── multica-runtime/          # 精简运行目录（仅 compose + .env.example + README）
├── multica/                  # multica 登录态持久化（挂载到 /root/.multica）
├── workspace/                # multica 任务工作目录（挂载到 /root/multica_workspaces）
├── opencode/                 # opencode 数据（挂载到 /root/.local/share/opencode）
└── README.md
```

> 构建相关文件在 `docker/`；运行相关文件在仓库根目录；文档站点在 `docs/`。

## 文档站点

完整文档在 `docs/`（VitePress，使用 pnpm）：

```bash
cd docs
pnpm install
pnpm dev        # 本地预览 http://localhost:5173
pnpm build      # 构建到 docs/.vitepress/dist
pnpm preview    # 预览构建产物
```

## 前置要求

- Docker + Docker Compose v2
- 已构建/可拉取的 `registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime` 镜像
- 可访问 TKE 内网 Git、DeepSeek API、multica server、MySQL

## 快速开始

```bash
cp .env.example .env
# 编辑 .env 填 git 凭据 / DEEPSEEK_API_KEY；在 docker-compose.yml 里填挂载路径
docker compose up -d
docker compose logs -f runtime
```

镜像**不内置** opencode 配置。容器起来后进容器创建一次
`/root/.config/opencode/opencode.json`（模型密钥、Playwright、数据库连接都在这里填），
完整示例见 `docs/guide/opencode.md`：

```bash
docker compose exec runtime bash
mkdir -p /root/.config/opencode
vi /root/.config/opencode/opencode.json
```

分享给同事：把仓库复制过去（运行至少需要 `docker-compose.yml` + `.env.example`），
对方 `cp .env.example .env` 填好后 `docker compose up -d` 即可（镜像已在 registry，无需本地构建），
再按文档创建一次 `opencode.json`。

Web 入口：apache 监听容器内 **80**，compose 映射到宿主 **8080**（`http://127.0.0.1:8080`）。

## 配置项（.env）

| 变量 | 说明 |
| --- | --- |
| `GIT_EMAIL` / `GIT_USERNAME` / `GIT_PASSWORD` | git 身份与凭据；密码含 `@ : / %` 需 URL 编码，建议用 access token。entrypoint 会写入 `~/.git-credentials` |
| `GIT_VIEW_CODE` | 用于推导 git host（`entrypoint-multica.sh`），缺省回退 `git.ap.tkelevator.com` |
| `GIT_AI_ASSET` | 保留项，当前无脚本读取 |
| `DEEPSEEK_API_KEY` | opencode 模型密钥（`opencode.json` 中用 `{env:DEEPSEEK_API_KEY}` 读取） |
| （登录） | 登录态存于 `./multica/config.json`（挂载持久化），首次进容器 `multica login --token mul_xxx` |
| `VIEW_USERNAME` / `VIEW_PASSWORD` | Playwright 登录凭据（`login.ts` 读取） |
| `MULTICA_SERVER_URL` | multica server 地址 |

> Playwright / MySQL MCP（数据库连接）的配置**不在 `.env`**，而在容器内的
> `opencode.json` 里直接填写，见 `docs/guide/opencode.md`。

## 挂载卷

数据与代码通过 bind mount 进容器，宿主路径**直接写在 `docker-compose.yml` 的 `volumes`**；
对应的容器内路径由 `environment` 里的路径变量暴露给 opencode（`VIEW_CODE_PATH` 等）：

| 宿主路径（示例） | 容器路径 | 变量 / 用途 |
| --- | --- | --- |
| `/path/to/view` | `/opt/tk` | `VIEW_CODE_PATH`（VIEW 代码仓库 / 工作目录） |
| `/path/to/asset` | `/opt/ai_asset` | `AI_ASSET_PATH`（AI Asset 仓库） |
| `/path/to/air_platform` | `/opt/air_platform` | `AIR_PLATFORM_PATH`（AIR Platform 仓库） |
| `/path/to/view_sql` | `/opt/db_change_scripts` | `VIEW_SQL_PATH`（DB 变更脚本） |
| `/path/to/auto_testing` | `/opt/auto_testing` | `AUTO_TESTING_PATH`（自动化测试） |
| `./multica` | `/root/.multica` | multica 登录态持久化 |
| `./workspace` | `/root/multica_workspaces` | multica 任务工作目录 |
| `./opencode` | `/root/.local/share/opencode` | opencode 数据 |

> 相对路径（`./multica`、`./opencode` 等）相对于 `docker-compose.yml` 所在处。
> `opencode.json`（`/root/.config/opencode/`）**不在挂载卷里**，需在容器内自行创建。

## 常用命令

```bash
docker compose up -d                 # 启动
docker compose down                  # 停止
docker compose restart runtime       # 重启（改完 opencode.json 后生效）
docker compose logs -f runtime       # 查看日志
docker compose exec runtime bash     # 进入容器
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

必须用 `buildx`（BuildKit），否则 Dockerfile 的 `ARG TARGETARCH` 为空会导致构建失败。
Dockerfile 支持 amd64 / arm64（`ARG TARGETARCH` 分支）。

同时构建 amd64 + arm64 并推送到 registry（多平台**不能** `--load`，必须 `--push`）：

```bash
docker login registry.cn-hangzhou.aliyuncs.com
docker buildx build --builder multiarch --platform linux/amd64,linux/arm64 \
  --provenance=false --sbom=false \
  -t registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime --push ./docker
```

> 构建上下文是 `docker/`（`Dockerfile` 与 `entrypoint-multica.sh`、`login.ts` 同目录）。

> `--provenance=false --sbom=false` 必需：否则 BuildKit 会生成 attestation manifest，
> aliyun ACR 会拒绝（`unknown manifest class for application/vnd.oci.empty.v1+json`）。

> `desktop-linux`（docker driver）不支持多平台，需用 `docker-container` driver 的 builder。
> 若本机没有，先创建：
> `docker buildx create --name multiarch --driver docker-container --use --bootstrap`

> 多平台构建在 arm64 Mac 上会用 QEMU 模拟 amd64。Dockerfile 已避免在构建期执行 Go/原生
> 二进制（git-lfs 用 `apt-get download`+`dpkg-deb -x` 安装以跳过 postinst；`multica version`
> 加了 `|| true`；opencode 用 `--ignore-scripts` 安装并手动接线平台二进制，因为其 postinstall
> 会执行二进制自检），否则 QEMU 下会 segfault。Node/npm 自身在 QEMU 下正常。

只构建单个架构并加载到本地（Apple Silicon 用 `linux/arm64` 为原生，避免 QEMU）：

```bash
docker buildx build --platform linux/arm64 \
  -t registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime --load ./docker
```

关键构建参数（Dockerfile `ARG`，均可用 `--build-arg` 覆盖）：`NODE_VERSION`、`MULTICA_VERSION`、
`MYSQL_MCP_VERSION`。opencode（v2，npm 包 `@opencode/cli`）与 openspec 均装最新版本。

## 注意事项

- 镜像**不内置** opencode 配置：`/root/.config/opencode/opencode.json` 由使用者在容器内创建
  （见 `docs/guide/opencode.md`）。该文件不在挂载卷里，容器重建后会丢失，需重新创建。
- **密钥**：`.env` 已被 `.gitignore` 和 `.dockerignore`（`.env*`）忽略，不会进 git 也不进镜像；
  数据库连接参数写在容器内的 `opencode.json` 里，注意不要把含密钥的它提交进仓库。
  另外 `.env.bk` 只被 `.dockerignore` 忽略，**不在 `.gitignore` 列表**，勿提交。
- **网络**：`runtime` 接在 bridge 网络 `multica_net`（子网在 `docker-compose.yml` 里写死）。
  在 macOS Docker Desktop 上，宿主 `ppp0` 的 VPN 路由**不会**进入容器，跨宿主/内网访问用
  `extra_hosts`。
- **multica 登录**：daemon 启动依赖 `./multica/config.json`（挂载到 `/root/.multica`）；
  该文件不存在时 daemon 不会自启，需进容器手动 `multica login --token mul_xxx` 生成一次。
- **工作目录**：multica 任务目录用其默认值 `$HOME/multica_workspaces`（容器内
  `/root/multica_workspaces`，已挂载 `./workspace`）。注意不要把它设成 `/opt/tk`。
- 更换部署机器时改 `docker-compose.yml` 里的挂载路径即可（`./multica` 等相对路径无需改），
  并重建一次 `opencode.json`。
