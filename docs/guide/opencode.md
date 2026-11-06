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

OpenCode V2 会监视配置变更；如果没有及时生效，可在界面执行 `/reload`。

## 跨会话记忆：AgentMemory（可选）

[AgentMemory](https://agent-memory.dev/docs/quickstart) 独立于 OpenCode 运行。
仓库根目录的 `docker-compose.agentmemory.yml` 单独启动 0.9.32 版服务，
记忆持久化到根目录 `./agentmemory-data`（与 OpenCode 数据目录分开）；
runtime 镜像从同版本官方镜像复制 MCP 入口，
提供全局可用的 `agentmemory-mcp`
作为 **本地 stdio MCP 客户端**。两份 Compose 共用 `view-agentmemory` 网络，以
`http://agentmemory:3111` 通信，MCP 不需要另开公网端口。
只有查看器绑定到宿主机 `127.0.0.1:3113`。

1. 在忽略提交的 `.env` 中设置强随机密钥（例如使用 `openssl rand -hex 32` 生成）。
   如果 runtime 由 `multica-runtime/` 下的 Compose 管理，还要在
   `multica-runtime/.env` 填入**同一个值**。不要把密钥写入 `opencode.json`。
2. 先从仓库根目录启动服务端，再启动 runtime。首次启动需要下载 AgentMemory
   的 worker，可能比一般镜像慢；确认服务健康后再连接客户端：

   ```bash
   docker compose -f docker-compose.agentmemory.yml up -d
   docker compose -f docker-compose.agentmemory.yml ps
   cd multica-runtime  # 若使用根目录 docker-compose.yml，则跳过此行
   docker compose up -d
   ```

   runtime 使用 `external` 网络；若未先启动独立记忆服务创建网络，runtime 的
   Compose 会报缺少 `view-agentmemory` 网络。已运行旧版 runtime 镜像时，
   先更新到包含 `agentmemory-mcp` 的新版镜像；可以只启动服务端而不重建 runtime。
   从原来 `multica-runtime` Compose 内的具名卷迁移时，**不要直接删除旧卷**：
   新的根目录 `./agentmemory-data` 是另一份空数据，需要另行备份并迁移。
   旧的 AgentMemory 容器还在运行时会占用 3113 端口；确认数据处理方式后
   先停止旧容器，再启动独立服务，不要执行会清除旧卷的 `down -v`。
3. 只需在每个运行 OpenCode 的容器中执行一次：

   ```bash
   docker exec multica-runtime opencode mcp add agentmemory --global -- agentmemory-mcp
   ```

   该命令向已有配置的 `mcp.servers` 添加条目，不覆盖模型等其他设置。
   新开 OpenCode 会话后，在 `/mcps` 中确认 `agentmemory` 已连接。
   配置强制使用共享服务，服务不可用时不会回退到客户端本地记忆。
   上游 `agentmemory connect opencode` 仍写旧版 `mcp.agentmemory` 结构，
   **不要用它配置 OpenCode V2**。如需手工编辑，使用：

   ```json
   {
     "mcp": {
       "servers": {
         "agentmemory": { "type": "local", "command": ["agentmemory-mcp"] }
       }
     }
   }
   ```

   请将 `mcp.servers.agentmemory` 合并到自己的配置中，而不是覆盖整个文件。
   新会话里使用 `memory_save` 保存带项目标识的决策，再开一个会话用
   `memory_recall` 指定相同项目查询，核对返回的 ID。

### 自动捕获（新版 runtime 镜像内置）

新版 runtime 镜像将固定版本的 capture 插件安装到 OpenCode V2 的
`/etc/opencode/plugins/agentmemory-capture/index.ts`，不会被
`./opencode-config:/root/.config/opencode` 的挂载遮住。**不需要另行下载插件**；
OpenCode 启动后会自动记录新会话、提示词及工具事件，并请求相关上下文。
这与 MCP 工具是两层独立能力：上面第 3 步仍需配置 MCP 才能主动调用
`memory_save` / `memory_recall`。

升级前请检查用户配置目录 `opencode-config/plugins/` 和项目的 `.opencode/plugins/`，
以及 `opencode.json` 的 `plugins`：如果此前安装过同名插件，先**备份并移走**
重复的插件，避免两个 `agentmemory-capture` ID 同时加载失败。不要直接删除
不确定来源的插件文件。新开一个会话后，检查 AgentMemory 查看器的 Sessions
中是否有该会话及提示词；插件在记忆服务不可达时会放行 OpenCode 的正常工作。

注意：自动捕获会将提示词、工具结果及部分推理内容写入共享记忆服务，
务必评估隐私和数据边界。自动捕获不保证每次对话都被提炼成准确的长期事实；
重要决策仍建议显式 `memory_save`。本地 PoC 在 OpenCode 2.2.5 上验证过
插件捕获和 MCP 召回；**自动注入已保存事实到系统提示词的效果尚未验证**。

多个容器接入时，每个容器安装自己的 MCP 客户端、使用同一服务地址和密钥。
同一密钥的客户端没有独立访问权限；需要隔离的团队应使用不同服务实例。
跨主机接入不要暴露明文 HTTP，请通过 HTTPS 或可信的私有隧道连接。
