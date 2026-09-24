import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: 'Multica AI Agents',
  description: 'TKE VIEW 的 multica 运行环境',
  // 部署到子路径时改成 base: '/xxx/'（务必以 / 开头和结尾）
  base: '/docs/',
  cleanUrls: true,
  head: [['meta', { name: 'theme-color', content: '#3451b2' }]],
  markdown: {
    lineNumbers: true,
  },
  themeConfig: {
    nav: [
      { text: '指南', link: '/guide/opencode', activeMatch: '/guide/' },
      { text: '附录', link: '/appendix/notes', activeMatch: '/appendix/' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '运行 multica',
          items: [
            { text: '配置环境变量', link: '/guide/env' },
            { text: '安装 Multica Cli', link: '/guide/host-install' },
          ],
        },
        {
          text: 'OpenCode',
          items: [
            { text: '安装OpenCode', link: '/guide/opencode' },
            { text: 'Playwright MCP', link: '/guide/mcp-playwright' },
            { text: 'Database MCP', link: '/guide/mcp-database' },
          ],
        },
        { text: '容器运行', link: '/guide/container' },
      ],
      '/appendix/': [
        {
          text: '附录',
          items: [{ text: '注意事项', link: '/appendix/notes' }],
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
