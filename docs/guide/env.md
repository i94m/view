# 配置环境变量

各 runtime（本机或容器）上代码仓库的路径往往不一致。为了让 opencode / multica 在任意环境下都能**统一**地定位代码、读取凭据，这里把这些信息集中放进环境变量。按系统设置：

## 按系统设置

macOS 和 Linux 将对应内容写入 `~/.zshrc` 或 `~/.bashrc`，然后 `source` 该文件（或重开终端）；Windows 在 PowerShell 中执行 `setx`，重开终端后生效。宿主机运行时，请把项目路径改为实际位置。

::: code-group

```bash [macOS / Linux / WSL]
# 路径（项目代码位置）
export VIEW_CODE_PATH="/opt/tk"
export AI_ASSET_PATH="/opt/ai_asset"
export VIEW_USER_MANUAL="/opt/view_user_menual"
export AIR_PLATFORM_PATH="/opt/air_platform"
export VIEW_SQL_PATH="/opt/db_change_scripts"
export AUTO_TESTING_PATH="/opt/auto_testing"

# Git
export GIT_EMAIL="you@rayootech.com"
export GIT_USERNAME="your-username"
export GIT_PASSWORD="your-token"

# View账号
export VIEW_USERNAME="you@rayootech.com"
export VIEW_PASSWORD="your-test-password"

# multica
export MULTICA_SERVER_URL="http://multica.gyouths.cn:3456"
export MULTICA_DAEMON_DEVICE_NAME="Your-Name's Runtime on Host"
```

```powershell [Windows]
# 路径（项目代码位置）
setx VIEW_CODE_PATH "C:\path\to\view"
setx AI_ASSET_PATH "C:\path\to\asset"
setx VIEW_USER_MANUAL "C:\path\to\view_user_menual"
setx AIR_PLATFORM_PATH "C:\path\to\air_platform"
setx VIEW_SQL_PATH "C:\path\to\view_sql"
setx AUTO_TESTING_PATH "C:\path\to\auto_testing"

# Git
setx GIT_EMAIL "you@rayootech.com"
setx GIT_USERNAME "your-username"
setx GIT_PASSWORD "your-token"

# View账号
setx VIEW_USERNAME "you@rayootech.com"
setx VIEW_PASSWORD "your-test-password"

# multica
setx MULTICA_SERVER_URL "http://multica.gyouths.cn:3456"
setx MULTICA_DAEMON_DEVICE_NAME "Your-Name's Runtime on Windows Host"
```

:::

Windows 也可以在「系统属性 → 环境变量」里手动添加。

::: tip 验证
重开终端后，以 `GIT_USERNAME` 为例检查：

::: code-group

```bash [macOS / Linux / WSL]
echo "$GIT_USERNAME"
```

```powershell [Windows]
echo $env:GIT_USERNAME
```

:::

能打印出用户名即配置成功；输出为空则检查变量名拼写及是否已加载新的环境变量。
:::

## 变量说明

| 变量 | 说明 |
| --- | --- |
| `VIEW_CODE_PATH` | View项目代码目录 |
| `AI_ASSET_PATH` | AI Asset 仓库 |
| `VIEW_USER_MANUAL` | VIEW 用户手册项目目录 |
| `AIR_PLATFORM_PATH` | AIR Platform 仓库目录 |
| `VIEW_SQL_PATH` | DB 变更脚本 |
| `AUTO_TESTING_PATH` | 自动化测试目录 |
| `GIT_EMAIL` / `GIT_USERNAME` | git 身份 |
| `GIT_PASSWORD` | git 凭据；含 `@ : / %` 需 URL 编码 |
| `VIEW_USERNAME` / `VIEW_PASSWORD` | View账号 |
| `MULTICA_SERVER_URL` | multica server 地址 |
| `MULTICA_DAEMON_DEVICE_NAME` | multica daemon 设备名，例如 `"Your-Name's Runtime on Host"` |

::: tip 容器中的路径变量
容器里，路径变量由 docker-compose 的 `environment` 设为容器内路径，其余变量由 `.env` 注入（见[安装 Multica](/guide/host-install)）。浏览器 MCP / 数据库 MCP 的配置不在环境变量里。
:::

## 验证配置

变量设置完成后，可以让 Agent 做一次整体核验。在任务中让 Tester「列出配置的项目路径」，它会读取各环境变量、核对路径是否存在，并检查 Git 身份：

<div style="margin: 16px 0 24px;">
  <video controls preload="metadata" playsinline poster="/videos/verify-config-poster.jpg" style="width: 100%; border-radius: 8px; background: #000;">
    <source src="/videos/verify-config.mp4" type="video/mp4" />
    你的浏览器不支持 HTML5 视频，请<a href="../videos/verify-config.mp4">下载视频</a>观看。
  </video>
  <p style="margin-top: 8px; text-align: center; color: var(--vp-c-text-2); font-size: 14px;">视频教程：验证环境变量配置</p>
</div>

确认无误后，还可以直接让 Agent 基于这些配置操作仓库，例如「查询昨天有哪些 OpenSpec 的提交」。
