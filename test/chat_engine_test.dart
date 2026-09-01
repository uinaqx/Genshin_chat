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
  prompt: '',
  soulMd: '纳西妲是须弥的草神，与旅行者彼此信任。',
);

void main() {
  test('相关记忆检索不会把全部 MemoryMD 塞进上下文', () {
    const memory = '''
- 旅行者喜欢甜食
- 旅行者最近在准备考试
- 旅行者上周去跑步
- 旅行者正在做一个聊天项目
- 旅行者昨晚睡眠不好
''';
    const retriever = RelevantMemoryRetriever();

    final result = retriever.retrieve(memory, '明天考试有点紧张', maxItems: 2);

    expect(result, contains('考试'));
    expect(result.split('\n').length, lessThanOrEqualTo(2));
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
      includeMemory: false,
    );

    expect(messages.last['content'], '今天好累');
    expect(messages.last['content'], isNot(startsWith('[')));
  });

  test('独立主动消息不会读取刚结束的短期聊天', () {
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
      includeMemory: false,
      appendUserMessage: false,
      includeRecentHistory: false,
    );

    expect(messages.where((message) => message['role'] != 'system'), isEmpty);
    expect(messages.join('\n'), isNot(contains('洗澡')));
    expect(messages.join('\n'), isNot(contains('晚安')));
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
