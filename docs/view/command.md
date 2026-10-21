# 基础命令

## 进入容器

进入 view 容器
```shell
docker exec -it local bash
```

如果本地使用的是 [alpine](https://hub.docker.com/r/rtwadewang/view/tags) 镜像，应该使用 `sh` 命令

```shell
docker exec -it local sh
```

## 容器的启停

```shell
docker {start|stop|restart} view
```

## 删除容器

```shell
docker rm view
```

## 删除镜像

```shell
docker rmi rtwadewang/view
```
