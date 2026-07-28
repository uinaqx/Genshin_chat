# 提瓦特微信 Web

提瓦特微信的网页版。访客通过 ChatGPT 登录后，可以与 92 名《原神》角色私聊，也可以自由选择角色创建群聊。聊天记录按登录账号隔离并保存在 D1，模型密钥仅存在于 Sites 服务端环境变量。

## 功能

- ChatGPT 登录与账号级数据隔离
- 92 名角色通讯录
- 私聊和自定义群聊
- 微信式短消息与单轮连续气泡
- 单次群聊最多 3 名角色发言
- 服务端 DeepSeek API 代理
- 每账号每日调用限额
- Apple 风格浅色界面与高斯模糊玻璃效果
- 桌面与手机自适应布局

## 本地开发

```bash
npm install
npm run dev
npm run build
npm test
```

本地预览会使用仅限 `localhost` 的旅行者账号。生产环境必须通过 ChatGPT 登录。

## 环境变量

参考 `.env.example`。生产密钥由 Sites 环境变量管理，不应写入源代码或提交记录。

## 数据

- `conversations`：用户拥有的私聊和群聊
- `messages`：按用户与会话隔离的消息
- `daily_usage`：每账号每日调用计数

数据库结构位于 `db/schema.ts`，迁移位于 `drizzle/`。
