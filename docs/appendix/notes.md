# 注意事项

## 配置与密钥

- 首次运行先 `docker exec -it multica-runtime opencode`，在界面里用 `/connect` 配置模型服务
  （见[安装 Multica](/guide/host-install)）。
- `.env` 及 `.env.*`（如 `.env.bak`、`.env.bk`）均被 `.gitignore` / `.dockerignore` 忽略，不会入库；
  `.env.example`（`!.env.example`）例外，模板需提交。
- 数据库密码等写在 `opencode.json` 里，注意不要提交进代码仓库。

## 网络

- `runtime` 接在 bridge 网络 `multica_net`（子网在 `docker-compose.yml` 里写死）。
- 容器内 DNS 不走宿主 VPN，`git.ap.tkelevator.com` 通过 `extra_hosts` 固定到 `10.251.68.173`；
  其它内网域名照此补充。macOS Docker Desktop 上宿主 VPN 路由不会自动进入容器，同样靠
  `extra_hosts`。

## multica

- daemon 依赖 `./multica/config.json`；该文件不存在时不会自启，需进容器
  `multica login --token mul_xxx` 生成一次。
- entrypoint 后台托管 daemon，异常退出 30s 后自动重拉；日志在 `/var/log/multica-daemon-boot.log`。
- 任务工作目录用默认 `$HOME/multica_workspaces`（宿主机 `./workspace`），不要设成 `/opt/tk`，
  否则 multica 会拒绝启动 daemon。

## 部署迁移

更换机器时改 `docker-compose.yml` 里的挂载路径即可，并在新机器上重建一次
`opencode.json`（见 [OpenCode 配置](/guide/opencode)）。
