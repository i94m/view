import { defineConfig } from 'vitepress'

// 部署路径固定为 /docs/（必须以 / 开头和结尾）。站点由自建/本地静态服务器托管，
// 不再发布到 GitHub Pages。
const base = '/docs/'

export default defineConfig({
  lang: 'zh-CN',
  title: 'View DevKit',
  description: 'View DevKit：本地与容器开发环境，以及 Multica、OpenCode Agent 文档',
  base,
  cleanUrls: true,
  // 文档里有大量指向本机环境的 http://localhost 链接，不是站点内部页面
  ignoreDeadLinks: [/^http:\/\/localhost/],
  head: [
    ['meta', { name: 'theme-color', content: '#3451b2' }],
    // head 里的 href 不会被 VitePress 自动加 base，这里手动拼
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}image/logo.svg` }],
  ],
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
    logo: { light: '/image/logo.svg', dark: '/image/logo.svg' },
    socialLinks: [{ icon: 'github', link: 'https://github.com/i94m/view' }],

    nav: [
      { text: 'View 开发环境', link: '/view/', activeMatch: '/view/' },
      { text: 'Multica Agent', link: '/guide/opencode', activeMatch: '/guide/' },
    ],

    sidebar: {
      '/view/': [
        {
          text: 'View 开发环境',
          items: [
            { text: '本地环境', link: '/view/' },
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
          text: '探索',
          items: [
            { text: 'Agent 小队 <span class="sidebar-badge">测试</span>', link: '/guide/squads' },
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
