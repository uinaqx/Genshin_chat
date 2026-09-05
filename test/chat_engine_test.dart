import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_chat/main.dart';

const _character = Character(
  id: 'nahida',
  name: '纳西妲',
  enName: 'Nahida',
  title: '白草净华',
  vision: '草',
  weapon: '法器',
  nation: '须弥',
  rarity: 5,
  description: '温柔、细致而聪慧。',
  avatarUrl: '',
  cardUrl: '',
  prompt: '纳西妲专属测试 Prompt：用户就是旅行者。',
  soulMd: '纳西妲是须弥的草神，与旅行者彼此信任。',
  groupPrompt: '纳西妲在群聊中会先观察，再自然接话。',
);

const _furina = Character(
  id: 'furina',
  name: '芙宁娜',
  enName: 'Furina',
  title: '不休独舞',
  vision: '水',
  weapon: '单手剑',
  nation: '枫丹',
  rarity: 5,
  description: '戏剧化、敏锐，也会用夸张掩饰认真。',
  avatarUrl: '',
  cardUrl: '',
  prompt: '芙宁娜专属测试 Prompt：用户就是旅行者。',
  soulMd: '芙宁娜经历过枫丹预言，与旅行者熟识。',
  groupPrompt: '芙宁娜会在群聊中用鲜明语气接话。',
);

