
## 在Docker中下载并运行View镜像

1.打开一个终端窗口

2.使用下面的 `docker network create` 命令在Docker中创建类型为 `bridge` 的网络:
```shell
docker network create --subnet=172.16.1.0/24 tke
```

3.使用下面的 `docker run` 命令将其作为Docker中的容器运行:

Windows
```shell
docker run -d ^
    --name view ^
    --network tke ^
    --ip 172.16.1.80 ^
    --restart always ^
    -p 80:80 ^
    -v <本机local代码目录>:/home/tke/local ^
    -v <本机preview代码目录>:/home/tke/preview ^
    -v <本机dev2代码目录>:/home/tke/dev2 ^
    -v <本机rc代码目录>:/home/tke/rc ^
    -v <本机live代码目录>:/home/tke/live ^
    rtwadewang/view:2.0.2
```

MacOS/Linux
```shell
docker run -d \
    --name view \
    --network tke \
    --ip 172.16.1.80 \
    --restart always \
    -p 80:80 \
    -v <本机local代码目录>:/home/tke/local \
    -v <本机preview代码目录>:/home/tke/preview \
    -v <本机dev2代码目录>:/home/tke/dev2 \
    -v <本机rc代码目录>:/home/tke/rc \
    -v <本机live代码目录>:/home/tke/live \
    rtwadewang/view:2.0.2
```
