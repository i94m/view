# 容器运行

用 docker compose 运行 multica runtime（需要 Docker + Compose v2）。在同一个目录下准备
`.env` 与 `docker-compose.yml` 两个文件。

## .env

```dotenv
# Git
GIT_EMAIL=you@rayootech.com
GIT_USERNAME=your-username
GIT_PASSWORD=your-token

# Auto Testing
VIEW_USERNAME=you@rayootech.com
VIEW_PASSWORD=your-test-password

# multica
MULTICA_SERVER_URL=http://172.66.30.237:3456
```

变量含义见 [配置环境变量](/guide/env)。

## docker-compose.yml

挂载路径直接写在这里（按本机实际路径修改）：

```yaml
services:
  runtime:
    image: registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime
    env_file: [.env]
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
      - /path/to/view:/opt/tk
      - /path/to/asset:/opt/ai_asset
      - /path/to/air_platform:/opt/air_platform
      - /path/to/view_sql:/opt/db_change_scripts
      - /path/to/auto_testing:/opt/auto_testing
      - ./multica:/root/.multica
      - ./workspace:/root/multica_workspaces
      - ./opencode:/root/.local/share/opencode
    ports:
      - "8080:80"
    networks:
      - multica_net
    restart: unless-stopped

networks:
  multica_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.10.0/24
```

## 启动

```bash
docker compose up -d
docker compose logs -f runtime
```

apache 监听容器内 80，映射到宿主 8080：`http://127.0.0.1:8080`。

## 连接 multica server

```bash
docker compose exec -it runtime multica setup self-host \
  --server-url http://172.66.30.237:3456 \
  --app-url    http://172.66.30.237:3456
docker compose exec runtime multica daemon status
```

登录态持久化在 `./multica`，重建容器无需重新配置。

## 配置 opencode

在容器内写入 `/root/.config/opencode/opencode.json`（内容见 [OpenCode 配置](/guide/opencode)）：

```bash
docker compose exec runtime bash
mkdir -p /root/.config/opencode
vi /root/.config/opencode/opencode.json
```

> 该文件容器重建后会丢失，需重新创建。需要浏览器自动化时，按
> [Playwright MCP › 容器方式](/guide/mcp-playwright) 另起独立 Playwright 容器。

## 常用命令

```bash
docker compose up -d                 # 启动
docker compose down                  # 停止
docker compose restart runtime       # 重启（改完 opencode.json 后生效）
docker compose exec runtime bash     # 进入容器
docker compose pull && docker compose up -d   # 更新运行环境
```

## 相关

- [配置环境变量](/guide/env)
- [安装 Multica Cli](/guide/host-install)
- [OpenCode 配置](/guide/opencode)
