import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'hive_service.dart';
import 'app_log_service.dart';

/// Cloud API service supporting native and OpenAI-compatible providers.
class CloudService extends GetxService {
  final HiveService _hive = Get.find<HiveService>();

  String get _provider =>
      _hive.getSetting(AppConstants.keyCloudProvider, defaultValue: 'openrouter') ??
      'openrouter';

  String get _apiKey {
    switch (_provider) {
      case 'anthropic':
        return _hive.getSetting(AppConstants.keyAnthropicKey) ?? '';
      case 'google':
        return _hive.getSetting(AppConstants.keyGoogleKey) ?? '';
      case 'kimi':
        return _hive.getSetting(AppConstants.keyKimiKey) ?? '';
      case 'stability':
        return _hive.getSetting(AppConstants.keyStabilityKey) ?? '';
      case 'nvidia':
        return _hive.getSetting(AppConstants.keyNvidiaKey) ?? '';
      case 'openrouter':
        return _hive.getSetting(AppConstants.keyOpenRouterKey) ?? '';
      case 'deepseek':
        return _hive.getSetting(AppConstants.keyDeepSeekKey) ?? '';
      case 'custom':
        return _hive.getSetting(AppConstants.keyCustomCloudKey) ?? '';
      default:
        return _hive.getSetting(AppConstants.keyOpenaiKey) ?? '';
    }
  }

  String get _model {
    switch (_provider) {
      case 'anthropic':
        return _hive.getSetting(AppConstants.keyAnthropicModel) ??
            'claude-sonnet-4-6';
      case 'google':
        return _hive.getSetting(AppConstants.keyGoogleModel) ??
            'gemini-2.5-flash';
      case 'kimi':
        return _hive.getSetting(AppConstants.keyKimiModel) ?? 'kimi-k2.6';
      case 'stability':
        final m = _hive.getSetting(AppConstants.keyStabilityModel) ??
            'sd3.5-large-turbo';
        return (m == 'sd3.5-flash' || m.isEmpty) ? 'sd3.5-large-turbo' : m;
      case 'nvidia':
        return _hive.getSetting(AppConstants.keyNvidiaModel) ??
            'meta/llama-3.1-8b-instruct';
      case 'openrouter':
        return _hive.getSetting(AppConstants.keyOpenRouterModel) ??
            'openai/gpt-4o-mini';
      case 'deepseek':
        return _hive.getSetting(AppConstants.keyDeepSeekModel) ??
            'deepseek-v4-flash';
      case 'custom':
        return _hive.getSetting(AppConstants.keyCustomCloudModel) ?? '';
      default:
        return _hive.getSetting(AppConstants.keyOpenaiModel) ?? 'gpt-5.2';
    }
  }

  int get _defaultMaxTokensForCloud {
    switch (_provider) {
      case 'anthropic':
        return 8192;
      case 'google':
        return 8192;
      case 'deepseek':
        return 8192;
      case 'openrouter':
        return 8192;
      case 'nvidia':
        return 8192;
      case 'kimi':
        return 8192;
      case 'openai':
        return 8192;
      default:
        return 4096;
    }
  }

  bool get isConfigured {
    if (_provider == 'custom') {
      final baseUrl =
          _hive.getSetting(AppConstants.keyCustomCloudBaseUrl) ?? '';
      return _apiKey.isNotEmpty && _model.isNotEmpty && baseUrl.isNotEmpty;
    }
    return _apiKey.isNotEmpty;
  }

