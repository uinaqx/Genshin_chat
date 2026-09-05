part of '../main.dart';

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.enName,
    required this.title,
    required this.vision,
    required this.weapon,
    required this.nation,
    required this.rarity,
    required this.description,
    required this.avatarUrl,
    required this.cardUrl,
    required this.prompt,
    required this.soulMd,
    this.groupPrompt = '',
  });

  final String id;
  final String name;
  final String enName;
  final String title;
  final String vision;
  final String weapon;
  final String nation;
  final int rarity;
  final String description;
  final String avatarUrl;
  final String cardUrl;
  final String prompt;
  final String soulMd;
  final String groupPrompt;

  String get regionLabel => nation.isEmpty ? '未知地区' : nation;

  String get shortInfo => '$vision / $regionLabel / $weapon';

  String get publicInfo {
    final source = description.trim().isNotEmpty
        ? description.trim()
        : title.trim().isNotEmpty
        ? title.trim()
        : '性格鲜明，正在提瓦特大陆上经历自己的故事。';
    final firstSentence = source.split(RegExp(r'[。！？!?]')).first.trim();
    final compact = firstSentence.length > 36
        ? '${firstSentence.substring(0, 36)}...'
        : firstSentence;
    return '来自$regionLabel。性格特点：$compact';
  }

  List<String> get voiceExamples {
    final marker = '贴近角色原作语气的中文示例（用于模仿语气，不要机械复读）：';
    final index = prompt.indexOf(marker);
    if (index < 0) {
      return const [];
    }
    final tail = prompt.substring(index).split('\n');
    final result = <String>[];
    for (final line in tail) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ')) {
        result.add(trimmed.substring(2).trim());
      } else if (result.isNotEmpty && trimmed.isEmpty) {
        break;
      }
    }
    return result;
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String,
      name: json['name'] as String,
      enName: json['enName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      vision: json['vision'] as String? ?? '',
      weapon: json['weapon'] as String? ?? '',
      nation: json['nation'] as String? ?? '',
      rarity: json['rarity'] as int? ?? 4,
      description: json['description'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      cardUrl: json['cardUrl'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      soulMd: json['soulMd'] as String? ?? json['prompt'] as String? ?? '',
      groupPrompt: json['groupPrompt'] as String? ?? '',
    );
  }
}

String _stripKnownSpeakerPrefix(String text, Iterable<Character> candidates) {
  var result = text.trim();
  for (var i = 0; i < 3; i += 1) {
    final before = result;
    for (final character in candidates) {
      final names = [
        character.name,
        character.enName,
        character.title,
      ].where((name) => name.trim().isNotEmpty);
      for (final name in names) {
        final escaped = RegExp.escape(name.trim());
        result = result.replaceFirst(
          RegExp('^\\s*(?:\\*\\*)?$escaped(?:\\*\\*)?\\s*[:：,，、-]\\s*'),
          '',
        );
      }
    }
    if (result == before) {
      break;
    }
  }
  return result.trim();
}

class ChatMessage {
  ChatMessage({
    required this.sender,
    required this.content,
    required this.createdAt,
    this.characterId,
    this.authorName,
  });

  final String sender;
  final String content;
  final DateTime createdAt;
  final String? characterId;
  final String? authorName;

  bool get isUser => sender == 'user';

  Map<String, dynamic> toJson() => {
    'sender': sender,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'characterId': characterId,
    'authorName': authorName,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String,
      content: json['content'] as String,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      characterId: json['characterId'] as String?,
      authorName: json['authorName'] as String?,
    );
  }
}

