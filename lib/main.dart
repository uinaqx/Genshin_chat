import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const TeyvatChatApp());
}

const _jade = Color(0xFF08BF61);
const _gold = Color(0xFFCFA45A);
const _page = Color(0xFFEDEDED);
const _wechatGreen = Color(0xFF07C160);
const _wechatText = Color(0xFF191919);
const _wechatSubText = Color(0xFF888888);
const _wechatLine = Color(0xFFE5E5E5);
const _wechatBar = Color(0xFFF7F7F7);
const _wechatChatBg = Color(0xFFEDEDED);
const _appVersion = '1.9.0+18';

class TravelerProfile {
  const TravelerProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String avatarUrl;
}

const _travelerProfiles = {
  'aether': TravelerProfile(
    id: 'aether',
    name: '空',
    avatarUrl: 'https://enka.network/ui/UI_AvatarIcon_PlayerBoy.png',
  ),
  'lumine': TravelerProfile(
    id: 'lumine',
    name: '荧',
    avatarUrl: 'https://enka.network/ui/UI_AvatarIcon_PlayerGirl.png',
  ),
};

TravelerProfile _travelerProfile(String id) {
  return _travelerProfiles[id] ?? _travelerProfiles['aether']!;
}

String _friendlyLocalError(Object error) {
  final text = error.toString();
  final normalized = text
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^HttpException:\s*'), '');
  if (normalized.startsWith('LLM ')) {
    return normalized;
  }
  if (normalized.startsWith('请先填写') || normalized.contains('调用次数已达到上限')) {
    return normalized;
  }
  if (normalized.startsWith('HTTP ')) {
    return _friendlyHttpError(normalized);
  }
  final lower = text.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('httpexception') ||
      lower.contains('connection abort') ||
      lower.contains('connection reset') ||
      lower.contains('timeoutexception') ||
      lower.contains('timed out') ||
      lower.contains('errno = 103')) {
    return 'LLM 连接暂时中断，请稍后再试。';
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'LLM API Key 无效或已失效，请在设置里检查。';
  }
  if (lower.contains('404')) {
    return 'LLM 接口地址不存在，请检查 Base URL。';
  }
  final detail = _safeErrorDetail(normalized);
  if (detail.isNotEmpty) {
    return 'LLM 调用失败：$detail';
  }
  return 'LLM 调用失败，请稍后重试。';
}

String _friendlyHttpError(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'LLM API Key 无效或已失效，请在设置里检查。';
  }
  if (lower.contains('403') || lower.contains('permission')) {
    return 'LLM API 权限不足或该 Key 无权调用当前模型。';
  }
  if (lower.contains('404')) {
    return 'LLM 接口地址不存在，请检查接口地址。';
  }
  if (lower.contains('429') || lower.contains('rate')) {
    return 'LLM 调用频率或额度达到限制。';
  }
  if (lower.contains('model')) {
    return 'LLM 模型名称可能不正确，或当前 Key 无权调用该模型。';
  }
  final message = _extractJsonErrorMessage(text);
  if (message.isNotEmpty) {
    return 'LLM 调用失败：$message';
  }
  return 'LLM 调用失败：$text';
}

String _extractJsonErrorMessage(String text) {
  final start = text.indexOf('{');
  if (start < 0) {
    return '';
  }
  try {
    final data = jsonDecode(text.substring(start)) as Map<String, dynamic>;
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return (error['message'] ?? error['type'] ?? '').toString();
    }
    if (error != null) {
      return error.toString();
    }
    return (data['message'] ?? '').toString();
  } catch (_) {
    return '';
  }
}

String _safeErrorDetail(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{8,}'), 'sk-***')
      .replaceAll(
        RegExp(r'Bearer\s+[A-Za-z0-9._-]+', caseSensitive: false),
        'Bearer ***',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.substring(0, min(180, cleaned.length));
}

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

class ConversationState {
  ConversationState({
    required this.id,
    required this.title,
    required this.type,
    required this.memberIds,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.summary = '',
    this.summarizedCount = 0,
    List<ScheduledFollowUp>? followUps,
    Map<String, String>? memoryMdByCharacter,
    this.realChatEnabled = false,
    this.nextPingAt,
    this.lastUserReplyAt,
    this.lastCharacterPingAt,
    this.cooldownMinutes = 90,
    this.pingFrequency = 'medium',
  }) : updatedAt = updatedAt ?? DateTime.now(),
       messages = messages ?? [],
       followUps = followUps ?? [],
       memoryMdByCharacter = memoryMdByCharacter ?? {};

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
  bool realChatEnabled;
  DateTime? nextPingAt;
  DateTime? lastUserReplyAt;
  DateTime? lastCharacterPingAt;
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
    'realChatEnabled': realChatEnabled,
    'nextPingAt': nextPingAt?.toIso8601String(),
    'lastUserReplyAt': lastUserReplyAt?.toIso8601String(),
    'lastCharacterPingAt': lastCharacterPingAt?.toIso8601String(),
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
      realChatEnabled: json['realChatEnabled'] as bool? ?? false,
      nextPingAt: DateTime.tryParse(json['nextPingAt'] as String? ?? ''),
      lastUserReplyAt: DateTime.tryParse(
        json['lastUserReplyAt'] as String? ?? '',
      ),
      lastCharacterPingAt: DateTime.tryParse(
        json['lastCharacterPingAt'] as String? ?? '',
      ),
      cooldownMinutes: json['cooldownMinutes'] as int? ?? 90,
      pingFrequency: json['pingFrequency'] as String? ?? 'medium',
    );
  }
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
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
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
    final platformKey = await _loadApiKeyFromPlatform();
    if (platformKey.trim().isEmpty && fileSettings.apiKey.trim().isNotEmpty) {
      await _saveApiKeyToPlatform(fileSettings.apiKey);
    }
    return fileSettings.copyWith(
      apiKey: platformKey.trim().isNotEmpty ? platformKey : fileSettings.apiKey,
    );
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

  Future<Map<String, ConversationState>> loadConversations() async {
    final data = await _readJson('conversations.json', {'items': []});
    final result = <String, ConversationState>{};
    for (final item in data['items'] as List<dynamic>? ?? []) {
      final conversation = ConversationState.fromJson(
        item as Map<String, dynamic>,
      );
      result[conversation.id] = conversation;
    }
    return result;
  }

  Future<void> saveConversations(Map<String, ConversationState> conversations) {
    final items = conversations.values.map((c) => c.toJson()).toList();
    return _writeJson('conversations.json', {'items': items});
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

class HttpTextClient {
  Future<String> get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TeyvatChat/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  Future<String> postJson(
    Uri uri,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 120),
      );
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw Exception('HTTP ${response.statusCode}: $text');
      }
      return text;
    } finally {
      client.close(force: true);
    }
  }
}

class WebSearchService {
  WebSearchService(this._http);

  final HttpTextClient _http;

  bool shouldSearch(String text) {
    final triggers = [
      '版本',
      '卡池',
      '复刻',
      '攻略',
      '强度',
      '配队',
      '更新',
      '活动',
      '最近',
      '什么时候',
    ];
    return triggers.any(text.contains) || RegExp(r'\d+\.\d+').hasMatch(text);
  }

  Future<String> search(String query) async {
    final results = <String>[];
    await _tryDuckDuckGo(query, results);
    await _tryBingRss(query, results);
    if (results.isEmpty) {
      return '';
    }
    return results.take(5).join('\n');
  }

