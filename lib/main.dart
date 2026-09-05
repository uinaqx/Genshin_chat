import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'src/data_layer.dart';
part 'src/model_gateway.dart';
part 'src/chat_engine.dart';
part 'src/app_controller.dart';
part 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _appVersion =
        await const MethodChannel(
          'genshin_chat/files',
        ).invokeMethod<String>('getAppVersion') ??
        _appVersion;
  } on PlatformException {
    // The build version remains available even if the Android channel is not.
  }
  runApp(const TeyvatChatApp());
}

const _jade = Color(0xFF08BF61);
const _gold = Color(0xFFCFA45A);
const _page = Color(0xFFF3F5F7);
const _wechatGreen = Color(0xFF07C160);
const _wechatText = Color(0xFF191919);
const _wechatSubText = Color(0xFF888888);
const _wechatLine = Color(0x1F5B6470);
const _wechatBar = Color(0xE8FFFFFF);
const _wechatChatBg = Color(0xFFF1F4F6);
const int recentContextMessageLimit = 100;
String _appVersion = '3.0.0+30';

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
    avatarUrl: 'asset://assets/images/traveler-aether.png',
  ),
  'lumine': TravelerProfile(
    id: 'lumine',
    name: '荧',
    avatarUrl: 'asset://assets/images/traveler-lumine.png',
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

Future<void> _showApiTestDialog(
  BuildContext context, {
  required bool success,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        success ? Icons.check_circle_outline : Icons.error_outline,
        color: success ? _wechatGreen : Colors.red.shade600,
        size: 34,
      ),
      title: Text(success ? 'API 测试成功' : 'API 测试失败'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
