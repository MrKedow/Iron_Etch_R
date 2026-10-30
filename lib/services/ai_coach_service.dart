import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../providers/app_providers.dart';

class AiCoachReply {
  final bool success;
  final String content;
  final String? error;
  final int? statusCode;
  final String? channel;

  const AiCoachReply({
    required this.success,
    required this.content,
    this.error,
    this.statusCode,
    this.channel,
  });

  factory AiCoachReply.failure(String message, {int? statusCode}) {
    return AiCoachReply(
      success: false,
      content: '',
      error: message,
      statusCode: statusCode,
    );
  }
}

class _AiTarget {
  final String endpoint;
  final String model;
  final String label;

  const _AiTarget({
    required this.endpoint,
    required this.model,
    required this.label,
  });
}

class AiCoachService {
  static const String pollinationsEndpoint =
      'https://text.pollinations.ai/openai';
  static const String pollinationsCompatEndpoint =
      'https://text.pollinations.ai/openai/chat/completions';
  static const String pollinationsV1Endpoint =
      'https://text.pollinations.ai/openai/v1/chat/completions';
  static const String blockRunEndpoint =
      'https://blockrun.ai/api/v1/chat/completions';
  static const String openCodeEndpoint =
      'https://opencode.ai/inference/openai/v1/chat/completions';

  static Future<AiCoachReply> chat({
    required List<Map<String, String>> messages,
    String? endpoint,
    String? model,
    String? apiKey,
  }) async {
    final configured = (endpoint == null || endpoint.trim().isEmpty)
        ? SettingsProvider.defaultAiEndpoint
        : endpoint.trim();
    final primaryUri = Uri.tryParse(configured);
    if (primaryUri == null || !primaryUri.hasScheme) {
      return AiCoachReply.failure('AI 接口地址无效，请在设置中检查。');
    }

    final key = apiKey?.trim() ?? '';
    final configuredModel = (model == null || model.trim().isEmpty)
        ? SettingsProvider.defaultAiModel
        : model.trim();
    final targets = <_AiTarget>[
      _AiTarget(
        endpoint: configured,
        model: configuredModel,
        label: _labelFor(configured),
      ),
    ];

    if (key.isEmpty) {
      for (final fallback in const [
        _AiTarget(
          endpoint: blockRunEndpoint,
          model: 'nvidia/gpt-oss-20b',
          label: 'BlockRun',
        ),
        _AiTarget(
          endpoint: pollinationsEndpoint,
          model: 'gpt-oss-20b',
          label: 'Pollinations',
        ),
        _AiTarget(
          endpoint: pollinationsCompatEndpoint,
          model: 'gpt-oss-20b',
          label: 'Pollinations',
        ),
        _AiTarget(
          endpoint: pollinationsV1Endpoint,
          model: 'gpt-oss-20b',
          label: 'Pollinations',
        ),
        _AiTarget(
          endpoint: openCodeEndpoint,
          model: 'big-pickle',
          label: 'OpenCode Zen',
        ),
      ]) {
        if (targets.any((target) => target.endpoint == fallback.endpoint)) {
          continue;
        }
        targets.add(fallback);
      }
    }

    final errors = <String>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final reply = await _attempt(
        target,
        messages,
        apiKey: key,
        timeout: Duration(seconds: i == 0 ? 35 : 25),
      );
      if (reply.success) return reply;
      errors.add('${target.label}：${reply.error ?? '未知错误'}');

      // 自定义 Key 只发送给用户配置的主通道，绝不外泄到公共回退通道。
      if (key.isNotEmpty) break;
    }

    if (errors.length > 1) {
      return AiCoachReply.failure('所有 AI 通道均不可用。${errors.join('；')}');
    }
    return AiCoachReply.failure(errors.isEmpty ? 'AI 服务不可用。' : errors.first);
  }

  static Future<AiCoachReply> testConnection({
    String? endpoint,
    String? model,
    String? apiKey,
  }) {
    return chat(
      endpoint: endpoint,
      model: model,
      apiKey: apiKey,
      messages: [
        {
          'role': 'system',
          'content': '你是铁镌健身应用的健康助手。只回复一句不超过20字的中文问候。',
        },
        {
          'role': 'user',
          'content': '请回复：连接成功。',
        },
      ],
    );
  }

  static Future<AiCoachReply> _attempt(
    _AiTarget target,
    List<Map<String, String>> messages, {
    required String apiKey,
    required Duration timeout,
  }) async {
    final uri = Uri.tryParse(target.endpoint);
    if (uri == null || !uri.hasScheme) {
      return AiCoachReply.failure('接口地址无效');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final body = jsonEncode({
      'model': target.model,
      'messages': messages,
      'temperature': .65,
      'max_tokens': 1800,
      'stream': false,
      if (target.endpoint.contains('blockrun') ||
          target.model.contains('gpt-oss'))
        'reasoning_effort': 'low',
    });

    final client = http.Client();
    try {
      final response =
          await client.post(uri, headers: headers, body: body).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final content = _extractContent(decoded);
        if (content.trim().isEmpty) {
          return AiCoachReply.failure(
            '返回了空内容',
            statusCode: response.statusCode,
          );
        }
        return AiCoachReply(
          success: true,
          content: _cleanContent(content),
          statusCode: response.statusCode,
          channel: target.label,
        );
      }

      final detail = _extractError(response.body);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiCoachReply.failure(
          apiKey.isEmpty ? '免费通道要求鉴权' : '鉴权失败，请检查 API Key',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        return AiCoachReply.failure(
          '请求过多（429）',
          statusCode: response.statusCode,
        );
      }
      return AiCoachReply.failure(
        'HTTP ${response.statusCode}${detail.isEmpty ? '' : '：$detail'}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return AiCoachReply.failure('响应超时');
    } catch (e) {
      final text = _friendlyError(e);
      return AiCoachReply.failure(
        text.contains('网络') ? text : '无法连接：$text',
      );
    } finally {
      client.close();
    }
  }

  static String _labelFor(String endpoint) {
    final lower = endpoint.toLowerCase();
    if (lower.contains('blockrun')) return 'BlockRun';
    if (lower.contains('pollinations')) return 'Pollinations';
    if (lower.contains('opencode')) return 'OpenCode Zen';
    return '自定义 AI';
  }

  static String _extractContent(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String) return content;
            if (content is List) {
              return content.map((part) {
                if (part is Map && part['text'] is String) {
                  return part['text'] as String;
                }
                return '';
              }).join();
            }
          }
          final text = first['text'];
          if (text is String) return text;
        }
      }
      final output = decoded['output_text'];
      if (output is String) return output;
    }
    if (decoded is String) return decoded;
    return '';
  }

  static String _cleanContent(String input) {
    var text = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '  ');
    text = text.replaceAll(
      RegExp(r'```(?:think|thinking)[\s\S]*?```', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<think(?:ing)?[\s\S]*?</think(?:ing)?>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<\|[^>]*\|>'), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String _extractError(String body) {
    if (body.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return _short(error['message'].toString());
        }
        if (decoded['message'] != null) {
          return _short(decoded['message'].toString());
        }
      }
    } catch (_) {
      // ignore
    }
    return _short(body);
  }

  static String _short(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length > 120
        ? '${normalized.substring(0, 120)}…'
        : normalized;
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection')) {
      return '网络不可用或被拦截';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