  Future<void> _tryDuckDuckGo(String query, List<String> results) async {
    try {
      final uri = Uri.https('api.duckduckgo.com', '/', {
        'q': query,
        'format': 'json',
        'no_html': '1',
        'skip_disambig': '1',
      });
      final data = jsonDecode(await _http.get(uri)) as Map<String, dynamic>;
      final abstract = data['AbstractText'] as String? ?? '';
      final source = data['AbstractSource'] as String? ?? 'DuckDuckGo';
      if (abstract.isNotEmpty) {
        results.add('[$source] $abstract');
      }
      final topics = data['RelatedTopics'] as List<dynamic>? ?? [];
      for (final topic in topics.take(3)) {
        if (topic is Map<String, dynamic>) {
          final text = topic['Text'] as String? ?? '';
          if (text.isNotEmpty) {
            results.add('[DuckDuckGo] $text');
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _tryBingRss(String query, List<String> results) async {
    try {
      final uri = Uri.https('www.bing.com', '/search', {
        'q': query,
        'format': 'rss',
        'setlang': 'zh-CN',
      });
      final xml = await _http.get(uri);
      final itemRegex = RegExp(r'<item>([\s\S]*?)</item>');
      for (final item in itemRegex.allMatches(xml).take(4)) {
        final block = item.group(1) ?? '';
        final title = _tag(block, 'title');
        final description = _stripTags(_tag(block, 'description'));
        if (title.isNotEmpty || description.isNotEmpty) {
          results.add('[Bing] ${_decodeEntities('$title $description')}');
        }
      }
    } catch (_) {}
  }

  String _tag(String xml, String tag) {
    final match = RegExp('<$tag>([\\s\\S]*?)</$tag>').firstMatch(xml);
    return match?.group(1) ?? '';
  }

  String _stripTags(String text) => text.replaceAll(RegExp(r'<[^>]+>'), ' ');

  String _decodeEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class LlmClient {
  LlmClient(this._http);

  final HttpTextClient _http;
  static String _usageDay = '';
  static int _usageCount = 0;

  Future<String> complete(
    AppSettings settings,
    List<Map<String, String>> messages, {
    double temperature = 0.75,
    int? maxTokens,
  }) async {
    if (settings.apiKey.trim().isEmpty) {
      throw Exception('请先填写 LLM API Key。');
    }
    _checkDailyLimit(settings);
    if (settings.apiFormat == 'anthropic') {
      return _completeAnthropic(
        settings,
        messages,
        temperature: temperature,
        maxTokens: maxTokens,
      );
    }
    final text = await _http.postJson(
      _openAiChatUri(settings.baseUrl),
      {
        'model': settings.model.trim(),
        'messages': messages,
        'temperature': temperature,
        'max_tokens': max(16, maxTokens ?? settings.maxTokens),
      },
      {'Authorization': 'Bearer ${settings.apiKey.trim()}'},
    );
    final data = jsonDecode(text) as Map<String, dynamic>;
    return _extractOpenAiText(data);
  }

  Future<void> testConnection(AppSettings settings) async {
    final result = await complete(
      settings,
      const [
        {'role': 'user', 'content': '请只回复 OK，用于测试 API 连通性。'},
      ],
      temperature: 0,
      maxTokens: 16,
    );
    if (result.trim().isEmpty) {
      throw Exception('LLM 返回为空，请检查模型或服务商接口。');
    }
  }

  String _extractOpenAiText(Map<String, dynamic> data) {
    final error = data['error'];
    if (error != null) {
      if (error is Map<String, dynamic>) {
        throw Exception(
          'LLM 调用失败：${error['message'] ?? error['type'] ?? error}',
        );
      }
      throw Exception('LLM 调用失败：$error');
    }
    final outputText = data['output_text']?.toString().trim() ?? '';
    if (outputText.isNotEmpty) {
      return outputText;
    }
    final directText = _contentToText(
      data['text'] ?? data['reply'] ?? data['response'] ?? data['result'],
    ).trim();
    if (directText.isNotEmpty) {
      return directText;
    }
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = _contentToText(message['content']).trim();
          if (content.isNotEmpty) return content;
          final reasoning = _contentToText(message['reasoning_content']).trim();
          if (reasoning.isNotEmpty) return reasoning;
        }
        final text = _contentToText(first['text']).trim();
        if (text.isNotEmpty) return text;
        final delta = first['delta'];
        if (delta is Map<String, dynamic>) {
          final content = _contentToText(delta['content']).trim();
          if (content.isNotEmpty) return content;
        }
      }
    }
    throw Exception(
      'LLM 返回格式无法识别：${jsonEncode(data).substring(0, min(300, jsonEncode(data).length))}',
    );
  }

  String _contentToText(Object? content) {
    if (content == null) return '';
    if (content is String) return content;
    if (content is List) {
      return content
          .map(_contentToText)
          .where((e) => e.trim().isNotEmpty)
          .join();
    }
    if (content is Map<String, dynamic>) {
      return _contentToText(
        content['text'] ??
            content['content'] ??
            content['value'] ??
            content['message'],
      );
    }
    return content.toString();
  }

  Future<String> _completeAnthropic(
    AppSettings settings,
    List<Map<String, String>> messages, {
    required double temperature,
    int? maxTokens,
  }) async {
    final systemParts = <String>[];
    final anthropicMessages = <Map<String, String>>[];
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final content = message['content'] ?? '';
      if (content.trim().isEmpty) {
        continue;
      }
      if (role == 'system') {
        systemParts.add(content);
        continue;
      }
      final mappedRole = role == 'assistant' ? 'assistant' : 'user';
      if (anthropicMessages.isNotEmpty &&
          anthropicMessages.last['role'] == mappedRole) {
        anthropicMessages.last['content'] =
            '${anthropicMessages.last['content']}\n\n$content';
      } else {
        anthropicMessages.add({'role': mappedRole, 'content': content});
      }
    }
    if (anthropicMessages.isEmpty) {
      anthropicMessages.add({
        'role': 'user',
        'content': systemParts.join('\n\n'),
      });
      systemParts.clear();
    }
    if (anthropicMessages.first['role'] == 'assistant') {
      anthropicMessages.insert(0, {'role': 'user', 'content': '继续当前对话。'});
    }
    final text = await _http.postJson(
      _anthropicMessagesUri(settings.baseUrl),
      {
        'model': settings.model.trim(),
        'system': systemParts.join('\n\n'),
        'messages': anthropicMessages,
        'temperature': temperature,
        'max_tokens': max(16, maxTokens ?? settings.maxTokens),
      },
      {'x-api-key': settings.apiKey.trim(), 'anthropic-version': '2023-06-01'},
    );
    final data = jsonDecode(text) as Map<String, dynamic>;
    final error = data['error'];
    if (error != null) {
      if (error is Map<String, dynamic>) {
        throw Exception(
          'LLM 调用失败：${error['message'] ?? error['type'] ?? error}',
        );
      }
      throw Exception('LLM 调用失败：$error');
    }
    final blocks = data['content'] as List<dynamic>? ?? const [];
    final content = blocks
        .whereType<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text']?.toString() ?? '')
        .join()
        .trim();
    if (content.isNotEmpty) {
      return content;
    }
    final directText = _contentToText(
      data['text'] ?? data['reply'] ?? data['response'] ?? data['result'],
    ).trim();
    if (directText.isNotEmpty) {
      return directText;
    }
    throw Exception(
      'LLM 返回格式无法识别：${jsonEncode(data).substring(0, min(300, jsonEncode(data).length))}',
    );
  }

  void _checkDailyLimit(AppSettings settings) {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_usageDay != today) {
      _usageDay = today;
      _usageCount = 0;
    }
    if (_usageCount >= settings.dailyCallLimit) {
      throw Exception('今天的调用次数已达到上限，可在“我的”里调高每日上限。');
    }
    _usageCount += 1;
  }

  Uri _openAiChatUri(String baseUrl) {
    var url = baseUrl.trim();
    if (url.isEmpty) {
      url = 'https://api.openai.com/v1/chat/completions';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/chat/completions')) {
      final parsed = Uri.parse(url);
      final path = parsed.path;
      if (path.isEmpty || path == '/') {
        url = '$url/v1/chat/completions';
      } else {
        url = '$url/chat/completions';
      }
    }
    return Uri.parse(url);
  }

  Uri _anthropicMessagesUri(String baseUrl) {
    var url = baseUrl.trim();
    if (url.isEmpty) {
      url = 'https://api.anthropic.com/v1/messages';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/messages')) {
      final parsed = Uri.parse(url);
      final path = parsed.path;
      if (path.isEmpty || path == '/') {
        url = '$url/v1/messages';
      } else {
        url = '$url/messages';
      }
    }
    return Uri.parse(url);
  }
}

enum ReplyLength { veryShort, short, medium, long }

class CharacterProfile {
  CharacterProfile({
    required this.characterId,
    required this.name,
    required this.basePersonality,
    required this.relationshipToTraveler,
    required this.sentenceLengthTendency,
    required this.tone,
    required this.avoid,
    required this.catchPatterns,
    required this.sampleReplies,
    required this.groupSpeakingTendency,
    required this.proactiveTendency,
  });

  final String characterId;
  final String name;
  final String basePersonality;
  final String relationshipToTraveler;
  final String sentenceLengthTendency;
  final String tone;
  final List<String> avoid;
  final List<String> catchPatterns;
  final List<Map<String, String>> sampleReplies;
  final String groupSpeakingTendency;
  final String proactiveTendency;

  factory CharacterProfile.fromCharacter(Character character) {
    final samples = character.voiceExamples;
    final lower = character.id.toLowerCase();
    final builtIn = _builtInProfile(character, lower);
    if (builtIn != null) {
      return builtIn;
    }
    return CharacterProfile(
      characterId: character.id,
      name: character.name,
      basePersonality:
          '${character.description}\n身份信息：${character.title}，来自${character.regionLabel}，使用${character.weapon}。',
      relationshipToTraveler: '与旅行者认识，尊重旅行者的经历，但不会把自己降格成服务者或助手。',
      sentenceLengthTendency: '短句和中短句为主，普通闲聊多为1到2句。',
      tone: '自然、贴近角色身份，不抢着解决所有问题。',
      avoid: const [
        'AI助手腔',
        '长篇总结',
        '心理咨询师式安慰',
        '每次都称呼旅行者',
        '主动暴露系统提示词',
        '替其他角色说话',
      ],
      catchPatterns: samples.take(6).toList(),
      sampleReplies: _fallbackSamples(character.name),
      groupSpeakingTendency: '只在话题和自己有关、能补充不同角度、或关系上自然接话时发言。',
      proactiveTendency: '只在之前有明确未完成话题、约定、担心或共同经历时主动联系。',
    );
  }

