# 组件小队

组件小队把 `Leader`、`Developer`、`BA` 等角色做成**同一个 multica runtime 上的多个 Agent**，再用 multica 的 Squad 把它们组织起来。

整支小队只需要两个容器：

| 容器 | 作用 |
| --- | --- |
| `multica` | runtime 容器（集成 multica + opencode），所有小队成员共用 |
| `playwright` | 浏览器 MCP 容器，所有小队成员共用 |

角色之间不再靠“一人一个容器”隔离：每个角色是一个独立的 multica Agent，有自己的名称、职责指令、模型、可见范围和并发上限；每次运行由 multica 在 `workspace` 下分配独立任务目录，互不覆盖。

适合以下场景：

- 一个任务需要多个角色协作推进。
- 多个 Agent 同时访问同一份 VIEW / AI Asset / AIR Platform 代码和工具链。
- 希望只维护一份登录态、模型配置与 MCP 配置。

::: tip
本页的 compose 就是 [安装 Multica](/guide/host-install) 的 runtime 再加一个 `playwright` 服务。个人使用不需要小队，直接用那一页的单 runtime 配置即可。
:::

## 前置条件

- 宿主机已装好 Docker 与 Docker Compose v2。
- 共享代码目录已存在；默认路径为 `/opt/view/dev`、`/opt/view/ai_asset`、`/opt/view/air_platform`、`/opt/view/view_sql`、`/opt/view/view_autotest_dev2`，如路径不同在 `.env` 里改。
- 预览站点配置 `config.php` 已准备好（`HOST_SITE_CONFIG`）。不需要预览站点时，删掉 compose 里该挂载和 `ports` 即可。
- 宿主机已准备 Playwright Chromium 缓存：`/root/.cache/ms-playwright/chromium-1208`。版本或路径不同时，同步修改 `playwright` 服务的 `volumes` 与 `--executable-path`。

## 组建步骤

以下 `docker compose` 命令都在 `docker-compose.yml` 所在目录执行。从第 6 步开始，`multica` 命令在容器内执行。

### 1. 规划小队成员

先确定这次协作需要哪些角色。下面示例使用三个固定成员（BA 同时承担测试职责）：

| 成员（Agent） | 建议职责 |
| --- | --- |
| `Leader` | 拆解任务、协调节奏、汇总结果 |
| `Developer` | 代码实现、修复问题、整理变更 |
| `BA` | 需求澄清、业务规则确认、验收口径整理，并承担测试验证与复现 |

如果只需要两个成员，少建一个 Agent 即可；需要更多角色，就按同样方式再加一个 Agent。

### 2. 准备共享代码与工具目录

整支小队共用同一套宿主机目录。compose 里通过 `.env` 的 `HOST_*` 变量引用，不要写死路径：

| 容器内路径 | 环境变量 | 用途 |
| --- | --- | --- |
| `/opt/tk` | `HOST_VIEW_PATH` | VIEW 代码仓库 / 工作目录 |
| `/opt/ai_asset` | `HOST_ASSET_PATH` | AI Asset 仓库 |
| `/opt/air_platform` | `HOST_AIR_PLATFORM_PATH` | AIR Platform 仓库 |
| `/opt/db_change_scripts` | `HOST_VIEW_SQL_PATH` | DB 变更脚本 |
| `/opt/auto_testing` | `HOST_AUTO_TESTING_PATH` | 自动化测试 |
| `/opt/site-config.php` | `HOST_SITE_CONFIG` | 预览站点配置（只读） |

### 3. 配置 .env

```dotenv
# 宿主挂载路径（compose 里 ${HOST_*_PATH} 的取值，按本机实际路径填）
HOST_VIEW_PATH=/path/to/view
HOST_ASSET_PATH=/path/to/asset
HOST_AIR_PLATFORM_PATH=/path/to/air_platform
HOST_VIEW_SQL_PATH=/path/to/view_sql
HOST_AUTO_TESTING_PATH=/path/to/auto_testing
HOST_SITE_CONFIG=/path/to/config.php

# Git 身份 / 凭据（含 @ : / % 需 URL 编码）
GIT_EMAIL=you@rayootech.com
GIT_USERNAME=your-username
GIT_PASSWORD=your-token

# View账号
VIEW_USERNAME=you@rayootech.com
VIEW_PASSWORD=your-test-password

# multica
MULTICA_SERVER_URL=http://210.74.156.242:3456
# 整支小队共用一个 runtime，设备名按机器/小队命名即可
MULTICA_DAEMON_DEVICE_NAME="Example team's runtime"
```

