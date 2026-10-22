# 本地环境 <Badge type="tip" text="php8.4" />

容器内是 `apache` + `php-fpm`，每个容器加载一份站点配置（`config.php`）；需要同时跑多个环境时，建多个容器、各自挂不同的站点配置即可。

容器默认以 `tk` 用户运行（`HOME=/opt/tk`），老代码里用 `$_ENV['HOME']` 定位代码目录的行为可以直接生效；需要 root 时用 `sudo`（免密）。

| 路径 | 说明 |
| --- | --- |
| `/opt/tk` | View 代码仓库（可只读挂载，镜像不会修改它） |
| `/opt/preview` | 预览站点根，容器启动时自动生成 |
| `/opt/preview-config/config.php` | 只读挂载的站点配置 |

## 使用 Docker run

```shell
docker run -d --name local --restart always \
  -v D:/tke/local:/opt/tk \
  -v D:/tke/sites/hk/config.php:/opt/preview-config/config.php:ro \
  -e VIEW_USERNAME=you@example.com \
  -p 80:80 ghcr.io/i94m/view:php8.4
```

- `/opt/tk`：View 代码目录，加 `:ro` 也可以（镜像不写仓库）
- `/opt/preview-config/config.php`：站点配置，只读挂载（例如 `sites/hk/config.php`）
- `VIEW_USERNAME`：自动登录用的邮箱，对应 `user` 表的 `Username` 字段

启动后访问 [http://localhost](http://localhost)。

::: details 运行 Dev/Dev2/RC 等环境（可选）
换端口和挂载路径即可：

```shell
docker run -d --name dev --restart always \
  -v D:/tke/dev:/opt/tk \
  -v D:/tke/sites/hk/config.php:/opt/preview-config/config.php:ro \
  -e VIEW_USERNAME=you@example.com \
  -p 8001:80 ghcr.io/i94m/view:php8.4
```

访问 [http://localhost:8001](http://localhost:8001)。
:::

## 使用 Docker Compose

```yaml
services:
  local:
    image: ghcr.io/i94m/view:php8.4
    container_name: local
    environment:
      VIEW_USERNAME: you@example.com
    volumes:
      - D:/tke/local:/opt/tk
      - D:/tke/sites/hk/config.php:/opt/preview-config/config.php:ro
    ports:
      - "80:80"
    restart: always
```

在 `docker-compose.yml` 所在目录执行：

```shell
docker compose up -d
```

访问 [http://localhost](http://localhost)；如果启动失败，先检查本机 80 端口是否被占用。

::: warning Windows / WSL
Windows 下建议把项目目录设置为区分大小写模式，参考 [case-sensitivity](https://learn.microsoft.com/zh-cn/windows/wsl/case-sensitivity)。

WSL 环境请把代码放在 Linux 文件系统里（例如 `/var/tke/dev`），参考 [Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/windows/wsl/)。
:::
