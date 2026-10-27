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
docker run -d -i --rm --init --pull=always \
  --entrypoint node --name playwright -p 8931:8931 \
  mcr.microsoft.com/playwright/mcp \
  /app/cli.js --headless --browser chromium --no-sandbox --port 8931 --host 0.0.0.0
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

官方文档：[Playwright MCP › Docker](https://github.com/microsoft/playwright-mcp#docker)。
