#!/bin/bash
# 基础镜像入口：启动 memcached / redis / php-fpm / apache，然后前台 tail 日志。
# 任一服务起不来就带着非 0 退出，避免容器「running 但 500」。

echo "Running on architecture: $(uname -m)"

start_service() {
    local name=$1
    if ! /etc/init.d/"${name}" start; then
        echo "[entrypoint] 启动 ${name} 失败" >&2
        exit 1
    fi
}

# 启动 memcached
start_service memcached

# 启动 redis
start_service redis-server

# 启动 php-fpm
start_service php8.4-fpm

# 启动 apache2
start_service apache2

# 端口自检：apache(80) / php-fpm(9000) 最多等 15 秒
for port in 80 9000; do
    ok=0
    for _ in $(seq 1 30); do
        if (exec 3<>/dev/tcp/127.0.0.1/"${port}") 2>/dev/null; then
            ok=1
            break
        fi
        sleep 0.5
    done
    if [ "${ok}" -ne 1 ]; then
        echo "[entrypoint] 端口 ${port} 未监听，查看 /var/log/apache2/error.log" >&2
        exit 1
    fi
done

tail -f /var/log/apache2/error.log
