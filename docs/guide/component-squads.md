# 组件小队

组件小队是一组按角色拆分的 multica runtime 容器。每个容器就是一个“小队成员”，例如：
`leader`、`developer`、`ba`、`tester`。这些成员共享同一套业务代码和工具链，但各自保留独立的 multica 登录态、workspace 与 opencode 数据。

适合以下场景：

- 一个任务需要多个角色协作推进。
- 希望 leader、开发、BA、测试分别保留自己的上下文与任务目录。
- 希望多个 agent 同时访问同一份 VIEW / AI Asset / AIR Platform 代码。

## 如何组建一个小队

### 1. 规划小队成员

先确定这次协作需要哪些角色。下面示例使用四个固定成员：

| 成员 | 建议职责 |
| --- | --- |
| `leader` | 拆解任务、协调节奏、汇总结果 |
| `developer` | 代码实现、修复问题、整理变更 |
| `ba` | 需求澄清、业务规则确认、验收口径整理 |
| `tester` | 测试验证、复现问题、整理测试结论 |

如果只需要两个或三个成员，可以删掉不需要的 service；如果需要更多角色，也可以按同样结构复制一个 service 并改名。

### 2. 准备小队运行目录

这类配置建议作为小队运行目录单独保存，例如：

```text
multica-squads/
├── docker-compose.yml
├── .env
├── workspace/          # Playwright 默认输出目录，可按需改成某个成员的 workspace
├── leader/
│   ├── multica/
│   ├── workspace/
│   └── opencode/
├── developer/
├── ba/
└── tester/
```

::: tip
单人/单 runtime 使用 [安装 Multica](/guide/host-install) 里的 `runtime` 配置即可；本页适合多人协作或需要按角色隔离运行状态的场景。
:::

### 3. 准备共享代码与工具目录

小队成员通常共享这些宿主机目录。建议不要在每个成员 service 里重复写宿主机路径，而是在 compose 顶层 `volumes` 里统一配置：

| 顶层 volume | 默认宿主机目录 | 容器内路径 | 用途 |
| --- | --- | --- | --- |
| `view_code` | `/opt/view/dev` | `/opt/tk` | VIEW 代码仓库 / 工作目录 |
| `ai_asset` | `/opt/view/ai_asset` | `/opt/ai_asset` | AI Asset 仓库 |
| `air_platform` | `/opt/view/air_platform` | `/opt/air_platform` | AIR Platform 仓库 |
| `view_sql` | `/opt/view/view_sql` | `/opt/db_change_scripts` | DB 变更脚本 |
| `auto_testing` | `/opt/view/view_autotest_dev2` | `/opt/auto_testing` | 自动化测试 |

如果你的服务器路径不同，修改 compose 底部 `volumes.*.driver_opts.device`。容器内路径建议保持不变。

### 4. 配置 .env

在小队运行目录创建 `.env`，按需填写：

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
```

::: warning
`.env` 里包含 Git 凭据和测试账号密码，不要提交到 git。
:::

### 5. 复制 compose 配置并启动

把本页的 `docker-compose.yml` 保存到小队运行目录，然后执行：

```bash
docker compose config
docker compose up -d
```

### 6. 初始化每个成员

每个成员都有独立的 `./<role>/multica`、`./<role>/workspace`、`./<role>/opencode`。首次使用时，分别进入成员容器完成登录和模型配置：

```bash
docker compose exec leader bash
multica login --token <TOKEN>
opencode
```

其他成员同理：

```bash
docker compose exec developer bash
docker compose exec ba bash
docker compose exec tester bash
```

在 opencode 中使用 `/connect` 配置模型服务；浏览器 MCP 按下文配置为远程 Playwright 服务。

## 前置条件

- 共享代码目录已存在；默认路径为 `/opt/view/dev`、`/opt/view/ai_asset`、`/opt/view/air_platform`、`/opt/view/view_sql`、`/opt/view/view_autotest_dev2`。如路径不同，请修改 compose 顶层 `volumes` 配置。
- 宿主机已准备 Playwright Chromium 缓存：`/root/.cache/ms-playwright/chromium-1208`。如版本或路径不同，请同步修改 `playwright.volumes` 与 `--executable-path`。
- opencode 的浏览器 MCP 配置应使用远程地址：`http://playwright:8931/mcp`。

示例 `opencode.json` 片段：

