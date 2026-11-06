# 持久记忆

有了持久记忆，编码 Agent 可以在新会话中**主动检索**之前保存的项目约定、技术决策和排查结论，不必每次从头解释。本示例仅启用 MCP 显式存取，**不安装自动捕获插件，也不会自动注入过往会话**。[AgentMemory](https://www.agent-memory.dev/docs) 是独立的记忆服务，支持 OpenCode、Claude Code、Codex、Cursor 等多种 Agent。下面用 Docker Compose 部署服务，并以 **OpenCode** 为接入示例，无需下载本项目仓库。

## 1. 创建目录和密钥

```bash
mkdir -p agentmemory-demo
cd agentmemory-demo
openssl rand -hex 32
```

在当前目录创建 `.env`，将命令输出替换到下方，不要把实际密钥提交到 Git：

```dotenv
AGENTMEMORY_SECRET=在这里填入生成的随机值
```

## 2. 创建 docker-compose.yml

在同一目录创建 `docker-compose.yml`。`agentmemory` 是通用记忆服务；`runtime` 仅用于演示 OpenCode，使用其他 Agent 时可按其官方接入方式替换：

```yaml
services:
  agentmemory:
    image: ghumarerohit/agentmemory:0.9.32
    environment:
      AGENTMEMORY_SECRET: ${AGENTMEMORY_SECRET:?请先设置密钥}
    volumes:
      - ./agentmemory-data:/data
    ports:
      - "127.0.0.1:3113:3113"
    restart: unless-stopped

  runtime:
    image: ghcr.io/i94m/view:php8.4-multica
    container_name: multica-runtime
    environment:
      AGENTMEMORY_URL: http://agentmemory:3111
      AGENTMEMORY_SECRET: ${AGENTMEMORY_SECRET:?请先设置密钥}
      AGENTMEMORY_FORCE_PROXY: "1"
      MULTICA_DAEMON_AUTOSTART: "0"
    volumes:
      - ./workspace:/workspace
      - ./opencode-config:/root/.config/opencode
      - ./opencode-data:/root/.local/share/opencode
    depends_on:
      - agentmemory
    restart: unless-stopped
```

两个容器在默认 Compose 网络中通过 `agentmemory:3111` 通信，只有查看器的 `3113` 端口绑定在宿主机本地。记忆与 OpenCode 配置分别保存在当前目录的 `agentmemory-data/`、`opencode-config/` 中。

## 3. 启动并接入 OpenCode（示例）

```bash
docker compose up -d
docker exec multica-runtime opencode mcp add agentmemory --global -- agentmemory-mcp
docker exec -it multica-runtime opencode
```

首次使用 OpenCode 时，在界面输入 `/connect` 配置模型。然后打开 `/mcps`，确认 `agentmemory` 已连接；明确要求 Agent 使用 `memory_save` 保存一条带项目名称的决策，记录成功工具调用返回的记忆 ID。新开会话后，明确要求使用 `memory_recall` 查询**同一项目**，核对返回的是同一个 ID。只看到 Agent 复述内容，不代表已经存入记忆。如果首次连接时服务还没准备好，稍等后在 `/mcps` 重试。

示例镜像只内置 MCP 客户端，不会自动记录 OpenCode 会话；查看器可以查看显式保存的记忆，但 Sessions 中没有自动捕获的记录是正常的。已有 OpenCode 容器的用户不必再创建一个 runtime：让原容器接入同一 Docker 网络、设置上述三个 `AGENTMEMORY_*` 环境变量，并在其中配置 MCP 即可。

使用其他 Agent 时，保留 `agentmemory` 服务并按[官方接入指南](https://agent-memory.dev/docs/connectors)配置对应客户端；不同 Agent 支持插件、钩子或仅 MCP，自动捕获能力并不相同。
