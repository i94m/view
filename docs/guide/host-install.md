# 安装 Multica Cli

如果不想用容器运行，也可以在本地机器上直接安装 multica CLI。

## 1. 安装

macOS / Linux：

```bash
curl -fsSL http://172.66.30.237:8008/multica/install.sh | bash
```

Windows PowerShell：

```powershell
iwr http://172.66.30.237:8008/multica/install.ps1 | iex
```

## 2. 连接执行电脑

```bash
multica setup self-host \
  --server-url http://172.66.30.237:3456 \
  --app-url    http://172.66.30.237:3456
```

## 3. 确认连接状态

```bash
multica daemon status
```

> 安装 Multica Cli 与[容器运行](/guide/container)二选一即可；容器内的 multica 已随镜像提供，无需重复安装。
