# nginx.conf —— 本地预览站点的前端

`nginx.conf` 整体替换 `/etc/nginx/nginx.conf`（Dockerfile 里 COPY，构建期 `nginx -t` 兜底）。
它等价搬迁了两处旧配置：`src/httpd.conf` + `src/sites/view.conf`（已删除）里的 vhost、
Alias、RewriteRule、mod_expires，以及站点目录下 8 个 `.htaccess`（nginx 不读 `.htaccess`）。

PHP-FPM 完全不动：pool `www`、`127.0.0.1:9000`、`clear_env = no`；环境变量由 FPM 从
entrypoint（`sudo -E`）继承，与前端是谁无关。

## 逐条对照

| Apache | nginx |
|---|---|
| `DocumentRoot /opt/preview/web` + `DirectoryIndex index.html index.php` | `root` + `index` |
| `<FilesMatch \.php$> SetHandler proxy:fcgi://127.0.0.1:9000` | `location ~ \.php($\|/)` → `fastcgi_pass phpfpm` |
| `Alias /login.php /opt/preview/overrides/login.php` | `location = /login.php` + 显式 `SCRIPT_FILENAME`（文件在 docroot 之外） |
| `Alias /vivid /opt/preview/vivid/public` | `location /vivid/` + `alias` + `try_files … @vivid`（命名 location：alias 里用 URI 回退会解析错路径） |
| `RewriteRule ^/v[0-9]+/(.*) /$1` | `rewrite ^/v[0-9]+/(.*)$ /$1 last;` |
| `ExpiresDefault now`、`/vN/` 与 `/img/` 7 天 | `map $request_uri $view_expires` + `expires`（用 `$request_uri`：`$uri` 已被 `/vN/` 剥离改写） |
| 8 个模块 `.htaccess`：静态放行，其余兜给 `/vivid/` | 每个模块一个 `location ^~ /<模块>/`：静态后缀 `try_files =404`，其余 `try_files … /vivid/index.php?$query_string` |
| `sharp/.htaccess` 的 `ErrorDocument 404 /common/blankpage/404.php` | `location ^~ /sharp/` 内 `error_page 404` |
| `SetEnv APPLICATION_ENV development` | `map $uri $view_app_env` → `fastcgi_param APPLICATION_ENV` |
| `SetEnvIf Authorization .+ HTTP_AUTHORIZATION=$0` | `fastcgi_param HTTP_AUTHORIZATION $http_authorization` |
| `AddOutputFilterByType DEFLATE …` | `gzip on` + `gzip_types` + `gzip_min_length 256` |
| Apache 默认拒绝 `.ht*` | `location ~ /\.ht { deny all; }`，**每个 `^~` 模块内重复一条** |
| 无 `LimitRequestBody`，真实上限是 php.ini 的 150M | `client_max_body_size 150m` |
| `ServerTokens` | `server_tokens off` |

## Apache 专属 `$_SERVER` 变量（不改仓库代码的关键）

老代码依赖三个 Apache/mod_rewrite 才有的变量，nginx 默认都不提供，必须在配置里补：

| 变量 | 代码里的引用量 | nginx 侧 |
|---|---|---|
| `SCRIPT_URL` | 43 处（`sys/includes/InitTour.php`、`responsive_footer.php` 等） | `$request_path`（原始路径，不含 query），**全站注入** |
| `SCRIPT_URI` | 39 处 | `$scheme://$http_host$request_path`，全站注入 |
| `REDIRECT_URL` | 3 处（`RepairoperationlistController.php:37`、`responsive_header_v2.php:513/:801`） | `$request_path`，**只注入 8 个模块 location 和 `@vivid`** |
| `SERVER_NAME` / `SERVER_PORT` | 66 / 15 处 | `$host` / 从 Host 头解析端口（Apache 默认 `UseCanonicalName Off`，跟随 Host 头） |

`REDIRECT_URL` 的作用域必须和 Apache 一致：只有在「目录级 .htaccess 重写」时 Apache 才提供它。
全局注入会让原本走 `?? PHP_SELF` 回退的页面变成路径匹配，页头菜单/权限分支会错位——这是
不在仓库里改那 3 行代码的前提。

**踩过的坑**：别给 FastCGI 传 `PATH_TRANSLATED`。PHP 的 `cgi.fix_pathinfo` 会优先用它推导
主脚本，`@vivid` 这类 location 里 `$fastcgi_script_name` 是原始 URI，于是 FPM 报
`Primary script unknown` → `/vivid/nonexistent-route` 从 302 变成 404。Apache 侧该变量本来
就是空的，不传才等价。

## 性能相关的默认值（以及刻意留白的地方）

本栈上**页面时间基本不在这层**：静态资源 TTFB ~2ms；只做渲染的 PHP 页 ~3ms；登录页/列表页
0.6–4s，绝大部分是「页面发起的 N 次查询 × 到远端 MySQL 的 ~22ms 往返」。所以这里只做
「不影响正确性」的几项：

| 项 | 值 | 说明 |
|---|---|---|
| `upstream phpfpm` + `fastcgi_keep_conn` | `keepalive 32` | 复用与 FPM 的连接，省掉每请求的 loopback 握手 |
| `fastcgi_buffer_size` / `fastcgi_buffers` | `32k` / `16 32k` | 页面常见 100–500KB（`/common/myaccount.php` 501KB），默认 8×4k 会落盘再读回 |
| `gzip_comp_level` | `5` | 6→5 CPU 更省，压缩率差别 <1% |
| `worker_processes` | `4` | 开发容器固定 4 个；`auto` 在 12 核宿主机上会起 12 个 worker（~65MB 常驻），压测时再调大 |

**刻意不开的**：`open_file_cache`（会把文件 fd/元数据缓存到分钟级，破坏「改完刷新立刻生效」；
实测只把静态 TTFB 从 ~2.4ms 降到 ~1.9ms）。PHP 侧的对应设置见 `src/dev-tuning.ini`
（opcache 每请求校验、realpath_cache_ttl=5）。

## 已知差异（可接受）

- >150 MiB 上传：nginx 直接 413，Apache 会读完 body 再由 PHP 丢弃（最终都传不上去）。
- PHP 响应的 `Expires`/`Cache-Control`：PHP location 里不加 `expires`（会覆盖 PHP 自己的
  `no-store`），代价是 `phpinfo` 这类响应少一组缓存头；登录态页面两边一致。
- ETag 字符串格式、nginx 自带错误页的正文/charset、`favicon.ico` 的 MIME、`Server` 头。

## 回滚

镜像维度：切回带 apache2 的旧 tag。容器内维度：`cp` 回 Debian 原版 `/etc/nginx/nginx.conf`，
`/etc/init.d/nginx stop` + `/etc/init.d/apache2 start`（前提是 apache2 还装着）。
