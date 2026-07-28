# 提瓦特微信

一个纯本地运行的《原神》角色聊天 Android 应用。用户在 App 内填写自己的 OpenAI 兼容 LLM API Key，就可以像微信一样与提瓦特角色私聊或群聊。

> 非官方粉丝项目。本项目与 HoYoverse、米哈游没有关联，角色、世界观、图片与相关素材版权归其原权利方所有。

## 下载

[一键下载 Android APK](https://github.com/uinaqx/Genshin_chat/raw/main/releases/teyvat-chat-release.apk)

当前仓库内提供已构建好的 APK：`releases/teyvat-chat-release.apk`。

## 功能

- 微信式首页、通讯录、我的三栏结构
- 主页面只显示已激活的会话，新角色从通讯录发起私聊
- 私聊和群聊互斥展示，交互接近微信
- 用户可选择旅行者形象：空或荧
- 本地保存聊天记录、设置、角色记忆
- 用户自行填写 API Key，不内置任何密钥
- API 配置支持 OpenAI 兼容格式与 Anthropic Messages 格式
- API 设置页支持一键测试连通性，便于区分密钥、模型、接口地址和返回格式问题
- 角色配置、对话规划、回复校验、群聊导演、记忆系统、主动跟进调度
- 群聊由导演模块选择 0 到 3 名角色发言，不会全员排队回复
- “真实聊天”模式会基于未完成话题主动跟进，避免随机尬聊
- 支持联网搜索相关问题，用于补充新版本、活动、卡池等信息

## 当前架构

核心逻辑目前集中在 `lib/main.dart`，主要模块包括：

- `CharacterProfile`：角色说话风格、关系、示例回复、群聊倾向
- `DialoguePlanner`：决定回复动作、情绪、长度和是否反问
- `ResponseGenerator`：根据上下文生成最终回复
- `ResponseValidator`：过滤长篇、AI 助手腔、角色名前缀、群聊发言人错乱
- `GroupChatOrchestrator`：决定群聊本轮谁说话、说几个人、按什么顺序
- `MemoryStore`：维护短期上下文、摘要和角色长期记忆
- `RelevantMemoryRetriever`：按当前话题筛选相关 MemoryMD 片段，减少无关记忆和 Token
- `ProactiveMessageScheduler`：根据未完成话题安排主动跟进
- `LocalStore`：保存本地设置与聊天记录
- `LiveChatWorker`：Android 后台任务，用于补发到期跟进消息

## 本地开发

需要安装 Flutter 和 Android SDK。

```powershell
flutter pub get
flutter analyze
flutter build apk --release
```

生成的 APK 位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

本仓库同时保留一份可直接下载的 APK：`releases/teyvat-chat-release.apk`。后续正式版本也可以继续使用 GitHub Releases 分发。

## API Key 与隐私

- App 不内置 API Key。
- API 格式可选择：
  - OpenAI 兼容格式，默认接口为 `https://api.openai.com/v1/chat/completions`
  - Anthropic 格式，默认接口为 `https://api.anthropic.com/v1/messages`
- 如果只填写根地址，例如 `https://api.openai.com` 或 `https://api.anthropic.com`，App 会自动补全到对应接口路径。
- 设置页的“一键测试 API”会发起一次极短测试请求，并显示更具体的失败原因。
- Android 版本会把用户填写的 API Key 保存到应用私有存储入口，不写入仓库文件。
- 不要在 Issue、日志、截图或提交中公开 API Key。
- 聊天记录保存在用户设备本地；上传仓库前不要提交本地数据文件。

## 角色数据

角色基础数据位于：

```text
assets/data/characters.json
```

相关生成脚本位于：

```text
tools/
```

`tools/.cache/` 是资料抓取缓存，已被 `.gitignore` 排除。

通讯录页面只展示角色来源和简短性格说明。完整 SoulMD、说话风格示例、长期记忆等后台资料不会在玩家界面直接显示。

## 开源参考与设计借鉴

- [SillyTavern](https://github.com/SillyTavern/SillyTavern)：参考角色卡、群聊自然激活、角色发言倾向和分层提示词思路。
- [RisuAI](https://github.com/kwaroran/Risuai)：参考近期记忆与相关记忆混合、上下文压缩和长期角色聊天设计。
- [ChatterUI](https://github.com/Vali-98/ChatterUI)：参考按上下文预算从最新消息向前装填、保留消息时间信息的移动端实现。
- [sillytavern-character-memory](https://github.com/bal-spec/sillytavern-character-memory)：参考结构化记忆提取、按当前话题检索相关记忆的思路。

本项目只借鉴公开架构与算法思想，代码按当前 Flutter/Android 架构独立实现。

## 版本更新

### 2.0.0+20

- 重构上下文拼装：按字符预算从最新消息向前选取历史，并向角色提供自然的本地时间感。
- 新增相关记忆检索：MemoryMD 不再整份注入，只选取与当前话题相关的片段。
- 重写日常对话规划：区分知识问题、日常询问、情绪表达、招呼和普通闲聊。
- 增加微信短回复硬限制：模型重写失败时，本地仍会限制句数和字数并清理典型 AI 助手腔。
- 单聊支持单轮连续发送 1 至 3 条独立消息气泡，规划器决定数量并以自然间隔逐条送达。
- 重构真实聊天调度：支持安静时段、未回复不连发、主动消息主题去重、上下文跟进和角色日常分享。
- 主动消息增加短语级重复检测、早晚语义校验、括号旁白清理与最多两次自动换题重写。
- 修复前后台会话同步：后台 Worker 写入的新消息会合并到当前聊天对象并立即显示。
- 前台与后台改用同一文件锁、临时文件替换和消息并集合并，避免主动消息与用户新消息同时保存时互相覆盖。
- 群聊加入角色最近发言时间和发言倾向，减少同一角色连续抢话和排队式回复。
- Android 后台任务同步使用新的时间感知主动聊天与短消息规则。
- OpenAI 兼容接口会识别 DeepSeek 等推理模型并自动预留推理 Token，截断结果不会作为正文发送。
- “一键测试 API”改为前台可见的成功/失败弹窗，不再被设置面板遮挡。
- “我的”页面改为读取安装包的真实版本号，后续发布无需再手工同步。
- 新增自动化测试，覆盖相关记忆、日常短回复、强制长度限制、主动消息防刷屏和前后台并发保存。

### 1.9.1+19

- LLM 调用失败后不再向聊天记录发送系统消息，只显示临时弹窗提醒。
- 放宽 LLM 请求等待时间，减少中转站或代理响应较慢时的误失败。
- 联网搜索失败不再打断正常角色回复。
- 优化未填写 API Key、每日调用次数上限、请求超时等错误提示。

### 1.9.0+18

- 增加初始化和设置页的一键 API 测试。
- 改进 OpenAI 兼容接口返回解析，支持非字符串消息内容、直接文本字段等更多格式。
- 修复回复校验、记忆、后续跟进等后处理失败时阻塞角色可见回复的问题。
- 修复成功调用 LLM 后，本地回复归一化正则崩溃的问题。
- 通讯录隐藏后台 SoulMD 和说话示例，只展示简洁公开角色信息。
- API 配置支持 OpenAI 兼容格式与 Anthropic Messages 格式。
- 修复 API URL 自动补全、Anthropic 历史消息转换和 HTTP 错误提示。
- 重构聊天系统，加入角色配置、对话规划、回复生成、回复校验、群聊导演、记忆系统和主动跟进调度。
- 单聊回复更短，更接近微信聊天，减少 AI 助手感。
- 群聊每轮由导演选择 0 到 3 个角色发言，不再全员排队回复。
- 增加基于未完成话题的真实聊天主动跟进。
- 增加调用成本控制，包括最大 Token、每日调用次数、群聊发言人数和冷却时间。
- Android API Key 存储从普通设置文件迁移到应用私有存储入口。
- 完成 GitHub 上传准备、APK 下载文件和项目文档。

## 开源说明

代码以 MIT License 发布。项目中涉及《原神》的角色名、设定、图片链接、世界观文本等不属于本项目作者，版权归原权利方所有。本项目仅作学习、研究和粉丝交流用途。
