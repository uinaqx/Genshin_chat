# 提瓦特微信 Web

一个面向浏览器的《原神》角色聊天应用。注册后可以与 116 名非旅行者角色私聊，也可以自由组合角色创建群聊。每个账号拥有独立的聊天记录，模型密钥仅保存在服务端环境变量中。

## 功能

- 邮箱注册与登录，密码使用 bcrypt 哈希保存
- HttpOnly 会话 Cookie 与账号级数据隔离
- 116 名角色通讯录，已同步至 2026 年 7 月上线的桑多涅
- 私聊和自定义群聊
- 微信式短消息与单轮连续气泡
- 回复期间仍可连续发送，新消息会合并为下一批请求
- 单次群聊最多 3 名角色发言
- 服务端 DeepSeek API 代理与每账号每日调用限额
- Apple 风格浅色界面与高斯模糊玻璃效果
- 桌面与手机自适应布局

## 技术架构

- Next.js 16 + React 19
- PostgreSQL
- bcrypt 密码哈希
- DeepSeek OpenAI 兼容接口
- Render Web Service + Render Postgres

## 本地开发

1. 准备 PostgreSQL 数据库。
2. 将 `.env.example` 复制为 `.env.local` 并填写配置。
3. 安装依赖并启动。

```bash
npm install
npm run dev
```

生产构建检查：

```bash
npm run build
npm test
```

## 部署到 Render

仓库根目录的 `render.yaml` 会创建一个 Node Web Service 和一个 PostgreSQL 数据库。

1. 在 Render Dashboard 选择 `New` -> `Blueprint`。
2. 连接这个 GitHub 仓库并确认 Blueprint。
3. 在创建页面填写 `DEEPSEEK_API_KEY`，不要把密钥提交到 GitHub。
4. 部署完成后访问 Render 分配的 `onrender.com` 地址。

健康检查地址为 `/api/health`。应用监听 Render 提供的 `PORT`，数据库连接由 Blueprint 自动注入。

> `render.yaml` 默认使用免费套餐。免费 Web Service 闲置后会休眠，首次唤醒可能较慢；免费 Render Postgres 会在创建 30 天后到期。正式公开运营时应在 Render 控制台将数据库升级为付费实例，避免聊天记录到期丢失。

## 环境变量

| 变量 | 用途 |
| --- | --- |
| `DATABASE_URL` | PostgreSQL 连接字符串 |
| `DATABASE_SSL` | 本地 PostgreSQL 可设置为 `false` |
| `DEEPSEEK_API_KEY` | 服务端模型密钥 |
| `DEEPSEEK_BASE_URL` | 默认 `https://api.deepseek.com` |
| `DEEPSEEK_MODEL` | 默认 `deepseek-v4-flash` |

## 数据安全

- API Key 和数据库连接串不进入浏览器包，也不会写入仓库。
- 登录密码只保存 bcrypt 哈希。
- 会话令牌仅保存 SHA-256 哈希，浏览器 Cookie 设置为 HttpOnly、SameSite=Lax，生产环境启用 Secure。
- 对话、消息、队列和每日用量均按账号隔离。

## 更新记录

### 1.2.0 - 2026-08-17

- 从 GPT Sites/Cloudflare D1 迁移到标准 Next.js/Render/PostgreSQL 架构。
- 新增邮箱注册、密码登录、安全会话与账号级聊天数据隔离。
- 新增 Render Blueprint、数据库绑定和 `/api/health` 健康检查。
- 模型密钥改为 Render 服务端环境变量，保持不可见且不进入 Git 历史。
- 保留消息持久化、批次合并和按会话串行生成回复的聊天队列。

### 1.1.0 - 2026-08-17

- 修复通讯录长列表覆盖底部导航栏的问题。
- 私聊已有角色可立即打开；新建私聊不再重新加载整份角色库和全部会话。
- 重构为“消息先持久化、模型按会话串行回复”的队列架构，回复期间输入框保持可用。
- 新消息会在上一轮完成后合并为下一批请求，切换页面或请求失败也不会丢失已发送内容。
- 针对 DeepSeek JSON 模式偶发空正文增加关闭思考模式、超时控制、空正文重试和解析兜底。
- 通讯录从 92 条角色记录同步到 121 条记录，其中 116 名非旅行者角色可聊天，最新为桑多涅。

### 1.0.0 - 2026-07-28

- 首次发布网页版，提供账号级数据隔离、私聊、自定义群聊与服务端模型代理。
