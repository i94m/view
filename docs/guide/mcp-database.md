# 数据库 MCP

为 opencode 提供只读的 MySQL 查询能力，供 multica 任务读取业务数据。

写在 `opencode.json` 的 `mcp.servers.local_tkhk`（各平台相同）：

```json
"local_tkhk": {
  "type": "local",
  "command": ["npx", "-y", "@benborla29/mcp-server-mysql"],
  "environment": {
    "MYSQL_HOST": "数据库地址",
    "MYSQL_PORT": "3306",
    "MYSQL_USER": "数据库用户名",
    "MYSQL_PASS": "数据库密码",
    "MYSQL_DB": "数据库名",
    "ALLOW_INSERT_OPERATION": "false",
    "ALLOW_UPDATE_OPERATION": "false",
    "ALLOW_DELETE_OPERATION": "false"
  },
  "timeout": { "startup": 60000 }
}
```

- **默认只读**：三个 `ALLOW_*_OPERATION` 均为 `false`，只开放查询。
- 连接参数写在 `environment` 里，不在 `.env`（见[配置环境变量](/guide/env)）。
- `timeout.startup` 预留 60s：首次 `npx` 拉取 `mcp-server-mysql` 可能较慢。

::: tip 密钥安全
`opencode.json` 含数据库密码，不要提交进代码仓库。
:::
