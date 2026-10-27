# Agent 小队

把 `Leader`、`Developer`、`BA` 等角色做成**同一个 multica runtime 上的多个 Agent**，再用 Multica 的 Squad 组织起来。每个角色有独立的指令、模型和并发上限，任务目录由 multica 分配，互不覆盖。

整支小队只需两个容器：

| 容器 | 作用 |
| --- | --- |
| `multica` | runtime（multica + opencode），所有成员共用 |
| `playwright` | 浏览器 MCP，所有成员共用 |

::: tip
本页的 compose 就是 [安装 Multica](/guide/host-install) 的 runtime 再加一个 `playwright` 服务；个人使用直接用那一页的配置即可。
:::

## 前置条件

- 宿主机已装好 Docker 与 Docker Compose v2。
- 共享代码目录与预览站点 `config.php` 已就绪（例如 `/opt/view/dev` 等），具体路径在下一步 `.env` 里填。
- 宿主机已准备 Playwright Chromium 缓存 `/root/.cache/ms-playwright/chromium-1208`；版本或路径不同时，修改 `playwright` 的挂载与 `--executable-path`。

## 1. 规划成员

| 成员（Agent） | 职责 |
| --- | --- |
| `Leader` | 拆解任务、协调节奏、汇总结果 |
| `Developer` | 代码实现、修复问题、整理变更 |
| `BA` | 需求澄清、验收口径整理，并承担测试验证与复现 |

BA 同时承担测试职责；成员数量可按需增减。

## 2. 配置 .env

```dotenv
# 共享目录，对应容器内 /opt/tk、/opt/ai_asset、/opt/air_platform、
# /opt/db_change_scripts、/opt/auto_testing
HOST_VIEW_PATH=/path/to/view
HOST_ASSET_PATH=/path/to/asset
HOST_AIR_PLATFORM_PATH=/path/to/air_platform
HOST_VIEW_SQL_PATH=/path/to/view_sql
HOST_AUTO_TESTING_PATH=/path/to/auto_testing

# 预览站点配置；不需要预览站点时，删掉这行与 compose 里对应的挂载、ports
HOST_SITE_CONFIG=/path/to/config.php

# Git 身份 / 凭据（含 @ : / % 需 URL 编码）
GIT_EMAIL=you@rayootech.com
GIT_USERNAME=your-username
GIT_PASSWORD=your-token

# View账号
VIEW_USERNAME=you@rayootech.com
VIEW_PASSWORD=your-test-password

# multica（整支小队共用一个 runtime）
MULTICA_SERVER_URL=http://210.74.156.242:3456
MULTICA_DAEMON_DEVICE_NAME="Example team's runtime"
```

::: warning
`.env` 里包含 Git 凭据和测试账号密码，不要提交到 git。
:::

## 3. 保存 docker-compose.yml 并启动

```yaml
services:
  multica:
    image: ghcr.io/i94m/view:php8.4-multica
    env_file: [.env]
    depends_on:
      - playwright
    extra_hosts:
      - "git.ap.tkelevator.com:10.251.68.173"
    stdin_open: true
    tty: true
    environment:
      VIEW_CODE_PATH: /opt/tk
      AI_ASSET_PATH: /opt/ai_asset
      AIR_PLATFORM_PATH: /opt/air_platform
      VIEW_SQL_PATH: /opt/db_change_scripts
      AUTO_TESTING_PATH: /opt/auto_testing
    volumes:
      - ${HOST_VIEW_PATH}:/opt/tk
      - ${HOST_ASSET_PATH}:/opt/ai_asset
      - ${HOST_AIR_PLATFORM_PATH}:/opt/air_platform
      - ${HOST_VIEW_SQL_PATH}:/opt/db_change_scripts
      - ${HOST_AUTO_TESTING_PATH}:/opt/auto_testing
      - ${HOST_SITE_CONFIG}:/opt/site-config.php:ro
      # 整支小队共用
      - ./.multica:/root/.multica
      - ./workspace:/root/multica_workspaces
      - ./opencode-config:/root/.config/opencode
      - ./opencode-data:/root/.local/share/opencode
      # 只读读取 Playwright 输出
      - ./playwright-output:/root/playwright-output:ro
    ports:
      - "8080:80"
    restart: unless-stopped

  playwright:
    image: mcr.microsoft.com/playwright/mcp:latest
    init: true
    # 以 root 运行：需要穿过 /root（0700）访问挂载进来的工作区
    user: "0:0"
    entrypoint: ["node", "/app/cli.js"]
    volumes:
      # 复用宿主机已安装的 Chromium
      - /root/.cache/ms-playwright/chromium-1208:/host-chromium:ro
      # 与 --output-dir 保持一致
      - ./playwright-output:/root/playwright-output
    command:
      - "--headless"
      - "--browser"
      - "chromium"
      - "--executable-path"
      - "/host-chromium/chrome-linux64/chrome"
      - "--no-sandbox"
      - "--allow-unrestricted-file-access"
      - "--output-dir"
      - "/root/playwright-output"
      - "--port"
      - "8931"
      - "--host"
      - "0.0.0.0"
      - "--allowed-hosts"
      - "*"
    restart: unless-stopped
```

- 两个服务按 compose 默认网络用服务名互访，Playwright MCP 地址是 `http://playwright:8931/mcp`，不需要暴露宿主机端口。
- 小队共用一套 `./.multica`、`./workspace`、`./opencode-config`、`./opencode-data`，登录和模型只配一次。
- `./playwright-output` 由 `playwright` 写入、`multica` 只读挂载，MCP 返回的截图/快照路径可以直接读取。
- `8080:80` 仅供浏览器查看预览站点，可按需删掉。

```bash
docker compose config
docker compose up -d
```

## 4. 初始化 runtime（只需一次）

配置 opencode 模型：

```bash
docker compose exec multica opencode
```

在界面里输入 `/connect`，选择模型服务商、填入 API Key。

浏览器 MCP 写进 `./opencode-config/opencode.json`（已有配置只合并 `mcp.servers.playwright`）：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "playwright": {
        "type": "remote",
        "url": "http://playwright:8931/mcp"
      }
    }
  }
}
```

数据库 MCP 见 [数据库 MCP](/guide/mcp-database)。

连接 multica 并启动 daemon：

```bash
docker compose exec multica multica setup self-host \
  --server-url http://210.74.156.242:3456 \
  --app-url    http://210.74.156.242:3456
```

确认 runtime 已注册（名称取自 `MULTICA_DAEMON_DEVICE_NAME`）：

```bash
docker compose exec multica multica runtime list
```

## 5. 开始协作

在 Multica 里用这个 runtime 建好成员 Agent 和小队后，把任务派给 `Leader`，或直接发起给某个成员；Leader 会按名单分派，成员在同一个 runtime 上执行。

调整角色行为直接改对应 Agent，不需要改 compose，也不需要重启容器。

## 常用维护命令

```bash
docker compose ps
docker compose logs -f multica
docker compose restart multica
docker compose down
docker compose exec multica bash
```

- daemon 日志：`docker compose exec multica tail -f /root/.multica/daemon.log`
- Playwright 异常：`docker compose logs -f playwright`
- 修改 `opencode-config` 后重启 `multica` 生效；重启会中断正在运行的任务。
