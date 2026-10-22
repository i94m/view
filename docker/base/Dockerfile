# 基础系统镜像。CI 用官方源；本地网络访问不了 Docker Hub 时可覆盖，例如：
#   --build-arg BASE_OS=docker.m.daocloud.io/library/debian:13-slim
ARG BASE_OS=debian:13-slim
FROM ${BASE_OS}

LABEL author="rt.wadewang"
LABEL description="View local development environment (PHP 8.4)."

WORKDIR /opt/tk

# PHP 版本固定为 8.4（src/ 下只保留 8.4 的 pdflib 二进制）
ARG TARGETARCH

# 非交互环境，避免 tzdata 等交互
ENV DEBIAN_FRONTEND=noninteractive

# 合并所有系统操作到一个RUN指令中
RUN useradd -m -d /opt/tk -s /bin/bash -c "TK User" tk && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        tzdata \
        apache2 \
        memcached \
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
        php8.4-ast \
        php8.4-bcmath \
        php8.4-bz2 \
        php8.4-curl \
        php8.4-gd \
        php8.4-gmp \
        php8.4-ldap \
        php8.4-imap \
        php8.4-mbstring \
        php8.4-mcrypt \
        php8.4-memcache \
        php8.4-memcached \
        php8.4-mongodb \
        php8.4-mysql \
        php8.4-redis \
        php8.4-sqlite3 \
        php8.4-xml \
        php8.4-xmlrpc \
        php8.4-soap \
        php8.4-solr \
        php8.4-xdebug \
        php8.4-xhprof \
        php8.4-zip \
        php-pear && \
    mkdir -p /var/log/php /var/log/View /var/log/SelfService && \
    chown -R www-data:www-data /var/log/php /var/log/View /var/log/SelfService && \
    if wget -q --tries=2 --timeout=20 https://getcomposer.org/installer -O composer-setup.php; then \
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
    else \
        echo "getcomposer.org 不可达，回退到 GitHub release"; \
        wget -O /usr/local/bin/composer \
            "https://ghfast.top/https://github.com/composer/composer/releases/latest/download/composer.phar"; \
        chmod +x /usr/local/bin/composer; \
    fi && \
    composer --version && \
    cp /etc/apache2/mods-available/allowmethods.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/ext_filter.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/include.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/vhost_alias.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/asis.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/proxy_fcgi.load /etc/apache2/mods-enabled/ && \
    cp /etc/apache2/mods-available/proxy.load /etc/apache2/mods-enabled/ && \
    rm /etc/apache2/sites-enabled/000-default.conf && \
    echo 'tk ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tk && \
    chmod 0440 /etc/sudoers.d/tk && \
    apt-get autoremove --yes && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache /opt/tk/composer-setup.php

# ---------- php.ini 及相关配置 ----------
COPY src/php.ini /etc/php/8.4/cli/php.ini
COPY src/php.ini /etc/php/8.4/fpm/php.ini
COPY src/www.conf /etc/php/8.4/fpm/pool.d/www.conf
COPY src/xdebug.ini /etc/php/8.4/mods-available/xdebug.ini

# 根据架构复制对应的 pdflib 文件
COPY src/php8.4_pdflib_nts_${TARGETARCH}.so /tmp
RUN PHP_EXTENSION_DIR=$(php -r "echo PHP_EXTENSION_DIR;") && \
    cp /tmp/php8.4_pdflib_nts_${TARGETARCH}.so ${PHP_EXTENSION_DIR}/pdflib.so
COPY src/pdflib.ini /etc/php/8.4/cli/conf.d/pdflib.ini
COPY src/pdflib.ini /etc/php/8.4/fpm/conf.d/pdflib.ini

# 配置 apache2
COPY src/httpd.conf /etc/apache2/apache2.conf
COPY src/sites /etc/apache2/sites-enabled/

# 配置项目（镜像自带素材）
COPY src/log4php_config.xml /opt/local/log4php_config.xml
COPY src/redisconfig /opt/local/redisconfig

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

# 健康检查：apache(80) 与 php-fpm(9000) 两个端口都通才算健康
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/80 && exec 3<>/dev/tcp/127.0.0.1/9000'

# 默认以 tk 用户运行：很多老代码用 $_ENV['HOME']，tk 的 HOME 就是 /opt/tk（代码目录）。
# 需要 root 的地方（启动 apache/php-fpm、生成站点根）由 entrypoint 里用 sudo 处理。
USER tk

CMD ["/run/entrypoint.sh"]
EXPOSE 80

# 添加架构标签
LABEL org.opencontainers.image.architecture=${TARGETARCH}