```json
{
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

## docker-compose.yml 示例

```yaml
services:
  leader:
    image: registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime
    env_file: [.env]
    depends_on:
      - playwright
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
      - view_code:/opt/tk
      - ai_asset:/opt/ai_asset
      - air_platform:/opt/air_platform
      - view_sql:/opt/db_change_scripts
      - auto_testing:/opt/auto_testing
      - ./leader/multica:/root/.multica
      - ./leader/workspace:/root/multica_workspaces
      - ./leader/opencode:/root/.local/share/opencode
      # 只读读取 Playwright 共享输出，例如 /root/playwright_workspace/.playwright-output
      - ./workspace:/root/playwright_workspace:ro
    restart: unless-stopped

  developer:
    image: registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime
    env_file: [.env]
    depends_on:
      - playwright
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
      - view_code:/opt/tk
      - ai_asset:/opt/ai_asset
      - air_platform:/opt/air_platform
      - view_sql:/opt/db_change_scripts
      - auto_testing:/opt/auto_testing
      - ./developer/multica:/root/.multica
      - ./developer/workspace:/root/multica_workspaces
      - ./developer/opencode:/root/.local/share/opencode
      # 只读读取 Playwright 共享输出，例如 /root/playwright_workspace/.playwright-output
      - ./workspace:/root/playwright_workspace:ro
    restart: unless-stopped

  ba:
    image: registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime
    env_file: [.env]
    depends_on:
      - playwright
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
      - view_code:/opt/tk
      - ai_asset:/opt/ai_asset
      - air_platform:/opt/air_platform
      - view_sql:/opt/db_change_scripts
      - auto_testing:/opt/auto_testing
      - ./ba/multica:/root/.multica
      - ./ba/workspace:/root/multica_workspaces
      - ./ba/opencode:/root/.local/share/opencode
      # 只读读取 Playwright 共享输出，例如 /root/playwright_workspace/.playwright-output
      - ./workspace:/root/playwright_workspace:ro
    restart: unless-stopped

  tester:
    image: registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime
    env_file: [.env]
    depends_on:
      - playwright
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
      - view_code:/opt/tk
      - ai_asset:/opt/ai_asset
      - air_platform:/opt/air_platform
      - view_sql:/opt/db_change_scripts
      - auto_testing:/opt/auto_testing
      - ./tester/multica:/root/.multica
      - ./tester/workspace:/root/multica_workspaces
      - ./tester/opencode:/root/.local/share/opencode
      # 只读读取 Playwright 共享输出，例如 /root/playwright_workspace/.playwright-output
      - ./workspace:/root/playwright_workspace:ro
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
      # 与 runtime 挂载同一份工作区到相同路径，截图/快照可直接写入 agent 工作区
      - ./workspace:/root/multica_workspaces
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
      - "/root/multica_workspaces/.playwright-output"
      - "--port"
      - "8931"
      - "--host"
      - "0.0.0.0"
      - "--allowed-hosts"
      - "*"
    restart: unless-stopped

volumes:
  view_code:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/view/dev
  ai_asset:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/view/ai_asset
  air_platform:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/view/air_platform
  view_sql:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/view/view_sql
  auto_testing:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/view/view_autotest_dev2
```

## 启动与进入小队成员容器

```bash
docker compose config
docker compose up -d
```

进入不同小队成员容器：

```bash
docker compose exec leader bash
docker compose exec developer bash
docker compose exec ba bash
docker compose exec tester bash
```

打开某个成员的 opencode：

```bash
docker compose exec leader opencode
```

## 目录与隔离关系

| 挂载项 | 说明 |
| --- | --- |
| `view_code:/opt/tk` | 多个角色共享同一份 VIEW 代码；宿主机路径由顶层 `volumes.view_code` 配置 |
| `ai_asset:/opt/ai_asset` | 多个角色共享 AI Asset；宿主机路径由顶层 `volumes.ai_asset` 配置 |
| `air_platform:/opt/air_platform` | 多个角色共享 AIR Platform；宿主机路径由顶层 `volumes.air_platform` 配置 |
| `view_sql:/opt/db_change_scripts` | 多个角色共享 DB 变更脚本；宿主机路径由顶层 `volumes.view_sql` 配置 |
| `auto_testing:/opt/auto_testing` | 多个角色共享自动化测试；宿主机路径由顶层 `volumes.auto_testing` 配置 |
| `./<role>/multica:/root/.multica` | 每个成员独立 multica 登录态 |
| `./<role>/workspace:/root/multica_workspaces` | 每个成员独立任务工作区 |
| `./<role>/opencode:/root/.local/share/opencode` | 每个成员独立 opencode 数据 |
| `./workspace:/root/playwright_workspace:ro` | 每个成员只读读取 Playwright 共享输出 |

::: warning Playwright 输出目录
`playwright` 服务默认把输出写到 `./workspace`。

各成员容器默认以只读方式挂载同一个目录到 `/root/playwright_workspace`，所以可以从下面路径读取浏览器截图/快照：

```bash
/root/playwright_workspace/.playwright-output
```

只读挂载不会影响成员自己的任务目录 `/root/multica_workspaces`。

如果希望截图/快照进入某个角色的工作区，需要同时修改 `playwright.volumes` 和各成员的只读挂载，确保它们指向同一个宿主机目录：

```yaml
services:
  leader:
    volumes:
      - ./leader/workspace:/root/playwright_workspace:ro

  playwright:
    volumes:
      - ./leader/workspace:/root/multica_workspaces
```

其他成员同理。也可以改成一个共享目录，例如 `./shared/workspace`，方便所有角色查看浏览器输出。
:::

## 常用维护命令

```bash
docker compose ps
docker compose logs -f playwright
docker compose logs -f leader
docker compose restart leader developer ba tester
docker compose down
```

如果修改了某个成员的 opencode 配置，重启对应容器即可：

```bash
docker compose restart leader
```
