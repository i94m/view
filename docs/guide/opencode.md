# OpenCode

[OpenCode](https://opencode.ai) 是开源的 AI 编码 agent，有终端界面、桌面端和 Web 端。在本项目中它
与 multica 配合，用于执行 agent 任务。

## 安装 opencode

本机安装，命令**全系统通用**：

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

安装后确认：

```bash
opencode --version
```

> 若命令执行失败，建议**让 AI 协助安装**，或参考官方文档 <https://opencode.ai/v2/docs>。
>
> 用**容器方式**运行时**无需安装**：镜像已集成 opencode（及 multica），见[安装 Multica](/guide/host-install)。

## 配置模型服务

首次使用先给 opencode 配好模型服务（服务商 / API Key），否则无法调用模型。

**本机**直接运行：

```bash
opencode
```

**容器**里先进入容器，再运行同样的命令：

```bash
docker exec -it multica-runtime opencode
```

> `multica-runtime` 由 `docker-compose.yml` 的 `container_name` 固定；

在界面里输入 `/connect`，按提示选择模型服务商、填入 API Key，保存后即可使用。

## 配置文件

| 平台 | 路径 |
| --- | --- |
| macOS / WSL | `~/.config/opencode/opencode.json` |
| Windows 原生 | `C:\Users\<用户名>\.config\opencode\opencode.json` |
| 容器 | `/root/.config/opencode/opencode.json` |

`opencode.json` 用于指定模型（`model` / `provider`）与配置 MCP：

- 模型：选择要使用的服务商与模型；
- MCP：
  - [浏览器 MCP](/guide/mcp-playwright) —— 浏览器自动化
  - [数据库 MCP](/guide/mcp-database) —— 查询 MySQL（默认只读）

改完重启 opencode 生效。
