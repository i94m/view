# 添加 Runtime

<div style="margin: 16px 0 24px;">
  <video controls preload="metadata" playsinline poster="/videos/add-runtime-and-create-agent-poster.jpg" style="width: 100%; border-radius: 8px; background: #000;">
    <source src="/videos/add-runtime-and-create-agent.mp4" type="video/mp4" />
    你的浏览器不支持 HTML5 视频，请<a href="../videos/add-runtime-and-create-agent.mp4">下载视频</a>观看。
  </video>
  <p style="margin-top: 8px; text-align: center; color: var(--vp-c-text-2); font-size: 14px;">视频教程：添加 Runtime 并创建 Agent</p>
</div>

把 multica 连接到**自托管实例**（写入配置、登录并启动 daemon）。三种运行方式对应三种做法。

## 桌面端

桌面端不使用 `multica setup`，而是通过用户目录下的 `desktop.json` 连接自托管实例。

Desktop 默认连接 Multica Cloud。连接**自托管实例**时，在用户目录的 `.multica` 下创建 `desktop.json`：

| 平台 | 路径 |
| --- | --- |
| macOS | `/Users/<你>/.multica/desktop.json` |
| Linux | `/home/<你>/.multica/desktop.json` |
| Windows | `C:\Users\<你>\.multica\desktop.json` |

::: tip
以上是默认位置。用户目录被迁移或重定向过的话，用实际路径；`.multica` 目录不存在时先创建。
:::

文件内容：

```json
{
  "schemaVersion": 1,
  "apiUrl": "https://api.example.com"
}
```

- `schemaVersion`：固定填 `1`。
- `apiUrl`：自托管实例地址，与 `.env` 里的 `MULTICA_SERVER_URL` 一致；本项目为 `http://210.74.156.242:3456`。

改完重启 Desktop 生效。

## CLI

```bash
multica setup self-host \
  --server-url http://210.74.156.242:3456 \
  --app-url    http://210.74.156.242:3456
```

## 容器

在容器内执行（见[安装 Multica](/guide/host-install)）：

```bash
docker exec -it multica-runtime multica setup self-host \
  --server-url http://210.74.156.242:3456 \
  --app-url    http://210.74.156.242:3456
```

## 确认状态

::: code-group

```bash [CLI]
multica daemon status
```

```bash [容器]
docker exec -it multica-runtime multica daemon status
```

:::

::: tip 登录态持久化
CLI 在 `~/.multica`，容器在挂载的 `./.multica`，重建容器无需重新配置。
:::
