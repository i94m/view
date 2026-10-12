# 配置环境变量

不同 runtime（机器 / 容器）上代码仓库的路径可能各不相同。为了让 opencode / multica 在任意环境下
都能以**统一**的方式定位代码、读取凭据，把这些信息统一放进环境变量。按系统设置：

## macOS / WSL

写进 `~/.zshrc` 或 `~/.bashrc`，改完 `source ~/.zshrc`（或重开终端）生效：

```bash
# 路径（项目代码位置）
export VIEW_CODE_PATH="/opt/tk"
export AI_ASSET_PATH="/opt/ai_asset"
export AIR_PLATFORM_PATH="/opt/air_platform"
export VIEW_SQL_PATH="/opt/db_change_scripts"
export AUTO_TESTING_PATH="/opt/auto_testing"

# Git
export GIT_EMAIL="you@rayootech.com"
export GIT_USERNAME="your-username"
export GIT_PASSWORD="your-token"

# View 登录（自动化测试）
export VIEW_USERNAME="you@rayootech.com"
export VIEW_PASSWORD="your-test-password"

# multica
export MULTICA_SERVER_URL="http://210.74.156.242:3456"
```

验证（以 `GIT_USERNAME` 为例）：

```bash
echo "$GIT_USERNAME"
```

能打印出用户名即配置成功；输出为空说明没生效，检查变量名拼写，并 `source ~/.zshrc`（或 `~/.bashrc`）
或重开终端。

## Windows

PowerShell（`setx` 写用户级变量，重开终端生效）：

```powershell
# 路径（项目代码位置）
setx VIEW_CODE_PATH "C:\path\to\view"
setx AI_ASSET_PATH "C:\path\to\asset"
setx AIR_PLATFORM_PATH "C:\path\to\air_platform"
setx VIEW_SQL_PATH "C:\path\to\view_sql"
setx AUTO_TESTING_PATH "C:\path\to\auto_testing"

# Git
setx GIT_EMAIL "you@rayootech.com"
setx GIT_USERNAME "your-username"
setx GIT_PASSWORD "your-token"

# View 登录（自动化测试）
setx VIEW_USERNAME "you@rayootech.com"
setx VIEW_PASSWORD "your-test-password"

# multica
setx MULTICA_SERVER_URL "http://210.74.156.242:3456"
```

也可以在「系统属性 → 环境变量」里手动添加。

验证（以 `GIT_USERNAME` 为例）：

```powershell
echo $env:GIT_USERNAME
```

能打印出用户名即配置成功；输出为空说明没生效，检查变量名拼写，并**重开终端**（`setx` 写入的变量需
重开终端才生效）。

## 变量说明

| 变量 | 说明 |
| --- | --- |
| `VIEW_CODE_PATH` | 项目代码位置（VIEW 仓库 / 工作目录） |
| `AI_ASSET_PATH` | AI Asset 仓库 |
| `AIR_PLATFORM_PATH` | AIR Platform 仓库目录 |
| `VIEW_SQL_PATH` | DB 变更脚本 |
| `AUTO_TESTING_PATH` | 自动化测试目录 |
| `GIT_EMAIL` / `GIT_USERNAME` | git 身份 |
| `GIT_PASSWORD` | git 凭据；含 `@ : / %` 需 URL 编码，建议用 access token |
| `VIEW_USERNAME` / `VIEW_PASSWORD` | View 自动化测试登录凭据 |
| `MULTICA_SERVER_URL` | multica server 地址 |

> 容器里，路径变量由 docker-compose 的 `environment` 设为容器内路径，其余变量由 `.env`
> 注入（见[安装 Multica](/guide/host-install)）。浏览器 MCP / 数据库 MCP 的配置不在环境变量里。

## 相关

- [安装 Multica](/guide/host-install)
- [安装 Multica](/guide/host-install)
- [OpenCode 配置](/guide/opencode)
