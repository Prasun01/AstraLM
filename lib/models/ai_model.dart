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
        if (isVision) 'vision': 'true',
        if (isImported) 'imported': 'true',
        if (isCustom) 'custom': 'true',
      };

  static String runtimeFromFilename(String filename, {String? template}) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.litertlm')) return runtimeLiteRt;
    if (lower.endsWith('.safetensors') || template == runtimeSd) {
      return runtimeSd;
    }
    return runtimeLlama;
  }

  static String _inferQuantization(String filename, String runtime) {
    final lower = filename.toLowerCase();
    if (lower.contains('q4_k_m') || lower.contains('q4_k')) return 'Q4_K_M';
    if (lower.contains('q4_0')) return 'Q4_0';
    if (lower.contains('q5_k_m') || lower.contains('q5_k')) return 'Q5_K_M';
    if (lower.contains('q3_k_s') || lower.contains('q3_k')) return 'Q3_K_S';
    if (lower.contains('q8_0') || lower.contains('q8') || lower.contains('int8')) {
      return 'int8';
    }
    if (lower.contains('fp16') || lower.endsWith('.safetensors')) return 'FP16';
    if (runtime == runtimeLiteRt) return 'int8';
    return 'Q4_K_M';
  }

  static String _inferRamRequired(String sizeStr, String runtime) {
    final match = RegExp(r'([\d.]+)\s*(GB|MB)', caseSensitive: false)
        .firstMatch(sizeStr);
    if (match == null) return '2.0 GB';
    final value = double.tryParse(match.group(1) ?? '') ?? 1.5;
    final unit = (match.group(2) ?? '').toUpperCase();
    final double sizeGb = unit == 'MB' ? value / 1024.0 : value;

    if (runtime == runtimeSd) {
      return '${(sizeGb + 2.0).toStringAsFixed(1)} GB';
    }
    final req = (sizeGb * 1.35 + 0.6).clamp(0.8, 16.0);
    return '${req.toStringAsFixed(1)} GB';
  }

  static List<String> _inferTags(
      String name, String filename, String description, String runtime) {
    final text = '$name $filename $description'.toLowerCase();
    final tagSet = <String>{};
    if (runtime == runtimeLiteRt) tagSet.add('litert');
    if (runtime == runtimeLlama) tagSet.add('gguf');
    if (runtime == runtimeSd) tagSet.add('image');

    if (text.contains('reason') ||
        text.contains('r1') ||
        text.contains('think') ||
        text.contains('distill') ||
        text.contains('math') ||
        text.contains('phi-3.5')) {
      tagSet.add('reasoning');
    }
    if (text.contains('code') ||
        text.contains('coding') ||
        text.contains('qwen')) {
      tagSet.add('coding');
    }
    if (text.contains('vision') ||
        text.contains('vl') ||
        hasVisionMarker(text)) {
      tagSet.add('vision');
    }
    if (text.contains('uncensored') ||
        text.contains('abliterated') ||
        text.contains('dolphin')) {
      tagSet.add('uncensored');
    }
    if (text.contains('tiny') ||
        text.contains('0.5b') ||
        text.contains('360m') ||
        text.contains('instant') ||
        text.contains('featherweight')) {
      tagSet.add('tiny');
      tagSet.add('fast');
    }
    if (text.contains('flagship') || text.contains('7b') || text.contains('9b') || text.contains('16b')) {
      tagSet.add('flagship');
    }
    if (tagSet.isEmpty || (!tagSet.contains('reasoning') && !tagSet.contains('uncensored') && !tagSet.contains('image'))) {
      tagSet.add('general');
    }
    return tagSet.toList();
  }

  AiModel copyWith({
    String? name,
    String? filename,
    String? url,
    String? size,
    String? description,
    String? template,
    String? runtime,
    String? quantization,
    String? ramRequired,
    List<String>? tags,
    bool? isVision,
    bool? isImported,
    bool? isCustom,
  }) {
    return AiModel(
      name: name ?? this.name,
      filename: filename ?? this.filename,
      url: url ?? this.url,
      size: size ?? this.size,
      description: description ?? this.description,
      template: template ?? this.template,
      runtime: runtime ?? this.runtime,
      quantization: quantization ?? this.quantization,
      ramRequired: ramRequired ?? this.ramRequired,
      tags: tags ?? this.tags,
      isVision: isVision ?? this.isVision,
      isImported: isImported ?? this.isImported,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
