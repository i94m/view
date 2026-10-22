#!/bin/bash
# 基础镜像入口：启动 memcached / redis / php-fpm / apache，然后前台 tail 日志。
# 任一服务起不来就带着非 0 退出，避免容器「running 但 500」。

echo "Running on architecture: $(uname -m)"

# 准备站点根 /opt/preview：仓库 /opt/tk 只读，镜像自带需要改动的文件。
# 失败不阻塞启动（没挂代码时仍能用容器跑别的），只是站点不可用。
if [ -x /run/site-init.sh ]; then
    echo "[entrypoint] 准备站点根 /opt/preview（基于 /opt/tk）"
    sudo -E /run/site-init.sh || echo "[entrypoint] site-init 失败，站点可能不可用" >&2
fi

# 注意：镜像默认 USER tk，特权操作走 sudo；-E 保留容器环境变量
# （php-fpm 启动时要继承 VIEW_USERNAME 等，sudo 默认会清空环境）
start_service() {
    local name=$1
    if ! sudo -E /etc/init.d/"${name}" start; then
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

sudo tail -f /var/log/apache2/error.log