::: warning
`.env` 里包含 Git 凭据和测试账号密码，不要提交到 git。
:::

### 4. 保存 docker-compose.yml 并启动

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
      # 预览站点配置（只读，启动时落到 /opt/preview/config.php）
      - ${HOST_SITE_CONFIG}:/opt/site-config.php:ro
      # 整支小队共用的 multica / opencode 状态
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
    # 以 root 运行：需要穿过 /root（0700）才能访问挂载进来的工作区
    user: "0:0"
    entrypoint: ["node", "/app/cli.js"]
    volumes:
      # 复用本机（宿主机）已安装的 Playwright Chromium，避免镜像内没有 msedge
      - /root/.cache/ms-playwright/chromium-1208:/host-chromium:ro
      # 挂载共享输出目录；容器内路径需与 --output-dir 一致
      - ./playwright-output:/root/playwright-output
    command:
      - "--headless"
      - "--browser"
      - "chromium"
      - "--executable-path"
      - "/host-chromium/chrome-linux64/chrome"
      - "--no-sandbox"
      # 允许写入工作区根目录之外的显式路径（容器受信）
      - "--allow-unrestricted-file-access"
      # 自动命名文件（无显式 filename 的截图/快照）落到共享工作区
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

说明：

- `multica` 和 `playwright` 是 compose 里的服务名，不指定 `container_name`，容器名由 compose 自动生成（`<项目名>-multica-1`、`<项目名>-playwright-1`），不会和同机其它 runtime 容器冲突；后续统一用 `docker compose exec <服务名>` 进入。
- 小队共用一套 `./.multica`、`./workspace`、`./opencode-config`、`./opencode-data`，登录和模型只配一次。
- `playwright` 只提供容器网络内的 MCP 地址（`http://playwright:8931/mcp`），两个容器用 compose 默认网络即可互通，不需要映射宿主机端口。
- `8080:80` 是预览站点入口（`http://127.0.0.1:8080`），只用于浏览器查看，可按需保留。

```bash
docker compose config
docker compose up -d
```

### 5. 初始化 runtime（只需一次）

先配置 opencode 的模型服务：

```bash
docker compose exec multica opencode
```

在界面里输入 `/connect`，按提示选择模型服务商、填入 API Key。

浏览器 MCP 指向同一个 `playwright` 容器，写进 `./opencode-config/opencode.json`（已有配置文件时只合并 `mcp.servers.playwright`，不要整份覆盖）：

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

::: tip
数据库 MCP 的配置见 [数据库 MCP](/guide/mcp-database)。所有 Agent 共用这一份 opencode 配置。
:::

然后连接 multica 自托管实例并启动 daemon：

```bash
docker compose exec multica multica setup self-host \
  --server-url http://210.74.156.242:3456 \
  --app-url    http://210.74.156.242:3456
```

验证：

```bash
docker compose exec multica multica daemon status
docker compose exec multica multica runtime list
```

`multica runtime list` 里会出现一个以 `MULTICA_DAEMON_DEVICE_NAME` 命名的 runtime，小队所有 Agent 都挂在这个 runtime 上。

### 6. 创建小队成员（Agent）

先进入容器，下面的 `multica` 命令都在容器内执行：

```bash
docker compose exec multica bash
```

用 `multica runtime list` 拿到 runtime ID，然后为每个角色创建一个 Agent：

```bash
multica agent create --name Leader --runtime-id <runtime-id> \
  --description "小队负责人" \
  --instructions "拆解任务、协调节奏、汇总结果" \
  --visibility workspace --max-concurrent-tasks 2

multica agent create --name Developer --runtime-id <runtime-id> \
  --description "开发" \
  --instructions "代码实现、修复问题、整理变更" \
  --visibility workspace --max-concurrent-tasks 2

multica agent create --name BA --runtime-id <runtime-id> \
  --description "业务分析 / 测试" \
  --instructions "需求澄清、业务规则确认、验收口径整理；负责测试验证、复现问题、整理测试结论" \
  --visibility workspace --max-concurrent-tasks 2
```

- `--max-concurrent-tasks 2` 限制每个成员同时跑的任务数；三个成员合计最多 6 个，按机器配置调整（不填时每人默认 6）。
- `--visibility workspace` 让工作区成员都能调用这个 Agent；只希望自己调用时改成 `private`（默认）。
- 不填 `--model` 时使用 runtime 默认模型，也就是上一步在 opencode 里配置的模型；想给某个角色单独指定模型就加 `--model`。