void main() {
  test('Android 角色资源包含127名完整可聊角色', () {
    final root =
        jsonDecode(File('assets/data/characters.json').readAsStringSync())
            as Map<String, dynamic>;
    final characters = (root['characters'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final chatable = characters
        .where(
          (character) => !character['id'].toString().startsWith('traveler-'),
        )
        .toList();

    expect(characters, hasLength(132));
    expect(chatable, hasLength(127));
    for (final character in chatable) {
      expect(character['prompt'].toString().trim(), isNotEmpty);
      expect(character['soulMd'].toString().trim(), isNotEmpty);
      expect(character['groupPrompt'].toString().trim(), isNotEmpty);
    }
  });

  test('日常问候采用微信短回复规划', () {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
    );
    final plan = DialoguePlanner().planSingle(
      profile: CharacterProfile.fromCharacter(_character),
      conversation: conversation,
      userText: '你在干嘛',
    );

    expect(plan.length, ReplyLength.short);
    expect(plan.maxCharacters, lessThanOrEqualTo(72));
    expect(plan.dialogueAct, contains('自己的生活'));
    expect(plan.messageCount, 2);
  });

  test('回复校验在重写不可用时仍会本地截短并去掉助手腔', () async {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
    );
    final validator = ResponseValidator(
      llm: LlmClient(HttpTextClient()),
      settings: const AppSettings(),
      characters: const {'nahida': _character},
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '自然接话',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 36,
    );

    final result = await validator.validateAndRewriteIfNeeded(
      draft: '我理解你的感受。如果你愿意的话，可以先制定一个完整计划，然后一步一步执行，最后再总结今天的收获。',
      messages: const [],
      conversation: conversation,
      speaker: _character,
      profile: CharacterProfile.fromCharacter(_character),
      plan: plan,
    );

    expect(result.length, lessThanOrEqualTo(36));
    expect(result, isNot(contains('我理解你的感受')));
    expect(result, isNot(contains('如果你愿意的话')));
  });

  test('回复校验会移除时间前缀和未说完的连接词', () async {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
    );
    final validator = ResponseValidator(
      llm: LlmClient(HttpTextClient()),
      settings: const AppSettings(),
      characters: const {'nahida': _character},
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '自然接话',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 48,
    );

    final result = await validator.validateAndRewriteIfNeeded(
      draft: '[12:09] （翻书）那就不学。反正',
      messages: const [],
      conversation: conversation,
      speaker: _character,
      profile: CharacterProfile.fromCharacter(_character),
      plan: plan,
    );

    expect(result, '那就不学。');
  });

  test('上下文中的历史消息不向模型暴露可模仿的时间前缀', () {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      messages: [
        ChatMessage(
          sender: 'user',
          content: '今天好累',
          createdAt: DateTime(2026, 7, 28, 12, 9),
        ),
      ],
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '关心',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 72,
    );

    final messages = ContextBuilder().build(
      conversation: conversation,
      speaker: _character,
      profile: CharacterProfile.fromCharacter(_character),
      plan: plan,
      userText: '今天好累',
    );

    expect(messages.last['content'], '今天好累');
    expect(messages.last['content'], isNot(startsWith('[')));
  });

  test('主动消息也会读取刚结束的短期聊天', () {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      messages: [
        ChatMessage(
          sender: 'user',
          content: '我要去洗澡了',
          createdAt: DateTime(2026, 7, 28, 22),
        ),
        ChatMessage(
          sender: 'assistant',
          content: '晚安，明天见。',
          createdAt: DateTime(2026, 7, 28, 22, 1),
          characterId: 'nahida',
          authorName: '纳西妲',
        ),
      ],
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '主动分享日常',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 68,
    );

    final messages = ContextBuilder().build(
      conversation: conversation,
      speaker: _character,
      profile: CharacterProfile.fromCharacter(_character),
      plan: plan,
      userText: '分享自己的新日常',
      appendUserMessage: false,
    );

    expect(messages.join('\n'), contains('洗澡'));
    expect(messages.join('\n'), contains('晚安'));
  });

  test('每次请求严格保留最近100条非系统消息', () {
    final history = List<ChatMessage>.generate(120, (index) {
      return ChatMessage(
        sender: index.isOdd ? 'user' : 'assistant',
        content: '历史消息$index',
        createdAt: DateTime(2026, 8, 1).add(Duration(minutes: index)),
        characterId: index.isEven ? 'nahida' : null,
        authorName: index.isEven ? '纳西妲' : null,
      );
    });
    history.insert(
      60,
      ChatMessage(
        sender: 'system',
        content: '不应进入模型的系统记录',
        createdAt: DateTime(2026, 8, 1, 1),
      ),
    );
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      messages: history,
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '自然接话',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 72,
    );

    final messages = ContextBuilder().build(
      conversation: conversation,
      speaker: _character,
      profile: CharacterProfile.fromCharacter(_character),
      plan: plan,
      userText: '历史消息119',
    );
    final historyMessages = messages
        .where((message) => message['role'] != 'system')
        .toList();

    expect(recentContextMessages(conversation), hasLength(100));
    expect(historyMessages, hasLength(100));
    expect(historyMessages.first['content'], '历史消息20');
    expect(historyMessages.last['content'], '历史消息119');
    expect(messages.join('\n'), isNot(contains('历史消息19')));
    expect(messages.join('\n'), isNot(contains('不应进入模型的系统记录')));
  });

  test('普通闲聊也必须携带完整角色设定、长期记忆、关系和未完成话题', () {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      memoryMdByCharacter: const {'nahida': '- 旅行者正在准备考试\n- 旅行者最近睡眠不好'},
      relationshipStateByCharacter: {
        'nahida': RelationshipState(
          stage: '长期同行、彼此信任',
          currentMood: '担心旅行者休息不足',
          recentTopics: const ['考试', '睡眠'],
          lastInteractionAt: DateTime(2026, 8, 2, 19),
        ),
      },
      followUps: [
        ScheduledFollowUp(
          id: 'exam-follow-up',
          speakerId: 'nahida',
          dueAt: DateTime(2026, 8, 2, 20),
          reason: '询问考试结果',
          prompt: '问旅行者考试是否顺利结束',
        ),
      ],
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '简短反应',
      length: ReplyLength.veryShort,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 1,
      avoidExplanation: true,
      maxCharacters: 36,
    );

    final prompt = ContextBuilder()
        .build(
          conversation: conversation,
          speaker: _character,
          profile: CharacterProfile.fromCharacter(_character),
          plan: plan,
          userText: '哈哈',
        )
        .map((message) => message['content'])
        .join('\n');

    expect(prompt, contains('纳西妲专属测试 Prompt'));
    expect(prompt, contains('纳西妲是须弥的草神'));
    expect(prompt, contains('旅行者正在准备考试'));
    expect(prompt, contains('与旅行者的关系状态'));
    expect(prompt, contains('长期同行、彼此信任'));
    expect(prompt, contains('担心旅行者休息不足'));
    expect(prompt, contains('考试 / 睡眠'));
    expect(prompt, contains('询问考试结果'));
    expect(prompt, contains('问旅行者考试是否顺利结束'));
  });

  test('连续回复会拆成独立的微信消息气泡', () {
    const splitter = ReplyBubbleSplitter();

    final messages = splitter.split(
      '刚在图书馆整理旧书。\n翻到一本写着古代药方的。',
      desiredCount: 2,
    );

    expect(messages, hasLength(2));
    expect(messages.first, '刚在图书馆整理旧书。');
    expect(messages.last, '翻到一本写着古代药方的。');
  });

  test('回复期间的新消息会合并到下一批而不会阻塞发送', () {
    final queue = ConversationTurnQueue();

    expect(queue.enqueue('nahida', '第一条'), isTrue);
    expect(queue.takeBatch('nahida'), ['第一条']);
    expect(queue.enqueue('nahida', '第二条'), isFalse);
    expect(queue.enqueue('nahida', '第三条'), isFalse);
    expect(queue.takeBatch('nahida'), ['第二条', '第三条']);
    expect(queue.isProcessing('nahida'), isTrue);

    queue.finish('nahida');
    expect(queue.isProcessing('nahida'), isFalse);
    expect(queue.isEmpty, isTrue);
    expect(queue.enqueue('nahida', '新一轮'), isTrue);
  });

  test('不同会话拥有互不干扰的回复队列', () {
    final queue = ConversationTurnQueue();

    expect(queue.enqueue('nahida', '须弥消息'), isTrue);
    expect(queue.enqueue('furina', '枫丹消息'), isTrue);
    expect(queue.takeBatch('nahida'), ['须弥消息']);
    expect(queue.takeBatch('furina'), ['枫丹消息']);
  });

  test('处理中和等待中的消息会一起持久化并可在重启后恢复', () {
    final queue = ConversationTurnQueue();
    expect(queue.enqueue('nahida', '第一条'), isTrue);
    expect(queue.takeBatch('nahida'), ['第一条']);
    expect(queue.enqueue('nahida', '第二条'), isFalse);

    final restored = ConversationTurnQueue()..restore(queue.toJson());
    expect(restored.pendingConversationIds, ['nahida']);
    expect(restored.begin('nahida'), isTrue);
    expect(restored.takeBatch('nahida'), ['第一条', '第二条']);
  });

  test('群聊整轮只调用一次模型并按角色ID绑定多气泡', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    final serverTask = () async {
      await for (final request in server) {
        requestCount += 1;
        final requestBody = await utf8.decoder.bind(request).join();
        expect(requestBody, contains('纳西妲专属测试 Prompt'));
        expect(requestBody, contains('芙宁娜专属测试 Prompt'));
        expect(requestBody, contains('最近100条群聊'));
        final groupPayload = jsonEncode({
          'messages': [
            {
              'character_id': 'nahida',
              'content': ['先坐一会儿。', '今天是被什么累到了？'],
            },
            {
              'character_id': 'furina',
              'content': ['居然累成这样。'],
            },
          ],
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': groupPayload},
              },
            ],
          }),
        );
        await request.response.close();
        await server.close(force: true);
      }
    }();
    final settings = AppSettings(
      apiKey: 'test-key',
      baseUrl:
          'http://${InternetAddress.loopbackIPv4.address}:${server.port}/v1/chat/completions',
      model: 'test-model',
      searchEnabled: false,
      maxTokens: 420,
    );
    final client = HttpTextClient();
    final agent = ChatAgent(
      characters: const {'nahida': _character, 'furina': _furina},
      settings: settings,
      llm: LlmClient(client),
      search: WebSearchService(client),
    );
    final conversation = ConversationState(
      id: 'group-test',
      title: '测试群聊',
      type: 'group',
      memberIds: const ['nahida', 'furina'],
      memoryMdByCharacter: const {
        'nahida': '- 旅行者昨天在赶项目',
        'furina': '- 旅行者答应看新剧目',
      },
      messages: [
        ChatMessage(
          sender: 'user',
          content: '纳西妲，今天好累，你们呢？',
          createdAt: DateTime(2026, 9, 3, 21),
        ),
      ],
    );

    final replies = await agent.replyGroupTurn(conversation, '纳西妲，今天好累，你们呢？');
    await serverTask;

    expect(requestCount, 1);
    expect(replies.map((message) => message.characterId), [
      'nahida',
      'nahida',
      'furina',
    ]);
    expect(replies.map((message) => message.authorName), ['纳西妲', '纳西妲', '芙宁娜']);
    expect(replies.map((message) => message.content), [
      '先坐一会儿。',
      '今天是被什么累到了？',
      '居然累成这样。',
    ]);
  });

  test('Android凭据和聊天后台不再读取普通明文存储', () {
    final mainActivity = File(
      'android/app/src/main/java/com/local/genshin/genshin_chat/MainActivity.java',
    ).readAsStringSync();
    final worker = File(
      'android/app/src/main/java/com/local/genshin/genshin_chat/LiveChatWorker.java',
    ).readAsStringSync();
    final secureStore = File(
      'android/app/src/main/java/com/local/genshin/genshin_chat/SecureApiKeyStore.java',
    ).readAsStringSync();
    final database = File(
      'android/app/src/main/java/com/local/genshin/genshin_chat/TeyvatDatabase.java',
    ).readAsStringSync();

    expect(mainActivity, contains('SecureApiKeyStore.save'));
    expect(mainActivity, contains('TeyvatDatabase.get'));
    expect(worker, isNot(contains('conversations.json')));
    expect(worker, isNot(contains('getString("api_key"')));
    expect(secureStore, contains('AndroidKeyStore'));
    expect(secureStore, contains('AES/GCM/NoPadding'));
    expect(database, contains('CREATE TABLE messages'));
    expect(database, contains('CREATE TABLE character_memories'));
    expect(database, contains('CREATE TABLE follow_ups'));
    expect(database, contains('CREATE TABLE reply_queue'));
  });

  test('合并批次不会在模型上下文中重复追加用户消息', () {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      messages: [
        ChatMessage(
          sender: 'user',
          content: '第二条',
          createdAt: DateTime(2026, 9, 1, 18),
        ),
        ChatMessage(
          sender: 'user',
          content: '第三条',
          createdAt: DateTime(2026, 9, 1, 18, 1),
        ),
      ],
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '自然接话',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 72,
    );

    final messages = ContextBuilder().build(
      conversation: conversation,
      speaker: _character,
      profile: CharacterProfile.fromCharacter(_character),
      plan: plan,
      userText: '第二条\n第三条',
    );
    final userMessages = messages
        .where((message) => message['role'] == 'user')
        .toList();

    expect(userMessages, hasLength(2));
    expect(userMessages.map((message) => message['content']), ['第二条', '第三条']);
  });

  test('回复校验会识别改写后的重复关键短语', () {
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      messages: [
        ChatMessage(
          sender: 'assistant',
          content: '顺路帮我带几株塞西莉亚花。',
          createdAt: DateTime(2026, 7, 28, 12),
          characterId: 'nahida',
          authorName: '纳西妲',
        ),
      ],
    );
    final validator = ResponseValidator(
      llm: LlmClient(HttpTextClient()),
      settings: const AppSettings(),
      characters: const {'nahida': _character},
    );
    const plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '主动发消息',
      length: ReplyLength.short,
      emotion: '自然',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 72,
    );

    final reason = validator.invalidReason(
      '散步时帮我把塞西莉亚花带回来？',
      conversation,
      _character,
      plan,
    );

    expect(reason, contains('相同短语'));
  });

  test('到期的真实聊天会基于未完成事项创建主动消息计划', () {
    final now = DateTime(2026, 7, 28, 12);
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      realChatEnabled: true,
      nextPingAt: now.subtract(const Duration(minutes: 1)),
      lastUserReplyAt: now.subtract(const Duration(hours: 2)),
      messages: [
        ChatMessage(
          sender: 'user',
          content: '明天要交项目',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
    );

    final followUp = const ProactiveMessageScheduler().maybeCreateDuePlan(
      conversation,
      const {'nahida': _character},
      currentTime: now,
    );

    expect(followUp, isNotNull);
    expect(followUp!.prompt, contains('项目'));
    expect(followUp.reason, contains('跟进'));
  });

  test('主动消息不会把“你在干嘛”当成需要复述的话题', () {
    final now = DateTime(2026, 7, 28, 12);
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      realChatEnabled: true,
      nextPingAt: now.subtract(const Duration(minutes: 1)),
      lastUserReplyAt: now.subtract(const Duration(hours: 2)),
      messages: [
        ChatMessage(
          sender: 'user',
          content: '你在干嘛',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
    );

    final followUp = const ProactiveMessageScheduler().maybeCreateDuePlan(
      conversation,
      const {'nahida': _character},
      currentTime: now,
    );

    expect(followUp, isNotNull);
    expect(followUp!.prompt, isNot(contains('你在干嘛')));
    expect(followUp.prompt, contains('自己的日常'));
  });

  test('用户未回复上一条主动消息时不会继续连发', () {
    final now = DateTime.now();
    final conversation = ConversationState(
      id: 'nahida',
      title: '纳西妲',
      type: 'single',
      memberIds: const ['nahida'],
      realChatEnabled: true,
      nextPingAt: now.subtract(const Duration(minutes: 1)),
      lastProactiveAt: now.subtract(const Duration(hours: 3)),
      lastUserReplyAt: now.subtract(const Duration(hours: 4)),
    );

    final plan = const ProactiveMessageScheduler().maybeCreateDuePlan(
      conversation,
      const {'nahida': _character},
    );

    expect(plan, isNull);
    expect(conversation.nextPingAt, isNotNull);
    expect(conversation.nextPingAt!.isAfter(now), isTrue);
  });

  test('前后台同时保存时会合并主动消息与用户新消息', () async {
    final originalDirectory = Directory.current;
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'genshin-chat-store-test-',
    );
    Directory.current = temporaryDirectory;
    try {
      final store = LocalStore();
      final base = ConversationState(
        id: 'nahida',
        title: '纳西妲',
        type: 'single',
        memberIds: const ['nahida'],
        updatedAt: DateTime(2026, 7, 28, 12),
        messages: [
          ChatMessage(
            sender: 'assistant',
            content: '刚整理完书架。',
            createdAt: DateTime(2026, 7, 28, 12),
            characterId: 'nahida',
            authorName: '纳西妲',
          ),
        ],
      );
      await store.saveConversations({'nahida': base});

      final foreground = await store.loadConversations();
      final background = await store.loadConversations();
      background['nahida']!.messages.add(
        ChatMessage(
          sender: 'assistant',
          content: '窗边闻到苹果糖的味道了。',
          createdAt: DateTime(2026, 7, 28, 12, 2),
          characterId: 'nahida',
          authorName: '纳西妲',
        ),
      );
      background['nahida']!.updatedAt = DateTime(2026, 7, 28, 12, 2);
      await store.saveConversations(background);

      foreground['nahida']!.messages.add(
        ChatMessage(
          sender: 'user',
          content: '我刚回来。',
          createdAt: DateTime(2026, 7, 28, 12, 1),
        ),
      );
      foreground['nahida']!.updatedAt = DateTime(2026, 7, 28, 12, 1);
      await store.saveConversations(foreground);

      final persisted = await store.loadConversations();
      final contents = persisted['nahida']!.messages
          .map((message) => message.content)
          .toList();
      expect(contents, contains('我刚回来。'));
      expect(contents, contains('窗边闻到苹果糖的味道了。'));
      expect(contents.toSet(), hasLength(contents.length));
    } finally {
      Directory.current = originalDirectory;
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
