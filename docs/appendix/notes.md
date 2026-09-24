# 注意事项

## 配置与密钥

- `/root/.config/opencode/opencode.json` 不随宿主机目录持久化，容器重建后会丢失，需重新创建。
- `.env` 已被 `.gitignore` / `.dockerignore` 忽略；但 `.env.bk` 只被 `.dockerignore` 忽略，勿提交。
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
