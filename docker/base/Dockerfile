# 基础系统镜像固定用官方 debian（CI 在 GitHub 上构建，不使用任何镜像代理）。
FROM debian:13-slim

LABEL author="rt.wadewang"
LABEL description="View local development environment (PHP 8.4)."

WORKDIR /opt/tk

# PHP 版本固定为 8.4（src/ 下只保留 8.4 的 pdflib 二进制）
ARG TARGETARCH

# 非交互环境，避免 tzdata 等交互
ENV DEBIAN_FRONTEND=noninteractive

# 合并所有系统操作到一个RUN指令中
# 扩展清单按「全仓库 grep 是否有引用」裁剪过：imap / xhprof / ast / xmlrpc /
# memcache(不带 d) 都是 0 处引用，已剔除；bz2 / sqlite3 / solr / mongodb / amqp /
# gmp / ldap / soap / zip / mcrypt 都有实际调用，保留。php-pear 不能删：
# sys/libs/System.php（被 OLE/PPS 用）会 require 'Console/Getopt.php'，那个来自 PEAR。
# memcached 不用 apt 装，改成 dpkg-deb 抽二进制（apt 装会拖进 perl ~50 MiB），
# 所以这里显式装它的两个运行库；对应的 memcache 用户和启动方式见 entrypoint。
RUN useradd -m -d /opt/tk -s /bin/bash -c "TK User" tk && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        tzdata \
        nginx-light \
        libevent-2.1-7t64 \
        libsasl2-2 \
        redis-server \
        lsb-release \
        apt-transport-https \
        sudo && \
    update-ca-certificates && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "deb https://packages.sury.org/php $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        php8.4 \
        php8.4-fpm \
        php8.4-amqp \
        php8.4-bcmath \
        php8.4-bz2 \
        php8.4-curl \
        php8.4-gd \
        php8.4-gmp \
        php8.4-ldap \
        php8.4-mbstring \
        php8.4-mcrypt \
        php8.4-memcached \
        php8.4-mongodb \
        php8.4-mysql \
        php8.4-redis \
        php8.4-sqlite3 \
        php8.4-xml \
        php8.4-soap \
        php8.4-solr \
        php8.4-xdebug \
        php8.4-zip \
        php-pear && \
    mkdir -p /var/log/php /var/log/View /var/log/SelfService && \
    apt-get download memcached && \
    dpkg-deb -x memcached_*.deb / && \
    rm -f memcached_*.deb && \
    groupadd -r memcache && \
    useradd -r -g memcache --no-create-home --home-dir /nonexistent \
        --shell /usr/sbin/nologin memcache && \
    chown -R www-data:www-data /var/log/php /var/log/View /var/log/SelfService && \
    if wget -q --tries=2 --timeout=20 https://getcomposer.org/installer -O composer-setup.php; then \
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
    else \
        echo "getcomposer.org 不可达，回退到 GitHub release"; \
        wget -O /usr/local/bin/composer \
            "https://github.com/composer/composer/releases/latest/download/composer.phar"; \
        chmod +x /usr/local/bin/composer; \
    fi && \
    composer --version && \
    rm -rf /usr/share/doc/* /usr/share/man/* && \
    echo 'tk ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tk && \
    chmod 0440 /etc/sudoers.d/tk && \
    apt-get autoremove --yes && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache /opt/tk/composer-setup.php

# ---------- php.ini 及相关配置 ----------
COPY src/php.ini /etc/php/8.4/cli/php.ini
COPY src/php.ini /etc/php/8.4/fpm/php.ini
COPY src/www.conf /etc/php/8.4/fpm/pool.d/www.conf
# 开发向的运行时调优（opcache 容量 / 每请求校验 / realpath 缓存时效），见文件内注释
COPY src/dev-tuning.ini /etc/php/8.4/fpm/conf.d/99-dev-tuning.ini
COPY src/dev-tuning.ini /etc/php/8.4/cli/conf.d/99-dev-tuning.ini
COPY src/xdebug.ini /etc/php/8.4/mods-available/xdebug.ini

# 根据架构复制对应的 pdflib 文件
COPY src/php8.4_pdflib_nts_${TARGETARCH}.so /tmp
RUN PHP_EXTENSION_DIR=$(php -r "echo PHP_EXTENSION_DIR;") && \
    cp /tmp/php8.4_pdflib_nts_${TARGETARCH}.so ${PHP_EXTENSION_DIR}/pdflib.so
COPY src/pdflib.ini /etc/php/8.4/cli/conf.d/pdflib.ini
COPY src/pdflib.ini /etc/php/8.4/fpm/conf.d/pdflib.ini

# 配置 nginx：单文件整体替换 Debian 默认 nginx.conf（不 include sites-enabled）。
# apache 与 8 个 .htaccess 的每条规则都在里面逐条等价搬迁，对照表见 src/nginx/README.md。
# http{} 内额外 include /etc/nginx/conf.d/*.conf —— view-wt 为每个 worktree 写一个
# server 块到这里（00-placeholder.conf 保证空目录时通配仍命中一个文件）。
COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/conf.d /etc/nginx/conf.d
# 构建期验证语法；nginx -t 会顺手创建空 pid 文件，删掉别烘进镜像
RUN nginx -t && rm -f /run/nginx.pid

# 配置项目（镜像自带素材）
COPY src/log4php_config.xml /opt/local/log4php_config.xml
COPY src/redisconfig /opt/local/redisconfig

# Laravel 的 bootstrap 缓存（services / packages / config / events / routes）默认写在
# basePath/bootstrap/cache 下；某些老页面会以仓库路径启动 Laravel，从而把缓存写回仓库。
# 统一指到容器内临时目录，任何 PHP 进程（nginx/php-fpm/CLI/agent）都不会再写仓库。
ENV APP_SERVICES_CACHE=/tmp/view-cache/services.php \
    APP_PACKAGES_CACHE=/tmp/view-cache/packages.php \
    APP_CONFIG_CACHE=/tmp/view-cache/config.php \
    APP_EVENTS_CACHE=/tmp/view-cache/events.php \
    APP_ROUTES_CACHE=/tmp/view-cache/routes.php
RUN mkdir -p /tmp/view-cache && chmod 777 /tmp/view-cache

# ---------- 站点根 ----------
# DocumentRoot 是 /opt/preview。镜像自带需要改动的文件（自动登录版 login.php）放在
# /opt/preview-tpl，由 /run/site-init.sh 在启动时铺到 /opt/preview，其余文件软链回
# /opt/tk 代码仓库（新增文件不需要重建，见 site-init.sh 注释）。
COPY src/preview/ /opt/preview-tpl/

# /opt/preview 是预览站点根，entrypoint 的 site-init 每次启动重新生成（无需持久化）。
RUN mkdir -p /opt/preview

# ---------- init ----------
COPY src/entrypoint.sh /run/entrypoint.sh
COPY src/site-init.sh /run/site-init.sh
RUN chmod +x /run/entrypoint.sh /run/site-init.sh && ln -sf /run/site-init.sh /run/init.sh

# 健康检查：nginx(80) 与 php-fpm(9000) 两个端口都通才算健康
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/80 && exec 3<>/dev/tcp/127.0.0.1/9000'

# 默认以 tk 用户运行：很多老代码用 $_ENV['HOME']，tk 的 HOME 就是 /opt/tk（代码目录）。
# 需要 root 的地方（启动 nginx/php-fpm、生成站点根）由 entrypoint 里用 sudo 处理。
USER tk

CMD ["/run/entrypoint.sh"]
EXPOSE 80

# 添加架构标签
LABEL org.opencontainers.image.architecture=${TARGETARCH}