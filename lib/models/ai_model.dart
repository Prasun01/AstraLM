class AiModel {
  static const runtimeLlama = 'llama';
  static const runtimeLiteRt = 'litert';
  static const runtimeSd = 'sd';

  static bool hasVisionMarker(String value) {
    final lower = value.toLowerCase();
    return lower.contains('vl-') ||
        lower.contains('-vl') ||
        lower.contains('llava') ||
        lower.contains('vision');
  }

  final String name;
  final String filename;
  final String url;
  final String size;
  final String description;
  final String template;
  final String runtime;
  final String quantization;
  final String ramRequired;
  final List<String> tags;
  final bool isVision;
  final bool isImported;
  final bool isCustom;

  AiModel({
    required this.name,
    required this.filename,
    required this.url,
    required this.size,
    required this.description,
    required this.template,
    String? runtime,
    String? quantization,
    String? ramRequired,
    List<String>? tags,
    this.isVision = false,
    this.isImported = false,
    this.isCustom = false,
  })  : runtime = runtime ?? runtimeFromFilename(filename, template: template),
        quantization = quantization ??
            _inferQuantization(
                filename, runtime ?? runtimeFromFilename(filename, template: template)),
        ramRequired = ramRequired ??
            _inferRamRequired(
                size, runtime ?? runtimeFromFilename(filename, template: template)),
        tags = tags ??
            _inferTags(
                name, filename, description, runtime ?? runtimeFromFilename(filename, template: template));

  String get bestFor {
    final lower = '$name $filename $description ${tags.join(" ")}'.toLowerCase();
    if (isVision || hasVisionMarker(lower)) return 'Image & Visual Understanding';
    if (lower.contains('coder') || lower.contains('coding') || lower.contains('deepseek-coder')) return 'Code, Math & Logic';
    if (lower.contains('r1') || lower.contains('reasoning') || lower.contains('think')) return 'Deep Reasoning & Step-by-Step Logic';
    if (lower.contains('moonlight') || lower.contains('16b') || lower.contains('mixtral')) return 'Complex Reasoning & Research';
    if (lower.contains('image') || runtime == runtimeSd || filename.endsWith('.safetensors')) return 'AI Image Generation';
    if (lower.contains('0.5b') || lower.contains('tiny') || lower.contains('smollm')) return 'Instant Responses (Ultra-Fast)';
    if (lower.contains('1.5b') || lower.contains('gemma-2-2b') || lower.contains('llama-3.2-1b')) return 'Everyday Chat & Quick Answers';
    return 'Everyday Chat & Writing';
  }

  factory AiModel.fromMap(Map<dynamic, dynamic> map) {
    final filename = map['filename']?.toString() ?? '';
    final template = map['template']?.toString() ?? 'chatml';
    final runtime = map['runtime']?.toString() ??
        runtimeFromFilename(filename, template: template);

    final tagsRaw = map['tags'];
    List<String>? tagsList;
    if (tagsRaw is List) {
      tagsList = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tagsList = tagsRaw.split(',').map((e) => e.trim()).toList();
    }

    final isVision = map['vision'] == true ||
        map['vision'] == 'true' ||
        hasVisionMarker('${map['name']} $filename ${map['description']}');

    return AiModel(
      name: map['name']?.toString() ?? '',
      filename: filename,
      url: map['url']?.toString() ?? '',
      size: map['size']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      template: template,
      runtime: runtime,
      quantization: map['quantization']?.toString(),
      ramRequired: (map['ram_required'] ?? map['ramRequired'])?.toString(),
      tags: tagsList,
      isVision: isVision,
      isImported: map['imported'] == true || map['imported'] == 'true',
      isCustom: map['custom'] == true || map['custom'] == 'true',
    );
  }

  factory AiModel.fromJson(Map<String, dynamic> json) => AiModel.fromMap(json);

  Map<String, String> toMap() => {
        'name': name,
        'filename': filename,
        'url': url,
        'size': size,
        'description': description,
        'template': template,
        'runtime': runtime,
        'quantization': quantization,
        'ram_required': ramRequired,
        'tags': tags.join(','),
        'vision': isVision.toString(),
        'imported': isImported.toString(),
        'custom': isCustom.toString(),
      };

  static String runtimeFromFilename(String filename, {String? template}) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.safetensors') || template == 'sd') {
      return runtimeSd;
    }
    if (lower.endsWith('.litertlm')) {
      return runtimeLiteRt;
    }
    return runtimeLlama;
  }

  static String _inferQuantization(String filename, String runtime) {
    if (runtime == runtimeSd) return 'fp16';
    if (runtime == runtimeLiteRt) return 'int8';
    final lower = filename.toLowerCase();
    final match = RegExp(
      r'(iq[1-4]_[a-z0-9_]+|q[1-8]_[k0-9_]+|q[1-8]_[a-z0-9_]+|fp16|f16|int8|int4)',
      caseSensitive: false,
    ).firstMatch(lower);
    return match?.group(0)?.toUpperCase() ?? 'Q4_K_M';
  }

  static String _inferRamRequired(String size, String runtime) {
    final match = RegExp(r'([\d.]+)\s*(GB|MB)', caseSensitive: false)
        .firstMatch(size);
    if (match == null) return '4.0 GB';
    final value = double.tryParse(match.group(1) ?? '') ?? 2.0;
    final unit = (match.group(2) ?? '').toUpperCase();
    final sizeInGb = unit == 'GB' ? value : value / 1024.0;
    final ram = (sizeInGb * 1.35 + 0.8).clamp(1.5, 32.0);
    return '${ram.toStringAsFixed(1)} GB';
  }

  static List<String> _inferTags(
      String name, String filename, String description, String runtime) {
    final text = '$name $filename $description'.toLowerCase();
    final tags = <String>[];
    if (runtime == runtimeSd) tags.add('image');
    if (runtime == runtimeLiteRt) tags.add('litert');
    if (runtime == runtimeLlama) tags.add('gguf');
    if (text.contains('coder') || text.contains('coding')) tags.add('coding');
    if (text.contains('vision') || text.contains('vl')) tags.add('vision');
    if (text.contains('fast') || text.contains('tiny') || text.contains('0.5b')) {
      tags.add('fast');
    }
    if (text.contains('r1') || text.contains('reasoning') || text.contains('think')) {
      tags.add('reasoning');
    }
    if (tags.isEmpty) tags.add('general');
    return tags;
  }
}
