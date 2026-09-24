# OpenCode

OpenCode is an open source AI coding agent. It’s available as a terminal-based interface, desktop app, or web app.

## 安装 opencode

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

详细安装方式见官方文档：<https://opencode.ai/v2/docs>

## 配置文件

| 平台 | 路径 |
| --- | --- |
| macOS / WSL | `~/.config/opencode/opencode.json` |
| Windows 原生 | `C:\Users\<用户名>\.config\opencode\opencode.json` |

文件里包含模型（`model` / `provider`，各自配置）和 MCP。MCP 配置见：

- [Playwright MCP](/guide/mcp-playwright) —— 浏览器自动化
- [Database MCP](/guide/mcp-database) —— 查询 MySQL（默认只读）

写好后重启 opencode 生效。

## 相关

- [Playwright MCP](/guide/mcp-playwright)
- [Database MCP](/guide/mcp-database)
- [配置环境变量](/guide/env)
- [安装 Multica Cli](/guide/host-install)
