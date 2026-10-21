# 在 Docker 中运行镜像

不用 Docker Compose，直接用 `docker run` 起一个本地 View 环境容器（一个容器只跑一个环境）。

## 1. 拉取镜像

```shell
docker login ghcr.io      # 镜像包为私有，需要 GitHub PAT（勾 read:packages）
docker pull ghcr.io/i94m/view:php8.4
```

## 2.（可选）创建固定 IP 的 bridge 网络

```shell
docker network create --subnet=172.16.1.0/24 tke
```

## 3. 启动容器

MacOS / Linux

```shell
docker run -d \
    --name local \
    --restart always \
    -p 80:80 \
    -v <本机 View 代码目录>:/opt/tk \
    -v <本机 sites 目录>:/opt/sites \
    ghcr.io/i94m/view:php8.4
```

Windows（CMD）

```shell
docker run -d ^
    --name local ^
    --restart always ^
    -p 80:80 ^
    -v <本机 View 代码目录>:/opt/tk ^
    -v <本机 sites 目录>:/opt/sites ^
    ghcr.io/i94m/view:php8.4
```

需要固定 IP 时补上 `--network tke --ip 172.16.1.80`。

## 4. 初始化

```shell
docker exec -it local /run/init.sh <你的8ID>
```

初始化做了什么、之后怎么配置 hosts，见 [本地环境](/view/)。