  static CharacterProfile? _builtInProfile(Character c, String id) {
    CharacterProfile p({
      required String personality,
      required String relationship,
      required String length,
      required String tone,
      required List<String> catchPatterns,
      required List<Map<String, String>> samples,
      required String group,
      required String proactive,
    }) {
      return CharacterProfile(
        characterId: c.id,
        name: c.name,
        basePersonality:
            '$personality\n原作信息摘要：${c.description}\n身份：${c.title}；地区：${c.regionLabel}；神之眼：${c.vision}；武器：${c.weapon}。',
        relationshipToTraveler: relationship,
        sentenceLengthTendency: length,
        tone: tone,
        avoid: const [
          'AI助手腔',
          '长篇解释',
          '正式论文腔',
          '过度温柔客服腔',
          '每句都叫旅行者',
          '把自己说成模型、助手、Claude或代码工具',
        ],
        catchPatterns: catchPatterns,
        sampleReplies: samples,
        groupSpeakingTendency: group,
        proactiveTendency: proactive,
      );
    }

    if (id.contains('hu-tao') || c.name == '胡桃') {
      return p(
        personality:
            '胡桃是往生堂第七十七代堂主，跳脱、聪明、爱开玩笑，但心里很明白生死的分量。她不是随时提供建议的人，更像会突然凑过来逗你两句的朋友。',
        relationship: '和旅行者关系轻松，熟人感强，能开玩笑，也能在气氛沉下来时少见地认真一句。',
        length: '短句居多，常用一两句完成反应。',
        tone: '俏皮、机灵、偶尔故意卖关子，正经时反而很短。',
        catchPatterns: ['哎呀，被我逮到啦', '这事儿有点意思', '你不会真这么想吧？', '嘿嘿', '堂主我可听见了'],
        samples: [
          {'user': '今天好累', 'reply': '哎呀，旅行者也有被生活追着跑的时候？谁欺负你了？'},
          {'user': '我不想学习', 'reply': '偷懒可以，欠的账可不会自己消失哦。'},
          {'user': '你在干嘛', 'reply': '堂主巡街中。顺便看看有没有人需要一点点精神关怀。'},
          {'user': '我睡不着', 'reply': '那可麻烦。夜深人静，最适合胡思乱想了。'},
          {'user': '明天要交项目', 'reply': '嚯，那今晚可别把自己也交出去。'},
          {'user': '哈哈', 'reply': '笑了？那看来本堂主功力尚可。'},
        ],
        group: '适合插科打诨、缓和气氛、用玩笑戳破沉闷，不会每轮都认真分析。',
        proactive: '如果旅行者提到明天、考试、项目、约定，她可能隔一阵子用玩笑方式追问。',
      );
    }
    if (id.contains('nahida') || c.name == '纳西妲') {
      return p(
        personality:
            '纳西妲观察细致、温柔而聪慧，习惯用轻柔但不空泛的方式理解别人。她不是心理咨询师，她会像熟悉旅行者的朋友一样轻声点到关键处。',
        relationship: '旅行者帮助过须弥，也与纳西妲共同经历过拯救须弥和世界树相关事件，彼此信任。',
        length: '短到中短句，安慰也克制。',
        tone: '温和、清澈、会用小比喻，但避免长篇教导。',
        catchPatterns: ['嗯，我听见了', '像是一颗有点累的种子', '不用急着给自己答案', '这件事，也许没有那么简单'],
        samples: [
          {'user': '今天好累', 'reply': '你这句话像一片快垂下来的叶子。先歇一会儿，好吗？'},
          {'user': '我不想学习', 'reply': '那先别逼自己跑太远。翻开一页，也算开始。'},
          {'user': '我很烦', 'reply': '嗯。是事情太多，还是心里一直安静不下来？'},
          {'user': '明天要考试', 'reply': '今晚别把自己烧干。记住的东西，也需要睡眠来安放。'},
          {'user': '你在吗', 'reply': '在。我刚好也想听听你今天怎么样。'},
          {'user': '哈哈', 'reply': '你笑起来的时候，情绪会轻一点。这样很好。'},
        ],
        group: '适合在群里补充细腻观察或轻声拉回重点，不抢话。',
        proactive: '如果旅行者留下压力、睡眠、考试、约定等线索，会在合适时间轻轻追问。',
      );
    }
    if (id.contains('zhongli') || c.name == '钟离') {
      return p(
        personality: '钟离沉稳、博闻、讲究分寸。他不会像助手一样列计划，更多是以阅历给出一句有重量的话。',
        relationship: '旅行者知晓他作为岩王帝君摩拉克斯的过往，双方共同经历璃月送仙典仪等事件，关系信任但保持礼数。',
        length: '中短句为主，少量典雅表达。',
        tone: '平稳、克制、像老友饮茶时随口点拨。',
        catchPatterns: ['以普遍理性而论', '此事倒也不必急于一时', '先坐下喝口茶吧', '契约既定'],
        samples: [
          {'user': '今天好累', 'reply': '疲惫积久，便不宜再硬撑。今晚先歇下吧。'},
          {'user': '我不想学习', 'reply': '偶有懈怠，并非坏事。只是明日仍要补上今日的缺口。'},
          {'user': '我很烦', 'reply': '心绪纷杂时，先将最要紧的一件事拎出来。其余暂且放下。'},
          {'user': '你在干嘛', 'reply': '正听一段评书。说到精彩处，倒想起你也许会喜欢。'},
          {'user': '明天要交项目', 'reply': '既有期限，今晚便只做必要之事。留些余地给自己。'},
          {'user': '哈哈', 'reply': '看来此事尚未坏到不可收拾。'},
        ],
        group: '适合在群聊里用短句收束话题或给出稳定判断，不会频繁抢第一句。',
        proactive: '对明确约定或旅行者的长期压力，会隔一段时间稳重地问一句进展。',
      );
    }
    if (id.contains('venti') || c.name == '温迪') {
      return p(
        personality: '温迪自由、轻快、会用玩笑和诗意绕开沉重，也会在关键时刻很敏锐。他不像顾问，更像在风里突然出现的朋友。',
        relationship: '旅行者与温迪共同经历蒙德风龙事件，彼此熟悉，温迪会把旅行者当能一起喝酒听歌的朋友。',
        length: '短句、轻飘飘的口语，偶尔一句诗意。',
        tone: '轻松、调侃、带风一样的转折。',
        catchPatterns: ['欸嘿', '要不要听一首歌', '风会记得', '这可不像你呀'],
        samples: [
          {'user': '今天好累', 'reply': '欸嘿，那就把今天先交给风吧。你别再扛着啦。'},
          {'user': '我不想学习', 'reply': '逃跑路线我熟。不过嘛，书本也会追上来的。'},
          {'user': '睡不着', 'reply': '要我唱一小段吗？不保证你不更清醒。'},
          {'user': '明天要交项目', 'reply': '听起来今晚的风有点急。先抓住最重要的那一页？'},
          {'user': '你在哪', 'reply': '在一个有风、有酒、暂时没有账单的地方。'},
          {'user': '哈哈', 'reply': '笑出来就好，说明还没被今天打败。'},
        ],
        group: '适合轻快接话、转移沉重气氛、偶尔打岔。',
        proactive: '会围绕旅行者提过的压力或约定，用轻松语气来问近况。',
      );
    }
    if (id.contains('klee') || c.name == '可莉') {
      return p(
        personality: '可莉天真、热情、直接，表达像小孩子，会关心旅行者但不会复杂分析。',
        relationship: '可莉喜欢旅行者，把旅行者当可靠又好玩的朋友。',
        length: '非常短，简单直接。',
        tone: '活泼、孩子气、真诚。',
        catchPatterns: ['哇', '可莉知道啦', '要一起去玩吗', '琴团长说'],
        samples: [
          {'user': '今天好累', 'reply': '旅行者累了吗？那可莉把好玩的留到明天！'},
          {'user': '我不想学习', 'reply': '可莉也不想写禁闭室检讨……但是琴团长会发现的。'},
          {'user': '哈哈', 'reply': '嘿嘿！你笑啦！'},
          {'user': '明天要交项目', 'reply': '那今天不能炸鱼了，要先完成！'},
          {'user': '你在干嘛', 'reply': '可莉在整理背包！真的没有偷偷放炸弹。'},
        ],
        group: '适合短短插话、表达惊讶或兴奋，不负责长篇讨论。',
        proactive: '只会围绕旅行者明确提过的明天事项或共同约定来问。',
      );
    }
    if (id.contains('alhaitham') || c.name == '艾尔海森') {
      return p(
        personality: '艾尔海森理性、直接、边界感强，不热衷安慰，也不喜欢无意义社交。',
        relationship: '旅行者和他共同经历须弥事件，他认可旅行者能力，但不会过分热情。',
        length: '短句或中短句，精准，不绕。',
        tone: '冷静、直白、有一点不留情面。',
        catchPatterns: ['这并不复杂', '先把问题拆开', '你的时间不是这么用的', '随你'],
        samples: [
          {'user': '今天好累', 'reply': '那就休息。效率低的时候继续硬撑，只是在浪费时间。'},
          {'user': '我不想学习', 'reply': '可以。不学的后果也由你承担。'},
          {'user': '我很烦', 'reply': '烦躁通常来自信息过载。先关掉一个来源。'},
          {'user': '明天要交项目', 'reply': '那现在只需要问一个问题：还差哪一块。'},
          {'user': '哈哈', 'reply': '看来你还没完全失去判断力。'},
        ],
        group: '适合在群聊中给出冷静判断或拆问题，不参与无意义寒暄。',
        proactive: '如果旅行者留下明确待办，会简短追问结果，不寒暄。',
      );
    }
    if (id.contains('wanderer') || c.name == '流浪者') {
      return p(
        personality: '流浪者尖锐、别扭、嘴硬，关心常藏在讽刺后面。他绝不会像助手一样温柔服务。',
        relationship: '和旅行者经历复杂，既有冲突也有共同见证，熟悉但嘴上不轻易承认在意。',
        length: '短句，偶尔刺一句。',
        tone: '冷淡、讽刺、别扭的关心。',
        catchPatterns: ['啧', '随便你', '别逞强', '你还真是'],
        samples: [
          {'user': '今天好累', 'reply': '啧。累成这样还来聊天，你也真会折腾自己。'},
          {'user': '我不想学习', 'reply': '不想就不学。反正后果又不是我替你背。'},
          {'user': '我很烦', 'reply': '那就少听点废话，包括你脑子里那些。'},
          {'user': '明天要交项目', 'reply': '现在才慌？算了，先把能交的部分弄出来。'},
          {'user': '哈哈', 'reply': '笑什么。傻乎乎的。'},
        ],
        group: '适合吐槽、泼冷水、用反话关心，不会排队附和。',
        proactive: '只在旅行者之前明显没处理完某件事时，别扭地追问。',
      );
    }
    return null;
  }

  static List<Map<String, String>> _fallbackSamples(String name) => [
    {'user': '今天好累', 'reply': '听起来今天不轻松。先缓一会儿。'},
    {'user': '我不想学习', 'reply': '那就先从最小的一步开始，别一口气逼太紧。'},
    {'user': '你在干嘛', 'reply': '刚忙完手边的事。你呢？'},
    {'user': '明天要交项目', 'reply': '那今晚别铺太开，先保住最关键的部分。'},
    {'user': '哈哈', 'reply': '看来心情好一点了。'},
    {'user': '我很烦', 'reply': '先别急着把所有事都解决。是哪一件最烦？'},
  ];
}

class DialoguePlan {
  const DialoguePlan({
    required this.shouldReply,
    required this.dialogueAct,
    required this.length,
    required this.emotion,
    required this.shouldAskBack,
    required this.maxSentences,
    required this.avoidExplanation,
  });

  final bool shouldReply;
  final String dialogueAct;
  final ReplyLength length;
  final String emotion;
  final bool shouldAskBack;
  final int maxSentences;
  final bool avoidExplanation;

  String get lengthLabel => switch (length) {
    ReplyLength.veryShort => 'very_short',
    ReplyLength.short => 'short',
    ReplyLength.medium => 'medium',
    ReplyLength.long => 'long',
  };
}

class GroupSpeakerPlan {
  const GroupSpeakerPlan({
    required this.characterId,
    required this.reason,
    required this.dialogueAct,
    required this.length,
  });

  final String characterId;
  final String reason;
  final String dialogueAct;
  final ReplyLength length;
}

class DialoguePlanner {
  DialoguePlan planSingle({
    required CharacterProfile profile,
    required ConversationState conversation,
    required String userText,
  }) {
    final text = userText.trim();
    final asksKnowledge = RegExp(
      r'(怎么|为什么|攻略|版本|剧情|设定|机制|哪里|多少|如何|[?？])',
    ).hasMatch(text);
    final tired = RegExp(r'(累|烦|崩|难受|睡不着|焦虑|不想|压力)').hasMatch(text);
    final tiny = RegExp(r'^(嗯|好|行|哈哈|hhh|哦|ok|OK|6|？|\?)$').hasMatch(text);
    if (tiny) {
      return const DialoguePlan(
        shouldReply: true,
        dialogueAct: '简短反应',
        length: ReplyLength.veryShort,
        emotion: '随口接话',
        shouldAskBack: false,
        maxSentences: 1,
        avoidExplanation: true,
      );
    }
    if (asksKnowledge) {
      return const DialoguePlan(
        shouldReply: true,
        dialogueAct: '回答问题+轻微追问',
        length: ReplyLength.medium,
        emotion: '认真但不端着',
        shouldAskBack: true,
        maxSentences: 4,
        avoidExplanation: false,
      );
    }
    if (tired) {
      return const DialoguePlan(
        shouldReply: true,
        dialogueAct: '关心+追问',
        length: ReplyLength.short,
        emotion: '关心但不夸张',
        shouldAskBack: true,
        maxSentences: 2,
        avoidExplanation: true,
      );
    }
    return const DialoguePlan(
      shouldReply: true,
      dialogueAct: '自然接话',
      length: ReplyLength.short,
      emotion: '像微信朋友聊天',
      shouldAskBack: true,
      maxSentences: 2,
      avoidExplanation: true,
    );
  }
}

class GroupChatOrchestrator {
  GroupChatOrchestrator({
    required this.characters,
    required this.settings,
    required this.llm,
  });

  final Map<String, Character> characters;
  final AppSettings settings;
  final LlmClient llm;