class ScheduledFollowUp {
  ScheduledFollowUp({
    required this.id,
    required this.speakerId,
    required this.dueAt,
    required this.reason,
    required this.prompt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String speakerId;
  final DateTime dueAt;
  final String reason;
  final String prompt;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'speakerId': speakerId,
    'dueAt': dueAt.toIso8601String(),
    'reason': reason,
    'prompt': prompt,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ScheduledFollowUp.fromJson(Map<String, dynamic> json) {
    return ScheduledFollowUp(
      id:
          json['id'] as String? ??
          'follow-up-${DateTime.now().microsecondsSinceEpoch}',
      speakerId: json['speakerId'] as String? ?? '',
      dueAt:
          DateTime.tryParse(json['dueAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 30)),
      reason: json['reason'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class FollowUpDecision {
  const FollowUpDecision({
    required this.delayMinutes,
    required this.reason,
    required this.prompt,
  });

  final int delayMinutes;
  final String reason;
  final String prompt;
}

class RelationshipState {
  RelationshipState({
    this.stage = '熟识',
    this.currentMood = '自然',
    List<String>? recentTopics,
    this.lastInteractionAt,
  }) : recentTopics = List<String>.from(recentTopics ?? const []);

  final String stage;
  final String currentMood;
  final List<String> recentTopics;
  final DateTime? lastInteractionAt;

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'currentMood': currentMood,
    'recentTopics': recentTopics,
    'lastInteractionAt': lastInteractionAt?.toIso8601String(),
  };

  factory RelationshipState.fromJson(Map<String, dynamic> json) {
    return RelationshipState(
      stage: json['stage'] as String? ?? '熟识',
      currentMood: json['currentMood'] as String? ?? '自然',
      recentTopics: (json['recentTopics'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      lastInteractionAt: DateTime.tryParse(
        json['lastInteractionAt'] as String? ?? '',
      ),
    );
  }
}

class ConversationState {
  ConversationState({
    required this.id,
    required this.title,
    required this.type,
    required List<String> memberIds,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.summary = '',
    this.summarizedCount = 0,
    List<ScheduledFollowUp>? followUps,
    Map<String, String>? memoryMdByCharacter,
    Map<String, RelationshipState>? relationshipStateByCharacter,
    this.realChatEnabled = false,
    this.nextPingAt,
    this.lastUserReplyAt,
    this.lastCharacterPingAt,
    this.lastProactiveAt,
    this.lastProactiveTopic = '',
    Map<String, DateTime>? lastSpokeAtByCharacter,
    this.cooldownMinutes = 90,
    this.pingFrequency = 'medium',
  }) : memberIds = List<String>.from(memberIds),
       updatedAt = updatedAt ?? DateTime.now(),
       messages = messages ?? [],
       followUps = followUps ?? [],
       memoryMdByCharacter = memoryMdByCharacter ?? {},
       relationshipStateByCharacter = relationshipStateByCharacter ?? {},
       lastSpokeAtByCharacter = lastSpokeAtByCharacter ?? {};

  final String id;
  String title;
  final String type;
  final List<String> memberIds;
  DateTime updatedAt;
  List<ChatMessage> messages;
  String summary;
  int summarizedCount;
  List<ScheduledFollowUp> followUps;
  Map<String, String> memoryMdByCharacter;
  Map<String, RelationshipState> relationshipStateByCharacter;
  bool realChatEnabled;
  DateTime? nextPingAt;
  DateTime? lastUserReplyAt;
  DateTime? lastCharacterPingAt;
  DateTime? lastProactiveAt;
  String lastProactiveTopic;
  Map<String, DateTime> lastSpokeAtByCharacter;
  int cooldownMinutes;
  String pingFrequency;

  String get preview {
    if (messages.isEmpty) {
      return type == 'group' ? '' : '发一条消息开始聊天';
    }
    return messages.last.content.replaceAll('\n', ' ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'memberIds': memberIds,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'summary': summary,
    'summarizedCount': summarizedCount,
    'followUps': followUps.map((item) => item.toJson()).toList(),
    'memoryMdByCharacter': memoryMdByCharacter,
    'relationshipStateByCharacter': relationshipStateByCharacter.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'realChatEnabled': realChatEnabled,
    'nextPingAt': nextPingAt?.toIso8601String(),
    'lastUserReplyAt': lastUserReplyAt?.toIso8601String(),
    'lastCharacterPingAt': lastCharacterPingAt?.toIso8601String(),
    'lastProactiveAt': lastProactiveAt?.toIso8601String(),
    'lastProactiveTopic': lastProactiveTopic,
    'lastSpokeAtByCharacter': lastSpokeAtByCharacter.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'cooldownMinutes': cooldownMinutes,
    'pingFrequency': pingFrequency,
  };

  factory ConversationState.fromJson(Map<String, dynamic> json) {
    return ConversationState(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      memberIds: (json['memberIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String? ?? '',
      summarizedCount: json['summarizedCount'] as int? ?? 0,
      followUps: (json['followUps'] as List<dynamic>? ?? [])
          .map((e) => ScheduledFollowUp.fromJson(e as Map<String, dynamic>))
          .toList(),
      memoryMdByCharacter:
          (json['memoryMdByCharacter'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, value.toString()),
          ),
      relationshipStateByCharacter:
          (json['relationshipStateByCharacter'] as Map<String, dynamic>? ?? {})
              .map(
                (key, value) => MapEntry(
                  key,
                  RelationshipState.fromJson(value as Map<String, dynamic>),
                ),
              ),
      realChatEnabled: json['realChatEnabled'] as bool? ?? false,
      nextPingAt: DateTime.tryParse(json['nextPingAt'] as String? ?? ''),
      lastUserReplyAt: DateTime.tryParse(
        json['lastUserReplyAt'] as String? ?? '',
      ),
      lastCharacterPingAt: DateTime.tryParse(
        json['lastCharacterPingAt'] as String? ?? '',
      ),
      lastProactiveAt: DateTime.tryParse(
        json['lastProactiveAt'] as String? ?? '',
      ),
      lastProactiveTopic: json['lastProactiveTopic'] as String? ?? '',
      lastSpokeAtByCharacter:
          (json['lastSpokeAtByCharacter'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(
              key,
              DateTime.tryParse(value.toString()) ?? DateTime(2000),
            ),
          ),
      cooldownMinutes: json['cooldownMinutes'] as int? ?? 90,
      pingFrequency: json['pingFrequency'] as String? ?? 'medium',
    );
  }
}

String _messagePersistenceKey(ChatMessage message) {
  return [
    message.createdAt.microsecondsSinceEpoch,
    message.sender,
    message.characterId ?? '',
    message.authorName ?? '',
    message.content,
  ].join('\u0001');
}

bool _isConversationStateNewer(
  ConversationState source,
  ConversationState target,
) {
  final sourceLastMessage = source.messages.isEmpty
      ? null
      : source.messages.last.createdAt;
  final targetLastMessage = target.messages.isEmpty
      ? null
      : target.messages.last.createdAt;
  return source.updatedAt.isAfter(target.updatedAt) ||
      (sourceLastMessage != null &&
          (targetLastMessage == null ||
              sourceLastMessage.isAfter(targetLastMessage))) ||
      source.messages.length > target.messages.length;
}

void _adoptConversationState(
  ConversationState target,
  ConversationState source,
) {
  target.title = source.title;
  target.memberIds
    ..clear()
    ..addAll(source.memberIds);
  target.updatedAt = source.updatedAt;
  target.messages = List<ChatMessage>.from(source.messages);
  target.summary = source.summary;
  target.summarizedCount = source.summarizedCount;
  target.followUps = List<ScheduledFollowUp>.from(source.followUps);
  target.memoryMdByCharacter = Map<String, String>.from(
    source.memoryMdByCharacter,
  );
  target.relationshipStateByCharacter = Map<String, RelationshipState>.from(
    source.relationshipStateByCharacter,
  );
  target.realChatEnabled = source.realChatEnabled;
  target.nextPingAt = source.nextPingAt;
  target.lastUserReplyAt = source.lastUserReplyAt;
  target.lastCharacterPingAt = source.lastCharacterPingAt;
  target.lastProactiveAt = source.lastProactiveAt;
  target.lastProactiveTopic = source.lastProactiveTopic;
  target.lastSpokeAtByCharacter = Map<String, DateTime>.from(
    source.lastSpokeAtByCharacter,
  );
  target.cooldownMinutes = source.cooldownMinutes;
  target.pingFrequency = source.pingFrequency;
}

DateTime? _laterDate(DateTime? first, DateTime? second) {
  if (first == null) {
    return second;
  }
  if (second == null) {
    return first;
  }
  return first.isAfter(second) ? first : second;
}

void _mergeConversationForPersistence(
  ConversationState target,
  ConversationState disk,
) {
  final localTitle = target.title;
  final localMemberIds = List<String>.from(target.memberIds);
  final localMessages = List<ChatMessage>.from(target.messages);
  final localMessageKeys = localMessages.map(_messagePersistenceKey).toSet();
  final diskMessageKeys = disk.messages.map(_messagePersistenceKey).toSet();
  final localOnlyMessages = localMessages
      .where(
        (message) => !diskMessageKeys.contains(_messagePersistenceKey(message)),
      )
      .toList();
  final diskOnlyMessages = disk.messages
      .where(
        (message) =>
            !localMessageKeys.contains(_messagePersistenceKey(message)),
      )
      .toList();
  final localFollowUps = List<ScheduledFollowUp>.from(target.followUps);
  final localMemory = Map<String, String>.from(target.memoryMdByCharacter);
  final localRelationship = Map<String, RelationshipState>.from(
    target.relationshipStateByCharacter,
  );
  final localRealChatEnabled = target.realChatEnabled;
  final localNextPingAt = target.nextPingAt;
  final localLastUserReplyAt = target.lastUserReplyAt;
  final localLastCharacterPingAt = target.lastCharacterPingAt;
  final localLastProactiveAt = target.lastProactiveAt;
  final localLastProactiveTopic = target.lastProactiveTopic;
  final localLastSpokeAt = Map<String, DateTime>.from(
    target.lastSpokeAtByCharacter,
  );
  final localCooldownMinutes = target.cooldownMinutes;
  final localPingFrequency = target.pingFrequency;
  final localUpdatedAt = target.updatedAt;
  final diskIsNewer = _isConversationStateNewer(disk, target);

  if (diskIsNewer) {
    _adoptConversationState(target, disk);
  }

  target.title = localTitle;
  target.memberIds
    ..clear()
    ..addAll(localMemberIds);
  target.realChatEnabled = localRealChatEnabled;
  target.cooldownMinutes = localCooldownMinutes;
  target.pingFrequency = localPingFrequency;

  final mergedMessages = <ChatMessage>[...localMessages, ...diskOnlyMessages]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  target.messages = mergedMessages;

  if (localOnlyMessages.isNotEmpty) {
    final firstLocalOnlyAt = localOnlyMessages
        .map((message) => message.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final followUpsById = {for (final item in disk.followUps) item.id: item};
    for (final item in localFollowUps) {
      if (followUpsById.containsKey(item.id) ||
          !item.createdAt.isBefore(firstLocalOnlyAt)) {
        followUpsById[item.id] = item;
      }
    }
    target.followUps = followUpsById.values.toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    target.memoryMdByCharacter = {...disk.memoryMdByCharacter, ...localMemory};
    target.relationshipStateByCharacter = {
      ...disk.relationshipStateByCharacter,
      ...localRelationship,
    };
    target.nextPingAt = localNextPingAt;
  } else if (!diskIsNewer) {
    target.followUps = localFollowUps;
    target.memoryMdByCharacter = localMemory;
    target.relationshipStateByCharacter = localRelationship;
    target.nextPingAt = localNextPingAt;
  }

  target.lastUserReplyAt = _laterDate(
    localLastUserReplyAt,
    disk.lastUserReplyAt,
  );
  target.lastCharacterPingAt = _laterDate(
    localLastCharacterPingAt,
    disk.lastCharacterPingAt,
  );
  target.lastProactiveAt = _laterDate(
    localLastProactiveAt,
    disk.lastProactiveAt,
  );
  if (localLastProactiveAt != null &&
      (disk.lastProactiveAt == null ||
          !localLastProactiveAt.isBefore(disk.lastProactiveAt!))) {
    target.lastProactiveTopic = localLastProactiveTopic;
  }
  for (final entry in localLastSpokeAt.entries) {
    target.lastSpokeAtByCharacter[entry.key] = _laterDate(
      entry.value,
      target.lastSpokeAtByCharacter[entry.key],
    )!;
  }

  var newestAt = _laterDate(localUpdatedAt, disk.updatedAt)!;
  if (target.messages.isNotEmpty) {
    newestAt = _laterDate(newestAt, target.messages.last.createdAt)!;
  }
  target.updatedAt = newestAt;
}

class AppSettings {
  const AppSettings({
    this.apiKey = '',
    this.apiFormat = 'openai',
    this.baseUrl = 'https://api.openai.com/v1/chat/completions',
    this.model = 'gpt-4.1-mini',
    this.searchEnabled = true,
    this.travelerId = 'aether',
    this.dailyCallLimit = 120,
    this.maxTokens = 220,
    this.groupMaxSpeakers = 3,
    this.proactiveCooldownMinutes = 90,
    this.lowCostGroupMode = true,
  });

  final String apiKey;
  final String apiFormat;
  final String baseUrl;
  final String model;
  final bool searchEnabled;
  final String travelerId;
  final int dailyCallLimit;
  final int maxTokens;
  final int groupMaxSpeakers;
  final int proactiveCooldownMinutes;
  final bool lowCostGroupMode;

  TravelerProfile get traveler => _travelerProfile(travelerId);

  AppSettings copyWith({
    String? apiKey,
    String? apiFormat,
    String? baseUrl,
    String? model,
    bool? searchEnabled,
    String? travelerId,
    int? dailyCallLimit,
    int? maxTokens,
    int? groupMaxSpeakers,
    int? proactiveCooldownMinutes,
    bool? lowCostGroupMode,
  }) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      apiFormat: apiFormat ?? this.apiFormat,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      searchEnabled: searchEnabled ?? this.searchEnabled,
      travelerId: travelerId ?? this.travelerId,
      dailyCallLimit: dailyCallLimit ?? this.dailyCallLimit,
      maxTokens: maxTokens ?? this.maxTokens,
      groupMaxSpeakers: groupMaxSpeakers ?? this.groupMaxSpeakers,
      proactiveCooldownMinutes:
          proactiveCooldownMinutes ?? this.proactiveCooldownMinutes,
      lowCostGroupMode: lowCostGroupMode ?? this.lowCostGroupMode,
    );
  }

  Map<String, dynamic> toJson({bool includeApiKey = true}) => {
    if (includeApiKey) 'apiKey': apiKey,
    'apiFormat': apiFormat,
    'baseUrl': baseUrl,
    'model': model,
    'searchEnabled': searchEnabled,
    'travelerId': travelerId,
    'dailyCallLimit': dailyCallLimit,
    'maxTokens': maxTokens,
    'groupMaxSpeakers': groupMaxSpeakers,
    'proactiveCooldownMinutes': proactiveCooldownMinutes,
    'lowCostGroupMode': lowCostGroupMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      apiKey: json['apiKey'] as String? ?? '',
      apiFormat: json['apiFormat'] as String? ?? 'openai',
      baseUrl:
          json['baseUrl'] as String? ??
          'https://api.openai.com/v1/chat/completions',
      model: json['model'] as String? ?? 'gpt-4.1-mini',
      searchEnabled: json['searchEnabled'] as bool? ?? true,
      travelerId: json['travelerId'] as String? ?? 'aether',
      dailyCallLimit: json['dailyCallLimit'] as int? ?? 120,
      maxTokens: json['maxTokens'] as int? ?? 220,
      groupMaxSpeakers: json['groupMaxSpeakers'] as int? ?? 3,
      proactiveCooldownMinutes: json['proactiveCooldownMinutes'] as int? ?? 90,
      lowCostGroupMode: json['lowCostGroupMode'] as bool? ?? true,
    );
  }
}

class LocalStore {
  static const _channel = MethodChannel('genshin_chat/files');

  Future<Directory> _baseDir() async {
    String path;
    if (Platform.isAndroid) {
      path = await _channel.invokeMethod<String>('getFilesDir') ?? '.';
    } else {
      path = '${Directory.current.path}${Platform.pathSeparator}local_data';
    }
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Map<String, dynamic>> _readJson(
    String fileName,
    Map<String, dynamic> fallback,
  ) async {
    final file = File(
      '${(await _baseDir()).path}${Platform.pathSeparator}$fileName',
    );
    if (!await file.exists()) {
      return fallback;
    }
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _writeJson(String fileName, Map<String, dynamic> data) async {
    final file = File(
      '${(await _baseDir()).path}${Platform.pathSeparator}$fileName',
    );
    final contents = const JsonEncoder.withIndent('  ').convert(data);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      await file.writeAsString(contents, flush: true);
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<T> _withConversationLock<T>(Future<T> Function() action) async {
    final lockFile = File(
      '${(await _baseDir()).path}${Platform.pathSeparator}'
      'follow_up_worker.lock',
    );
    final handle = await lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return await action();
    } finally {
      try {
        await handle.unlock();
      } catch (_) {}
      await handle.close();
    }
  }

  Future<String> _loadApiKeyFromPlatform() async {
    if (!Platform.isAndroid) {
      return '';
    }
    try {
      return await _channel.invokeMethod<String>('loadApiKey') ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _saveApiKeyToPlatform(String apiKey) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('saveApiKey', apiKey);
    } catch (_) {}
  }

  Future<AppSettings> loadSettings() async {
    final raw = await _readJson('settings.json', {});
    final fileSettings = AppSettings.fromJson(raw);
    var platformKey = await _loadApiKeyFromPlatform();
    if (platformKey.trim().isEmpty && fileSettings.apiKey.trim().isNotEmpty) {
      await _saveApiKeyToPlatform(fileSettings.apiKey);
      platformKey = await _loadApiKeyFromPlatform();
    }
    if (raw.containsKey('apiKey')) {
      await _writeJson(
        'settings.json',
        fileSettings.toJson(includeApiKey: false),
      );
    }
    return fileSettings.copyWith(apiKey: platformKey);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _saveApiKeyToPlatform(settings.apiKey);
    await _writeJson('settings.json', settings.toJson(includeApiKey: false));
  }

  Future<void> syncLiveWorker() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('syncLiveWorker');
    } catch (_) {}
  }

  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestNotificationPermission');
    } catch (_) {}
  }

  Future<Map<String, ConversationState>> loadConversations() async {
    return _withConversationLock(() async {
      final Map<String, dynamic> data;
      if (Platform.isAndroid) {
        final payload =
            await _channel.invokeMethod<String>('loadConversations') ??
            '{"items":[]}';
        data = jsonDecode(payload) as Map<String, dynamic>;
      } else {
        data = await _readJson('conversations.json', {'items': []});
      }
      final result = <String, ConversationState>{};
      for (final item in data['items'] as List<dynamic>? ?? []) {
        final conversation = ConversationState.fromJson(
          item as Map<String, dynamic>,
        );
        result[conversation.id] = conversation;
      }
      return result;
    });
  }

  Future<void> saveConversations(Map<String, ConversationState> conversations) {
    return _withConversationLock(() async {
      final Map<String, dynamic> data;
      if (Platform.isAndroid) {
        final payload =
            await _channel.invokeMethod<String>('loadConversations') ??
            '{"items":[]}';
        data = jsonDecode(payload) as Map<String, dynamic>;
      } else {
        data = await _readJson('conversations.json', {'items': []});
      }
      for (final item in data['items'] as List<dynamic>? ?? []) {
        final disk = ConversationState.fromJson(item as Map<String, dynamic>);
        final local = conversations[disk.id];
        if (local == null) {
          conversations[disk.id] = disk;
        } else {
          _mergeConversationForPersistence(local, disk);
        }
      }
      final items = conversations.values.map((c) => c.toJson()).toList();
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>(
          'saveConversations',
          jsonEncode({'items': items}),
        );
      } else {
        await _writeJson('conversations.json', {'items': items});
      }
    });
  }

  Future<Map<String, dynamic>> loadReplyQueue() async {
    if (!Platform.isAndroid) {
      return _readJson('reply_queue.json', {'pending': {}});
    }
    try {
      final payload =
          await _channel.invokeMethod<String>('loadReplyQueue') ??
          '{"pending":{}}';
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return {'pending': <String, dynamic>{}};
    }
  }

  Future<void> saveReplyQueue(Map<String, dynamic> queue) async {
    if (!Platform.isAndroid) {
      await _writeJson('reply_queue.json', queue);
      return;
    }
    await _channel.invokeMethod<void>('saveReplyQueue', jsonEncode(queue));
  }
}

class CharacterRepository {
  Future<List<Character>> load() async {
    final raw = await rootBundle.loadString('assets/data/characters.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return (data['characters'] as List<dynamic>)
        .map((e) => Character.fromJson(e as Map<String, dynamic>))
        .where((character) => !character.id.startsWith('traveler-'))
        .toList();
  }
}

class AvatarCache {
  AvatarCache._();

  static final instance = AvatarCache._();
  static const _channel = MethodChannel('genshin_chat/files');

  final Map<String, Uint8List> _memory = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};

  Future<Uint8List?> load(String url) {
    final cached = _memory[url];
    if (cached != null) {
      return SynchronousFuture(cached);
    }
    return _inFlight.putIfAbsent(url, () async {
      try {
        final file = await _cacheFile(url);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _memory[url] = bytes;
            return bytes;
          }
        }

        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        try {
          final request = await client.getUrl(Uri.parse(url));
          request.headers.set('User-Agent', 'TeyvatChat/1.0');
          final response = await request.close();
          if (response.statusCode >= 400) {
            return null;
          }
          final bytes = await consolidateHttpClientResponseBytes(response);
          if (bytes.isNotEmpty) {
            _memory[url] = bytes;
            await file.writeAsBytes(bytes, flush: true);
            return bytes;
          }
        } finally {
          client.close(force: true);
        }
      } catch (_) {}
      return null;
    })..whenComplete(() => _inFlight.remove(url));
  }

  Future<File> _cacheFile(String url) async {
    final basePath = await _channel.invokeMethod<String>('getFilesDir') ?? '.';
    final dir = Directory('$basePath${Platform.pathSeparator}avatar_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    return File('${dir.path}${Platform.pathSeparator}$fileName.bin');
  }
}
