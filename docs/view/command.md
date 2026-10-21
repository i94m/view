# 基础命令

## 进入容器

进入 view 容器（容器名以 `docker run`/compose 里定义的为准，示例为 `local`）

```shell
docker exec -it local bash
```

> 当前镜像基于 Debian，`bash` / `sh` 都可用；历史上的 alpine 版本已不再发布。

## 容器的启停

```shell
docker {start|stop|restart} local
```

## 删除容器

```shell
docker rm local
```

## 删除镜像

```shell
docker rmi ghcr.io/i94m/view:php8.4
```
