# 本地环境 <Badge type="tip" text="php8.4" />

容器内是 `nginx` + `php-fpm`，每个容器加载一份站点配置（只读挂载的 `/opt/site-config.php`）；需要同时跑多个环境时，建多个容器、各自挂不同的站点配置即可。

容器默认以 `tk` 用户运行（`HOME=/opt/tk`），老代码里用 `$_ENV['HOME']` 定位代码目录的行为可以直接生效；需要 root 时用 `sudo`（免密）。

| 路径 | 说明 |
| --- | --- |
| `/opt/tk` | View 代码仓库 |

## 使用 Docker run

```shell
docker run -d --name local --restart always \
  -v D:/tke/local:/opt/tk \
  -v D:/tke/sites/hk/config.php:/opt/site-config.php:ro \
  -e VIEW_USERNAME=you@example.com \
  -p 80:80 ghcr.io/i94m/view:php8.4
```

- `/opt/tk`：View 代码目录
- `/opt/site-config.php`：站点配置，只读挂载（例如 `sites/hk/config.php`）
- `VIEW_USERNAME`：自动登录用的邮箱

启动后访问 [http://localhost](http://localhost)。

## 切换站点

一个容器只加载一份站点配置，换站点就是换 `/opt/site-config.php` 的挂载源。比如要访问 **china**，把挂载源换成 `sites/china/config.php`：

```shell
docker run -d --name china --restart always \
  -v D:/tke/local:/opt/tk \
  # [!code focus]
  -v D:/tke/sites/china/config.php:/opt/site-config.php:ro \
  -e VIEW_USERNAME=you@example.com \
  -p 80:80 ghcr.io/i94m/view:php8.4
```

| 站点 | 站点配置挂载 |
| --- | --- |
| china | `-v D:/tke/sites/china/config.php:/opt/site-config.php:ro` |
| hk | `-v D:/tke/sites/hk/config.php:/opt/site-config.php:ro` |
| global | `-v D:/tke/sites/global/config.php:/opt/site-config.php:ro` |

同时跑多个站点就起多个容器：换 `--name`、换宿主端口（如 `-p 8001:80`），各自挂自己的站点配置。

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
      - D:/tke/sites/hk/config.php:/opt/site-config.php:ro
    ports:
      - "80:80"
    restart: unless-stopped
```

在 `docker-compose.yml` 所在目录执行：

```shell
docker compose up -d
```

访问 [http://localhost](http://localhost)；如果启动失败，先检查本机 80 端口是否被占用。

::: warning Windows / WSL
WSL 环境请把代码放在 Linux 文件系统里（例如 `~/tke/dev`），不要放在 `/mnt/c/...`，参考 [Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/windows/wsl/)。
:::
