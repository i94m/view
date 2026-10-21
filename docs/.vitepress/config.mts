import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: 'Multica AI Agents',
  description: 'TKE VIEW 的 multica 运行环境',
  // 部署到子路径时改成 base: '/xxx/'（务必以 / 开头和结尾）
  base: '/docs/',
  cleanUrls: true,
  // 文档里有大量指向本机环境的 http://localhost 链接，不是站点内部页面
  ignoreDeadLinks: [/^http:\/\/localhost/],
  head: [['meta', { name: 'theme-color', content: '#3451b2' }]],
  markdown: {
    lineNumbers: true,
    image: { lazyLoad: true },
    container: {
      tipLabel: '提示',
      warningLabel: '警告',
      dangerLabel: '危险',
      infoLabel: '信息',
      detailsLabel: '详细信息',
    },
  },
  themeConfig: {
    nav: [
      { text: '指南', link: '/guide/opencode', activeMatch: '/guide/' },
      { text: 'View 本地环境', link: '/view/', activeMatch: '/view/' },
    ],

    sidebar: {
      '/view/': [
        {
          text: 'View 本地环境',
          items: [
            { text: '本地环境', link: '/view/' },
            { text: '介绍', link: '/view/info' },
            { text: '基础命令', link: '/view/command' },
            { text: 'IDE 配置 / Xdebug', link: '/view/ide' },
            { text: '常见问题', link: '/view/question' },
            { text: '在 Docker 中运行镜像', link: '/view/backup' },
          ],
        },
      ],
      '/guide/': [
        {
          text: 'Multica',
          items: [
            { text: '配置环境变量', link: '/guide/env' },
            { text: '安装 Multica', link: '/guide/host-install' },
            { text: '添加 Runtime', link: '/guide/multica-setup' },
            { text: '添加项目资源', link: '/guide/project-resources' },
          ],
        },
        {
          text: 'OpenCode',
          items: [
            { text: '安装和配置', link: '/guide/opencode' },
            { text: '浏览器 MCP', link: '/guide/mcp-playwright' },
            { text: '数据库 MCP', link: '/guide/mcp-database' },
          ],
        },
        {
          text: 'Agent 协作',
          items: [
            { text: '组件小队', link: '/guide/component-squads' },
          ],
        },
      ],
    },

    outline: { level: [2, 3], label: '本页目录' },
    docFooter: { prev: '上一篇', next: '下一篇' },
    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '菜单',
    darkModeSwitchLabel: '主题',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',

    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: '搜索文档', buttonAriaLabel: '搜索文档' },
          modal: {
            noResultsText: '无法找到相关结果',
            resetButtonTitle: '清除查询条件',
            footer: {
              selectText: '选择',
              navigateText: '切换',
              closeText: '关闭',
            },
          },
        },
      },
    },
  },
})
