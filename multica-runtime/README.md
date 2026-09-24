# Multica Runtime

镜像：`registry.cn-hangzhou.aliyuncs.com/tke-view/view:php8.4-multica-runtime`

## 运行

```bash
cp .env.example .env      # 填 git 凭据 / DEEPSEEK_API_KEY；挂载路径在 docker-compose.yml 里填
docker compose up -d
docker compose logs -f runtime
```

## 配置 opencode

镜像不内置 opencode 配置。容器起来后进容器创建一次
`/root/.config/opencode/opencode.json`（模型密钥、Playwright、数据库连接都在这里填）：

```bash
docker compose exec runtime bash
mkdir -p /root/.config/opencode
vi /root/.config/opencode/opencode.json
```

完整示例（本机版 / 容器版）见文档站点 `docs/guide/opencode.md`。

## 配置运行时

容器起来后，进容器连到 multica server（执行一次）：

```bash
docker compose exec -it runtime multica setup self-host \
  --server-url http://172.66.30.237:3456 \
  --app-url    http://172.66.30.237:3456
```

会配置 CLI + 登录 + 启动 daemon；登录态持久化在 `./multica`，重建容器无需重配。

验证：

```bash
docker compose exec runtime multica daemon status
docker compose exec runtime multica runtime list
```

## 常用命令

```bash
docker compose up -d                 # 启动
docker compose down                  # 停止
docker compose logs -f runtime       # 日志
docker compose exec runtime bash     # 进容器
```

## 主机安装

连接执行电脑
1.安装
macOS / Linux
curl -fsSL http://172.66.30.237:8008/multica/install.sh | bash
Windows PowerShell
iwr http://172.66.30.237:8008/multica/install.ps1 | iex
 
2.连接
multica setup self-host \ --server-url http://172.66.30.237:8023 \ --app-url http://172.66.30.237:3456
 
3.确认连接状态：
multica daemon status