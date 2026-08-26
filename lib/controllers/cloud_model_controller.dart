import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../services/app_log_service.dart';
import '../services/hive_service.dart';
import 'settings_controller.dart';

class CloudProviderInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool requiresKeyForList;
  final bool supportsFetch;

  const CloudProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.requiresKeyForList = true,
    this.supportsFetch = true,
  });
}

class CloudModelController extends GetxController {
  final HiveService _hive = Get.find<HiveService>();
  final SettingsController _settings = Get.find<SettingsController>();

  static const _cachePrefix = 'cloud_model_cache_';
  static const _cacheTimePrefix = 'cloud_model_cache_time_';
  static const _defaultModelsByProvider = <String, List<String>>{
    'google': [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.0-flash',
      'gemini-2.0-flash-thinking-exp',
      'imagen-3.0-generate-002',
      'imagen-3.0-fast-generate-001',
    ],
    'openai': [
      'gpt-4.5-preview',
      'gpt-4o',
      'gpt-4o-mini',
      'o1',
      'o3-mini',
      'dall-e-3',
    ],
    'anthropic': [
      'claude-3-7-sonnet-latest',
      'claude-3-5-sonnet-latest',
      'claude-3-5-haiku-latest',
    ],
    'deepseek': [
      'deepseek-chat',
      'deepseek-reasoner',
    ],
    'nvidia': [
      'meta/llama-3.3-70b-instruct',
      'meta/llama-3.1-405b-instruct',
      'mistralai/mistral-large-2-instruct',
      'deepseek-ai/deepseek-r1',
      'meta/llama-3.1-70b-instruct',
      'meta/llama-3.1-8b-instruct',
    ],
    'groq': [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'mixtral-8x7b-32768',
      'gemma2-9b-it',
      'deepseek-r1-distill-llama-70b',
    ],
    'openrouter': [
      'deepseek/deepseek-r1',
      'deepseek/deepseek-chat',
      'anthropic/claude-3.7-sonnet',
      'anthropic/claude-3.5-sonnet',
      'openai/gpt-4.5-preview',
      'openai/gpt-4o',
      'openai/gpt-4o-mini',
      'openai/o3-mini',
      'google/gemini-2.5-pro',
      'google/gemini-2.5-flash',
      'google/gemini-2.0-flash-001',
      'meta-llama/llama-3.3-70b-instruct',
      'mistralai/mistral-large-2411',
      'qwen/qwen-2.5-72b-instruct',
    ],
  };

  final providers = const [
    CloudProviderInfo(
      id: 'openrouter',
      name: 'OpenRouter',
      description: 'Free model list · OpenAI compatible',
      icon: PhosphorIconsBold.gitBranch,
    ),
    CloudProviderInfo(
      id: 'openai',
      name: 'OpenAI',
      description: 'GPT-4.5, GPT-4o, o1, o3-mini & DALL-E 3',
      icon: PhosphorIconsBold.sparkle,
    ),
    CloudProviderInfo(
      id: 'anthropic',
      name: 'Anthropic Claude',
      description: 'Claude 3.7 Sonnet (Thinking) & 3.5',
      icon: PhosphorIconsBold.brain,
    ),
    CloudProviderInfo(
      id: 'google',
      name: 'Google Gemini',
      description: 'Gemini 2.5 Flash/Pro & Imagen 3',
      icon: PhosphorIconsBold.diamond,
    ),
    CloudProviderInfo(
      id: 'deepseek',
      name: 'DeepSeek',
      description: 'DeepSeek-V3 & DeepSeek-R1 Reasoning',
      icon: PhosphorIconsBold.lightning,
    ),
    CloudProviderInfo(
      id: 'groq',
      name: 'Groq',
      description: 'Ultra-fast LPU inference · Llama 3.3',
      icon: PhosphorIconsBold.lightning,
    ),
    CloudProviderInfo(
      id: 'nvidia',
      name: 'NVIDIA NIM',
      description: 'Hosted frontier open models & Llama 3.3',
      icon: PhosphorIconsBold.cpu,
    ),
    CloudProviderInfo(
      id: 'custom',
      name: 'Custom API',
      description: 'Manual OpenAI-compatible endpoint',
      icon: PhosphorIconsBold.sliders,
      supportsFetch: false,
    ),
  ];