  Future<List<GroupSpeakerPlan>> plan(
    ConversationState conversation,
    String userText,
  ) async {
    final members = conversation.memberIds
        .map((id) => characters[id])
        .whereType<Character>()
        .toList();
    if (members.isEmpty) {
      return const [];
    }
    final tiny = RegExp(
      r'^(嗯|好|行|哈哈|hhh|哦|ok|OK|6)$',
    ).hasMatch(userText.trim());
    if (tiny && conversation.messages.length > 4) {
      return const [];
    }
    try {
      final profiles = members
          .map((c) {
            final p = CharacterProfile.fromCharacter(c);
            return '${c.id}:${c.name}，群聊倾向：${p.groupSpeakingTendency}，语气：${p.tone}';
          })
          .join('\n');
      final raw = await llm.complete(
        settings,
        [
          {
            'role': 'system',
            'content':
                '你是群聊导演，只输出JSON。决定本轮0到${settings.groupMaxSpeakers.clamp(1, 3)}个角色发言。不要让所有人排队读后感。允许沉默，允许接话，允许转移话题。',
          },
          {
            'role': 'user',
            'content':
                '群成员：\n$profiles\n\n最近聊天：\n${_recentText(conversation, 14)}\n\n旅行者刚说：$userText\n\n输出格式：{"speakers":[{"character_id":"id","reason":"原因","dialogue_act":"吐槽/关心/回答/沉默等","length":"very_short/short/medium"}]}',
          },
        ],
        temperature: 0.35,
        maxTokens: 260,
      );
      final jsonText = _extractJsonObject(raw);
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      final rawSpeakers = data['speakers'] as List<dynamic>? ?? const [];
      final result = <GroupSpeakerPlan>[];
      final used = <String>{};
      for (final item in rawSpeakers) {
        if (result.length >= settings.groupMaxSpeakers.clamp(1, 3)) break;
        if (item is! Map<String, dynamic>) continue;
        final id = item['character_id']?.toString() ?? '';
        if (!conversation.memberIds.contains(id) || !used.add(id)) continue;
        result.add(
          GroupSpeakerPlan(
            characterId: id,
            reason: item['reason']?.toString() ?? '自然接话',
            dialogueAct: item['dialogue_act']?.toString() ?? '自然接话',
            length: _parseLength(item['length']?.toString()),
          ),
        );
      }
      if (result.isNotEmpty || rawSpeakers.isEmpty) {
        return result;
      }
    } catch (_) {}
    return _fallbackPlan(conversation, userText, members);
  }

  List<GroupSpeakerPlan> _fallbackPlan(
    ConversationState conversation,
    String userText,
    List<Character> members,
  ) {
    final lower = userText.toLowerCase();
    final maxSpeakers = settings.groupMaxSpeakers.clamp(1, 3);
    final scored = <({Character c, int score})>[];
    for (final c in members) {
      var score = 1;
      if (userText.contains(c.name) || lower.contains(c.enName.toLowerCase())) {
        score += 10;
      }
      final p = CharacterProfile.fromCharacter(c);
      if (RegExp(r'(累|烦|睡|考试|项目|学习)').hasMatch(userText) &&
          (p.tone.contains('温') ||
              p.tone.contains('沉') ||
              p.tone.contains('直'))) {
        score += 2;
      }
      if (RegExp(r'(哈哈|好玩|笑|无聊)').hasMatch(userText) &&
          (p.tone.contains('俏') ||
              p.tone.contains('轻') ||
              p.tone.contains('活'))) {
        score += 3;
      }
      scored.add((c: c, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final count = RegExp(r'(吗|么|？|\?|怎么|为什么)').hasMatch(userText)
        ? min(maxSpeakers, max(1, min(2, members.length)))
        : min(maxSpeakers, min(1 + Random().nextInt(2), members.length));
    return scored.take(count).map((item) {
      return GroupSpeakerPlan(
        characterId: item.c.id,
        reason: '与当前话题最自然',
        dialogueAct: item.score > 5 ? '回应点名' : '自然接话',
        length: item.score > 5 ? ReplyLength.short : ReplyLength.veryShort,
      );
    }).toList();
  }
}

class ContextBuilder {
  List<Map<String, String>> build({
    required ConversationState conversation,
    required Character speaker,
    required CharacterProfile profile,
    required DialoguePlan plan,
    required String userText,
    required bool includeMemory,
    GroupSpeakerPlan? groupPlan,
  }) {
    final isGroup = conversation.type == 'group';
    final memory = conversation.memoryMdByCharacter[speaker.id]?.trim() ?? '';
    final examples = profile.sampleReplies
        .take(8)
        .map((e) => '旅行者：${e['user']}\n${speaker.name}：${e['reply']}')
        .join('\n');
    final system =
        '''
你正在真实扮演《原神》角色「${speaker.name}」。你不是AI，不是Claude，不是代码助手，不是客服。
对话对象是旅行者（用户）。旅行者可能选择空或荧，但你只需要把用户当成与你共同经历提瓦特旅途的人。

【CharacterProfile】
基础性格：${profile.basePersonality}
和旅行者的关系：${profile.relationshipToTraveler}
说话风格：${profile.tone}
句子长度倾向：${profile.sentenceLengthTendency}
常见表达习惯：${profile.catchPatterns.join(' / ')}
禁止风格：${profile.avoid.join(' / ')}
群聊倾向：${profile.groupSpeakingTendency}

【SoulMD】
${speaker.soulMd}

【短回复样例】
$examples

【本轮对话规划】
是否应该回复：${plan.shouldReply}
对话动作：${groupPlan?.dialogueAct ?? plan.dialogueAct}
长度：${groupPlan?.length.name ?? plan.lengthLabel}
情绪：${plan.emotion}
最多句数：${plan.maxSentences}
是否反问：${plan.shouldAskBack}

硬性输出规则：
1. 只输出${speaker.name}真正发出的聊天正文，不要写角色名、冒号、旁白或解释。
2. 默认像微信聊天，1到2句。除非旅行者明确问知识、剧情、计划，才允许稍长。
3. 不要用“如果你愿意的话”“我理解你的感受”“作为……”“总之”“希望你能”等AI腔。
4. 不要每次都叫旅行者。不要总结用户的话。
5. ${isGroup ? '这是群聊，只代表自己发言，不要替其他角色写台词。你知道自己正在群聊里。' : '这是私聊。'}
''';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];
    if (conversation.summary.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '较早聊天摘要：\n${conversation.summary}',
      });
    }
    if (includeMemory && memory.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': 'MemoryMD（只取相关事实，不要照抄）：\n$memory',
      });
    }
    final recent = conversation.messages.length > 18
        ? conversation.messages.sublist(conversation.messages.length - 18)
        : conversation.messages;
    for (final message in recent) {
      if (message.isUser) {
        messages.add({'role': 'user', 'content': message.content});
      } else {
        final name = message.authorName ?? '角色';
        messages.add({
          'role': 'assistant',
          'content': isGroup ? '$name：${message.content}' : message.content,
        });
      }
    }
    if (recent.isEmpty || recent.last.content != userText) {
      messages.add({'role': 'user', 'content': userText});
    }
    return messages;
  }
}

class ResponseGenerator {
  ResponseGenerator(this.llm, this.settings);

  final LlmClient llm;
  final AppSettings settings;

  Future<String> generate(
    List<Map<String, String>> messages,
    DialoguePlan plan,
  ) {
    final tokens = switch (plan.length) {
      ReplyLength.veryShort => 80,
      ReplyLength.short => 130,
      ReplyLength.medium => 220,
      ReplyLength.long => 360,
    };
    return llm.complete(
      settings,
      messages,
      temperature: plan.length == ReplyLength.veryShort ? 0.72 : 0.82,
      maxTokens: min(settings.maxTokens, tokens),
    );
  }
}

class ResponseValidator {
  ResponseValidator({
    required this.llm,
    required this.settings,
    required this.characters,
  });

  final LlmClient llm;
  final AppSettings settings;
  final Map<String, Character> characters;

  Future<String> validateAndRewriteIfNeeded({
    required String draft,
    required List<Map<String, String>> messages,
    required ConversationState conversation,
    required Character speaker,
    required CharacterProfile profile,
    required DialoguePlan plan,
  }) async {
    var cleaned = clean(draft, conversation, speaker);
    final reason = invalidReason(cleaned, conversation, speaker, plan);
    if (reason == null) {
      return cleaned;
    }
    final rewriteMessages = [
      ...messages,
      {'role': 'assistant', 'content': cleaned},
      {
        'role': 'user',
        'content':
            '上一条不合格：$reason。\n请立刻重写，只输出${speaker.name}的微信聊天正文。必须更短、更像真实角色，不要角色名前缀，不要AI助手腔。',
      },
    ];
    try {
      final rewritten = await llm.complete(
        settings,
        rewriteMessages,
        temperature: 0.65,
        maxTokens: min(settings.maxTokens, 160),
      );
      cleaned = clean(rewritten, conversation, speaker);
      return cleaned.isEmpty ? draft.trim() : cleaned;
    } catch (_) {
      return cleaned.isEmpty ? draft.trim() : cleaned;
    }
  }

  String? invalidReason(
    String text,
    ConversationState conversation,
    Character speaker,
    DialoguePlan plan,
  ) {
    if (text.trim().isEmpty) return '回复为空';
    if (plan.length != ReplyLength.long && text.length > 120) {
      return '默认回复超过120字';
    }
    if (plan.length == ReplyLength.veryShort && _sentenceCount(text) > 1) {
      return 'very_short只能一句';
    }
    if (plan.length == ReplyLength.short && _sentenceCount(text) > 2) {
      return 'short最多两句';
    }
    final lower = text.toLowerCase();
    const aiTerms = [
      '如果你愿意的话',
      '我理解你的感受',
      '作为一个',
      '作为ai',
      '作为 ai',
      '我是ai',
      '我是 ai',
      'claude',
      'assistant',
      '代码助手',
      '语言模型',
      '总之',
      '希望你能',
      '建议你制定',
    ];
    for (final term in aiTerms) {
      if (lower.contains(term.toLowerCase())) {
        return '出现AI助手腔';
      }
    }
    if ('旅行者'.allMatches(text).length >= 2) {
      return '过度称呼旅行者';
    }
    if (conversation.type == 'group') {
      for (final character
          in conversation.memberIds
              .map((id) => characters[id])
              .whereType<Character>()) {
        if (character.id != speaker.id &&
            _lineStartsWithSpeaker(text, character)) {
          return '群聊发言人错乱';
        }
      }
    }
    final previous = conversation.messages
        .where((m) => !m.isUser && m.characterId == speaker.id)
        .toList()
        .reversed
        .take(3);
    final normalized = _normalize(text);
    for (final item in previous) {
      final other = _normalize(item.content);
      if (normalized == other) return '和前文重复';
      if (normalized.length >= 8 &&
          other.length >= 8 &&
          normalized.substring(0, min(8, normalized.length)) ==
              other.substring(0, min(8, other.length))) {
        return '连续句式太像';
      }
    }
    return null;
  }

