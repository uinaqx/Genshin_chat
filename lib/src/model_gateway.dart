part of '../main.dart';

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
    final requestedTokens = max(16, maxTokens ?? settings.maxTokens);
    var tokenBudget = _openAiTokenBudget(settings.model, requestedTokens);
    Future<Map<String, dynamic>> request() async {
      final text = await _http.postJson(
        _openAiChatUri(settings.baseUrl),
        {
          'model': settings.model.trim(),
          'messages': messages,
          'temperature': temperature,
          'max_tokens': tokenBudget,
        },
        {'Authorization': 'Bearer ${settings.apiKey.trim()}'},
      );
      return jsonDecode(text) as Map<String, dynamic>;
    }

    var data = await request();
    if (_openAiWasTruncated(data) && tokenBudget < 1024) {
      _checkDailyLimit(settings);
      tokenBudget = min(1024, max(768, tokenBudget * 2));
      data = await request();
    }
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
    if (_openAiWasTruncated(data)) {
      throw Exception('LLM 输出被模型截断，请稍后重试或提高单次 Token 上限。');
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

  int _openAiTokenBudget(String model, int requested) {
    final normalized = model.toLowerCase();
    final usesReasoningTokens =
        normalized.contains('reasoner') ||
        normalized.contains('deepseek-r1') ||
        normalized.contains('deepseek-v4');
    return usesReasoningTokens ? max(requested, 384) : requested;
  }

  bool _openAiWasTruncated(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      return false;
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      return false;
    }
    final reason = first['finish_reason']?.toString().toLowerCase() ?? '';
    return reason == 'length' || reason == 'max_tokens';
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
