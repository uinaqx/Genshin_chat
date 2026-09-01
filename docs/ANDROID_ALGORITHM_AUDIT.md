# Android 聊天算法审计

审计日期：2026-09-01

## 对照范围

- Android 前台：`lib/main.dart`
- Android 后台：`android/app/src/main/java/com/local/genshin/genshin_chat/LiveChatWorker.java`
- Web 消息队列：`app/api/chat/route.ts` 与 `app/chat/chat-app.tsx`
- Web 角色上下文：`app/lib/character-context.ts`
- 角色数据源：`data/characters.json`

## 已确认的旧实现问题

1. Android 前台核心集中在单个约6260行文件，后台 Worker 又复制了一套网络、提示词、记忆和主动消息代码，两个实现已经分叉。
2. Android 角色资源只有92条记录，排除旅行者后只有87名可聊角色，并且没有 `groupPrompt`；Web 数据源已有132条记录和127名完整可聊角色。
3. 前台回复最多读取24条消息且受3200字符预算限制；群聊导演读取16条、摘要读取50条、主动消息读取14条，后台 Worker 只读取18至24条。
4. MemoryMD 由关键词和时间间隔决定是否加载，普通聊天经常没有长期记忆；独立主动消息还会故意排除最近聊天。
5. Android `Character` 没有读取 `groupPrompt`，最终回复也没有完整注入新版 `prompt`，所以仅替换 JSON 不会让新版提示词生效。
6. 会话忙碌时 `_sendMessage` 直接返回，输入框和发送按钮同时禁用，用户在等待期间无法继续聊天。
7. 群聊采用一次导演调用加每个角色一次生成调用，成本高于 Web 单轮生成方案，也更容易出现角色 ID 与正文错配。
8. 原生 Worker 从普通 SharedPreferences 读取 API Key，尚未达到 Android Keystore 的目标安全级别。

## 2.1.0+21 已完成

- 建立最近100条非系统消息的统一上下文下限。
- 每次对话请求强制携带完整 MemoryMD、旅行者关系状态和未完成话题。
- 前台回复完整发送角色 Prompt、SoulMD，以及群聊场景下的 groupPrompt。
- 后台 Worker 同步采用100条历史、完整角色 Prompt 和完整持久状态。
- 角色资源与 Web 数据源同步为132条记录、127名可聊角色，并增加自动校验命令。
- 增加按会话串行的用户消息队列，回复期间允许继续发送，新增消息合并到下一批。

## 后续必须完成

- 将 `main.dart` 拆分为 UI、领域模型、存储、模型网关、聊天引擎和后台任务模块。
- 用 Drift/SQLite 替换普通 JSON 会话文件，并持久化待回复队列。
- 用 Android Keystore/`flutter_secure_storage` 替换普通 SharedPreferences 密钥桥接。
- 让 WorkManager 与前台共用一个聊天引擎，移除 Java 中重复的提示词和模型适配代码。
- 将群聊迁移为一次调用生成整轮0至3名角色发言，并以角色 ID 校验头像、名字和正文。
- 完成新版 Apple 浅色液态玻璃界面、数据库新装流程、后台通知和断网恢复测试。