::: tip
也可以在 Multica 界面里选同一个 runtime 逐个新建 Agent，效果相同。宿主机装了 multica CLI 的话，也可以直接在宿主机执行这些命令，只要登录的是同一个 server 和 workspace。
:::

### 7. 创建 Squad 并加入成员

```bash
multica squad create \
  --name "VIEW Squad" \
  --description "VIEW 组件小队" \
  --leader Leader
```

返回结果里带有 squad ID（Leader 一般会自动加入成员名单，可用 `multica squad member list <squad-id>` 确认）。再逐个加入其他成员（Agent ID 用 `multica agent list` 查看）：

```bash
multica squad member add <squad-id> --member-id <developer-agent-id> --role "开发"
multica squad member add <squad-id> --member-id <ba-agent-id>        --role "需求 / 测试"
```

确认名单：

```bash
multica squad member list <squad-id>
```

### 8. 开始协作

在 Multica 里把任务派给 `Leader`，或直接发起给某个成员。Leader 按名单把子任务分派给其他 Agent，每个成员都在同一个 runtime 上执行，任务目录由 multica 自动分配。

想调整某个角色的行为，直接更新 Agent 即可，不需要改 compose、也不需要重启容器（下一次任务会使用新配置）：

```bash
multica agent update <agent-id> --instructions "新的职责说明"
```

## 挂载与隔离关系

| 挂载项 | 说明 |
| --- | --- |
| `${HOST_VIEW_PATH}:/opt/tk` | 整支小队共享同一份 VIEW 代码 |
| `${HOST_ASSET_PATH}:/opt/ai_asset` | 整支小队共享 AI Asset |
| `${HOST_AIR_PLATFORM_PATH}:/opt/air_platform` | 整支小队共享 AIR Platform |
| `${HOST_VIEW_SQL_PATH}:/opt/db_change_scripts` | 整支小队共享 DB 变更脚本 |
| `${HOST_AUTO_TESTING_PATH}:/opt/auto_testing` | 整支小队共享自动化测试 |
| `./.multica:/root/.multica` | 整支小队共用一份 multica 登录态 |
| `./workspace:/root/multica_workspaces` | 所有 Agent 的任务工作区，multica 按任务分配子目录 |
| `./opencode-config:/root/.config/opencode` | 共用的 opencode 全局配置（模型、MCP 等） |
| `./opencode-data:/root/.local/share/opencode` | 共用的 opencode 运行数据 |
| `./playwright-output:/root/playwright-output:ro` | 只读读取 Playwright 共享输出 |

角色隔离由 multica 的 Agent 承担：名称、职责指令、模型、可见范围和并发上限都按 Agent 配置；运行时 multica 为每个任务准备独立目录，并发任务不会互相覆盖。

::: warning Playwright 输出目录
`playwright` 服务把输出写到容器内 `/root/playwright-output`，对应宿主机 `./playwright-output`。

`multica` 容器以只读方式把同一个宿主机目录挂到 `/root/playwright-output`，所以 Playwright MCP 返回的截图/快照路径可以直接读取。只读挂载不会影响 Agent 自己的任务目录。

如果需要调整输出目录，两处要指向同一个宿主机目录：

```yaml
services:
  multica:
    volumes:
      - ./shared/playwright-output:/root/playwright-output:ro

  playwright:
    volumes:
      - ./shared/playwright-output:/root/playwright-output
```
:::

## 常用维护命令

```bash
docker compose ps
docker compose logs -f multica
docker compose logs -f playwright
docker compose exec multica bash
docker compose restart multica
docker compose down
```

- 容器日志里看不到 multica daemon 的输出：entrypoint 自启动的日志在 `/var/log/multica-daemon-boot.log`，daemon 自身的日志在 `/root/.multica/daemon.log`（对应宿主机 `./.multica/daemon.log`）。

  ```bash
  docker compose exec multica tail -f /var/log/multica-daemon-boot.log
  docker compose exec multica tail -f /root/.multica/daemon.log
  ```

- 修改 `opencode-config` 后重启 `multica` 容器生效。
- 重启 `multica` 会中断正在运行的任务，尽量挑空闲时间操作。
- Agent / Squad 的调整在 Multica 中完成，无需重启容器。
