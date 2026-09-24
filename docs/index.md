---
layout: home

hero:
  name: Multica AI Agents
  tagline: Make humans and AI agents work as one team
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/env
    - theme: alt
      text: 访问站点
      # 目标：站点根 /
      # 1) '/' 会被 VitePress 拼成 '/docs/'，改用相对上一级 '../'（解析结果为 /）
      # 2) VitePress 的全局 click 监听还会拦截站内链接走 SPA 路由，
      #    并把 base 还原成 /docs/；加 target 让它跳过拦截、做整页跳转
      target: _self
      link: ../
---