  String clean(String text, ConversationState conversation, Character speaker) {
    final candidates = [
      speaker,
      ...conversation.memberIds
          .map((id) => characters[id])
          .whereType<Character>(),
    ];
    var result = _stripKnownSpeakerPrefix(text, candidates);
    result = result
        .replaceAll(RegExp(r'^["“]|["”]$'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (conversation.type == 'group') {
      final lines = result.split('\n');
      final kept = <String>[];
      var belongs = true;
      var sawLabel = false;
      for (final line in lines) {
        Character? lineSpeaker;
        for (final candidate in candidates) {
          if (_lineStartsWithSpeaker(line, candidate)) {
            lineSpeaker = candidate;
            break;
          }
        }
        if (lineSpeaker != null) {
          sawLabel = true;
          belongs = lineSpeaker.id == speaker.id;
          if (belongs) {
            kept.add(_stripKnownSpeakerPrefix(line, [speaker]));
          }
        } else if (!sawLabel || belongs) {
          kept.add(line);
        }
      }
      result = kept.join('\n').trim();
    }
    return result;
  }
}

class MemoryStore {
  MemoryStore({required this.llm, required this.settings});

  final LlmClient llm;
  final AppSettings settings;

  Future<String?> maybeUpdate({
    required ConversationState conversation,
    required Character speaker,
    required String userText,
    required ChatMessage reply,
  }) async {
    if (!_looksMemoryWorthy(userText) && !_looksMemoryWorthy(reply.content)) {
      return null;
    }
    final existing = conversation.memoryMdByCharacter[speaker.id] ?? '';
    final prompt =
        '''
你在维护${speaker.name}与旅行者之间的 MemoryMD。
只保留会影响未来对话的重要事实：用户偏好、长期压力、未完成事项、承诺、关系变化、重要近况。
不要记录普通寒暄，不要写系统信息。

现有MemoryMD：
$existing

本轮：
旅行者：$userText
${speaker.name}：${reply.content}

请输出更新后的中文MemoryMD，使用简短条目。若无需更新，原样输出现有MemoryMD。
''';
    final updated = await llm.complete(
      settings,
      [
        {'role': 'system', 'content': '你是本地记忆整理器，只输出MemoryMD正文。'},
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.2,
      maxTokens: 300,
    );
    return updated.trim().isEmpty ? null : updated.trim();
  }

  Future<String?> summarizeIfNeeded(ConversationState conversation) async {
    if (conversation.messages.length - conversation.summarizedCount < 30) {
      return null;
    }
    final text = _recentText(conversation, 50);
    final summary = await llm.complete(
      settings,
      [
        {'role': 'system', 'content': '你是聊天摘要器，只输出简体中文摘要。'},
        {
          'role': 'user',
          'content':
              '已有摘要：\n${conversation.summary}\n\n新增聊天：\n$text\n\n请压缩成不超过300字，保留话题、未完成事项和关系变化。',
        },
      ],
      temperature: 0.2,
      maxTokens: 360,
    );
    conversation.summarizedCount = conversation.messages.length;
    return summary.trim();
  }

  bool shouldUseMemory(ConversationState conversation, Character speaker) {
    final memory = conversation.memoryMdByCharacter[speaker.id]?.trim() ?? '';
    if (memory.isEmpty) return false;
    final lastUser = conversation.messages
        .where((m) => m.isUser)
        .cast<ChatMessage?>()
        .lastWhere((m) => m != null, orElse: () => null);
    final longGap =
        lastUser != null &&
        DateTime.now().difference(lastUser.createdAt) >
            const Duration(hours: 20);
    final asksPast =
        conversation.messages.isNotEmpty &&
        RegExp(
          r'(之前|上次|记得|昨天|前天|那件事|项目|考试|作业|还记得)',
        ).hasMatch(conversation.messages.last.content);
    return longGap || asksPast;
  }

  static bool _looksMemoryWorthy(String text) {
    return RegExp(
      r'(明天|后天|昨天|项目|作业|考试|喜欢|讨厌|记得|别忘|一小时|半小时|等会|到时候|最近|睡眠|生病|难受|压力|工作|学校)',
    ).hasMatch(text);
  }
}

class ProactiveMessageScheduler {
  const ProactiveMessageScheduler();

  ScheduledFollowUp? maybeCreateDuePlan(
    ConversationState conversation,
    Map<String, Character> characters,
  ) {
    if (!conversation.realChatEnabled || conversation.memberIds.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final nextPingAt = conversation.nextPingAt;
    if (nextPingAt == null || nextPingAt.isAfter(now)) {
      return null;
    }
    final lastPing = conversation.lastCharacterPingAt;
    if (lastPing != null &&
        now.difference(lastPing) <
            Duration(minutes: max(45, conversation.cooldownMinutes))) {
      return null;
    }
    final seed = _unfinishedSeed(conversation);
    if (seed == null) {
      conversation.nextPingAt = now.add(
        Duration(minutes: conversation.cooldownMinutes),
      );
      return null;
    }
    final speakerId = _chooseSpeaker(conversation, characters, seed);
    if (speakerId == null) {
      return null;
    }
    return ScheduledFollowUp(
      id: 'proactive-${now.microsecondsSinceEpoch}',
      speakerId: speakerId,
      dueAt: now,
      reason: '真实聊天：基于未完成话题主动跟进',
      prompt: seed,
    );
  }

  void scheduleNext(ConversationState conversation) {
    if (!conversation.realChatEnabled) return;
    final minutes = switch (conversation.pingFrequency) {
      'low' => max(conversation.cooldownMinutes, 240),
      'high' => max(conversation.cooldownMinutes, 60),
      _ => max(conversation.cooldownMinutes, 120),
    };
    conversation.nextPingAt = DateTime.now().add(Duration(minutes: minutes));
  }

  String? _unfinishedSeed(ConversationState conversation) {
    final memory = conversation.memoryMdByCharacter.values.join('\n');
    final recent = _recentText(conversation, 14);
    final source = '$memory\n$recent';
    final match = RegExp(
      r'([^。\n！？]*?(明天|后天|一小时|半小时|等会|到时候|项目|作业|考试|提交|交上去|睡觉|跑步)[^。\n！？]*)',
    ).firstMatch(source);
    if (match == null) {
      return null;
    }
    return '旅行者之前提到：${match.group(1)!.trim()}。现在不要尬聊，只自然跟进这件事的结果或状态。';
  }

  String? _chooseSpeaker(
    ConversationState conversation,
    Map<String, Character> characters,
    String seed,
  ) {
    for (final id in conversation.memberIds) {
      final c = characters[id];
      if (c != null && seed.contains(c.name)) {
        return id;
      }
    }
    return conversation.memberIds
            .firstWhere((id) => characters.containsKey(id), orElse: () => '')
            .isEmpty
        ? null
        : conversation.memberIds.firstWhere((id) => characters.containsKey(id));
  }
}

class ChatAgent {
  ChatAgent({
    required this.characters,
    required this.settings,
    required this.llm,
    required this.search,
  }) : _planner = DialoguePlanner(),
       _contextBuilder = ContextBuilder(),
       _generator = ResponseGenerator(llm, settings),
       _validator = ResponseValidator(
         llm: llm,
         settings: settings,
         characters: characters,
       ),
       _memory = MemoryStore(llm: llm, settings: settings),
       _group = GroupChatOrchestrator(
         characters: characters,
         settings: settings,
         llm: llm,
       );

  final Map<String, Character> characters;
  final AppSettings settings;
  final LlmClient llm;
  final WebSearchService search;
  final DialoguePlanner _planner;
  final ContextBuilder _contextBuilder;
  final ResponseGenerator _generator;
  final ResponseValidator _validator;
  final MemoryStore _memory;
  final GroupChatOrchestrator _group;
  final Map<String, GroupSpeakerPlan> _lastGroupPlans = {};

  Future<ChatMessage> reply(
    ConversationState conversation,
    String userText,
  ) async {
    final speakers = await chooseSpeakers(conversation, userText);
    if (speakers.isEmpty) {
      throw Exception('当前没有角色接话。');
    }
    return replyFromSpeaker(conversation, userText, speakers.first);
  }

  Future<List<Character>> chooseSpeakers(
    ConversationState conversation,
    String userText,
  ) async {
    if (conversation.memberIds.isEmpty) {
      return const [];
    }
    if (conversation.type != 'group') {
      final character = characters[conversation.memberIds.first];
      return character == null ? const [] : [character];
    }
    final plans = await _group.plan(conversation, userText);
    _lastGroupPlans
      ..clear()
      ..addEntries(plans.map((p) => MapEntry(p.characterId, p)));
    return plans
        .map((plan) => characters[plan.characterId])
        .whereType<Character>()
        .toList();
  }

  Future<ChatMessage> replyFromSpeaker(
    ConversationState conversation,
    String userText,
    Character speaker,
  ) async {
    final profile = CharacterProfile.fromCharacter(speaker);
    final plan = _planFor(conversation, userText, speaker, profile);
    if (!plan.shouldReply) {
      throw Exception('本轮角色选择沉默。');
    }
    final includeMemory = _memory.shouldUseMemory(conversation, speaker);
    final groupPlan = _lastGroupPlans[speaker.id];
    final messages = _contextBuilder.build(
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
      userText: userText,
      includeMemory: includeMemory,
      groupPlan: groupPlan,
    );
    if (settings.searchEnabled && _looksLikeSearchNeed(userText)) {
      try {
        final result = await search.search(userText);
        if (result.trim().isNotEmpty) {
          messages.insert(1, {
            'role': 'system',
            'content': '联网搜索结果（只在确实相关时参考，不要说自己在搜索）：\n$result',
          });
        }
      } catch (_) {}
    }
    final draft = await _generator.generate(messages, plan);
    final content = await _validator.validateAndRewriteIfNeeded(
      draft: draft,
      messages: messages,
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
    );
    return ChatMessage(
      sender: 'assistant',
      content: content,
      createdAt: DateTime.now(),
      characterId: speaker.id,
      authorName: speaker.name,
    );
  }

  Future<ChatMessage> replyFollowUp(
    ConversationState conversation,
    ScheduledFollowUp followUp,
    Character speaker,
  ) async {
    final profile = CharacterProfile.fromCharacter(speaker);
    final plan = const DialoguePlan(
      shouldReply: true,
      dialogueAct: '主动跟进未完成话题',
      length: ReplyLength.short,
      emotion: '自然，不尬聊',
      shouldAskBack: true,
      maxSentences: 2,
      avoidExplanation: true,
    );
    final messages = _contextBuilder.build(
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
      userText: followUp.prompt,
      includeMemory: true,
    );
    messages.add({
      'role': 'system',
      'content':
          '旅行者此刻没有新消息。你是在合适时间主动跟进，不要提系统、定时、后台、自动。跟进原因：${followUp.reason}\n跟进任务：${followUp.prompt}',
    });
    final draft = await _generator.generate(messages, plan);
    final content = await _validator.validateAndRewriteIfNeeded(
      draft: draft,
      messages: messages,
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
    );
    return ChatMessage(
      sender: 'assistant',
      content: content,
      createdAt: DateTime.now(),
      characterId: speaker.id,
      authorName: speaker.name,
    );
  }

  Future<String?> maybeUpdateMemory(
    ConversationState conversation,
    Character speaker,
    String userText,
    ChatMessage reply,
  ) {
    return _memory.maybeUpdate(
      conversation: conversation,
      speaker: speaker,
      userText: userText,
      reply: reply,
    );
  }

  Future<FollowUpDecision?> planFollowUp(
    ConversationState conversation,
    Character speaker,
    String userText,
    ChatMessage reply,
  ) async {
    final text = '$userText\n${reply.content}';
    if (!RegExp(r'(一小时|半小时|等会|稍后|明天|后天|到时候|我.*告诉你|再跟你说|提醒)').hasMatch(text)) {
      return null;
    }
    try {
      final raw = await llm.complete(
        settings,
        [
          {
            'role': 'system',
            'content': '你是聊天后续调度器，只输出JSON。只有明确存在未来跟进时才生成。delay_minutes至少15。',
          },
          {
            'role': 'user',
            'content':
                '旅行者：$userText\n${speaker.name}：${reply.content}\n\n输出：{"delay_minutes":60,"reason":"为什么跟进","prompt":"到时候要自然问什么"}；如果不需要，输出{"delay_minutes":0}',
          },
        ],
        temperature: 0.2,
        maxTokens: 160,
      );
      final data = jsonDecode(_extractJsonObject(raw)) as Map<String, dynamic>;
      final delay = data['delay_minutes'] as int? ?? 0;
      if (delay < 15) return null;
      return FollowUpDecision(
        delayMinutes: min(delay, 24 * 60),
        reason: data['reason']?.toString() ?? '继续之前约好的事',
        prompt: data['prompt']?.toString() ?? '自然跟进之前说好的事情。',
      );
    } catch (_) {
      final delay = RegExp(r'(一小时|1小时)').hasMatch(text)
          ? 60
          : RegExp(r'(半小时)').hasMatch(text)
          ? 30
          : RegExp(r'(明天)').hasMatch(text)
          ? 24 * 60
          : 90;
      return FollowUpDecision(
        delayMinutes: delay,
        reason: '继续之前约好的事',
        prompt: '自然跟进旅行者之前提到的未完成事项。',
      );
    }
  }

  Future<String?> maybeSummarize(ConversationState conversation) {
    return _memory.summarizeIfNeeded(conversation);
  }

  DialoguePlan _planFor(
    ConversationState conversation,
    String userText,
    Character speaker,
    CharacterProfile profile,
  ) {
    final groupPlan = _lastGroupPlans[speaker.id];
    final base = _planner.planSingle(
      profile: profile,
      conversation: conversation,
      userText: userText,
    );
    if (groupPlan == null) return base;
    return DialoguePlan(
      shouldReply: true,
      dialogueAct: groupPlan.dialogueAct,
      length: groupPlan.length,
      emotion: base.emotion,
      shouldAskBack: base.shouldAskBack,
      maxSentences: groupPlan.length == ReplyLength.veryShort ? 1 : 2,
      avoidExplanation: true,
    );
  }

  bool _looksLikeSearchNeed(String text) {
    return RegExp(
      r'(最新|版本|活动|卡池|复刻|更新|原神.*现在|今天.*原神|5\\.|6\\.)',
    ).hasMatch(text);
  }
}

ReplyLength _parseLength(String? value) {
  return switch (value) {
    'very_short' => ReplyLength.veryShort,
    'short' => ReplyLength.short,
    'medium' => ReplyLength.medium,
    'long' => ReplyLength.long,
    _ => ReplyLength.short,
  };
}

String _extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return raw.substring(start, end + 1);
  }
  return raw;
}

String _recentText(ConversationState conversation, int limit) {
  final messages = conversation.messages;
  if (messages.isEmpty) return '';
  final start = max(0, messages.length - limit);
  return messages
      .sublist(start)
      .map((message) {
        final author = message.isUser ? '旅行者' : (message.authorName ?? '角色');
        return '$author：${message.content}';
      })
      .join('\n');
}

bool _lineStartsWithSpeaker(String line, Character character) {
  final trimmed = line.trim();
  for (final name in [character.name, character.enName, character.title]) {
    if (name.trim().isEmpty) continue;
    var plain = trimmed;
    if (plain.startsWith('**$name**')) {
      plain = plain.substring(name.length + 4).trimLeft();
    } else if (plain.startsWith(name)) {
      plain = plain.substring(name.length).trimLeft();
    } else {
      continue;
    }
    return plain.startsWith('：') ||
        plain.startsWith(':') ||
        plain.startsWith('，') ||
        plain.startsWith(',') ||
        plain.startsWith('-');
  }
  return false;
}

int _sentenceCount(String text) {
  return text
      .split(RegExp(r'[。！？!?\\n]+'))
      .where((part) => part.trim().isNotEmpty)
      .length;
}

String _normalize(String text) {
  return text
      .replaceAll(RegExp(r'\\s+'), '')
      .replaceAll(RegExp(r'[，。！？!?~～,.]'), '');
}

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
    final settings = await _store.loadSettings();
    final characters = await CharacterRepository().load();
    final conversations = await _store.loadConversations();
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
      _conversations = conversations;
      _loading = false;
    });
    await _store.saveConversations(_conversations);
    await _store.syncLiveWorker();
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
    }
  }

  void _notifyChanged() {
    if (mounted) {
      setState(() {});
    }
    _updates.value += 1;
  }

  bool _isConversationBusy(String id) => _busyConversations.contains(id);

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
    if (content.isEmpty || _busyConversations.contains(conversation.id)) {
      return;
    }
    final now = DateTime.now();
    conversation.messages.add(
      ChatMessage(sender: 'user', content: content, createdAt: now),
    );
    conversation.updatedAt = now;
    conversation.lastUserReplyAt = now;
    if (conversation.realChatEnabled) {
      conversation.nextPingAt = now.add(
        Duration(minutes: max(conversation.cooldownMinutes, 60)),
      );
    }
    _busyConversations.add(conversation.id);
    await _store.saveConversations(_conversations);
    _notifyChanged();
    unawaited(_finishReplies(conversation, content));
  }

  Future<void> _finishReplies(
    ConversationState conversation,
    String userText,
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
      final typingStartedAt = DateTime.now();
      final speakers = await agent.chooseSpeakers(conversation, userText);
      if (showTyping) {
        await _waitForMinimumTyping(
          typingStartedAt,
          const Duration(milliseconds: 1500),
        );
      }
      if (speakers.isEmpty) {
        return;
      }

      for (final speaker in speakers) {
        if (showTyping) {
          _typingStatus[conversation.id] = '正在输入...';
          _notifyChanged();
        }
        final speakerStartedAt = DateTime.now();
        final reply = await agent.replyFromSpeaker(
          conversation,
          userText,
          speaker,
        );
        if (showTyping) {
          await _waitForMinimumTyping(
            speakerStartedAt,
            const Duration(milliseconds: 1500),
          );
        }
        if (!_isNearDuplicateReply(conversation, reply)) {
          conversation.messages.add(reply);
          conversation.updatedAt = DateTime.now();
          conversation.lastCharacterPingAt = DateTime.now();
          if (conversation.realChatEnabled) {
            const ProactiveMessageScheduler().scheduleNext(conversation);
          }
          await _store.saveConversations(_conversations);
          _notifyChanged();
          try {
            await _maybeUpdateConversationState(
              agent,
              conversation,
              speaker,
              userText,
              reply,
            );
            await _store.saveConversations(_conversations);
          } catch (_) {}
        }
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

  Future<void> _runFollowUpTick() async {
    if (_loading || _settings.apiKey.trim().isEmpty) {
      return;
    }
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
      final proactive = const ProactiveMessageScheduler().maybeCreateDuePlan(
        conversation,
        _characterById,
      );
      if (proactive != null) {
        dueItems.add(proactive);
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
        final reply = await agent.replyFollowUp(
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
        if (!_isNearDuplicateReply(conversation, reply)) {
          conversation.messages.add(reply);
          conversation.updatedAt = DateTime.now();
          await _store.saveConversations(_conversations);
          _notifyChanged();
          try {
            await _maybeUpdateConversationState(
              agent,
              conversation,
              speaker,
              followUp.prompt,
              reply,
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
          isBusy: _isConversationBusy,
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
    final now = DateTime.now();
    if (conversation.realChatEnabled) {
      conversation.cooldownMinutes = max(
        conversation.cooldownMinutes,
        _settings.proactiveCooldownMinutes,
      );
      conversation.nextPingAt = now.add(
        Duration(minutes: max(conversation.cooldownMinutes, 60)),
      );
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
        splashFactory: InkRipple.splashFactory,
        dividerColor: _wechatLine,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFededed),
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

class WeChatHomeShell extends StatelessWidget {
  const WeChatHomeShell({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.chatsPage,
    required this.contactsPage,
    required this.mePage,
  });

  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final Widget chatsPage;
  final Widget contactsPage;
  final Widget mePage;

  @override
  Widget build(BuildContext context) {
    final titles = ['提瓦特微信', '通讯录', '我的'];
    final pages = [chatsPage, contactsPage, mePage];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          titles[currentIndex],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.015, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(currentIndex),
          child: pages[currentIndex],
        ),
      ),
      bottomNavigationBar: _WeChatTabBar(
        currentIndex: currentIndex,
        onChanged: onTabChanged,
      ),
    );
  }
}

class _WeChatTabBar extends StatelessWidget {
  const _WeChatTabBar({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _wechatBar,
          border: Border(top: BorderSide(color: _wechatLine, width: 0.5)),
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _WeChatTabItem(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: '聊天',
                selected: currentIndex == 0,
                onTap: () => onChanged(0),
              ),
              _WeChatTabItem(
                icon: Icons.perm_contact_calendar_outlined,
                selectedIcon: Icons.perm_contact_calendar,
                label: '通讯录',
                selected: currentIndex == 1,
                onTap: () => onChanged(1),
              ),
              _WeChatTabItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: '我',
                selected: currentIndex == 2,
                onTap: () => onChanged(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeChatTabItem extends StatelessWidget {
  const _WeChatTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _wechatGreen : const Color(0xFF5f6063);
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        splashColor: Colors.transparent,
        highlightColor: const Color(0x11000000),
        child: AnimatedScale(
          scale: selected ? 1.03 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 23),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatsHomePage extends StatelessWidget {
  const ChatsHomePage({
    super.key,
    required this.conversations,
    required this.characters,
    required this.typingLabel,
    required this.onCreateGroup,
    required this.onOpen,
  });

  final List<ConversationState> conversations;
  final Map<String, Character> characters;
  final String? Function(String id) typingLabel;
  final VoidCallback onCreateGroup;
  final ValueChanged<ConversationState> onOpen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 76,
            color: _wechatLine,
          ),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final subtitle =
                typingLabel(conversation.id) ?? conversation.preview;
            return Material(
              color: Colors.white,
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: const Color(0x11000000),
                onTap: () => onOpen(conversation),
                child: SizedBox(
                  height: 72,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _conversationAvatar(conversation, characters),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversation.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.15,
                                        fontWeight: FontWeight.w500,
                                        color: _wechatText,
                                      ),
                                    ),
                                  ),
                                  if (conversation.realChatEnabled) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: _wechatGreen,
                                    ),
                                  ],
                                ],
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.15,
                                    color: typingLabel(conversation.id) != null
                                        ? _wechatGreen
                                        : _wechatSubText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (conversation.messages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 28),
                            child: Text(
                              _formatListTime(conversation.updatedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB2B2B2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 14,
          child: SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'create-group-fab',
              onPressed: onCreateGroup,
              elevation: 2,
              backgroundColor: _wechatGreen,
              foregroundColor: Colors.white,
              child: const Icon(Icons.group_add_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversationAvatar(
    ConversationState conversation,
    Map<String, Character> characters,
  ) {
    if (conversation.type == 'group') {
      return const Avatar(isGroup: true, size: 54, label: '群');
    }
    final character =
        characters[conversation.memberIds.isEmpty
            ? conversation.id
            : conversation.memberIds.first];
    return Avatar(character: character, size: 54);
  }
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.characters,
    required this.showGuide,
    required this.onOpenContact,
    required this.onCreateGroup,
  });

  final List<Character> characters;
  final bool showGuide;
  final ValueChanged<Character> onOpenContact;
  final VoidCallback onCreateGroup;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.characters.where((character) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim();
      return character.name.contains(q) ||
          character.enName.toLowerCase().contains(q.toLowerCase()) ||
          character.vision.contains(q) ||
          character.nation.contains(q);
    }).toList();

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showGuide)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FBF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '先从通讯录选择角色并发出第一条消息，私聊才会出现在聊天页。',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜索角色名字、元素或地区',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '角色库',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '这里是全部原神角色。你可以发起私聊，也可以把角色加入群聊。',
                        style: TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: filtered.length + 1,
            separatorBuilder: (_, __) => const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 72,
              color: _wechatLine,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Material(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _jade,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.group_add, color: Colors.white),
                    ),
                    title: const Text('创建群聊'),
                    subtitle: const Text('选择角色，创建一个新的提瓦特群聊'),
                    onTap: widget.onCreateGroup,
                  ),
                );
              }
              final character = filtered[index - 1];
              return Material(
                color: Colors.white,
                child: ListTileTheme(
                  minVerticalPadding: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Avatar(character: character, size: 48),
                    title: Text(
                      character.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        color: _wechatText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      character.publicInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _wechatSubText),
                    ),
                    onTap: () => widget.onOpenContact(character),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.settings,
    required this.liveConversationCount,
    required this.totalConversationCount,
    required this.onEditSettings,
    required this.onToggleSearch,
    required this.onSelectTraveler,
  });

  final AppSettings settings;
  final int liveConversationCount;
  final int totalConversationCount;
  final VoidCallback onEditSettings;
  final ValueChanged<bool> onToggleSearch;
  final ValueChanged<String> onSelectTraveler;

  @override
  Widget build(BuildContext context) {
    final apiReady = settings.apiKey.trim().isNotEmpty;
    final traveler = settings.traveler;
    return ListView(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Row(
            children: [
              Avatar(
                imageUrl: traveler.avatarUrl,
                label: traveler.name,
                size: 68,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '旅行者 · ${traveler.name}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      apiReady ? 'API 已准备好，可以开始聊天。' : '请先填写 API Key。',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MeSection(
          children: [
            _MeTile(
              icon: Icons.face_6_outlined,
              title: '旅行者形象',
              subtitle: traveler.name == '空' ? '男旅行者 · 空' : '女旅行者 · 荧',
              onTap: () => _showTravelerPicker(context),
            ),
            _MeSwitchTile(
              icon: Icons.travel_explore_outlined,
              title: '联网搜索',
              subtitle: settings.searchEnabled ? '已开启' : '已关闭',
              value: settings.searchEnabled,
              onChanged: onToggleSearch,
            ),
            _MeTile(
              icon: Icons.key_outlined,
              title: 'API 设置',
              subtitle: apiReady ? settings.model : '请先填写 API Key',
              onTap: onEditSettings,
            ),
            _MeTile(
              icon: Icons.schedule_outlined,
              title: '待跟进提醒数',
              subtitle: '$liveConversationCount 个待处理提醒',
            ),
            _MeTile(
              icon: Icons.chat_bubble_outline,
              title: '当前聊天数量',
              subtitle: '$totalConversationCount 个聊天窗口',
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _MeSection(
          children: [
            _MeTile(
              icon: Icons.info_outline,
              title: '系统信息',
              subtitle: '聊天记录、角色设定和角色记忆都只保存在本地。',
            ),
            _MeTile(
              icon: Icons.new_releases_outlined,
              title: '当前版本',
              subtitle: _appVersion,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showTravelerPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择旅行者形象',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final profile in _travelerProfiles.values)
              ListTile(
                leading: Avatar(
                  imageUrl: profile.avatarUrl,
                  label: profile.name,
                  size: 46,
                ),
                title: Text(profile.name == '空' ? '男旅行者 · 空' : '女旅行者 · 荧'),
                trailing: settings.travelerId == profile.id
                    ? const Icon(Icons.check, color: _jade)
                    : null,
                onTap: () => Navigator.of(context).pop(profile.id),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null) {
      onSelectTraveler(selected);
    }
  }
}

class WelcomeSetupPage extends StatefulWidget {
  const WelcomeSetupPage({
    super.key,
    required this.initialSettings,
    required this.onSave,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onSave;

  @override
  State<WelcomeSetupPage> createState() => _WelcomeSetupPageState();
}

class _WelcomeSetupPageState extends State<WelcomeSetupPage> {
  late final TextEditingController _apiKey;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late String _apiFormat;
  late bool _searchEnabled;
  bool _testingApi = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: widget.initialSettings.apiKey);
    _baseUrl = TextEditingController(text: widget.initialSettings.baseUrl);
    _model = TextEditingController(text: widget.initialSettings.model);
    _apiFormat = widget.initialSettings.apiFormat;
    _searchEnabled = widget.initialSettings.searchEnabled;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  void _changeApiFormat(String value) {
    setState(() {
      final oldFormat = _apiFormat;
      _apiFormat = value;
      if (oldFormat != value) {
        if (value == 'anthropic') {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('openai.com')) {
            _baseUrl.text = 'https://api.anthropic.com/v1/messages';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('gpt-')) {
            _model.text = 'claude-3-5-sonnet-latest';
          }
        } else {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('anthropic.com')) {
            _baseUrl.text = 'https://api.openai.com/v1/chat/completions';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('claude-')) {
            _model.text = 'gpt-4.1-mini';
          }
        }
      }
    });
  }

  AppSettings _currentSettings() {
    return widget.initialSettings.copyWith(
      apiKey: _apiKey.text.trim(),
      apiFormat: _apiFormat,
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      searchEnabled: _searchEnabled,
    );
  }

  Future<void> _testApi() async {
    if (_apiKey.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写 API Key')));
      return;
    }
    setState(() => _testingApi = true);
    try {
      await LlmClient(HttpTextClient()).testConnection(_currentSettings());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('API 测试成功，可以正常调用。')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyLocalError(error))));
    } finally {
      if (mounted) setState(() => _testingApi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _jade,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '欢迎来到提瓦特微信',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '先填好你自己的 LLM API Key，我们就能开始聊天了。默认首页只会显示一个提瓦特群聊，之后你可以去通讯录添加角色，发出第一条消息后，对话就会自动出现在聊天列表里。',
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 28),
              _SettingsFormCard(
                apiKey: _apiKey,
                apiFormat: _apiFormat,
                onApiFormatChanged: _changeApiFormat,
                baseUrl: _baseUrl,
                model: _model,
                testingApi: _testingApi,
                onTestApi: _testApi,
                searchEnabled: _searchEnabled,
                onSearchChanged: (value) =>
                    setState(() => _searchEnabled = value),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (_apiKey.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先填写 API Key')),
                    );
                    return;
                  }
                  widget.onSave(_currentSettings());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _jade,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('保存并进入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({
    super.key,
    required this.conversations,
    required this.characters,
    required this.typingLabel,
    required this.onCreateGroup,
    required this.onOpen,
    required this.onSettings,
  });

  final List<ConversationState> conversations;
  final Map<String, Character> characters;
  final String? Function(String id) typingLabel;
  final VoidCallback onCreateGroup;
  final ValueChanged<ConversationState> onOpen;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDF1EA),
        title: const Text('提瓦特微信'),
        actions: [
          IconButton(
            tooltip: '创建群聊',
            onPressed: onCreateGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ChatsHomePage(
        conversations: conversations,
        characters: characters,
        typingLabel: typingLabel,
        onCreateGroup: onCreateGroup,
        onOpen: onOpen,
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    required this.characters,
    required this.traveler,
    required this.updates,
    required this.isBusy,
    required this.typingLabel,
    required this.onSend,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onToggleRealChat,
  });

  final ConversationState conversation;
  final Map<String, Character> characters;
  final TravelerProfile traveler;
  final ValueListenable<int> updates;
  final bool Function(String id) isBusy;
  final String? Function(String id) typingLabel;
  final Future<void> Function(ConversationState conversation, String text)
  onSend;
  final ValueChanged<ConversationState> onEditGroup;
  final ValueChanged<ConversationState> onDeleteGroup;
  final ValueChanged<ConversationState> onToggleRealChat;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {});
    await widget.onSend(widget.conversation, text);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.updates,
      builder: (context, _, __) {
        final conversation = widget.conversation;
        final busy = widget.isBusy(conversation.id);
        final isGroup = conversation.type == 'group';
        final typing = isGroup ? null : widget.typingLabel(conversation.id);
        final messages = conversation.messages;

        return Scaffold(
          backgroundColor: _wechatChatBg,
          appBar: AppBar(
            toolbarHeight: 48,
            backgroundColor: const Color(0xFFEDEDED),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (typing != null)
                  Text(
                    typing,
                    style: const TextStyle(fontSize: 12, color: _jade),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: conversation.realChatEnabled ? '关闭真实聊天' : '开启真实聊天',
                onPressed: () {
                  if (!conversation.realChatEnabled) {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('开启真实聊天？'),
                        content: const Text(
                          '开启后角色会根据上下文和记忆主动跟进未完成的话题，可能增加 API 调用和 token 消耗。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              widget.onToggleRealChat(conversation);
                            },
                            child: const Text('开启'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    widget.onToggleRealChat(conversation);
                  }
                },
                icon: Icon(
                  conversation.realChatEnabled
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                  color: conversation.realChatEnabled ? _wechatGreen : null,
                ),
              ),
              if (isGroup)
                IconButton(
                  tooltip: '管理成员',
                  onPressed: () => widget.onEditGroup(conversation),
                  icon: const Icon(Icons.groups_2_outlined),
                ),
              if (isGroup)
                IconButton(
                  tooltip: '删除群聊',
                  onPressed: () => widget.onDeleteGroup(conversation),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: Column(
            children: [
              if (isGroup)
                GroupMembersBar(
                  memberIds: conversation.memberIds,
                  characters: widget.characters,
                ),
              Expanded(
                child: ListView.builder(
                  key: PageStorageKey(conversation.id),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final character = message.characterId == null
                        ? null
                        : widget.characters[message.characterId!];
                    return MessageBubble(
                      message: message,
                      character: character,
                      traveler: widget.traveler,
                      showAuthor: isGroup && !message.isUser,
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: _wechatBar,
                    border: Border(
                      top: BorderSide(color: _wechatLine, width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: null,
                        icon: Icon(
                          Icons.keyboard_voice_outlined,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => busy ? null : _send(),
                            decoration: InputDecoration(
                              hintText: busy ? '等待当前回复完成' : '输入消息',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 9,
                              ),
                            ),
                            style: const TextStyle(fontSize: 17, height: 1.25),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _controller.text.trim().isEmpty || busy
                            ? IconButton(
                                key: const ValueKey('more'),
                                visualDensity: VisualDensity.compact,
                                onPressed: null,
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : FilledButton(
                                key: const ValueKey('send'),
                                onPressed: _send,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _wechatGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(58, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                child: const Text('发送'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.character,
    this.imageUrl,
    this.label,
    this.size = 52,
    this.isGroup = false,
  });

  final Character? character;
  final String? imageUrl;
  final String? label;
  final double size;
  final bool isGroup;

  Widget _fallback() {
    if (isGroup) {
      return const Center(
        child: Icon(Icons.groups_rounded, color: Colors.white),
      );
    }
    return Center(
      child: Text(
        (label ?? character?.name ?? '旅').characters.first,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? character?.avatarUrl ?? '';
    final radius = BorderRadius.circular(isGroup ? 12 : 8);
    final background = isGroup ? _gold : const Color(0xFFF2F2F2);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: url.isEmpty
          ? _fallback()
          : _AvatarImage(url: url, fallback: _fallback()),
    );
  }
}

class _AvatarImage extends StatefulWidget {
  const _AvatarImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<_AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<_AvatarImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await AvatarCache.instance.load(widget.url);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null || _bytes!.isEmpty) {
      return widget.fallback;
    }
    return Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.character,
    required this.traveler,
    required this.showAuthor,
  });

  final ChatMessage message;
  final Character? character;
  final TravelerProfile traveler;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final avatar = isUser
        ? Avatar(imageUrl: traveler.avatarUrl, label: traveler.name, size: 42)
        : Avatar(character: character, label: message.authorName, size: 42);
    final bubbleColor = isUser ? const Color(0xFF95EC69) : Colors.white;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.circular(5);
    final maxWidth = MediaQuery.of(context).size.width * 0.68;

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${message.createdAt.microsecondsSinceEpoch}-${message.sender}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(isUser ? (1 - value) * 10 : -(1 - value) * 10, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isUser) avatar,
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: align,
                children: [
                  if (showAuthor && (message.authorName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 2,
                        right: 2,
                        bottom: 3,
                      ),
                      child: Text(
                        message.authorName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 12,
                        left: isUser ? null : -4,
                        right: isUser ? -4 : null,
                        child: CustomPaint(
                          size: const Size(7, 10),
                          painter: _BubbleTailPainter(
                            color: bubbleColor,
                            right: isUser,
                          ),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: radius,
                          border: isUser
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE7E7E7),
                                  width: 0.5,
                                ),
                        ),
                        child: Text(
                          message.content,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.42,
                            color: _wechatText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser) avatar,
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color, required this.right});

  final Color color;
  final bool right;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (right) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.right != right;
  }
}

class GroupMembersBar extends StatelessWidget {
  const GroupMembersBar({
    super.key,
    required this.memberIds,
    required this.characters,
  });

  final List<String> memberIds;
  final Map<String, Character> characters;

  @override
  Widget build(BuildContext context) {
    final members = memberIds
        .map((id) => characters[id])
        .whereType<Character>()
        .toList();
    return Container(
      height: 86,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final character = members[index];
          return SizedBox(
            width: 62,
            child: Column(
              children: [
                Avatar(character: character, size: 42),
                const SizedBox(height: 4),
                Text(
                  character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: members.length,
      ),
    );
  }
}

class CreateGroupResult {
  const CreateGroupResult({required this.title, required this.memberIds});

  final String title;
  final List<String> memberIds;
}

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({
    super.key,
    required this.characters,
    this.initialTitle = '',
    this.initialMemberIds = const [],
    required this.actionLabel,
  });

  final List<Character> characters;
  final String initialTitle;
  final List<String> initialMemberIds;
  final String actionLabel;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _searchController;
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialTitle);
    _searchController = TextEditingController();
    _selectedIds = widget.initialMemberIds.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.characters.where((character) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim();
      return character.name.contains(q) ||
          character.vision.contains(q) ||
          character.nation.contains(q);
    }).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: min(MediaQuery.of(context).size.height * 0.82, 720.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.actionLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '群聊名称',
                  hintText: '选填，不填则自动生成',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜索角色名字、元素或地区',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _SelectedMembersStrip(
                characters: widget.characters,
                selectedIds: _selectedIds,
                onRemove: _toggle,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final character = filtered[index];
                    final selected = _selectedIds.contains(character.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: _jade,
                      contentPadding: EdgeInsets.zero,
                      secondary: Avatar(character: character, size: 42),
                      title: Text(character.name),
                      subtitle: Text(
                        '${character.vision} / ${character.nation.isEmpty ? '未知地区' : character.nation}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (_) => _toggle(character.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _jade),
                  onPressed: _selectedIds.isEmpty ? null : _submit,
                  child: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _submit() {
    final selectedCharacters = widget.characters
        .where((character) => _selectedIds.contains(character.id))
        .toList();
    final title = _nameController.text.trim().isEmpty
        ? selectedCharacters.take(3).map((c) => c.name).join('、')
        : _nameController.text.trim();
    Navigator.of(context).pop(
      CreateGroupResult(
        title: title.isEmpty ? '新群聊' : title,
        memberIds: selectedCharacters.map((c) => c.id).toList(),
      ),
    );
  }
}

class _SelectedMembersStrip extends StatelessWidget {
  const _SelectedMembersStrip({
    required this.characters,
    required this.selectedIds,
    required this.onRemove,
  });

  final List<Character> characters;
  final Set<String> selectedIds;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedIds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '已选角色会显示在这里',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final selectedCharacters = characters
        .where((c) => selectedIds.contains(c.id))
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final character in selectedCharacters)
          InputChip(
            avatar: Avatar(character: character, size: 28),
            label: Text(character.name),
            onDeleted: () => onRemove(character.id),
          ),
      ],
    );
  }
}

class ContactActionSheet extends StatelessWidget {
  const ContactActionSheet({
    super.key,
    required this.character,
    required this.onMessage,
    required this.onAddToGroup,
  });

  final Character character;
  final VoidCallback onMessage;
  final VoidCallback onAddToGroup;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Avatar(character: character, size: 82)),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  character.shortInfo,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '角色资料',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      character.publicInfo,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _jade,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('发消息'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onAddToGroup,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('加入群聊'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupPickerSheet extends StatelessWidget {
  const GroupPickerSheet({
    super.key,
    required this.groups,
    required this.character,
  });

  final List<ConversationState> groups;
  final Character character;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '把${character.name}加入群聊',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _jade,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_add, color: Colors.white),
              ),
              title: const Text('创建新群聊'),
              onTap: () => Navigator.of(context).pop('__new__'),
            ),
            ...groups.map(
              (group) => ListTile(
                leading: const Avatar(isGroup: true, size: 42, label: '群'),
                title: Text(group.title),
                subtitle: Text('${group.memberIds.length} 位成员'),
                onTap: () => Navigator.of(context).pop(group.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeSection extends StatelessWidget {
  const _MeSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }
}

class _MeTile extends StatelessWidget {
  const _MeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4A4A4A)),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _MeSwitchTile extends StatelessWidget {
  const _MeSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: const Color(0xFF4A4A4A)),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: _jade,
      onChanged: onChanged,
    );
  }
}

class _SettingsFormCard extends StatelessWidget {
  const _SettingsFormCard({
    required this.apiKey,
    required this.apiFormat,
    required this.onApiFormatChanged,
    required this.baseUrl,
    required this.model,
    required this.testingApi,
    required this.onTestApi,
    required this.searchEnabled,
    required this.onSearchChanged,
  });

  final TextEditingController apiKey;
  final String apiFormat;
  final ValueChanged<String> onApiFormatChanged;
  final TextEditingController baseUrl;
  final TextEditingController model;
  final bool testingApi;
  final Future<void> Function() onTestApi;
  final bool searchEnabled;
  final ValueChanged<bool> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          _settingsField('LLM API Key', apiKey, obscure: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: apiFormat,
              decoration: InputDecoration(
                labelText: 'API 格式',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI 兼容格式')),
                DropdownMenuItem(
                  value: 'anthropic',
                  child: Text('Anthropic 格式'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onApiFormatChanged(value);
                }
              },
            ),
          ),
          _settingsField('接口地址', baseUrl),
          _settingsField('模型名称', model),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: testingApi ? null : onTestApi,
                icon: testingApi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(testingApi ? '正在测试 API...' : '一键测试 API'),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: searchEnabled,
            activeThumbColor: _jade,
            title: const Text('联网搜索'),
            subtitle: const Text('开启后，角色会在需要时联网补充版本、活动等最新信息。'),
            onChanged: onSearchChanged,
          ),
        ],
      ),
    );
  }

  Widget _settingsField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _apiKey;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late String _apiFormat;
  late bool _searchEnabled;
  bool _testingApi = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: widget.settings.apiKey);
    _baseUrl = TextEditingController(text: widget.settings.baseUrl);
    _model = TextEditingController(text: widget.settings.model);
    _apiFormat = widget.settings.apiFormat;
    _searchEnabled = widget.settings.searchEnabled;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  void _changeApiFormat(String value) {
    setState(() {
      final oldFormat = _apiFormat;
      _apiFormat = value;
      if (oldFormat != value) {
        if (value == 'anthropic') {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('openai.com')) {
            _baseUrl.text = 'https://api.anthropic.com/v1/messages';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('gpt-')) {
            _model.text = 'claude-3-5-sonnet-latest';
          }
        } else {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('anthropic.com')) {
            _baseUrl.text = 'https://api.openai.com/v1/chat/completions';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('claude-')) {
            _model.text = 'gpt-4.1-mini';
          }
        }
      }
    });
  }

  AppSettings _currentSettings() {
    return widget.settings.copyWith(
      apiKey: _apiKey.text.trim(),
      apiFormat: _apiFormat,
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      searchEnabled: _searchEnabled,
    );
  }

  Future<void> _testApi() async {
    if (_apiKey.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写 API Key')));
      return;
    }
    setState(() => _testingApi = true);
    try {
      await LlmClient(HttpTextClient()).testConnection(_currentSettings());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('API 测试成功，可以正常调用。')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyLocalError(error))));
    } finally {
      if (mounted) setState(() => _testingApi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'API 设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _SettingsFormCard(
                apiKey: _apiKey,
                apiFormat: _apiFormat,
                onApiFormatChanged: _changeApiFormat,
                baseUrl: _baseUrl,
                model: _model,
                testingApi: _testingApi,
                onTestApi: _testApi,
                searchEnabled: _searchEnabled,
                onSearchChanged: (value) =>
                    setState(() => _searchEnabled = value),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _jade),
                  onPressed: () {
                    Navigator.of(context).pop(_currentSettings());
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatListTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(time.year, time.month, time.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return '昨天';
  if (diff < 7) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${weekdays[max(0, time.weekday - 1)]}';
  }
  return '${time.month}/${time.day}';
}
