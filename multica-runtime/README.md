# Multica Runtime

镜像：`ghcr.io/i94m/view:php8.4-multica`

镜像已内置 **multica 与 opencode**（及 openspec、uv、MySQL MCP、python3/jq/ripgrep/tini），无需另行安装。

## 运行

```bash
docker login ghcr.io                  # 私有包需要；已设为 public 可跳过
cp .env.example .env                  # 填 git 凭据 + HOST_*_PATH 挂载路径 + HOST_SITE_CONFIG（站点 config.php）
docker compose up -d
docker logs -f multica-runtime
```

启动后预览站点自动就绪（宿主 8080），`/opt/preview` 由容器启动时生成，不需要执行初始化脚本。

## 配置 opencode

镜像不内置 opencode 的模型配置。**首次运行先给 opencode 配好模型服务**：

```bash
docker exec -it multica-runtime opencode
```

在界面里输入 `/connect`，按提示选择模型服务商、填入 API Key，保存后即可使用。

MCP（Playwright / MySQL）等配置写在容器的 `/root/.config/opencode/opencode.json`，
完整示例（本机版 / 容器版）见文档站点 `docs/guide/opencode.md`。

## 配置运行时

容器起来后，进容器连到 multica server（执行一次）：

```bash
docker exec -it multica-runtime multica setup self-host \
  --server-url http://210.74.156.242:3456 \
  --app-url    http://210.74.156.242:3456
```

会配置 CLI + 登录 + 启动 daemon；登录态持久化在 `./.multica`，重建容器无需重配。

验证：

```bash
docker exec -it multica-runtime multica daemon status
docker exec -it multica-runtime multica runtime list
```

## 常用命令

```bash
docker compose up -d                 # 启动
docker compose down                  # 停止
docker logs -f multica-runtime       # 日志
docker exec -it multica-runtime bash     # 进容器
```

## 主机安装

连接执行电脑
1.安装
macOS / Linux
curl -fsSL http://210.74.156.242:8008/multica/install.sh | bash
Windows PowerShell
iwr http://210.74.156.242:8008/multica/install.ps1 | iex
 
2.连接
multica setup self-host \
  --server-url http://210.74.156.242:3456 \
  --app-url    http://210.74.156.242:3456
 
3.确认连接状态：
multica daemon status
