# 添加模型

OpenCode 通过 `/connect` 命令添加模型服务商：在界面里选择服务商，按提示填入对应的凭证信息，保存后即可在 `/models` 里选用该服务商的模型。

本页介绍两个常用服务商：

- **DeepSeek** —— API Key 方式，粘贴密钥即可；
- **GitHub Copilot** —— 设备授权方式，无需手动填写密钥。

## 通用步骤

先进入 opencode 的交互界面：

::: code-group

```bash [本机]
opencode
```

```bash [容器]
docker exec -it multica-runtime opencode
```

:::

::: tip
`multica-runtime` 是 `docker-compose.yml` 里固定的容器名（`container_name`）。
:::

进入界面后：

1. 输入 `/connect`，选择模型服务商；
2. 按提示填入对应的凭证信息（见下方各服务商说明）；
3. 输入 `/models`，选择要使用的模型。

配置保存后会写入 `opencode.json` 的全局配置目录（各平台路径见[安装和配置](/guide/opencode)）。

## DeepSeek

DeepSeek 使用 **API Key** 方式，无需浏览器登录，直接粘贴密钥即可。

### 1. 获取 API Key

登录 [DeepSeek 开放平台](https://platform.deepseek.com/api_keys)，在「API Keys」页面创建一个新的 API Key 并复制。

::: warning 密钥安全
API Key 只显示一次，请妥善保存，不要提交进代码仓库。
:::

### 2. 连接 DeepSeek

在 opencode 界面中输入 `/connect`，选择 **DeepSeek**，粘贴上一步复制的 API Key，保存。

也可以不通过界面，而是用环境变量提供密钥：

```bash
export DEEPSEEK_API_KEY=你的密钥
```

::: info 说明
- DeepSeek 支持「已保存的 API Key」与 `DEEPSEEK_API_KEY` 环境变量两种凭证来源，任选其一即可。
- 环境变量需在 opencode 服务所在的进程环境里生效（容器方式对应在容器内设置）。
:::

### 3. 选择模型

输入 `/models`，选择 `deepseek/` 前缀的模型（例如 `deepseek/deepseek-flash`、`deepseek/deepseek-v4-pro`）。

## GitHub Copilot

<div style="margin: 16px 0 24px;">
  <video controls preload="metadata" playsinline poster="/videos/add-github-copilot-model-poster.jpg" style="width: 100%; border-radius: 8px; background: #000;">
    <source src="/videos/add-github-copilot-model.mp4" type="video/mp4" />
    你的浏览器不支持 HTML5 视频，请<a href="../videos/add-github-copilot-model.mp4">下载视频</a>观看。
  </video>
  <p style="margin-top: 8px; text-align: center; color: var(--vp-c-text-2); font-size: 14px;">视频教程：配置 GitHub Copilot 模型</p>
</div>

GitHub Copilot 使用**设备授权（Device OAuth）**，无需手动填写 API Key，而是打开授权页面完成登录。

### 1. 确认订阅

连接的账号需要具备 Copilot Chat 权限：

- 个人账号：开通 Copilot Free / Pro 即可；
- 组织账号：由组织分配 Copilot 席位（seat）。

如果没有授权，OpenCode 会提示无 Copilot 权限，需先开通或让组织分配席位后重新连接。

### 2. 连接 GitHub Copilot

在 opencode 界面中输入 `/connect`，选择 **GitHub Copilot**：

1. 选择 **GitHub.com** 或 **GitHub Enterprise**；
2. 按提示打开授权 URL，输入界面给出的设备码，完成登录授权；
3. 授权完成后回到 opencode 继续。

::: info GitHub Enterprise
选择 Enterprise 时，按提示填写部署域名（例如 `company.ghe.com`）。OpenCode 会优先使用 GitHub 返回的 Copilot API 端点，否则根据企业域名推导端点。
:::

### 3. 选择模型

授权完成后输入 `/models`，选择 `github-copilot/` 前缀的模型。

::: tip 说明
OpenCode 会在登录后自动拉取该账号当前可用的 Copilot 模型列表。
:::

## 切换模型

- 输入 `/models` 可随时切换当前会话使用的模型；
- 也可以在 `opencode.json` 中通过 `model` 字段指定默认模型，例如：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "deepseek/deepseek-v4-pro"
}
```

改完无需重启，OpenCode 会自动重载配置。
