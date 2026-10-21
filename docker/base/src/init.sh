#!/bin/sh
# 本地开发初始化：对挂载进来的 View 代码做一次性 patch。
# 所有 patch 都带幂等守卫，重复执行不会重复注入（旧版本会往 login.php 里插两遍自动登录）。

if [ ! "$1" ]; then
    echo '缺少8ID参数，例如: /run/init.sh 80000888';
    exit 1;
fi

corePath=/opt/tk
user8ID=${1}

if [ ! "$(ls -A $corePath)" ]; then
    echo "${corePath}目录不存在，请确认是否已经映射代码到容器中";
    exit 1;
fi

cp /opt/local/log4php_config.xml ${corePath}/log4php_config.xml
# /opt/local/redisconfig 是目录，必须用 cp -r（旧脚本用 cp，实际一直在静默失败）
mkdir -p ${corePath}/redisconfig
cp -a /opt/local/redisconfig/. ${corePath}/redisconfig/

cd ${corePath} || exit

# tke_config.php：按 Host 前缀加载 sites/<pre>/config.php
if grep -q 'sPreUrl' sys/includes/tke_config.php 2>/dev/null; then
    printf '\033[33m sys/includes/tke_config.php 已处理，跳过 \033[0m\n'
else
    configCode='$sPreUrl = substr($_SERVER["HTTP_HOST"], 0, strpos($_SERVER["HTTP_HOST"], "."));\n    $sPreUrl = $sPreUrl ?: "hk";\n    require_once(BASE_DIR . "\/..\/sites\/" . $sPreUrl . "\/config.php");'
    sed -i "s/require_once(BASE_DIR . \"\/config.php\");/${configCode}/g" sys/includes/tke_config.php
    sed -i '$s/?>/''/' sys/includes/tke_config.php
    printf "\033[32m Updated sys/includes/tke_config.php \033[0m\n"
fi

# http.lib：指向 ngcore 实现
rm -f sys/libs/http.lib
echo "<?php include('./ngcore/http.lib');" >> sys/libs/http.lib
printf "\033[32m Updated sys/libs/http.lib \033[0m\n"

# login.php：按 8ID 自动登录
if grep -q 'Use custom 8id automatic login' web/login.php 2>/dev/null; then
    printf '\033[33m web/login.php 已处理，跳过（避免重复注入） \033[0m\n'
else
    loginCode="\    // Use custom 8id automatic login\n    \$user = \$db->get(\"SELECT id FROM \`user\` WHERE \`ActiveDirectoryID\` = '${user8ID}' LIMIT 1\");\n    if (empty(\$user))die('Incorrect 8ID.');userLogin(\$user->id);\n    die();"
    sed -i "/UserInformationService as UserInformationService;/a\ \n${loginCode}" web/login.php
    sed -i 's/use SystemAdmin\\User\\Service\\UserInformationService as UserInformationService;/use SystemAdmin\\User\\Service\\UserInformationService as UserInformationService ;/' web/login.php
    printf "\033[32m Updated web/login.php \033[0m\n"
fi

# multilingual.lib：跳过翻译表查询
if grep -qF 'function _xlate($source,$moduleid = null,$dbx = null) {return $source;' sys/libs/multilingual.lib 2>/dev/null; then
    printf '\033[33m sys/libs/multilingual.lib 已处理，跳过 \033[0m\n'
else
    sed -i.bak 's#function _xlate($source,$moduleid = null,$dbx = null) {#function _xlate($source,$moduleid = null,$dbx = null) {return $source;#' sys/libs/multilingual.lib
    printf "\033[32m Updated sys/libs/multilingual.lib \033[0m\n"
fi

# vivid 配置：注释掉 redis sentinel
if grep -qF "// 'options' => \$redisSentinel" vivid/config/10.x/database.php 2>/dev/null; then
    printf '\033[33m vivid/config/10.x/database.php 已处理，跳过 \033[0m\n'
else
    sed -i "s/'options' => \$redisSentinel/\/\/ 'options' => \$redisSentinel/" vivid/config/10.x/database.php
    sed -i "s/'default' => \$redisSentinel/\/\/ 'default' => \$redisSentinel/" vivid/config/10.x/database.php
    sed -i "s/'cache' => \$redisSentinel/\/\/ 'cache' => \$redisSentinel/" vivid/config/10.x/database.php
    printf "\033[32m Updated vivid/config/10.x/database.php \033[0m\n"
fi

if grep -qF "// 'options' => array_merge" vivid/config/12.x/database.php 2>/dev/null; then
    printf '\033[33m vivid/config/12.x/database.php 已处理，跳过 \033[0m\n'
else
    sed -i "s/'options' => array_merge/\/\/ 'options' => array_merge/" vivid/config/12.x/database.php
    sed -i "s/'default' => \$redisSentinel/\/\/ 'default' => \$redisSentinel/" vivid/config/12.x/database.php
    sed -i "s/'cache' => \$redisSentinel/\/\/ 'cache' => \$redisSentinel/" vivid/config/12.x/database.php
    printf "\033[32m Updated vivid/config/12.x/database.php \033[0m\n"
fi

# Handler.php：屏蔽框架错误页
if grep -q 'function renderBackup(' vivid/app/Exceptions/Handler.php 2>/dev/null; then
    printf '\033[33m vivid/app/Exceptions/Handler.php 已处理，跳过 \033[0m\n'
else
    sed -i "s/function render(/function renderBackup(/g" vivid/app/Exceptions/Handler.php
    printf "\033[32m Updated vivid/app/Exceptions/Handler.php \033[0m\n"
fi

printf "\033[32m 初始化操作完成 \033[0m\n"
printf "\033[33m 警告，以上文件仅用于本地开发，请勿提交到Git仓库!\033[0m\n"
