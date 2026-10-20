# 添加项目资源

项目资源告诉 Agent 这组任务会用到哪些代码、默认在哪里执行。这里介绍**本地目录**的两种添加方式；GitHub 仓库等其它资源见[官方文档](https://multica.ai/docs/zh/project-resources)。

## 桌面端

<div style="margin: 16px 0 24px;">
  <video controls preload="metadata" playsinline poster="/videos/add-project-resource-desktop-poster.jpg" style="width: 100%; border-radius: 8px; background: #000;">
    <source src="/videos/add-project-resource-desktop.mp4" type="video/mp4" />
    你的浏览器不支持 HTML5 视频，请<a href="../videos/add-project-resource-desktop.mp4">下载视频</a>观看。
  </video>
  <p style="margin-top: 8px; text-align: center; color: var(--vp-c-text-2); font-size: 14px;">视频教程：桌面端添加项目资源</p>
</div>

1. 打开项目的 **资源**，或者创建项目对话框里的 **本地目录** 标签页 —— 项目还没建出来时也能做同样的选择。
2. 选择「添加本地目录」，再选择要使用的文件夹。
3. 选择运行如何使用它 —— **原地** 还是 **并行**，两者的区别见[运行如何共享这个目录](https://multica.ai/docs/zh/project-resources#运行如何共享这个目录)。
   - 如果这个文件夹是 git 仓库、并且那台机器上的运行时能做隔离，Desktop 会预选 **并行**，否则预选 **原地**。
   - 当场可以改，之后也可以在 **资源** 里点目录旁边的铅笔图标改。

::: tip
添加本地目录的界面只在 Desktop 中提供，因为浏览器不能选择电脑上的文件夹。
:::

## 命令行

<div style="margin: 16px 0 24px;">
  <video controls preload="metadata" playsinline poster="/videos/add-project-resource-cli-poster.jpg" style="width: 100%; border-radius: 8px; background: #000;">
    <source src="/videos/add-project-resource-cli.mp4" type="video/mp4" />
    你的浏览器不支持 HTML5 视频，请<a href="../videos/add-project-resource-cli.mp4">下载视频</a>观看。
  </video>
  <p style="margin-top: 8px; text-align: center; color: var(--vp-c-text-2); font-size: 14px;">视频教程：使用 CLI 添加项目资源</p>
</div>

没有使用 Desktop 时，用 `multica project resource add` 把本地目录绑定到项目和指定运行时：

```bash
multica project resource add <project-id> \
 --type local_directory \
 --local-path /absolute/path/to/repo \
 --daemon-id <daemon-id> \
 --execution-mode worktree
```

- `--local-path`：目录的绝对路径，目录必须已存在且运行时可以读写。
- `--daemon-id`：绑定该目录的守护进程；可用 `multica runtime list` 查看对应的运行时 ID。
- `--execution-mode worktree`：对应桌面端的 **并行**；省略时为 **原地**（`in_place`）。

::: info 原地与并行
- **原地（`in_place`）**：Agent 直接在你的目录里工作，同一时间只进行一次运行，后到的运行会等待。
- **并行（`worktree`）**：每次运行创建独立的 git worktree，同一目录上的运行可以并发，并且不会写入你的工作副本。要求目录是至少有一次提交的 git 仓库，且运行时支持该模式。
:::

::: tip 其它限制
- 每个项目在同一台守护进程上最多关联一个本地目录。
- 团队中的不同电脑可以分别为同一个项目关联各自的目录。
:::
