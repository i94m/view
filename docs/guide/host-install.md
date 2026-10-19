# 安装 Multica

multica 有三种运行方式，任选其一：**桌面端（推荐）**、**CLI**、**容器**。连接自托管实例、启动 daemon 的步骤见 [添加 Runtime](/guide/multica-setup)。

## 桌面端（推荐）

Multica Desktop 是 Multica 的桌面客户端。

- 下载安装：<https://multica.ai/download>
- 官方文档：<https://multica.ai/docs/zh/desktop-app>

### 连接自托管实例

Desktop 默认连接 Multica Cloud。若要连接**自托管实例**，需在用户目录的 `.multica` 下创建 `desktop.json`，填入自托管实例的地址：

| 平台 | 路径 |
| --- | --- |
| macOS | `/Users/<你>/.multica/desktop.json` |
| Linux | `/home/<你>/.multica/desktop.json` |
| Windows | `C:\Users\<你>\.multica\desktop.json` |

::: tip
以上为默认位置。用户目录被迁移或重定向过的话，用实际路径；`.multica` 目录不存在时先创建。
:::

文件内容：

```json
{
  "schemaVersion": 1,
  "apiUrl": "https://api.example.com"
}
```

- `schemaVersion`：固定填 `1`。
- `apiUrl`：自托管实例地址，与 `.env` 里的 `MULTICA_SERVER_URL` 一致；本项目为 `http://210.74.156.242:3456`。

改完重启 Desktop 生效。

## CLI

### 1. 安装

::: code-group

```bash [macOS / Linux]
curl -fsSL http://210.74.156.242:8008/multica/install.sh | bash
```

```powershell [Windows PowerShell]
iwr http://210.74.156.242:8008/multica/install.ps1 | iex
```

:::

### 2. 连接自托管实例

安装后，按 [添加 Runtime](/guide/multica-setup) 连接自托管实例并启动 daemon。

## 容器

用 docker compose 运行 multica runtime；下面所有命令都在 `docker-compose.yml` 所在目录执行。

::: tip 镜像已集成，无需另行安装
镜像内含 **multica 与 opencode**（及 openspec、uv、MySQL MCP 等），宿主机只需装好 Docker / Docker Compose。
:::

连接自托管实例、启动 daemon 见 [添加 Runtime](/guide/multica-setup)。

### 前置条件：先安装 Docker Compose

运行前请先装好 **Docker** 与 **Docker Compose v2**，并确认 Docker 已启动：

```bash
docker --version
docker compose version
```

- 未安装 Docker：按系统到 <https://docs.docker.com/get-docker/> 安装（macOS / Windows 用 Docker Desktop，Linux 用 Docker Engine）。
- Compose 需 **v2**：命令是 `docker compose`（中间是空格），不是旧的 `docker-compose`。Docker Desktop 自带，Linux 单独安装见 <https://docs.docker.com/compose/install/>。

### 配置 .env

在当前目录创建 `.env`，按需填写：

```dotenv
# Git 仓库地址（GIT_VIEW_CODE 供 entrypoint 推导 git host）
GIT_VIEW_CODE=https://git.ap.tkelevator.com/VIEW/view_code.git
GIT_AI_ASSET=https://git.ap.tkelevator.com/AI/AI_Asset.git

# Git 身份 / 凭据（含 @ : / % 需 URL 编码）
GIT_EMAIL=you@rayootech.com
GIT_USERNAME=your-username
GIT_PASSWORD=your-token

# Auto Testing
VIEW_USERNAME=you@rayootech.com
VIEW_PASSWORD=your-test-password

# multica
MULTICA_SERVER_URL=http://210.74.156.242:3456
MULTICA_DAEMON_DEVICE_NAME="{动态名称}'s Runtime on Container"
```

变量含义见 [配置环境变量](/guide/env)。

### 配置 docker-compose.yml

在当前目录创建 `docker-compose.yml`，按本机实际路径修改 `volumes`：

```yaml{4,18-22}
services:
  runtime:
    image: registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime
    container_name: multica-runtime
    env_file: [.env]
    extra_hosts:
      - "git.ap.tkelevator.com:10.251.68.173"
    working_dir: /opt/tk
    stdin_open: true
    tty: true
    environment:
      VIEW_CODE_PATH: /opt/tk
      AI_ASSET_PATH: /opt/ai_asset
      AIR_PLATFORM_PATH: /opt/air_platform
      VIEW_SQL_PATH: /opt/db_change_scripts
      AUTO_TESTING_PATH: /opt/auto_testing
    volumes:
      - /path/to/view:/opt/tk
      - /path/to/asset:/opt/ai_asset
      - /path/to/air_platform:/opt/air_platform
      - /path/to/view_sql:/opt/db_change_scripts
      - /path/to/auto_testing:/opt/auto_testing
      - ./multica:/root/.multica
      - ./workspace:/root/multica_workspaces
      - ./opencode:/root/.local/share/opencode
    ports:
      - "8080:80"
    networks:
      - multica_net
    restart: unless-stopped

networks:
  multica_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.10.0/24
```

### 启动

```bash
docker compose up -d
docker logs -f multica-runtime
```

apache 监听容器内 80，映射到宿主 8080：`http://127.0.0.1:8080`。

### 配置 opencode

容器内 opencode 的安装与配置（模型服务、MCP 等）见 [OpenCode 配置](/guide/opencode)。
