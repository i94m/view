# 浏览器 MCP

<div style="margin: 16px 0 24px;">
  <video controls preload="metadata" playsinline poster="/videos/add-playwright-mcp-poster.jpg" style="width: 100%; border-radius: 8px; background: #000;">
    <source src="/videos/add-playwright-mcp.mp4" type="video/mp4" />
    你的浏览器不支持 HTML5 视频，请<a href="../videos/add-playwright-mcp.mp4">下载视频</a>观看。
  </video>
  <p style="margin-top: 8px; text-align: center; color: var(--vp-c-text-2); font-size: 14px;">视频教程：添加浏览器 MCP</p>
</div>

为 opencode 提供浏览器自动化（打开页面、点击、截图、抓取等），是 multica 任务执行网页操作/登录的基础。

以下配置适用于 **OpenCode V2**。

## 各平台配置

写在 `opencode.json` 的 `mcp.servers.playwright`。下面示例是完整配置；如果已有 `opencode.json`，只把 `mcp.servers.playwright` 合并进去即可。

::: code-group

```json [macOS]
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "playwright": {
        "type": "local",
        "command": ["npx", "@playwright/mcp@latest", "--browser", "msedge"]
      }
    }
  }
}
```

```json [Windows 原生]
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "playwright": {
        "type": "local",
        "command": ["cmd", "/c", "npx", "--yes", "@playwright/mcp@latest", "--browser", "msedge"]
      }
    }
  }
}
```

```json [WSL]
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "playwright": {
        "type": "local",
        "command": [
          "cmd.exe", "/c", "npx", "--yes", "@playwright/mcp@latest", "--browser", "msedge"
        ],
        "codemode": false
      }
    }
  }
}
```

:::

::: info 说明
- `--browser msedge`：Playwright 自行启动系统 Edge，无需调试端口。
- Windows / WSL 用 `cmd`（`cmd /c` / `cmd.exe`）才能找到 `npx`；WSL 因此要在 Windows 上装好 Node.js 与 Edge。
- `--yes` 让 npx 自动确认安装；WSL 另加 `codemode: false`。
:::

## 容器方式

在容器里跑 opencode 时，另起一个独立 Playwright 容器，opencode 用远程地址连过去：

```bash
mkdir -p ~/playwright-profile
docker run -d -i --rm --init --pull=always \
  --entrypoint node --name playwright -p 8931:8931 \
  -v ~/playwright-profile:/data/profile \
  mcr.microsoft.com/playwright/mcp \
  /app/cli.js --headless --browser chromium --no-sandbox \
  --user-data-dir /data/profile \
  --port 8931 --host 0.0.0.0
```

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "playwright": {
        "type": "remote",
        "url": "http://localhost:8931/mcp"
      }
    }
  }
}
```

::: info 说明
- 官方镜像仅支持无头 Chromium。
- 同一 docker 网络时用容器名：`http://playwright:8931/mcp`。
- 单 runtime 场景可以让 Playwright 容器独立运行；用[小队](/guide/squads)时，它是 compose 里的 `playwright` 服务，随小队一起启动，不需要映射宿主机端口。
:::

## 登录态持久化（cookie）

Playwright MCP 默认是持久化 profile，但写在**容器内部**：

```text
/root/.cache/ms-playwright/mcp-{channel}-{workspace-hash}
```

这带来两个问题：

1. 容器 `--rm` 或 compose 重建后目录消失，登录态、cookie 全部丢失；
2. `{workspace-hash}` 由 MCP 客户端的 workspace root 计算，换项目目录就是另一个 profile。

要跨重启保留登录态，显式指定 `--user-data-dir` 并挂载到宿主机：

```yaml
services:
  playwright:
    image: mcr.microsoft.com/playwright/mcp:latest
    entrypoint: ["node", "/app/cli.js"]
    volumes:
      - ./playwright-profile:/data/profile
    command:
      - "--headless"
      - "--browser"
      - "chromium"
      - "--no-sandbox"
      - "--user-data-dir"
      - "/data/profile"
      - "--port"
      - "8931"
      - "--host"
      - "0.0.0.0"
```

目录里是完整的 Chromium profile，关键内容：

| 内容 | 文件 |
|---|---|
| Cookie（登录态） | `Default/Cookies`（SQLite） |
| localStorage / IndexedDB | `Default/Local Storage`、`Default/IndexedDB` |
| 浏览器设置 / 指纹 | `Local State` 等 |

注意：

- **不要加 `--isolated`**，它把 profile 放在内存，不会写盘。
- 一个持久 profile 同时只能被一个浏览器实例使用；需要并行时用 `--isolated` 或给每个实例分配不同的 `--user-data-dir`。
- 想重置登录态：停掉容器，删除 `./playwright-profile` 后重新启动。
- 只想预置 cookie 而不共享整个 profile：用 `--storage-state <path>`（通常配合 `--isolated`）。

### 重启后报 `Browser is already in use for /data/profile`

这是 Chromium 的单例锁残留：容器被强杀或宿主机重启时，profile 目录里会留下
`SingletonLock` / `SingletonCookie` / `SingletonSocket`。锁里记录的是旧容器的
`<hostname>-<pid>`，新容器里这个 pid 可能又被占用，Chromium 就误判为已有实例。

`browser_close` 只关闭页面，不会杀掉浏览器进程，也无法释放这个锁。恢复方法：

```bash
# 先确认没有第二个容器/实例在用同一个 profile
docker ps | grep playwright

# 宿主机能直接访问挂载目录时
rm -f ./playwright-profile/SingletonLock ./playwright-profile/SingletonCookie ./playwright-profile/SingletonSocket

# 或用一次性容器清理（路径与 compose 的挂载保持一致）
docker run --rm -v "$PWD/playwright-profile:/data/profile" alpine \
  rm -f /data/profile/SingletonLock /data/profile/SingletonCookie /data/profile/SingletonSocket
```

长期方案只加一行 `entrypoint`，启动前清掉残留锁，不需要额外脚本：

```yaml
services:
  playwright:
    image: mcr.microsoft.com/playwright/mcp:latest
    entrypoint:
      - /bin/sh
      - -c
      - rm -f /data/profile/Singleton*; exec node /app/cli.js "$$@"
      - --
    volumes:
      - ./playwright-profile:/data/profile
    command:
      - "--headless"
      - "--browser"
      - "chromium"
      - "--no-sandbox"
      - "--user-data-dir"
      - "/data/profile"
      - "--port"
      - "8931"
      - "--host"
      - "0.0.0.0"
```

`$$@` 是 compose 的转义写法（`$$` → `$`），把 `command` 的参数原样传给 `cli.js`。
这样每次容器启动都会先删除 `SingletonLock/Cookie/Socket`，宿主机重启后也能自动恢复。

官方文档：[Playwright MCP › Docker](https://github.com/microsoft/playwright-mcp#docker)。
