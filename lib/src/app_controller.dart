part of '../main.dart';

class TeyvatChatApp extends StatefulWidget {
  const TeyvatChatApp({super.key});

  @override
  State<TeyvatChatApp> createState() => _TeyvatChatAppState();
}

class _TeyvatChatAppState extends State<TeyvatChatApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _updates = ValueNotifier<int>(0);
  final _store = LocalStore();
  final _http = HttpTextClient();
  final _random = Random();
  late final _llm = LlmClient(_http);
  late final _search = WebSearchService(_http);
  Map<String, Character> _characterById = {};
  Map<String, ConversationState> _conversations = {};
  final Map<String, String> _typingStatus = {};
  final Set<String> _busyConversations = {};
  final ConversationTurnQueue _turnQueue = ConversationTurnQueue();
  Timer? _followUpTimer;
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  int _homeTabIndex = 0;
  bool _showContactsGuide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _followUpTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_runFollowUpTick()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _followUpTimer?.cancel();
    _updates.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final isInitialLoad = _loading;
    final settings = await _store.loadSettings();
    final characters = await CharacterRepository().load();
    final conversations = await _store.loadConversations();
    final queuedReplies = isInitialLoad
        ? await _store.loadReplyQueue()
        : const <String, dynamic>{};
    final byId = {for (final c in characters) c.id: c};
    _sanitizeConversationMembers(conversations, byId);
    _sanitizeFollowUps(conversations, byId);

    conversations.putIfAbsent(
      'group-teyvat',
      () => ConversationState(
        id: 'group-teyvat',
        title: '提瓦特群聊',
        type: 'group',
        memberIds: [
          'nahida',
          'zhongli',
          'furina',
          'venti',
          'raiden',
          'hu-tao',
          'neuvillette',
          'arlecchino',
        ].where(byId.containsKey).toList(),
      ),
    );
    _sanitizeSavedReplies(conversations, byId);

    setState(() {
      _settings = settings;
      _characterById = byId;
      if (isInitialLoad) {
        _turnQueue.restore(queuedReplies);
      }
      if (_conversations.isEmpty) {
        _conversations = conversations;
      } else {
        for (final entry in conversations.entries) {
          final local = _conversations[entry.key];
          if (local == null) {
            _conversations[entry.key] = entry.value;
          } else if (!_busyConversations.contains(entry.key)) {
            _adoptConversationState(local, entry.value);
          }
        }
      }
      _loading = false;
    });
    await _store.saveConversations(_conversations);
    await _store.syncLiveWorker();
    if (isInitialLoad) {
      unawaited(_resumePendingReplyQueues());
    }
    unawaited(_runFollowUpTick());
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applySettings(
    AppSettings settings, {
    bool showContactsGuide = false,
    int? switchTab,
  }) async {
    setState(() {
      _settings = settings;
      if (switchTab != null) {
        _homeTabIndex = switchTab;
      }
      if (showContactsGuide) {
        _showContactsGuide = true;
      }
    });
    await _store.saveSettings(settings);
    await _store.syncLiveWorker();
  }

  void _sanitizeConversationMembers(
    Map<String, ConversationState> conversations,
    Map<String, Character> characters,
  ) {
    final removable = <String>[];
    for (final entry in conversations.entries) {
      final conversation = entry.value;
      if (conversation.type == 'single') {
        if (conversation.memberIds.isEmpty ||
            !characters.containsKey(conversation.memberIds.first)) {
          removable.add(entry.key);
        }
        continue;
      }
      conversation.memberIds.removeWhere((id) => !characters.containsKey(id));
      if (conversation.memberIds.isEmpty) {
        removable.add(entry.key);
      }
    }
    for (final id in removable) {
      conversations.remove(id);
    }
  }

  void _sanitizeSavedReplies(
    Map<String, ConversationState> conversations,
    Map<String, Character> characters,
  ) {
    for (final conversation in conversations.values) {
      final candidates = conversation.memberIds
          .map((id) => characters[id])
          .whereType<Character>()
          .toList();
      if (candidates.isEmpty) {
        continue;
      }
      conversation.messages = conversation.messages.map((message) {
        if (message.isUser) {
          return message;
        }
        final cleanContent = _stripKnownSpeakerPrefix(
          message.content,
          candidates,
        );
        if (cleanContent == message.content) {
          return message;
        }
        return ChatMessage(
          sender: message.sender,
          content: cleanContent,
          createdAt: message.createdAt,
          characterId: message.characterId,
          authorName: message.authorName,
        );
      }).toList();
    }
  }

  void _sanitizeFollowUps(
    Map<String, ConversationState> conversations,
    Map<String, Character> characters,
  ) {
    for (final conversation in conversations.values) {
      conversation.followUps = conversation.followUps.where((item) {
        return item.speakerId.isNotEmpty &&
            characters.containsKey(item.speakerId) &&
            conversation.memberIds.contains(item.speakerId);
      }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      conversation.memoryMdByCharacter.removeWhere(
        (key, value) => !characters.containsKey(key),
      );
      conversation.lastSpokeAtByCharacter.removeWhere(
        (key, value) => !characters.containsKey(key),
      );
    }
  }

  Future<void> _mergeExternalConversationUpdates() async {
    final external = await _store.loadConversations();
    var changed = false;
    for (final entry in external.entries) {
      if (_busyConversations.contains(entry.key)) {
        continue;
      }
      final local = _conversations[entry.key];
      if (local == null) {
        _conversations[entry.key] = entry.value;
        changed = true;
        continue;
      }
      final source = entry.value;
      final hasNewerMessages =
          source.messages.length > local.messages.length ||
          (source.messages.isNotEmpty &&
              (local.messages.isEmpty ||
                  source.messages.last.createdAt.isAfter(
                    local.messages.last.createdAt,
                  )));
      if (source.updatedAt.isAfter(local.updatedAt) || hasNewerMessages) {
        _adoptConversationState(local, source);
        changed = true;
      }
    }
    if (changed) {
      _notifyChanged();
    }
  }

  void _notifyChanged() {
    if (mounted) {
      setState(() {});
    }
    _updates.value += 1;
  }

  String? _typingLabel(String id) => _typingStatus[id];

  void _showTransientError(Object error) {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_friendlyLocalError(error)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _sendMessage(ConversationState conversation, String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    final now = DateTime.now();
    conversation.messages.add(
      ChatMessage(sender: 'user', content: content, createdAt: now),
    );
    conversation.updatedAt = now;
    conversation.lastUserReplyAt = now;
    if (conversation.realChatEnabled) {
      const ProactiveMessageScheduler().scheduleNext(conversation);
    }
    final shouldStart = _turnQueue.enqueue(conversation.id, content);
    final firstBatch = shouldStart
        ? _turnQueue.takeBatch(conversation.id)
        : const <String>[];
    if (shouldStart) {
      _busyConversations.add(conversation.id);
    }
    await _store.saveConversations(_conversations);
    await _store.saveReplyQueue(_turnQueue.toJson());
    _notifyChanged();
    if (shouldStart) {
      unawaited(_drainReplyQueue(conversation, firstBatch));
    }
  }

  Future<void> _drainReplyQueue(
    ConversationState conversation,
    List<String> firstBatch,
  ) async {
    final agent = ChatAgent(
      characters: _characterById,
      settings: _settings,
      llm: _llm,
      search: _search,
    );
    try {
      var batch = firstBatch;
      while (batch.isNotEmpty) {
        final userText = batch.join('\n');
        try {
          await _processReplyBatch(agent, conversation, userText);
        } catch (error) {
          _showTransientError(error);
        }
        _turnQueue.completeBatch(conversation.id);
        await _store.saveReplyQueue(_turnQueue.toJson());
        batch = _turnQueue.takeBatch(conversation.id);
        if (batch.isNotEmpty) {
          await _store.saveReplyQueue(_turnQueue.toJson());
        }
      }
    } finally {
      _turnQueue.finish(conversation.id);
      _busyConversations.remove(conversation.id);
      _typingStatus.remove(conversation.id);
      await _store.saveConversations(_conversations);
      await _store.saveReplyQueue(_turnQueue.toJson());
      _notifyChanged();
    }
  }

  Future<void> _resumePendingReplyQueues() async {
    for (final conversationId in _turnQueue.pendingConversationIds) {
      final conversation = _conversations[conversationId];
      if (conversation == null) {
        _turnQueue.drop(conversationId);
        continue;
      }
      if (!_turnQueue.begin(conversationId)) {
        continue;
      }
      final batch = _turnQueue.takeBatch(conversationId);
      if (batch.isEmpty) {
        _turnQueue.finish(conversationId);
        continue;
      }
      _busyConversations.add(conversationId);
      await _store.saveReplyQueue(_turnQueue.toJson());
      unawaited(_drainReplyQueue(conversation, batch));
    }
    await _store.saveReplyQueue(_turnQueue.toJson());
    _notifyChanged();
  }

  Future<void> _processReplyBatch(
    ChatAgent agent,
    ConversationState conversation,
    String userText,
  ) async {
    final generationConversation = ConversationState.fromJson(
      conversation.toJson(),
    );
    if (conversation.type == 'group') {
      await _processGroupReplyBatch(
        agent,
        conversation,
        generationConversation,
        userText,
      );
      return;
    }
    final showTyping = conversation.type != 'group';
    await _delayBeforeTyping();
    if (showTyping) {
      _typingStatus[conversation.id] = '正在输入...';
      _notifyChanged();
    }
    final typingStartedAt = DateTime.now();
    final speakers = await agent.chooseSpeakers(
      generationConversation,
      userText,
    );
    if (showTyping) {
      await _waitForMinimumTyping(
        typingStartedAt,
        const Duration(milliseconds: 1500),
      );
    }
    if (speakers.isEmpty) return;

    for (final speaker in speakers) {
      if (showTyping) {
        _typingStatus[conversation.id] = '正在输入...';
        _notifyChanged();
      }
      final speakerStartedAt = DateTime.now();
      final replies = await agent.replyFromSpeaker(
        generationConversation,
        userText,
        speaker,
      );
      if (showTyping) {
        await _waitForMinimumTyping(
          speakerStartedAt,
          const Duration(milliseconds: 1500),
        );
      }
      final acceptedReplies = <ChatMessage>[];
      for (final reply in replies) {
        if (_isNearDuplicateReply(conversation, reply)) continue;
        if (acceptedReplies.isNotEmpty) {
          await Future.delayed(
            Duration(milliseconds: 420 + _random.nextInt(481)),
          );
        }
        conversation.messages.add(reply);
        generationConversation.messages.add(reply);
        acceptedReplies.add(reply);
        conversation.updatedAt = DateTime.now();
        conversation.lastCharacterPingAt = DateTime.now();
        conversation.lastSpokeAtByCharacter[speaker.id] = DateTime.now();
        generationConversation.lastSpokeAtByCharacter[speaker.id] =
            DateTime.now();
        await _store.saveConversations(_conversations);
        _notifyChanged();
      }
      if (acceptedReplies.isEmpty) continue;
      if (conversation.realChatEnabled) {
        const ProactiveMessageScheduler().scheduleNext(conversation);
      }
      final combinedReply = ChatMessage(
        sender: 'assistant',
        content: acceptedReplies.map((reply) => reply.content).join('\n'),
        createdAt: acceptedReplies.last.createdAt,
        characterId: speaker.id,
        authorName: speaker.name,
      );
      try {
        await _maybeUpdateConversationState(
          agent,
          conversation,
          speaker,
          userText,
          combinedReply,
        );
        await _store.saveConversations(_conversations);
      } catch (_) {}
    }
  }

  Future<void> _processGroupReplyBatch(
    ChatAgent agent,
    ConversationState conversation,
    ConversationState generationConversation,
    String userText,
  ) async {
    final replies = await agent.replyGroupTurn(
      generationConversation,
      userText,
    );
    if (replies.isEmpty) return;
    final acceptedBySpeaker = <String, List<ChatMessage>>{};
    var acceptedCount = 0;
    for (final reply in replies) {
      final speakerId = reply.characterId;
      final speaker = speakerId == null ? null : _characterById[speakerId];
      if (speaker == null || !conversation.memberIds.contains(speaker.id)) {
        continue;
      }
      if (_isNearDuplicateReply(conversation, reply)) continue;
      if (acceptedCount > 0) {
        await Future.delayed(
          Duration(milliseconds: 420 + _random.nextInt(481)),
        );
      }
      conversation.messages.add(reply);
      generationConversation.messages.add(reply);
      acceptedBySpeaker.putIfAbsent(speaker.id, () => []).add(reply);
      acceptedCount += 1;
      final now = DateTime.now();
      conversation.updatedAt = now;
      conversation.lastCharacterPingAt = now;
      conversation.lastSpokeAtByCharacter[speaker.id] = now;
      generationConversation.lastSpokeAtByCharacter[speaker.id] = now;
      await _store.saveConversations(_conversations);
      _notifyChanged();
    }
    if (acceptedBySpeaker.isEmpty) return;
    if (conversation.realChatEnabled) {
      const ProactiveMessageScheduler().scheduleNext(conversation);
    }
    for (final entry in acceptedBySpeaker.entries) {
      final speaker = _characterById[entry.key];
      if (speaker == null || entry.value.isEmpty) continue;
      final combinedReply = ChatMessage(
        sender: 'assistant',
        content: entry.value.map((reply) => reply.content).join('\n'),
        createdAt: entry.value.last.createdAt,
        characterId: speaker.id,
        authorName: speaker.name,
      );
      try {
        await _maybeUpdateConversationState(
          agent,
          conversation,
          speaker,
          userText,
          combinedReply,
        );
        await _store.saveConversations(_conversations);
      } catch (_) {}
    }
  }

  Future<void> _waitForMinimumTyping(
    DateTime startedAt,
    Duration minimum,
  ) async {
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minimum) {
      await Future.delayed(minimum - elapsed);
    }
  }

  Future<void> _delayBeforeTyping() {
    return Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(1001)));
  }

  Future<void> _maybeUpdateConversationState(
    ChatAgent agent,
    ConversationState conversation,
    Character speaker,
    String userText,
    ChatMessage reply,
  ) async {
    _updateRelationshipState(conversation, speaker, userText, reply);
    final updatedMemory = await agent.maybeUpdateMemory(
      conversation,
      speaker,
      userText,
      reply,
    );
    if (updatedMemory != null && updatedMemory.trim().isNotEmpty) {
      conversation.memoryMdByCharacter[speaker.id] = updatedMemory.trim();
    }
    final followUp = await agent.planFollowUp(
      conversation,
      speaker,
      userText,
      reply,
    );
    if (followUp != null) {
      conversation.followUps.removeWhere(
        (item) =>
            item.speakerId == speaker.id && item.dueAt.isAfter(DateTime.now()),
      );
      conversation.followUps.add(
        ScheduledFollowUp(
          id: 'follow-up-${DateTime.now().microsecondsSinceEpoch}-${speaker.id}',
          speakerId: speaker.id,
          dueAt: DateTime.now().add(Duration(minutes: followUp.delayMinutes)),
          reason: followUp.reason,
          prompt: followUp.prompt,
        ),
      );
      conversation.followUps.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      await _store.syncLiveWorker();
    } else if (conversation.realChatEnabled) {
      const ProactiveMessageScheduler().scheduleNext(conversation);
      await _store.syncLiveWorker();
    }
    final summary = await agent.maybeSummarize(conversation);
    if (summary != null && summary.trim().isNotEmpty) {
      conversation.summary = summary.trim();
    }
  }

  void _updateRelationshipState(
    ConversationState conversation,
    Character speaker,
    String userText,
    ChatMessage reply,
  ) {
    final previous =
        conversation.relationshipStateByCharacter[speaker.id] ??
        RelationshipState();
    final interactionCount = conversation.messages
        .where((message) => message.isUser || message.characterId == speaker.id)
        .length;
    final stage = switch (interactionCount) {
      >= 80 => '长期同行、彼此信任',
      >= 30 => '关系亲近、了解彼此习惯',
      >= 10 => '熟悉、交流自然',
      _ => previous.stage,
    };
    final combined = '$userText\n${reply.content}';
    final mood = RegExp(r'(累|烦|难受|焦虑|压力|委屈|生气|低落)').hasMatch(combined)
        ? '在意旅行者近况，但保持角色自己的表达方式'
        : RegExp(r'(哈哈|开心|好玩|太好了|成功)').hasMatch(combined)
        ? '轻松、愿意接着聊'
        : '自然、延续当前熟悉程度';
    final topic = _shorten(userText.replaceAll(RegExp(r'\s+'), ' ').trim(), 36);
    final topics = <String>[
      if (topic.length >= 2) topic,
      ...previous.recentTopics.where((item) => item != topic),
    ].take(5).toList();
    conversation.relationshipStateByCharacter[speaker.id] = RelationshipState(
      stage: stage,
      currentMood: mood,
      recentTopics: topics,
      lastInteractionAt: DateTime.now(),
    );
  }

  Future<void> _runFollowUpTick() async {
    if (_loading || _settings.apiKey.trim().isEmpty) {
      return;
    }
    await _mergeExternalConversationUpdates();
    final now = DateTime.now();
    for (final conversation in _conversations.values) {
      if (_busyConversations.contains(conversation.id) ||
          conversation.memberIds.isEmpty) {
        continue;
      }
      final dueItems =
          conversation.followUps
              .where((item) => !item.dueAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (dueItems.isEmpty) {
        final proactive = const ProactiveMessageScheduler().maybeCreateDuePlan(
          conversation,
          _characterById,
        );
        if (proactive != null) {
          dueItems.add(proactive);
        }
      }
      if (dueItems.isEmpty) {
        continue;
      }
      _busyConversations.add(conversation.id);
      await _store.saveConversations(_conversations);
      unawaited(_finishScheduledFollowUps(conversation, dueItems));
    }
  }

  Future<void> _finishScheduledFollowUps(
    ConversationState conversation,
    List<ScheduledFollowUp> dueItems,
  ) async {
    final agent = ChatAgent(
      characters: _characterById,
      settings: _settings,
      llm: _llm,
      search: _search,
    );

    try {
      final showTyping = conversation.type != 'group';
      await _delayBeforeTyping();
      if (showTyping) {
        _typingStatus[conversation.id] = '正在输入...';
        _notifyChanged();
      }
      for (final followUp in dueItems) {
        final speaker = _characterById[followUp.speakerId];
        if (speaker == null) {
          continue;
        }
        if (showTyping) {
          _typingStatus[conversation.id] = '正在输入...';
          _notifyChanged();
        }
        final speakerStartedAt = DateTime.now();
        final replies = await agent.replyFollowUp(
          conversation,
          followUp,
          speaker,
        );
        if (showTyping) {
          await _waitForMinimumTyping(
            speakerStartedAt,
            const Duration(milliseconds: 1500),
          );
        }
        final acceptedReplies = <ChatMessage>[];
        for (final reply in replies) {
          if (_isNearDuplicateReply(conversation, reply)) {
            continue;
          }
          if (acceptedReplies.isNotEmpty) {
            await Future.delayed(
              Duration(milliseconds: 420 + _random.nextInt(481)),
            );
          }
          conversation.messages.add(reply);
          acceptedReplies.add(reply);
          conversation.updatedAt = DateTime.now();
          conversation.lastCharacterPingAt = DateTime.now();
          conversation.lastSpokeAtByCharacter[speaker.id] = DateTime.now();
          await _store.saveConversations(_conversations);
          _notifyChanged();
        }
        if (acceptedReplies.isNotEmpty) {
          if (followUp.id.startsWith('proactive-')) {
            conversation.lastProactiveAt = DateTime.now();
            conversation.lastProactiveTopic = followUp.prompt;
          }
          if (conversation.realChatEnabled) {
            const ProactiveMessageScheduler().scheduleNext(conversation);
          }
          final combinedReply = ChatMessage(
            sender: 'assistant',
            content: acceptedReplies.map((reply) => reply.content).join('\n'),
            createdAt: acceptedReplies.last.createdAt,
            characterId: speaker.id,
            authorName: speaker.name,
          );
          try {
            await _maybeUpdateConversationState(
              agent,
              conversation,
              speaker,
              followUp.prompt,
              combinedReply,
            );
            await _store.saveConversations(_conversations);
          } catch (_) {}
        }
        conversation.followUps.removeWhere((item) => item.id == followUp.id);
      }
    } catch (error) {
      _showTransientError(error);
    } finally {
      _busyConversations.remove(conversation.id);
      _typingStatus.remove(conversation.id);
      await _store.saveConversations(_conversations);
      _notifyChanged();
    }
  }

  bool _isNearDuplicateReply(
    ConversationState conversation,
    ChatMessage reply,
  ) {
    final normalized = _normalizeReplyForCompare(reply.content);
    if (normalized.length < 2) {
      return true;
    }
    final recent = conversation.messages.reversed
        .where(
          (message) =>
              !message.isUser && message.characterId == reply.characterId,
        )
        .take(6);
    for (final message in recent) {
      final other = _normalizeReplyForCompare(message.content);
      if (other == normalized) {
        return true;
      }
      final minLength = min(other.length, normalized.length);
      if (minLength >= 4 &&
          (other.contains(normalized) || normalized.contains(other))) {
        return true;
      }
      if (minLength >= 4 &&
          _longestCommonSubstringLength(other, normalized) >= 4) {
        return true;
      }
      if (minLength >= 8 &&
          (other.startsWith(normalized.substring(0, minLength)) ||
              normalized.startsWith(other.substring(0, minLength)))) {
        return true;
      }
    }
    return false;
  }

  String _normalizeReplyForCompare(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[，。！？、,.!?~～…\-]'), '')
        .trim();
  }

  Future<void> _showSettings() async {
    final sheetContext = _navigatorKey.currentContext;
    if (sheetContext == null) {
      return;
    }
    final settings = await showModalBottomSheet<AppSettings>(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => SettingsSheet(settings: _settings),
    );
    if (settings != null) {
      await _applySettings(settings);
    }
  }

  ConversationState _ensureSingleConversation(Character character) {
    final existing = _conversations[character.id];
    if (existing != null) {
      return existing;
    }
    final conversation = ConversationState(
      id: character.id,
      title: character.name,
      type: 'single',
      memberIds: [character.id],
    );
    _conversations[character.id] = conversation;
    return conversation;
  }

  Future<void> _openConversation(ConversationState conversation) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    await navigator.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => ChatPage(
          conversation: conversation,
          characters: _characterById,
          traveler: _settings.traveler,
          updates: _updates,
          typingLabel: _typingLabel,
          onSend: _sendMessage,
          onEditGroup: _showEditGroupMembers,
          onDeleteGroup: _deleteGroupConversation,
          onToggleRealChat: _toggleRealChat,
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved);
          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleRealChat(ConversationState conversation) async {
    conversation.realChatEnabled = !conversation.realChatEnabled;
    if (conversation.realChatEnabled) {
      await _store.requestNotificationPermission();
      conversation.cooldownMinutes = max(
        conversation.cooldownMinutes,
        _settings.proactiveCooldownMinutes,
      );
      const ProactiveMessageScheduler().scheduleNext(conversation);
    } else {
      conversation.nextPingAt = null;
    }
    await _store.saveConversations(_conversations);
    await _store.syncLiveWorker();
    _notifyChanged();
  }

  Future<void> _openSingleChat(Character character) async {
    _showContactsGuide = false;
    final conversation = _ensureSingleConversation(character);
    await _store.saveConversations(_conversations);
    await _openConversation(conversation);
  }

  Future<void> _showCharacterActions(Character character) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => ContactActionSheet(
        character: character,
        onMessage: () async {
          Navigator.of(sheetContext).pop();
          await _openSingleChat(character);
        },
        onAddToGroup: () async {
          Navigator.of(sheetContext).pop();
          await _showGroupPickerForCharacter(character);
        },
      ),
    );
  }

  Future<void> _showGroupPickerForCharacter(Character character) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    final groups =
        _conversations.values
            .where((conversation) => conversation.type == 'group')
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => GroupPickerSheet(groups: groups, character: character),
    );
    if (target == null) {
      return;
    }
    if (target == '__new__') {
      await _showCreateGroup(preselectedMemberIds: [character.id]);
      return;
    }
    final group = _conversations[target];
    if (group == null || group.type != 'group') {
      return;
    }
    if (!group.memberIds.contains(character.id)) {
      group.memberIds.add(character.id);
      group.updatedAt = DateTime.now();
      await _store.saveConversations(_conversations);
      _notifyChanged();
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${character.name} 已加入 ${group.title}')),
      );
  }

  Future<void> _showCreateGroup({
    List<String> preselectedMemberIds = const [],
  }) async {
    final sheetContext = _navigatorKey.currentContext;
    if (sheetContext == null) {
      return;
    }
    final result = await showModalBottomSheet<CreateGroupResult>(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => CreateGroupSheet(
        characters: _characterById.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
        initialMemberIds: preselectedMemberIds,
        actionLabel: '创建群聊',
      ),
    );
    if (result == null || result.memberIds.isEmpty) {
      return;
    }
    final id = 'group-${DateTime.now().microsecondsSinceEpoch}';
    final conversation = ConversationState(
      id: id,
      title: result.title,
      type: 'group',
      memberIds: result.memberIds,
    );
    _conversations[id] = conversation;
    await _store.saveConversations(_conversations);
    _notifyChanged();
    await _openConversation(conversation);
  }

  Future<void> _showEditGroupMembers(ConversationState conversation) async {
    final sheetContext = _navigatorKey.currentContext;
    if (sheetContext == null || conversation.type != 'group') {
      return;
    }
    final result = await showModalBottomSheet<CreateGroupResult>(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => CreateGroupSheet(
        characters: _characterById.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
        initialTitle: conversation.title,
        initialMemberIds: conversation.memberIds,
        actionLabel: '创建群聊',
      ),
    );
    if (result == null || result.memberIds.isEmpty) {
      return;
    }
    conversation.title = result.title;
    conversation.memberIds
      ..clear()
      ..addAll(result.memberIds.where(_characterById.containsKey));
    conversation.updatedAt = DateTime.now();
    await _store.saveConversations(_conversations);
    _notifyChanged();
  }

  Future<void> _deleteGroupConversation(ConversationState conversation) async {
    if (conversation.type != 'group') {
      return;
    }
    final sheetContext = _navigatorKey.currentContext;
    if (sheetContext == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: const Text('删除群聊'),
        content: Text('确定删除“${conversation.title}”吗？聊天记录也会一起删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    _busyConversations.remove(conversation.id);
    _typingStatus.remove(conversation.id);
    _conversations.remove(conversation.id);
    await _store.saveConversations(_conversations);
    await _store.syncLiveWorker();
    _notifyChanged();
    _navigatorKey.currentState?.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '提瓦特微信',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _wechatGreen),
        scaffoldBackgroundColor: _page,
        fontFamilyFallback: const ['Noto Sans CJK SC', 'Microsoft YaHei'],
        useMaterial3: true,
        splashFactory: InkSparkle.splashFactory,
        dividerColor: _wechatLine,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xD9FFFFFF),
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _wechatText,
          titleTextStyle: TextStyle(
            color: _wechatText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xF5FFFFFF),
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xF5FFFFFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _settings.apiKey.trim().isEmpty
          ? WelcomeSetupPage(
              initialSettings: _settings,
              onSave: (settings) => _applySettings(
                settings,
                showContactsGuide: true,
                switchTab: 1,
              ),
            )
          : WeChatHomeShell(
              currentIndex: _homeTabIndex,
              onTabChanged: (index) {
                setState(() {
                  _homeTabIndex = index;
                });
              },
              chatsPage: ChatsHomePage(
                conversations: _chatListConversations,
                characters: _characterById,
                typingLabel: _typingLabel,
                onCreateGroup: () => _showCreateGroup(),
                onOpen: _openConversation,
              ),
              contactsPage: ContactsPage(
                characters: _contactCharacters,
                showGuide: _showContactsGuide,
                onOpenContact: _showCharacterActions,
                onCreateGroup: () => _showCreateGroup(),
              ),
              mePage: MePage(
                settings: _settings,
                liveConversationCount: _pendingFollowUpCount,
                totalConversationCount: _chatListConversations.length,
                onEditSettings: _showSettings,
                onToggleSearch: (value) =>
                    _applySettings(_settings.copyWith(searchEnabled: value)),
                onSelectTraveler: (id) =>
                    _applySettings(_settings.copyWith(travelerId: id)),
              ),
            ),
    );
  }

  List<ConversationState> get _orderedConversations {
    final items = _conversations.values.toList();
    items.sort((a, b) {
      if (a.id == 'group-teyvat') return -1;
      if (b.id == 'group-teyvat') return 1;
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      if (a.messages.isNotEmpty || b.messages.isNotEmpty) {
        return byTime;
      }
      return a.title.compareTo(b.title);
    });
    return items;
  }

  List<ConversationState> get _chatListConversations {
    return _orderedConversations.where((conversation) {
      if (conversation.id == 'group-teyvat') return true;
      if (conversation.type == 'group') return true;
      return conversation.messages.isNotEmpty;
    }).toList();
  }

  List<Character> get _contactCharacters {
    final items = _characterById.values.toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  int get _pendingFollowUpCount => _conversations.values.fold<int>(
    0,
    (sum, conversation) => sum + (conversation.realChatEnabled ? 1 : 0),
  );
}
