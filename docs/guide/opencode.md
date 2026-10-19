# OpenCode

[OpenCode](https://opencode.ai) 是开源的 AI 编码 agent，有终端界面、桌面端和 Web 端。在本项目中它与 multica 配合，用于执行 agent 任务。

::: tip 推荐版本
推荐使用 **OpenCode V2**。本项目文档、安装命令与 `opencode.json` 示例均按 V2 编写。
:::

## 安装 opencode

本机安装 OpenCode V2，命令**全系统通用**：

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

安装后确认：

```bash
opencode --version
```

::: tip
若命令执行失败，建议**让 AI 协助安装**，或参考官方文档 <https://opencode.ai/v2/docs>。
:::

::: info 容器方式运行时无需安装
镜像已集成 opencode（及 multica），见[安装 Multica](/guide/host-install)。
:::

## 配置模型服务

首次使用先给 opencode 配好模型服务（服务商 / API Key），否则无法调用模型。

::: code-group

```bash [本机]
opencode
```

```bash [容器]
docker exec -it multica-runtime opencode
```

:::

::: tip
`multica-runtime` 是 `docker-compose.yml` 里固定的容器名（`container_name`）。
:::

在界面里输入 `/connect`，按提示选择模型服务商、填入 API Key，保存后即可使用。

## 配置文件

| 平台 | 路径 |
| --- | --- |
| macOS / WSL | `~/.config/opencode/opencode.json` |
| Windows 原生 | `C:\Users\<用户名>\.config\opencode\opencode.json` |
| 容器 | `/root/.config/opencode/opencode.json` |

使用本项目提供的 `docker-compose.yml` 启动容器时，容器内的全局配置目录已挂载到宿主机：

```text
./opencode-config:/root/.config/opencode
```

因此在容器里保存的全局配置会落到 compose 所在目录下的 `./opencode-config/`。例如：

```text
./opencode-config/opencode.json
./opencode-config/cli.json
```

OpenCode 的运行数据目录也会单独持久化：

```text
./opencode-data:/root/.local/share/opencode
```

其中 `opencode-config` 用于保存模型、MCP、CLI 设置等配置；`opencode-data` 用于保存会话数据库、日志、snapshot 等运行数据。

`opencode.json` 用于指定模型（`model` / `provider`）与配置 MCP：

- 模型：选择要使用的服务商与模型；
- MCP：
  - [浏览器 MCP](/guide/mcp-playwright) —— 浏览器自动化
  - [数据库 MCP](/guide/mcp-database) —— 查询 MySQL（默认只读）

建议在配置文件中保留 schema，方便编辑器校验与补全：

```json
{
  "$schema": "https://opencode.ai/config.json"
}
```

改完重启 opencode 生效。