  final modelsByProvider = <String, List<String>>{}.obs;
  final fetchedAtByProvider = <String, DateTime>{}.obs;
  final isLoadingProvider = <String, bool>{}.obs;
  final errorByProvider = <String, String>{}.obs;
  final searchByProvider = <String, String>{}.obs;
  final freeFirstByProvider = <String, bool>{}.obs;
  final modelTagsByProvider = <String, Map<String, List<String>>>{}.obs;
  final customProviderError = ''.obs;

  final customNameController = TextEditingController();
  final customBaseUrlController = TextEditingController();
  final customApiKeyController = TextEditingController();
  final customModelController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    if (!providers.any((provider) => provider.id == activeProvider)) {
      _settings.setCloudProvider('openrouter');
    }
    for (final provider in providers) {
      _loadCachedModels(provider.id);
      ensureDefaultModels(provider.id);
    }
    _syncCustomControllers();
  }

  @override
  void onClose() {
    customNameController.dispose();
    customBaseUrlController.dispose();
    customApiKeyController.dispose();
    customModelController.dispose();
    super.onClose();
  }

  String get activeProvider => _settings.cloudProvider.value;

  String activeModelFor(String provider) {
    switch (provider) {
      case 'openrouter':
        return _settings.openRouterModel.value;
      case 'anthropic':
        return _settings.anthropicModel.value;
      case 'deepseek':
        return _settings.deepSeekModel.value;
      case 'google':
        return _settings.googleModel.value;
      case 'nvidia':
        return _settings.nvidiaModel.value;
      case 'groq':
        return _settings.groqModel.value;
      case 'custom':
        return _settings.customCloudModel.value;
      default:
        return _settings.openaiModel.value;
    }
  }

  String apiKeyFor(String provider) {
    switch (provider) {
      case 'openrouter':
        return _settings.openRouterKey.value;
      case 'anthropic':
        return _settings.anthropicKey.value;
      case 'deepseek':
        return _settings.deepSeekKey.value;
      case 'google':
        return _settings.googleKey.value;
      case 'nvidia':
        return _settings.nvidiaKey.value;
      case 'groq':
        return _settings.groqKey.value;
      case 'custom':
        return _settings.customCloudKey.value;
      default:
        return _settings.openaiKey.value;
    }
  }

  TextEditingController apiKeyControllerFor(String provider) {
    return _settings.apiKeyControllerFor(provider);
  }

  bool isConfigured(String provider) {
    if (provider == 'custom') {
      return _settings.customCloudBaseUrl.value.isNotEmpty &&
          _settings.customCloudModel.value.isNotEmpty &&
          _settings.customCloudKey.value.isNotEmpty;
    }
    return apiKeyFor(provider).isNotEmpty;
  }

  String statusLabel(String provider) {
    return isConfigured(provider) ? 'Connected' : 'Needs Key';
  }

  List<String> filteredModelsFor(String provider) {
    final query = (searchByProvider[provider] ?? '').toLowerCase().trim();
    final active = activeModelFor(provider);
    final source = [...(modelsByProvider[provider] ?? const <String>[])];
    if (active.isNotEmpty && !source.contains(active)) {
      source.insert(0, active);
    }
    final filtered = query.isEmpty
        ? source
        : source.where((id) => id.toLowerCase().contains(query)).toList();
    final freeFirst = freeFirstByProvider[provider] == true;
    filtered.sort((a, b) {
      if (a == active) return -1;
      if (b == active) return 1;
      if (freeFirst) {
        final aFree = isFreeModel(provider, a);
        final bFree = isFreeModel(provider, b);
        if (aFree != bFree) return aFree ? -1 : 1;
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return filtered;
  }

  String fetchedLabel(String provider) {
    final fetchedAt = fetchedAtByProvider[provider];
    if (fetchedAt == null &&
        (modelsByProvider[provider] ?? const <String>[]).isNotEmpty) {
      return 'Built-in list';
    }
    if (fetchedAt == null) return 'Not fetched yet';
    final diff = DateTime.now().difference(fetchedAt);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inHours < 1) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
  }

  List<String> modelTagsFor(String provider, String modelId) {
    final normalized =
        provider == 'google' ? modelId.replaceFirst('models/', '') : modelId;
    if (provider == 'nvidia') return const ['NIM'];
    if (provider == 'groq') return const ['LPU'];
    if (provider == 'anthropic') return const ['Anthropic'];
    return modelTagsByProvider[provider]?[normalized] ??
        modelTagsByProvider[provider]?[modelId] ??
        const <String>[];
  }

  bool isFreeModel(String provider, String modelId) {
    return modelTagsFor(provider, modelId).contains('FREE') ||
        modelId.toLowerCase().contains(':free');
  }

  int freeModelCountFor(String provider) {
    return (modelsByProvider[provider] ?? const <String>[])
        .where((id) => isFreeModel(provider, id))
        .length;
  }

  void toggleFreeFirst(String provider) {
    freeFirstByProvider[provider] = !(freeFirstByProvider[provider] ?? false);
  }

  Future<void> saveApiKey(String provider, String value) async {
    await _settings.setApiKey(provider, value);
  }

  Future<void> removeApiKey(String provider) async {
    await _settings.removeApiKey(provider);
    if (provider == 'custom') {
      await _settings.clearCustomCloudConfig();
    }
    await _hive.setSetting('$_cachePrefix$provider', null);
    await _hive.setSetting('$_cacheTimePrefix$provider', null);
    modelsByProvider[provider] = [];
    ensureDefaultModels(provider);
    update();
  }

  void ensureDefaultModels(String provider) {
    final defaults = _defaultModelsByProvider[provider];
    if (defaults == null || defaults.isEmpty) return;

    final existing = modelsByProvider[provider] ?? const <String>[];
    if (existing.isNotEmpty) return;

    modelsByProvider[provider] = [...defaults];
  }

  bool canFetchModels(String provider) {
    if (provider == 'custom') return false;
    return apiKeyFor(provider).isNotEmpty;
  }

  bool canSelectModel(String provider) {
    if (provider == 'custom') {
      return _settings.customCloudBaseUrl.value.isNotEmpty &&
          _settings.customCloudKey.value.isNotEmpty;
    }
    return apiKeyFor(provider).isNotEmpty;
  }

  Future<void> selectModel(
    String provider,
    String modelId, {
    bool showSnackbar = true,
  }) async {
    final normalized =
        provider == 'google' ? modelId.replaceFirst('models/', '') : modelId;
    await _settings.setCloudProvider(provider);
    await _settings.setCloudModel(provider, normalized);
    await _settings.setInferenceMode('cloud');
    if (!showSnackbar) return;
    Get.snackbar('Cloud Model Active', '$provider · $normalized',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> saveCustomProvider() async {
    final validationError = validateCustomProvider();
    if (validationError != null) {
      customProviderError.value = validationError;
      return;
    }
    customProviderError.value = '';
    await _settings.setCustomCloudConfig(
      name: customNameController.text,
      baseUrl: customBaseUrlController.text,
      apiKey: customApiKeyController.text,
      model: customModelController.text,
    );
    await selectModel(
      'custom',
      _settings.customCloudModel.value,
      showSnackbar: false,
    );
  }

  Future<void> clearCustomProvider() async {
    await _settings.clearCustomCloudConfig();
    customProviderError.value = '';
    _syncCustomControllers();
  }

  List<Map<String, String>> get customProfiles => _settings.customCloudProfiles;

  int get customProfileIndex => _settings.customCloudProfileIndex.value;

  Future<void> selectCustomProfile(int index) async {
    await _settings.selectCustomCloudProfile(index);
    _syncCustomControllers();
    customProviderError.value = '';
  }

  void beginNewCustomProfile() {
    _settings.beginNewCustomCloudProfile();
    _syncCustomControllers();
    customProviderError.value = '';
  }

  String? validateCustomProvider() {
    final baseUrl = customBaseUrlController.text.trim();
    final apiKey = customApiKeyController.text.trim();
    final model = customModelController.text.trim();

    if (baseUrl.isEmpty) return 'Base URL is required.';
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return 'Enter a valid OpenAI-compatible base URL.';
    }
    if (apiKey.isEmpty) return 'API key is required.';
    if (model.isEmpty) return 'Model ID is required.';
    return null;
  }

  Future<void> refreshModels(String provider) async {
    if (provider == 'custom') return;

    if (apiKeyFor(provider).isEmpty) {
      errorByProvider.remove(provider);
      return;
    }

    isLoadingProvider[provider] = true;
    errorByProvider.remove(provider);

    try {
      final response = await _requestModelList(provider);
      if (response.statusCode != 200) {
        final detail = '${response.statusCode}: ${_shortBody(response.body)}';
        errorByProvider[provider] = detail;
        Get.find<AppLogService>().warning(
          'Model list request failed for $provider',
          details: detail,
        );
        return;
      }

      final ids = _parseModelIds(provider, response.body);
      modelsByProvider[provider] = ids;
      modelTagsByProvider[provider] = _parseModelTags(provider, response.body);
      final fetchedAt = DateTime.now();
      fetchedAtByProvider[provider] = fetchedAt;
      await _hive.setSetting('$_cachePrefix$provider', ids);
      await _hive.setSetting(
          '$_cacheTimePrefix$provider', fetchedAt.toIso8601String());
    } catch (e) {
      errorByProvider[provider] = '$e';
      Get.find<AppLogService>().warning(
        'Model list request failed for $provider',
        details: e,
      );
    } finally {
      isLoadingProvider[provider] = false;
    }
  }

  Future<http.Response> _requestModelList(String provider) {
    switch (provider) {
      case 'openrouter':
        return http.get(
          Uri.parse('${AppConstants.openRouterEndpoint}/models'),
          headers: {'Authorization': 'Bearer ${apiKeyFor(provider)}'},
        );
      case 'deepseek':
        return http.get(
          Uri.parse('${AppConstants.deepSeekEndpoint}/models'),
          headers: {'Authorization': 'Bearer ${apiKeyFor(provider)}'},
        );
      case 'google':
        return http.get(Uri.parse(
            '${AppConstants.googleEndpoint}?key=${apiKeyFor(provider)}'));
      case 'nvidia':
        return http.get(
          Uri.parse('${AppConstants.nvidiaEndpoint}/models'),
          headers: {'Authorization': 'Bearer ${apiKeyFor(provider)}'},
        );
      case 'groq':
        return http.get(
          Uri.parse('${AppConstants.groqEndpoint}/models'),
          headers: {'Authorization': 'Bearer ${apiKeyFor(provider)}'},
        );
      case 'anthropic':
        return http.get(
          Uri.parse('https://api.anthropic.com/v1/models'),
          headers: {
            'x-api-key': apiKeyFor(provider),
            'anthropic-version': '2023-06-01',
          },
        );
      default:
        return http.get(
          Uri.parse('https://api.openai.com/v1/models'),
          headers: {'Authorization': 'Bearer ${apiKeyFor(provider)}'},
        );
    }
  }

  List<String> _parseModelIds(String provider, String body) {
    final data = jsonDecode(body);

    if (provider == 'google') {
      final raw = data['models'] as List? ?? [];
      final list = <String>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name']?.toString() ?? '';
        final methods = item['supportedGenerationMethods'] as List? ?? [];

        // Only include models that support generateContent or predict
        final supportsChat = methods.any((m) =>
            m.toString() == 'generateContent' || m.toString() == 'predict');
        if (!supportsChat) continue;

        // Clean model ID (strip 'models/' prefix)
        final cleanId = name.startsWith('models/') ? name.substring(7) : name;
        if (cleanId.isEmpty) continue;

        // Filter out non-chat / internal clutter
        final lower = cleanId.toLowerCase();
        if (lower.contains('embedding') ||
            lower.contains('aqa') ||
            lower.contains('bison') ||
            lower.contains('gecko') ||
            lower.startsWith('text-')) {
          continue;
        }

        list.add(cleanId);
      }
      return list.toSet().toList();
    }

    final raw = data['data'] as List? ?? [];
    final list = <String>[];

    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final lower = id.toLowerCase();

      // Filter out unusable clutter models (embeddings, TTS, Whisper, Moderations, Rerankers)
      if (lower.contains('embedding') ||
          lower.contains('whisper') ||
          lower.contains('tts-') ||
          (lower.contains('dall-e') && provider != 'openai') ||
          lower.contains('moderation') ||
          lower.contains('rerank') ||
          lower.contains('retriever') ||
          lower.contains('guard') ||
          lower.contains('bge-') ||
          lower.contains('canary') ||
          lower.contains('davinci') ||
          lower.contains('babbage') ||
          lower.contains('curie') ||
          lower.contains('ada') ||
          lower.startsWith('ft:') ||
          lower.startsWith('ft-') ||
          lower.contains('similarity')) {
        continue;
      }

      // OpenAI specific filtering
      if (provider == 'openai') {
        final isChatOrVision = lower.startsWith('gpt-') ||
            lower.startsWith('o1') ||
            lower.startsWith('o3') ||
            lower.startsWith('chatgpt') ||
            lower.startsWith('dall-e');
        if (!isChatOrVision || lower.contains('-instruct')) continue;
      }

      // NVIDIA specific filtering
      if (provider == 'nvidia') {
        if (lower.contains('nv-embed') ||
            lower.contains('clip') ||
            lower.contains('reward') ||
            lower.contains('safety')) {
          continue;
        }
      }

      list.add(id);
    }

    // Sort models cleanly: active/popular versions first
    list.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      // Put flash / sonnet / mini / pro / 4o / r1 models near top
      final aScore = _modelPriorityScore(aLower);
      final bScore = _modelPriorityScore(bLower);
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.compareTo(b);
    });

    return list.toSet().toList();
  }

  int _modelPriorityScore(String modelId) {
    final m = modelId.toLowerCase();
    if (m.contains('claude-3-7') || m.contains('claude-3.7')) return 115;
    if (m.contains('deepseek-r1') || m.contains('deepseek-reasoner')) return 110;
    if (m.contains('o3-mini') || m.contains('o1')) return 105;
    if (m.contains('gpt-4.5') || m.contains('gemini-2.5-pro')) return 100;
    if (m.contains('gemini-2.5-flash') || m.contains('gpt-4o') || m.contains('claude-3.5-sonnet') || m.contains('claude-3-5-sonnet')) return 95;
    if (m.contains('deepseek-chat') || m.contains('gpt-4o-mini') || m.contains('gemini-2.0-flash')) return 90;
    if (m.contains('llama-3.3') || m.contains('claude-3-5-haiku') || m.contains('claude-3-haiku')) return 85;
    if (m.contains('llama-3.1-405b') || m.contains('llama-3.1-70b') || m.contains('mistral-large')) return 80;
    if (m.contains('llama-3.1') || m.contains('gemma-2') || m.contains('gemma2') || m.contains('qwen')) return 75;
    if (m.contains('imagen-3') || m.contains('dall-e-3')) return 70;
    if (m.contains('free')) return 65;
    return 10;
  }

  Map<String, List<String>> _parseModelTags(String provider, String body) {
    if (provider != 'openrouter') return const {};

    final data = jsonDecode(body);
    final raw = data['data'] as List? ?? [];
    final tags = <String, List<String>>{};

    for (final model in raw) {
      if (model is! Map) continue;
      final id = model['id']?.toString();
      if (id == null || id.isEmpty) continue;

      final pricing = model['pricing'];
      final isFreeId = id.toLowerCase().contains(':free');
      final isFreePrice = pricing is Map && _isZeroOpenRouterPricing(pricing);
      if (isFreeId || isFreePrice) {
        tags[id] = const ['FREE'];
      }
    }

    return tags;
  }

  bool _isZeroOpenRouterPricing(Map pricing) {
    final prompt = _pricingValue(pricing['prompt']);
    final completion = _pricingValue(pricing['completion']);
    final request = _pricingValue(pricing['request']);
    return prompt == 0 && completion == 0 && (request == null || request == 0);
  }

  double? _pricingValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void _loadCachedModels(String provider) {
    final raw = _hive.getSetting<List>('$_cachePrefix$provider');
    if (raw != null) {
      modelsByProvider[provider] = raw.whereType<String>().toList();
    }
    final rawTime = _hive.getSetting<String>('$_cacheTimePrefix$provider');
    if (rawTime != null) {
      final parsed = DateTime.tryParse(rawTime);
      if (parsed != null) fetchedAtByProvider[provider] = parsed;
    }
  }

  void _syncCustomControllers() {
    customNameController.text = _settings.customCloudName.value;
    customBaseUrlController.text = _settings.customCloudBaseUrl.value;
    customApiKeyController.text = _settings.customCloudKey.value;
    customModelController.text = _settings.customCloudModel.value;
  }

  String _shortBody(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 280) return compact;
    return '${compact.substring(0, 280)}...';
  }
}