  /// Send a message to the cloud API. Returns the response text.
  /// [messages] is a list of {role, content} maps forming the conversation.
  /// [imageBase64] is optional for multimodal requests.
  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
    void Function(String token)? onToken,
  }) async {
    if (!isConfigured) {
      return 'ERROR: No API key configured for $_provider. Go to Settings.';
    }

    try {
      if (onToken != null) {
        if (_provider == 'google') {
          return await _streamGoogle(
            messages: messages,
            imageBase64: imageBase64,
            temperature: temperature,
            maxTokens: maxTokens,
            onToken: onToken,
          );
        }
        if (_provider == 'anthropic') {
          return await _streamAnthropic(
            messages: messages,
            imageBase64: imageBase64,
            temperature: temperature,
            maxTokens: maxTokens,
            onToken: onToken,
          );
        }
        if (_supportsStreaming) {
          return await _streamOpenAICompatible(
            endpoint: _openAICompatibleEndpoint,
            providerLabel: _providerLabel,
            messages: messages,
            imageBase64: imageBase64,
            temperature: temperature,
            maxTokens: maxTokens,
            extraHeaders: _openAICompatibleExtraHeaders,
            onToken: onToken,
          );
        }
      }

      switch (_provider) {
        case 'anthropic':
          return await _sendAnthropic(
              messages, imageBase64, temperature, maxTokens);
        case 'google':
          return await _sendGoogle(
              messages, imageBase64, temperature, maxTokens);
        case 'kimi':
          return await _sendKimi(messages, imageBase64, temperature, maxTokens);
        case 'stability':
          return await _sendStability(messages);
        case 'nvidia':
          return await _sendNvidia(
              messages, imageBase64, temperature, maxTokens);
        case 'openrouter':
          return await _sendOpenRouter(
              messages, imageBase64, temperature, maxTokens);
        case 'deepseek':
          return await _sendDeepSeek(
              messages, imageBase64, temperature, maxTokens);
        case 'custom':
          return await _sendCustomOpenAICompatible(
              messages, imageBase64, temperature, maxTokens);
        default:
          return await _sendOpenAI(
              messages, imageBase64, temperature, maxTokens);
      }
    } catch (e) {
      Get.find<AppLogService>().error('Cloud API request failed', details: e);
      return 'ERROR: Cloud API request failed — $e';
    }
  }

  bool get _supportsStreaming =>
      _provider == 'openai' ||
      _provider == 'nvidia' ||
      _provider == 'openrouter' ||
      _provider == 'deepseek' ||
      _provider == 'custom' ||
      _provider == 'kimi' ||
      _provider == 'google' ||
      _provider == 'anthropic';

  String get _openAICompatibleEndpoint {
    switch (_provider) {
      case 'nvidia':
        return '${AppConstants.nvidiaEndpoint}/chat/completions';
      case 'openrouter':
        return '${AppConstants.openRouterEndpoint}/chat/completions';
      case 'deepseek':
        return '${AppConstants.deepSeekEndpoint}/chat/completions';
      case 'custom':
        final baseUrl =
            (_hive.getSetting(AppConstants.keyCustomCloudBaseUrl) ?? '')
                .toString()
                .replaceAll(RegExp(r'/+$'), '');
        return '$baseUrl/chat/completions';
      case 'kimi':
        return AppConstants.kimiEndpoint;
      default:
        return AppConstants.openaiEndpoint;
    }
  }

  String get _providerLabel {
    switch (_provider) {
      case 'nvidia':
        return 'NVIDIA NIM';
      case 'openrouter':
        return 'OpenRouter';
      case 'deepseek':
        return 'DeepSeek';
      case 'custom':
        return _hive.getSetting(AppConstants.keyCustomCloudName) ??
            'Custom API';
      case 'kimi':
        return 'Kimi';
      default:
        return 'OpenAI';
    }
  }

  Map<String, String> get _openAICompatibleExtraHeaders {
    if (_provider == 'openrouter') {
      return const {
        'HTTP-Referer': 'https://ai-chat.local',
        'X-Title': 'AI Chat',
      };
    }
    return const {};
  }

  // ─── OpenAI ─────────────────────────────────────

  Future<String> _sendOpenAI(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    if (_model.toLowerCase().contains('dall-e')) {
      return await _sendOpenAIImage(messages);
    }

    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg['role'] == 'user' &&
          imageBase64 != null &&
          msg == messages.last) {
        apiMessages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': msg['content']},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}
            },
          ],
        });
      } else {
        apiMessages.add({'role': msg['role'], 'content': msg['content']});
      }
    }

    final response = await http.post(
      Uri.parse(AppConstants.openaiEndpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': apiMessages,
        'temperature': temperature ?? AppConstants.defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
      }),
    );

    if (response.statusCode != 200) {
      return 'ERROR: OpenAI returned ${response.statusCode} — ${response.body}';
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  }

  // ─── Anthropic ──────────────────────────────────

  Future<String> _sendAnthropic(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    // Extract system message
    String? systemMsg;
    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg['role'] == 'system') {
        systemMsg = msg['content'];
        continue;
      }

      if (msg['role'] == 'user' &&
          imageBase64 != null &&
          msg == messages.last) {
        apiMessages.add({
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': imageBase64,
              }
            },
            {'type': 'text', 'text': msg['content']},
          ],
        });
      } else {
        apiMessages.add({
          'role': msg['role'],
          'content': msg['content'],
        });
      }
    }

    final body = <String, dynamic>{
      'model': _model,
      'messages': apiMessages,
      'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
      'temperature': temperature ?? AppConstants.defaultTemperature,
    };
    if (systemMsg != null) body['system'] = systemMsg;

    final response = await http.post(
      Uri.parse(AppConstants.anthropicEndpoint),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      return 'ERROR: Anthropic returned ${response.statusCode} — ${response.body}';
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List;
    return content.isNotEmpty ? content[0]['text'] ?? '' : '';
  }

  Future<String> _streamAnthropic({
    required List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
    required void Function(String token) onToken,
  }) async {
    String? systemMsg;
    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg['role'] == 'system') {
        systemMsg = msg['content'];
        continue;
      }

      if (msg['role'] == 'user' &&
          imageBase64 != null &&
          msg == messages.last) {
        apiMessages.add({
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': imageBase64,
              }
            },
            {'type': 'text', 'text': msg['content']},
          ],
        });
      } else {
        apiMessages.add({
          'role': msg['role'],
          'content': msg['content'],
        });
      }
    }

    final body = <String, dynamic>{
      'model': _model,
      'messages': apiMessages,
      'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
      'temperature': temperature ?? AppConstants.defaultTemperature,
      'stream': true,
    };
    if (systemMsg != null) body['system'] = systemMsg;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);
    try {
      final request = await client.postUrl(Uri.parse(AppConstants.anthropicEndpoint));
      request.headers.set('x-api-key', _apiKey);
      request.headers.set('anthropic-version', '2023-06-01');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      request.write(jsonEncode(body));

      final response = await request.close();
      if (response.statusCode != 200) {
        final errBody = await response.transform(utf8.decoder).join();
        return 'ERROR: Anthropic returned ${response.statusCode} — $errBody';
      }

      final fullText = StringBuffer();
      String remainder = '';
      bool inReasoning = false;

      await for (final chunk in response.transform(utf8.decoder)) {
        final text = remainder + chunk;
        final lines = text.split('\n');
        remainder = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          try {
            final data = jsonDecode(jsonStr);
            if (data['type'] == 'content_block_delta') {
              final delta = data['delta'];
              if (delta != null) {
                if (delta['type'] == 'thinking_delta') {
                  final t = delta['thinking'] as String?;
                  if (t != null && t.isNotEmpty) {
                    if (!inReasoning) {
                      inReasoning = true;
                      fullText.write('<think>\n');
                      onToken('<think>\n');
                    }
                    fullText.write(t);
                    onToken(t);
                  }
                } else if (delta['type'] == 'text_delta') {
                  if (inReasoning) {
                    inReasoning = false;
                    fullText.write('\n</think>\n\n');
                    onToken('\n</think>\n\n');
                  }
                  final t = delta['text'] as String?;
                  if (t != null && t.isNotEmpty) {
                    fullText.write(t);
                    onToken(t);
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      if (inReasoning) {
        inReasoning = false;
        fullText.write('\n</think>\n\n');
        onToken('\n</think>\n\n');
      }

      return fullText.toString();
    } finally {
      client.close(force: true);
    }
  }

  // ─── Google Gemini ──────────────────────────────

  Map<String, dynamic> _buildGooglePayload({
    required List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  }) {
    String? systemInstruction;
    final contents = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'];
      final content = msg['content']?.trim() ?? '';
      if (content.isEmpty) continue;

      if (role == 'system') {
        systemInstruction = systemInstruction == null
            ? content
            : '$systemInstruction\n\n$content';
        continue;
      }

      final geminiRole = role == 'assistant' ? 'model' : 'user';
      final parts = <Map<String, dynamic>>[
        {'text': content}
      ];

      if (imageBase64 != null && msg == messages.last && geminiRole == 'user') {
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': imageBase64,
          }
        });
      }

      // Merge consecutive turns of same role to avoid Gemini 400 Alternation error
      if (contents.isNotEmpty && contents.last['role'] == geminiRole) {
        final existingParts =
            contents.last['parts'] as List<Map<String, dynamic>>;
        existingParts.addAll(parts);
      } else {
        contents.add({'role': geminiRole, 'parts': parts});
      }
    }

    if (contents.isNotEmpty && contents.first['role'] == 'model') {
      contents.insert(0, {
        'role': 'user',
        'parts': [
          {'text': 'Hello'}
        ]
      });
    }

    final payload = <String, dynamic>{
      'contents': contents.isEmpty
          ? [
              {
                'role': 'user',
                'parts': [
                  {'text': 'Hi'}
                ]
              }
            ]
          : contents,
      'generationConfig': {
        'temperature': temperature ?? AppConstants.defaultTemperature,
        'maxOutputTokens': maxTokens ?? _defaultMaxTokensForCloud,
      },
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      payload['system_instruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    return payload;
  }

  Future<String> _sendGoogle(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    final payload = _buildGooglePayload(
      messages: messages,
      imageBase64: imageBase64,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    final cleanModel =
        _model.startsWith('models/') ? _model.substring(7) : _model;
    final url =
        '${AppConstants.googleEndpoint}/$cleanModel:generateContent?key=$_apiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      return 'ERROR: Google returned ${response.statusCode} — ${response.body}';
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final contentParts = candidates[0]['content']['parts'] as List;
      final buffer = StringBuffer();
      for (final p in contentParts) {
        final isThought = p['thought'] == true;
        final t = p['text'] as String? ?? '';
        if (isThought) {
          buffer.write('<think>\n$t\n</think>\n\n');
        } else {
          buffer.write(t);
        }
      }
      return buffer.toString();
    }
    return '';
  }

  Future<String> _streamGoogle({
    required List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
    required void Function(String token) onToken,
  }) async {
    final payload = _buildGooglePayload(
      messages: messages,
      imageBase64: imageBase64,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    final cleanModel =
        _model.startsWith('models/') ? _model.substring(7) : _model;
    final url =
        '${AppConstants.googleEndpoint}/$cleanModel:streamGenerateContent?alt=sse&key=$_apiKey';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 35);
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode != 200) {
        final errBody = await response.transform(utf8.decoder).join();
        return _formatApiError(errBody, 'Google Gemini', response.statusCode);
      }

      final fullText = StringBuffer();
      String remainder = '';
      bool inReasoning = false;

      await for (final chunk in response.transform(utf8.decoder)) {
        final text = remainder + chunk;
        final lines = text.split('\n');
        remainder = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          try {
            final data = jsonDecode(jsonStr);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final contentParts = candidates[0]['content']?['parts'] as List?;
              if (contentParts != null) {
                for (final part in contentParts) {
                  final isThought = part['thought'] == true;
                  final t = part['text'] as String?;
                  if (t != null && t.isNotEmpty) {
                    if (isThought) {
                      if (!inReasoning) {
                        inReasoning = true;
                        fullText.write('<think>\n');
                        onToken('<think>\n');
                      }
                      fullText.write(t);
                      onToken(t);
                    } else {
                      if (inReasoning) {
                        inReasoning = false;
                        fullText.write('\n</think>\n\n');
                        onToken('\n</think>\n\n');
                      }
                      fullText.write(t);
                      onToken(t);
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      if (inReasoning) {
        inReasoning = false;
        fullText.write('\n</think>\n\n');
        onToken('\n</think>\n\n');
      }

      return fullText.toString();
    } finally {
      client.close(force: true);
    }
  }

  // ─── Kimi (Moonshot AI — OpenAI-compatible) ─────

  Future<String> _sendKimi(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      apiMessages.add({'role': msg['role'], 'content': msg['content']});
    }

    final response = await http.post(
      Uri.parse(AppConstants.kimiEndpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': apiMessages,
        'temperature': temperature ?? AppConstants.defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
      }),
    );

    if (response.statusCode != 200) {
      return 'ERROR: Kimi returned ${response.statusCode} — ${response.body}';
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  }

  Future<String> _sendNvidia(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg['role'] == 'user' &&
          imageBase64 != null &&
          msg == messages.last) {
        apiMessages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': msg['content']},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}
            },
          ],
        });
      } else {
        apiMessages.add({'role': msg['role'], 'content': msg['content']});
      }
    }

    final response = await http.post(
      Uri.parse('${AppConstants.nvidiaEndpoint}/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': apiMessages,
        'temperature': temperature ?? AppConstants.defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
      }),
    );

    if (response.statusCode != 200) {
      return 'ERROR: NVIDIA NIM returned ${response.statusCode} — ${response.body}';
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  }

  Future<String> _sendOpenRouter(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    return _sendOpenAICompatible(
      endpoint: '${AppConstants.openRouterEndpoint}/chat/completions',
      providerLabel: 'OpenRouter',
      messages: messages,
      imageBase64: imageBase64,
      temperature: temperature,
      maxTokens: maxTokens,
      extraHeaders: const {
        'HTTP-Referer': 'https://ai-chat.local',
        'X-Title': 'AI Chat',
      },
    );
  }

  Future<String> _sendDeepSeek(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    return _sendOpenAICompatible(
      endpoint: '${AppConstants.deepSeekEndpoint}/chat/completions',
      providerLabel: 'DeepSeek',
      messages: messages,
      imageBase64: imageBase64,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  Future<String> _sendCustomOpenAICompatible(
    List<Map<String, String>> messages,
    String? imageBase64,
    double? temperature,
    int? maxTokens,
  ) async {
    final baseUrl = (_hive.getSetting(AppConstants.keyCustomCloudBaseUrl) ?? '')
        .toString()
        .replaceAll(RegExp(r'/+$'), '');
    return _sendOpenAICompatible(
      endpoint: '$baseUrl/chat/completions',
      providerLabel:
          _hive.getSetting(AppConstants.keyCustomCloudName) ?? 'Custom API',
      messages: messages,
      imageBase64: imageBase64,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  Future<String> _sendOpenAICompatible({
    required String endpoint,
    required String providerLabel,
    required List<Map<String, String>> messages,
    required String? imageBase64,
    required double? temperature,
    required int? maxTokens,
    Map<String, String> extraHeaders = const {},
  }) async {
    final apiMessages = <Map<String, dynamic>>[];

    apiMessages.addAll(_buildOpenAICompatibleMessages(messages, imageBase64));

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        ...extraHeaders,
      },
      body: jsonEncode({
        'model': _model,
        'messages': apiMessages,
        'temperature': temperature ?? AppConstants.defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
      }),
    );

    if (response.statusCode != 200) {
      return 'ERROR: $providerLabel returned ${response.statusCode} — ${response.body}';
    }

    final data = jsonDecode(response.body);
    final choice = (data['choices'] as List?)?.isNotEmpty == true
        ? data['choices'][0] as Map
        : null;
    final message = choice?['message'] as Map?;
    final reasoning = message?['reasoning_content']?.toString() ??
        message?['thought']?.toString();
    final content = message?['content']?.toString() ?? '';
    if (reasoning != null && reasoning.isNotEmpty) {
      return '<think>\n$reasoning\n</think>\n\n$content';
    }
    return content;
  }

  Future<String> _streamOpenAICompatible({
    required String endpoint,
    required String providerLabel,
    required List<Map<String, String>> messages,
    required String? imageBase64,
    required double? temperature,
    required int? maxTokens,
    required void Function(String token) onToken,
    Map<String, String> extraHeaders = const {},
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      extraHeaders.forEach((k, v) => request.headers.set(k, v));

      request.write(jsonEncode({
        'model': _model,
        'messages': _buildOpenAICompatibleMessages(messages, imageBase64),
        'temperature': temperature ?? AppConstants.defaultTemperature,
        'max_tokens': maxTokens ?? _defaultMaxTokensForCloud,
        'stream': true,
      }));

      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        return _formatApiError(body, providerLabel, response.statusCode);
      }

      final buffer = StringBuffer();
      String remainder = '';
      bool inReasoning = false;

      await for (final chunk in response.transform(utf8.decoder)) {
        final text = remainder + chunk;
        final lines = text.split('\n');
        remainder = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;

          final payload = trimmed.substring(5).trim();
          if (payload == '[DONE]') break;

          try {
            final data = jsonDecode(payload);
            final choice = (data['choices'] as List?)?.isNotEmpty == true
                ? data['choices'][0] as Map
                : null;
            final delta = choice?['delta'] as Map?;
            final reasoning = delta?['reasoning_content']?.toString() ??
                delta?['thought']?.toString();
            if (reasoning != null && reasoning.isNotEmpty) {
              if (!inReasoning) {
                inReasoning = true;
                buffer.write('<think>\n');
                onToken('<think>\n');
              }
              buffer.write(reasoning);
              onToken(reasoning);
            }
            final token = delta?['content']?.toString();
            if (token != null && token.isNotEmpty) {
              if (inReasoning) {
                inReasoning = false;
                buffer.write('\n</think>\n\n');
                onToken('\n</think>\n\n');
              }
              buffer.write(token);
              onToken(token);
            }
          } catch (_) {
            // Ignore malformed keep-alive chunks and continue reading.
          }
        }
      }

      if (inReasoning) {
        inReasoning = false;
        buffer.write('\n</think>\n\n');
        onToken('\n</think>\n\n');
      }

      return buffer.toString();
    } finally {
      client.close(force: true);
    }
  }

  List<Map<String, dynamic>> _buildOpenAICompatibleMessages(
    List<Map<String, String>> messages,
    String? imageBase64,
  ) {
    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg['role'] == 'user' &&
          imageBase64 != null &&
          msg == messages.last) {
        apiMessages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': msg['content']},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}
            },
          ],
        });
      } else {
        apiMessages.add({'role': msg['role'], 'content': msg['content']});
      }
    }

    return apiMessages;
  }

  // ─── OpenAI DALL-E (Image Generation) ───────────

  Future<String> _sendOpenAIImage(
    List<Map<String, String>> messages,
  ) async {
    if (_apiKey.trim().isEmpty) {
      return 'ERROR: OpenAI API key is missing. Please enter your API key in Settings → Cloud API.';
    }

    final userMessages = messages.where((m) => m['role'] == 'user').toList();
    if (userMessages.isEmpty) {
      return 'ERROR: No prompt found for image generation.';
    }

    final prompt = userMessages.last['content']?.trim() ?? '';
    if (prompt.isEmpty) {
      return 'ERROR: Image prompt cannot be empty.';
    }

    final modelName = _model.toLowerCase().contains('dall-e-2') ? 'dall-e-2' : 'dall-e-3';

    try {
      final url = Uri.parse('https://api.openai.com/v1/images/generations');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${_apiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelName,
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
          'response_format': 'b64_json',
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        try {
          final errJson = jsonDecode(response.body);
          final msg = errJson['error']?['message'] ?? response.body;
          return 'ERROR: OpenAI ($msg)';
        } catch (_) {
          return 'ERROR: OpenAI returned ${response.statusCode} — ${response.body}';
        }
      }

      final data = jsonDecode(response.body);
      final b64 = data['data']?[0]?['b64_json'];
      if (b64 != null && b64.toString().isNotEmpty) {
        return '[IMAGE_BASE64]$b64';
      }
      return 'ERROR: No image data returned by OpenAI.';
    } catch (e) {
      return 'ERROR: OpenAI image request failed — $e';
    }
  }

  // ─── Stability AI (Image Generation) ────────────

  Future<String> _sendStability(
    List<Map<String, String>> messages,
  ) async {
    if (_apiKey.trim().isEmpty) {
      return 'ERROR: Stability AI API key is missing. Please enter your API key in Settings → Cloud API.';
    }

    // Extract the latest user prompt for the image generation
    final userMessages = messages.where((m) => m['role'] == 'user').toList();
    if (userMessages.isEmpty) {
      return 'ERROR: No user prompt found for image generation.';
    }

    final prompt = userMessages.last['content']?.trim() ?? '';
    if (prompt.isEmpty) {
      return 'ERROR: Image prompt cannot be empty.';
    }

    // Determine correct endpoint and model name
    String modelName = _model.trim();
    if (modelName.isEmpty || modelName == 'sd3.5-flash') {
      modelName = 'sd3.5-large-turbo';
    }

    String endpointUrl = AppConstants.stabilityEndpoint;
    if (modelName == 'core') {
      endpointUrl = 'https://api.stability.ai/v2beta/stable-image/generate/core';
    } else if (modelName == 'ultra') {
      endpointUrl = 'https://api.stability.ai/v2beta/stable-image/generate/ultra';
    } else {
      endpointUrl = 'https://api.stability.ai/v2beta/stable-image/generate/sd3';
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(endpointUrl));
      request.headers.addAll({
        'Authorization': 'Bearer ${_apiKey.trim()}',
        'Accept': 'application/json',
      });

      request.fields['prompt'] = prompt;
      if (endpointUrl.endsWith('/sd3')) {
        request.fields['model'] = modelName;
      }
      request.fields['output_format'] = 'jpeg';
      request.fields['aspect_ratio'] = '1:1';

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        try {
          final errJson = jsonDecode(responseBody);
          final errors =
              errJson['errors'] ?? errJson['message'] ?? responseBody;
          return 'ERROR: Stability AI ($errors)';
        } catch (_) {
          return 'ERROR: Stability AI returned ${streamedResponse.statusCode} — $responseBody';
        }
      }

      final data = jsonDecode(responseBody);
      final base64Image = data['image'];
      if (base64Image != null && base64Image.toString().isNotEmpty) {
        return '[IMAGE_BASE64]$base64Image';
      }

      return 'ERROR: No image data returned by Stability AI.';
    } catch (e) {
      return 'ERROR: Stability AI request failed — $e';
    }
  }

  String _formatApiError(String rawBody, String provider, int statusCode) {
    try {
      final parsed = jsonDecode(rawBody);
      if (parsed is Map) {
        if (parsed['error'] is Map) {
          final msg = parsed['error']['message']?.toString();
          if (msg != null && msg.isNotEmpty) {
            return '$provider Error ($statusCode): $msg';
          }
        } else if (parsed['error'] is String) {
          return '$provider Error ($statusCode): ${parsed['error']}';
        } else if (parsed['message'] != null) {
          return '$provider Error ($statusCode): ${parsed['message']}';
        }
      }
    } catch (_) {}

    if (statusCode == 401 || statusCode == 403) {
      return 'Authentication Failed ($statusCode): Invalid or missing API key for $provider. Please verify your key in Settings.';
    } else if (statusCode == 429) {
      return 'Rate Limit / Quota Exceeded ($statusCode): Free tier limit reached for $provider. Please wait a moment.';
    } else if (statusCode == 404) {
      return 'Model Not Found ($statusCode): The selected model is unavailable for $provider.';
    }
    return '$provider Error ($statusCode): $rawBody';
  }
}
