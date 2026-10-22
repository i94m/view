# 本地环境 <Badge type="tip" text="php8.4" />

## 使用说明

::: tip 提示：
当前环境使用 `apache` + `php-fpm`，每个容器跑一份站点配置（一个 `config.php`）；需要同时跑多个环境时，建多个容器、各自挂不同的站点配置即可。

容器默认以 `tk` 用户运行（`HOME=/opt/tk`），老代码里用 `$_ENV['HOME']` 定位代码目录的行为可以直接生效；需要 root 时 `sudo` 即可（免密）。
:::

容器中的目录：

| 路径 | 说明 |
| --- | --- |
| `/opt/tk` | View 代码仓库（可以只读挂载，镜像不会修改它） |
| `/opt/ai_asset`、`/opt/air_platform`、`/opt/db_change_scripts`、`/opt/auto_testing` | 其他项目目录（本地环境只用到 `/opt/tk`） |
| `/opt/preview` | 预览站点根，容器启动时自动生成（软链 + 少量镜像自带/改写文件） |
| `/opt/preview-config/config.php` | 只读挂载的站点配置 |

## 创建容器

### 使用 Docker run 命令

运行 local 代码：

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

:::warning 提示
如果使用的是 windows 环境，在开始配置环境前，建议设置项目目录为区分大小写模式，参考：[https://learn.microsoft.com/zh-cn/windows/wsl/case-sensitivity](https://learn.microsoft.com/zh-cn/windows/wsl/case-sensitivity)。

如果使用的是 [WSL](https://learn.microsoft.com/zh-cn/windows/wsl/) 环境，应该把代码放到 linux 系统中，同时使用 linux 的项目路径如：`/var/tke/dev`。参考: [Docker Desktop WSL 2 backend on Windows](https://docs.docker.com/desktop/windows/wsl/)
:::

尝试访问：[http://localhost](http://localhost)

::: details 运行 Dev/Dev2/RC 等环境（可选）
不同环境分配不同的端口号即可：

```shell
docker run -d --name dev --restart always \
  -v D:/tke/dev:/opt/tk \
  -v D:/tke/sites/hk/config.php:/opt/preview-config/config.php:ro \
  -e VIEW_USERNAME=you@example.com \
  -p 8001:80 ghcr.io/i94m/view:php8.4
```

尝试访问：[http://localhost:8001](http://localhost:8001)
:::

### 使用 Docker Compose 命令

1. 在本地创建一个名为 `docker-compose.yml` 的文件，并复制粘贴以下内容。

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

以上配置仅包含 local 环境的容器。

2. 打开终端工具，并切换到 `docker-compose.yml` 文件所在的目录。例如：

```shell
cd ~/Desktop/
```

3. 创建并启动服务（`-d` 参数可以让服务在后台运行）。

```shell
docker compose up -d
```

4. 验证服务是否创建成功。

访问本地站点: [http://localhost](http://localhost)

::: tip 提示：
如果运行失败，请检查本机的 80 端口是否被占用。
:::

## 配置站点

打开本机的 hosts 配置文件，并复制粘贴以下内容。

```ini
# Local站点
127.0.0.1       hk.local.test
127.0.0.1       china.local.test
127.0.0.1       global.local.test
# Preview站点
127.0.0.1       hk.preview.test
127.0.0.1       china.preview.test
127.0.0.1       global.preview.test
```

::: tip
一个容器只加载一份 `config.php`，站点由挂载的配置决定；hosts 里的域名主要用于本地访问习惯。
:::

::: details 配置 Dev2/RC 等环境（可选）:
```ini
# Dev2站点
127.0.0.1       hk.dev2.test
127.0.0.1       china.dev2.test
127.0.0.1       global.dev2.test
# RC站点
127.0.0.1       hk.rc.test
127.0.0.1       china.rc.test
127.0.0.1       global.rc.test
```
:::

## 项目初始化（自动）

镜像启动时会自动把 `/opt/tk` 铺成预览站点根 `/opt/preview`（不需要的文件软链回仓库，需要改的少数文件由镜像提供或启动时生成），**不需要手动执行初始化，也不会修改仓库**（`git status` 保持干净）。

启动日志里能看到：

```
[entrypoint] 准备站点根 /opt/preview（基于 /opt/tk）
[site-init] config.php ← /opt/preview-config/config.php（只读挂载）
[site-init] 完成：DocumentRoot /opt/preview/web（软链 62 个），仓库 /opt/tk 未写入
```

- 日常修改代码、在 `web/`/`sys/`/`vivid/app/` 下新增文件都会立即生效，不用重启；
- 切分支 / 重新拉代码后如需重建站点根：`docker exec -it <容器> /run/init.sh`（只重建 `/opt/preview`）。

至此本地环境已经搭建好了，尝试访问: [http://hk.local.test](http://hk.local.test)
