import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/download_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import '../services/hive_service.dart';
import '../services/app_log_service.dart';
import '../services/device_info_service.dart';
import '../models/ai_model.dart';
import '../core/constants.dart';
import 'settings_controller.dart';

enum _ModelLoadAction { cancel, unload, continueLoad }

class ModelController extends GetxController {
  final DownloadService _download = Get.find<DownloadService>();
  final LocalImageService _localImage = Get.find<LocalImageService>();
  final InferenceService _inference = Get.find<InferenceService>();
  final HiveService _hive = Get.find<HiveService>();
  final SettingsController _settings = Get.find<SettingsController>();

  static const _customModelsKey = 'custom_url_models';
  static const _androidImportChannel =
      MethodChannel('com.aichat.ai_chat/model_import');

  Map<String, DownloadProgress> get activeDownloads =>
      _download.activeDownloads;

  final availableModels = <AiModel>[].obs;
  final downloadedFiles = <String>[].obs;
  final isImporting = false.obs;
  final customModels = <AiModel>[].obs;
  final fileSizes = <String, int>{}.obs;
  final modelScope = 'local'.obs;
  final localFilter = ''.obs;
  final localSizeFilter = 'all'.obs; // 'all', 'tiny', 'small', 'medium'
  final sortMode = 'popular'.obs; // 'popular', 'size_asc', 'size_desc', 'name'
  final importFileName = ''.obs;
  final importStatus = ''.obs;
  final importCopiedBytes = 0.obs;
  final importTotalBytes = 0.obs;
  final importBytesPerSecond = 0.0.obs;
  final sortSmallestFirst = true.obs;
  final externalDownloadId = Rx<int?>(null);

  void toggleSort() {
    if (sortMode.value == 'popular') {
      sortMode.value = 'size_asc';
    } else if (sortMode.value == 'size_asc') {
      sortMode.value = 'size_desc';
    } else if (sortMode.value == 'size_desc') {
      sortMode.value = 'name';
    } else {
      sortMode.value = 'popular';
    }
  }

  void setSortMode(String mode) {
    sortMode.value = mode;
  }

  void setSizeFilter(String size) {
    localSizeFilter.value = size;
  }

  static const localFilters = [
    'all',
    'recommended',
    'downloaded',
    'general',
    'image',
    'uncensored',
    'vision'
  ];

  bool isRecommendedModel(AiModel model) {
    final dev = Get.find<DeviceInfoService>();
    final ram = dev.totalRamGB.value > 0 ? dev.totalRamGB.value : 6.0;
    final bytes = _knownModelBytes(model);
    if (model.template == 'sd') return ram >= 6.0;
    if (ram <= 4.0) {
      return bytes <= 1600 * 1024 * 1024;
    } else if (ram <= 8.0) {
      return bytes <= 3600 * 1024 * 1024;
    }
    return true;
  }

  List<AiModel> get recommendedModels {
    return availableModels.where((m) => isRecommendedModel(m)).take(6).toList();
  }

  List<AiModel> get displayedModels {
    return filteredDisplayedModels;
  }

  List<AiModel> get filteredDisplayedModels {
    final filter =
        localFilter.value.isEmpty ? defaultLocalFilter : localFilter.value;
    final sizeFilter = localSizeFilter.value;

    var list = availableModels.where((model) {
      // 1. Category Filter
      final bool matchesCategory;
      switch (filter) {
        case 'all':
          matchesCategory = true;
          break;
        case 'recommended':
          matchesCategory = isRecommendedModel(model);
          break;
        case 'downloaded':
          matchesCategory = isDownloaded(model.filename);
          break;
        case 'uncensored':
          matchesCategory = isUncensoredModel(model);
          break;
        case 'vision':
          matchesCategory = isVisionModel(model);
          break;
        case 'image':
          matchesCategory = isImageModel(model);
          break;
        case 'general':
        default:
          matchesCategory = isGeneralModel(model);
          break;
      }
      if (!matchesCategory) return false;

      // 2. Size Filter
      if (sizeFilter != 'all') {
        final bytes = _knownModelBytes(model);
        if (sizeFilter == 'tiny') {
          if (bytes > 1600 * 1024 * 1024) return false;
        } else if (sizeFilter == 'small') {
          if (bytes < 1400 * 1024 * 1024 || bytes > 3200 * 1024 * 1024) {
            return false;
          }
        } else if (sizeFilter == 'medium') {
          if (bytes <= 3200 * 1024 * 1024) return false;
        }
      }

      return true;
    }).toList();

    // 3. Sorting
    final active = _inference.loadedModelName.value;
    list.sort((a, b) {
      if (a.filename == active) return -1;
      if (b.filename == active) return 1;
      final aDownloaded = isDownloaded(a.filename);
      final bDownloaded = isDownloaded(b.filename);
      if (aDownloaded != bDownloaded) return aDownloaded ? -1 : 1;

      switch (sortMode.value) {
        case 'size_asc':
          final aBytes = _knownModelBytes(a);
          final bBytes = _knownModelBytes(b);
          return aBytes.compareTo(bBytes);
        case 'size_desc':
          final aBytes = _knownModelBytes(a);
          final bBytes = _knownModelBytes(b);
          return bBytes.compareTo(aBytes);
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'popular':
        default:
          return 0;
      }
    });

    return list;
  }

  String get defaultLocalFilter =>
      downloadedFiles.isNotEmpty ? 'downloaded' : 'all';

  double get importProgress => importTotalBytes.value <= 0
      ? 0.0
      : (importCopiedBytes.value / importTotalBytes.value)
          .clamp(0.0, 1.0)
          .toDouble();

  int get downloadedCount => downloadedFiles.length;

  String get activeLocalModelName => _inference.loadedModelName.value;

  @override
  void onInit() {
    super.onInit();
    _loadCustomModels();
    availableModels.value = AppConstants.availableModels
        .map((m) => AiModel.fromMap(m))
        .toList()
      ..addAll(customModels);
    refreshDownloaded();
  }

  void _loadCustomModels() {
    final raw =
        _hive.getSetting<List>(_customModelsKey, defaultValue: []) ?? [];
    customModels.value = raw
        .whereType<Map>()
        .map((m) => AiModel.fromMap(Map<String, String>.from(m)))
        .toList();
  }

  Future<void> _saveCustomModels() async {
    await _hive.setSetting(
      _customModelsKey,
      customModels.map((m) => m.toMap()).toList(),
    );
  }

  Future<void> refreshDownloaded() async {
    await _deletePartialImports();
    final files = (await _download.getDownloadedModels())
        .where((file) => !_isAuxiliaryImageFile(file))
        .toList();
    downloadedFiles.value = files;
    for (final file in files) {
      fileSizes[file] = await _download.getModelSize(file);
    }

    // Add any downloaded files that are not in availableModels
    final existingFilenames = availableModels.map((m) => m.filename).toSet();
    for (final file in files) {
      if (!existingFilenames.contains(file)) {
        final lower = file.toLowerCase();
        final runtime = AiModel.runtimeFromFilename(file);
        final isLiteRt = runtime == AiModel.runtimeLiteRt;
        final isVision = isLiteRt && AiModel.hasVisionMarker(lower);

        availableModels.add(AiModel(
          name: file,
          filename: file,
          url: '',
          size: _formatModelSize(file),
          description: 'Imported from local storage',
          template: isLiteRt ? 'litert' : 'chatml',
          runtime: runtime,
          isImported: true,
          isVision: isVision,
        ));
      }
    }

    // Remove any imported models that are no longer downloaded
    availableModels.removeWhere(
        (model) => model.isImported && !files.contains(model.filename));

    if (localFilter.value.isEmpty) {
      localFilter.value = defaultLocalFilter;
    }
  }

  bool isDownloaded(String filename) => downloadedFiles.contains(filename);

  bool _isAuxiliaryImageFile(String filename) {
    final lower = filename.toLowerCase();
    return lower == 'taesd.safetensors' ||
        lower.startsWith('taesd-') ||
        lower.startsWith('taesd_') ||
        lower == 'diffusion_pytorch_model.safetensors' ||
        lower.endsWith('.vae.safetensors') ||
        lower.startsWith('vae-') ||
        lower.startsWith('vae_');
  }

  bool _isIncompleteCatalogFile(AiModel model, int fileBytes) {
    if (model.url.trim().isEmpty || model.isImported || fileBytes <= 0) {
      return false;
    }
    if (fileBytes < 1024 * 1024) return true;
    final expectedBytes = _declaredModelBytes(model);
    if (expectedBytes <= 0) return false;
    return fileBytes < (expectedBytes * 0.35).round();
  }

  bool get isDownloading => _download.isDownloadingAny;

  String get lastLoadedModelName =>
      _hive.getSetting<String>(AppConstants.keyLocalModelName) ?? '';

  bool get canLoadLastModel =>
      lastLoadedModelName.isNotEmpty && isDownloaded(lastLoadedModelName);

  DownloadProgress? getDownloadProgress(String filename) =>
      _download.activeDownloads[filename];

  bool isDownloadingModel(String filename) =>
      _download.activeDownloads.containsKey(filename);

  void setLocalFilter(String filter) {
    if (localFilters.contains(filter)) {
      localFilter.value = filter;
    }
  }

  bool isVisionModel(AiModel model) {
    if (!isLiteRtModel(model)) return false;
    final lower =
        '${model.name} ${model.filename} ${model.description}'.toLowerCase();
    return model.isVision || AiModel.hasVisionMarker(lower);
  }

  bool isUncensoredModel(AiModel model) {
    return AppConstants.isUncensoredModelName(
      '${model.name} ${model.filename} ${model.description}',
    );
  }

  bool isImageModel(AiModel model) {
    final lower = model.filename.toLowerCase();
    return model.runtime == AiModel.runtimeSd ||
        lower.endsWith('.safetensors') ||
        model.template == 'sd';
  }

  bool isLiteRtModel(AiModel model) {
    return model.runtime == AiModel.runtimeLiteRt ||
        model.filename.toLowerCase().endsWith('.litertlm');
  }

  bool isLlamaModel(AiModel model) {
    return model.runtime == AiModel.runtimeLlama ||
        model.filename.toLowerCase().endsWith('.gguf');
  }

  bool isGeneralModel(AiModel model) =>
      !isVisionModel(model) &&
      !isUncensoredModel(model) &&
      !isImageModel(model);

  String modelSizeLabel(AiModel model) {
    final bytes = fileSizes[model.filename] ?? 0;
    if (bytes > 0) return DownloadService.formatBytes(bytes);
    return model.size;
  }

  int _knownModelBytes(AiModel model) {
    final detected = fileSizes[model.filename] ?? 0;
    if (detected > 0) return detected;
    return _declaredModelBytes(model);
  }

  int _declaredModelBytes(AiModel model) {
    final match = RegExp(r'([\d.]+)\s*(GB|MB)', caseSensitive: false)
        .firstMatch(model.size);
    if (match == null) return 0;
    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = (match.group(2) ?? '').toUpperCase();
    if (unit == 'GB') return (value * 1024 * 1024 * 1024).round();
    if (unit == 'MB') return (value * 1024 * 1024).round();
    return 0;
  }

  String _formatModelSize(String filename) {
    final bytes = fileSizes[filename] ?? 0;
    if (bytes <= 0) return 'Local File';
    return DownloadService.formatBytes(bytes);
  }

  String filenameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'model.gguf';
    final decoded = Uri.decodeComponent(segment.split('?').first);
    if (decoded.toLowerCase().endsWith('.gguf') ||
        decoded.toLowerCase().endsWith('.litertlm') ||
        decoded.toLowerCase().endsWith('.safetensors')) {
      return decoded;
    }
    return '$decoded.gguf';
  }

  Future<String> detectUrlSize(String url) async {
    try {
      final bytes = await _download.getRemoteFileSize(url);
      if (bytes <= 0) return 'Unknown size';
      return DownloadService.formatBytes(bytes);
    } catch (_) {
      return 'Unknown size';
    }
  }

  Future<void> addModelFromUrl({
    required String name,
    required String url,
    String? filename,
    String? description,
    String template = 'chatml',
    String? size,
    bool isVision = false,
  }) async {
    final resolvedFilename = (filename == null || filename.trim().isEmpty)
        ? filenameFromUrl(url)
        : filename.trim();

    final model = AiModel(
      name: name.trim().isEmpty ? resolvedFilename : name.trim(),
      filename: resolvedFilename,
      url: url.trim(),
      size: size == null || size.trim().isEmpty ? 'Unknown size' : size.trim(),
      description: description == null || description.trim().isEmpty
          ? 'Added from custom URL'
          : description.trim(),
      template: template.trim().isEmpty ? 'chatml' : template.trim(),
      runtime: AiModel.runtimeFromFilename(
        resolvedFilename,
        template: template.trim().isEmpty ? 'chatml' : template.trim(),
      ),
      isVision: isVision &&
          AiModel.runtimeFromFilename(
                resolvedFilename,
                template: template.trim().isEmpty ? 'chatml' : template.trim(),
              ) ==
              AiModel.runtimeLiteRt,
      isCustom: true,
    );

    customModels.removeWhere((m) => m.filename == model.filename);
    customModels.add(model);
    availableModels.removeWhere((m) => m.filename == model.filename);
    availableModels.add(model);
    await _saveCustomModels();
  }

  Future<void> downloadModel(AiModel model) async {
    try {
      await _download.downloadModel(
        url: model.url,
        filename: model.filename,
      );
      await refreshDownloaded();
    } catch (e) {
      Get.find<AppLogService>().error('Model download failed', details: e);
      Get.snackbar('Download Failed', '$e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> downloadModelToDownloads(AiModel model) async {
    if (model.url.trim().isEmpty) {
      Get.snackbar('Download Unavailable', 'This model has no download URL.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (!Platform.isAndroid) {
      Get.snackbar(
        'Android Only',
        'Use the app download button or import a local model on this platform.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isImporting.value = true;
      importFileName.value = model.filename;
      importStatus.value = 'Starting download...';
      importCopiedBytes.value = 0;
      importTotalBytes.value = 0;
      importBytesPerSecond.value = 0;

      final result =
          await _androidImportChannel.invokeMapMethod<String, dynamic>(
        'downloadToDownloads',
        {'url': model.url, 'filename': model.filename},
      );
      externalDownloadId.value = result?['downloadId'] as int?;
      final filename = result?['filename'] as String? ?? model.filename;
      Get.snackbar(
        'Download Started',
        '$filename is downloading to your Downloads folder.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on PlatformException catch (e) {
      isImporting.value = false;
      externalDownloadId.value = null;
      Get.find<AppLogService>().error(
        'Download to Downloads failed',
        details: '${e.code}: ${e.message}',
      );
      Get.snackbar('Download Failed', e.message ?? e.code,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      isImporting.value = false;
      externalDownloadId.value = null;
      Get.find<AppLogService>()
          .error('Download to Downloads failed', details: e);
      Get.snackbar('Download Failed', '$e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> cancelExternalDownload() async {
    final id = externalDownloadId.value;
    if (id != null) {
      try {
        await _androidImportChannel.invokeMethod('cancelDownloadToDownloads', {'downloadId': id});
      } catch (e) {
        Get.find<AppLogService>().error('Cancel download failed', details: e);
      }
      externalDownloadId.value = null;
      isImporting.value = false;
      importStatus.value = 'Download cancelled';
    }
  }

  void pauseDownload(String filename) {
    _download.pauseDownload(filename);
  }

  Future<void> deleteModel(String filename) async {
    await _download.deleteModel(filename);
    await refreshDownloaded();
    // Unload if this was the active model
    if (_inference.loadedModelName.value == filename) {
      await _inference.unloadModel();
    }
  }

  Future<void> loadModel(String filename) async {
    if (_inference.isLoadingModel.value) {
      Get.snackbar('Model Loading', 'Another model is already loading.',
          snackPosition: SnackPosition.TOP,
          barBlur: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
      return;
    }

    final model =
        availableModels.firstWhereOrNull((m) => m.filename == filename);
    if (_isAuxiliaryImageFile(filename)) {
      Get.snackbar(
        'Helper File',
        '$filename is used internally by image generation and cannot be loaded as a model.',
        snackPosition: SnackPosition.TOP,
        barBlur: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
      return;
    }

    final path = await _download.modelPath(filename);
    final isImage = filename.toLowerCase().endsWith('.safetensors') ||
        (model != null && isImageModel(model));

    if (isImage) {
      if (_localImage.isModelLoaded.value) {
        await _localImage.unloadModel();
      }
      _showImageModelLoadingDialog(filename);
      final result = await _localImage.loadModel(path, modelName: filename);
      if (Get.isDialogOpen ?? false) Get.back();

      final isError = !_localImage.isModelLoaded.value;
      Get.snackbar(
        isError ? 'Model Not Loaded' : 'Image Model',
        result,
        snackPosition: SnackPosition.TOP,
        duration:
            isError ? const Duration(seconds: 5) : const Duration(seconds: 2),
      );
    } else {
      final result = await _inference.loadModel(
        path,
        modelName: filename,
        modelRuntime: model?.runtime,
        enableLiteRtVision: model == null ? false : isVisionModel(model),
      );
      if (_inference.isModelLoaded.value) {
        await _settings.setInferenceMode('local');
        final isDark = Get.isDarkMode;
        Get.rawSnackbar(
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 14,
          backgroundColor: isDark ? const Color(0xFF161822) : const Color(0xFFFFFFFF),
          boxShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          icon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: PhosphorIcon(
              PhosphorIconsBold.checkCircle,
              color: const Color(0xFF34C759),
              size: 22,
            ),
          ),
          titleText: Text(
            'Model Loaded',
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0E1017),
            ),
          ),
          messageText: Text(
            result,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF555E72),
            ),
          ),
          duration: const Duration(seconds: 2),
        );
      } else {
        final isDark = Get.isDarkMode;
        Get.rawSnackbar(
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 14,
          backgroundColor: isDark ? const Color(0xFF161822) : const Color(0xFFFFFFFF),
          boxShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          icon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: PhosphorIcon(
              PhosphorIconsBold.xCircle,
              color: const Color(0xFFFF453A),
              size: 22,
            ),
          ),
          titleText: Text(
            'Model Load Failed',
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0E1017),
            ),
          ),
          messageText: Text(
            result,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF555E72),
            ),
          ),
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _showRuntimeRestartDialog({
    required String currentRuntime,
    required String targetRuntime,
    required String pendingModelName,
    required String pendingModelPath,
  }) async {
    final currentLabel = _runtimeLabel(currentRuntime);
    final targetLabel = _runtimeLabel(targetRuntime);
    await Get.dialog<void>(
      AlertDialog(
        title: const Text('Restart required'),
        content: Text(
          'You already used $currentLabel in this app session. '
          'Switching to $targetLabel requires an app restart.\n\n'
          'Restart the app now, and it will prompt you to load $pendingModelName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final hive = Get.find<HiveService>();
              await hive.setSetting(AppConstants.keyLocalModelName, pendingModelName);
              await hive.setSetting(AppConstants.keyLocalModelPath, pendingModelPath);
              await hive.setSetting(AppConstants.keyLocalModelRuntime, targetRuntime);
              try {
                await _androidImportChannel.invokeMethod('restartApp');
              } catch (_) {
                SystemNavigator.pop();
              }
            },
            child: const Text('Restart app'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  String _runtimeLabel(String runtime) {
    switch (runtime.toLowerCase()) {
      case AiModel.runtimeLiteRt:
        return 'LiteRT';
      case AiModel.runtimeLlama:
        return 'GGUF';
      default:
        return 'local model';
    }
  }

  Future<int> _modelFileBytes(
    String filename,
    String path,
    AiModel? model,
  ) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        fileSizes[filename] = bytes;
        return bytes;
      }
    } catch (_) {}
    final cached = fileSizes[filename] ?? 0;
    if (cached > 0) return cached;
    return model == null ? 0 : _knownModelBytes(model);
  }

  Future<bool> _hasValidSafetensorsHeader(String path) async {
    RandomAccessFile? raf;
    try {
      final file = File(path);
      final length = await file.length();
      if (length < 16) return false;
      raf = await file.open();
      final bytes = await raf.read(16);
      if (bytes.length < 16) return false;

      var headerLength = 0;
      for (var i = 0; i < 8; i++) {
        headerLength += bytes[i] << (8 * i);
      }

      if (headerLength <= 2 || headerLength > length - 8) return false;
      if (headerLength > 64 * 1024 * 1024) return false;
      return bytes[8] == 0x7B;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  Future<bool> _hasLikelyValidLiteRtFile(String path, int fileBytes) async {
    RandomAccessFile? raf;
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length < 10 * 1024 * 1024) return false;

      raf = await file.open();
      final bytes = await raf.read(16);
      if (bytes.length < 8) return false;

      // Verify LiteRT-LM magic identifier 'LITERTLM' at bytes 0-7
      final hasLmLiteRt = bytes[0] == 0x4C && // 'L'
          bytes[1] == 0x49 && // 'I'
          bytes[2] == 0x54 && // 'T'
          bytes[3] == 0x45 && // 'E'
          bytes[4] == 0x52 && // 'R'
          bytes[5] == 0x54 && // 'T'
          bytes[6] == 0x4C && // 'L'
          bytes[7] == 0x4D; // 'M'

      if (hasLmLiteRt) {
        return true;
      }

      // Note: We intentionally DO NOT allow standard TFLite models starting with 'TFL3' at offset 4
      // if they lack the 'LITERTLM' container header, because the native LiteRT-LM engine 
      // strictly expects the .litertlm conversational bundle structure and will crash with a
      // SIGABRT native assert check failure if it is not present.
      return false;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  Future<_ModelLoadAction> _confirmModelLoadSafety({
    required String filename,
    required int fileBytes,
    required bool isLiteRt,
  }) async {
    final availableRamGb = await _refreshAvailableRamGb();

    final availableBytes = (availableRamGb * 1024 * 1024 * 1024).round();
    final modelLabel = fileBytes > 0
        ? DownloadService.formatWholeMb(fileBytes)
        : 'Unknown size';
    final ramLabel = availableBytes > 0
        ? DownloadService.formatWholeMb(availableBytes)
        : 'Unknown';
    final lower = filename.toLowerCase();
    final hasMeasuredMemory = availableBytes > 0 && fileBytes > 0;
    final isCriticallyLow = hasMeasuredMemory &&
        (availableBytes < fileBytes || _isLowMemoryBytes(availableBytes));
    final isLargeForRam =
        availableBytes > 0 && fileBytes > 0 && availableBytes < fileBytes * 2;
    final isLowRam = availableBytes > 0 && _isLowMemoryBytes(availableBytes);
    final String warning;
    if (isCriticallyLow) {
      warning =
          'Available RAM is lower than recommended. This can crash the app if Android cannot reserve enough memory.';
    } else if (isLargeForRam || isLowRam || isLiteRt) {
      warning =
          'This can crash the app if Android cannot reserve enough memory for the model.';
    } else {
      warning = 'Loading local models can use more memory than the file size.';
    }
    final runtimeLabel = isLiteRt
        ? 'LiteRT-LM'
        : lower.endsWith('.gguf')
            ? 'GGUF'
            : lower.endsWith('.safetensors')
                ? 'Image model'
                : 'Local model';
    final loadedName = _inference.loadedModelName.value;
    final hasLoadedModel =
        _inference.isModelLoaded.value && loadedName.isNotEmpty;
    final isSameModelLoaded = hasLoadedModel && loadedName == filename;

    final result = await Get.dialog<_ModelLoadAction>(
      AlertDialog(
        title: Text(isCriticallyLow ? 'Restart recommended' : 'Load model?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(filename),
            const SizedBox(height: 12),
            Text('Runtime: $runtimeLabel'),
            Text('Available RAM: $ramLabel'),
            Text('Model size: $modelLabel'),
            if (hasLoadedModel) ...[
              const SizedBox(height: 12),
              Text(
                isSameModelLoaded
                    ? 'This model is already loaded.'
                    : 'Already loaded: $loadedName',
              ),
              if (!isSameModelLoaded)
                const Text('Unload it before loading another model.'),
            ],
            const SizedBox(height: 12),
            Text(warning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: _ModelLoadAction.cancel),
            child: const Text('Cancel'),
          ),
          if (hasLoadedModel)
            TextButton(
              onPressed: () => Get.back(result: _ModelLoadAction.unload),
              child: const Text('Unload'),
            ),
          if (isCriticallyLow)
            TextButton(
              onPressed: () async {
                Get.back(result: _ModelLoadAction.cancel);
                final hive = Get.find<HiveService>();
                final modelPath = await _download.modelPath(filename);
                await hive.setSetting(AppConstants.keyLocalModelName, filename);
                await hive.setSetting(AppConstants.keyLocalModelPath, modelPath);
                await hive.setSetting(AppConstants.keyLocalModelRuntime,
                    isLiteRt ? AiModel.runtimeLiteRt : AiModel.runtimeLlama);
                try {
                  await _androidImportChannel.invokeMethod('restartApp');
                } catch (_) {
                  SystemNavigator.pop();
                }
              },
              child: const Text('Restart app'),
            ),
          ElevatedButton(
            onPressed: () async {
              await _refreshAvailableRamGb();
              Get.back(result: _ModelLoadAction.continueLoad);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return result ?? _ModelLoadAction.cancel;
  }

  Future<bool> _confirmLiteRtGpuWarning() async {
    final mode = _settings.liteRtPerformanceMode.value;
    if (mode == 'cpu_safe') return true;

    final accepted = _hive.getSetting<bool>(
          AppConstants.keyLiteRtGpuWarningAccepted,
          defaultValue: false,
        ) ??
        false;
    if (accepted) return true;

    final modeLabel = mode == 'gpu_fast' ? 'GPU Fast' : 'Auto Fast';
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('$modeLabel LiteRT speed'),
        content: const Text(
          'GPU can make LiteRT models much faster, closer to Edge Gallery speed. '
          'On some phones GPU/OpenCL can crash the app while loading. '
          'If that happens, Auto Fast will use CPU on the next load.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Continue'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed == true) {
      await _hive.setSetting(AppConstants.keyLiteRtGpuWarningAccepted, true);
      return true;
    }
    return false;
  }

  bool _isLowMemoryBytes(int bytes) => bytes < 768 * 1024 * 1024;

  Future<double> _refreshAvailableRamGb() async {
    try {
      final device = Get.find<DeviceInfoService>();
      await device.refreshMemoryInfo();
      return device.availableRamGB.value;
    } catch (_) {
      return 0;
    }
  }

  void _showImageModelLoadingDialog(String filename) {
    final localImage = Get.find<LocalImageService>();
    final isDark = Get.isDarkMode;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161822) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Loading $filename',
                style: GoogleFonts.manrope(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0E1017),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Obx(() {
                final log = localImage.latestLog.value;
                return Text(
                  log.isEmpty ? 'Initializing on-device engine...' : log,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                );
              }),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> unloadModel() async {
    await _inference.unloadModel();
    await _localImage.unloadModel();
  }

  Future<void> importModelFromStorage() async {
    if (isImporting.value) {
      Get.snackbar(
          'Import in Progress', 'Wait for the current import to finish.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (Platform.isAndroid) {
      await _importModelWithAndroidPicker();
      return;
    }

    String? partialImportPath;
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: false,
        withReadStream: true,
      );

      if (result != null) {
        final picked = result.files.single;
        final filename = picked.name;
        final lower = filename.toLowerCase();

        if (!lower.endsWith('.gguf') &&
            !lower.endsWith('.litertlm') &&
            !lower.endsWith('.safetensors')) {
          Get.snackbar('Unsupported Model',
              'Only .gguf, .litertlm, and .safetensors files can be imported.',
              snackPosition: SnackPosition.BOTTOM);
          return;
        }

        final file = picked.path == null ? null : File(picked.path!);
        final totalBytes = picked.size > 0
            ? picked.size
            : file == null
                ? 0
                : await file.length();
        if (totalBytes <= 0) {
          Get.snackbar('Import Failed', 'The selected file is empty.',
              snackPosition: SnackPosition.BOTTOM);
          return;
        }

        final sourceStream = picked.readStream ?? file?.openRead();
        if (sourceStream == null) {
          Get.snackbar(
            'Import Failed',
            'Unable to read the selected file. Try selecting it from local storage.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

        final modelsDir = await _download.modelsDir;
        final destPath = '$modelsDir/$filename';
        final partPath = '$destPath.part';
        partialImportPath = partPath;
        final destFile = File(destPath);
        final partFile = File(partPath);
        var shouldReplace = false;

        if (await destFile.exists()) {
          final replace = await _confirmReplace(filename);
          if (!replace) return;
          shouldReplace = true;
        }

        isImporting.value = true;
        importFileName.value = filename;
        importStatus.value = 'Copying to app storage...';
        importCopiedBytes.value = 0;
        importTotalBytes.value = totalBytes;
        importBytesPerSecond.value = 0;

        if (await partFile.exists()) {
          await partFile.delete();
        }

        await _copyWithProgress(sourceStream, partFile);
        if (shouldReplace && await destFile.exists()) {
          await destFile.delete();
        }
        await partFile.rename(destPath);
        fileSizes[filename] = await File(destPath).length();

        await refreshDownloaded();
        localFilter.value = 'downloaded';
        importStatus.value = 'Import complete';
        Get.snackbar('Import Successful', 'Model $filename imported.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (partialImportPath != null) {
        final partialFile = File(partialImportPath);
        if (await partialFile.exists()) {
          await partialFile.delete();
        }
      }
      Get.find<AppLogService>().error('Model import failed', details: e);
      Get.snackbar('Import Failed', '$e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isImporting.value = false;
      importFileName.value = '';
      importStatus.value = '';
      importCopiedBytes.value = 0;
      importTotalBytes.value = 0;
      importBytesPerSecond.value = 0;
    }
  }

  Future<void> _importModelWithAndroidPicker() async {
    try {
      isImporting.value = true;
      importFileName.value = '';
      importStatus.value = 'Select a model file...';
      importCopiedBytes.value = 0;
      importTotalBytes.value = 0;
      importBytesPerSecond.value = 0;

      final result =
          await _androidImportChannel.invokeMapMethod<String, dynamic>(
        'pickAndImportModel',
        {'modelsDir': await _download.modelsDir},
      );

      if (result?['cancelled'] == true) return;

      final filename = result?['filename'] as String?;
      if (filename != null && filename.isNotEmpty) {
        fileSizes[filename] = (result?['bytes'] as num?)?.toInt() ??
            await _download.getModelSize(filename);
        await refreshDownloaded();
        localFilter.value = 'downloaded';
        Get.snackbar('Import Successful', 'Model $filename imported.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on PlatformException catch (e) {
      Get.find<AppLogService>().error(
        'Android model import failed',
        details: '${e.code}: ${e.message}',
      );
      Get.snackbar('Import Failed', e.message ?? e.code,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.find<AppLogService>()
          .error('Android model import failed', details: e);
      Get.snackbar('Import Failed', '$e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isImporting.value = false;
      importFileName.value = '';
      importStatus.value = '';
      importCopiedBytes.value = 0;
      importTotalBytes.value = 0;
      importBytesPerSecond.value = 0;
    }
  }

  Future<void> _copyWithProgress(
    Stream<List<int>> source,
    File destination,
  ) async {
    final startedAt = DateTime.now();
    final sink = destination.openWrite();
    try {
      await for (final chunk in source) {
        sink.add(chunk);
        importCopiedBytes.value += chunk.length;
        final elapsed =
            DateTime.now().difference(startedAt).inMilliseconds / 1000;
        if (elapsed > 0) {
          importBytesPerSecond.value = importCopiedBytes.value / elapsed;
        }
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<bool> _confirmReplace(String filename) async {
    final result = await Get.dialog<bool>(
      Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return AlertDialog(
            backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsBold.copy,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Model Already Exists',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'A model file named "$filename" is already imported in your local app storage. Would you like to replace it?',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Get.back(result: true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  'Replace File',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return result ?? false;
  }

  Future<void> _deletePartialImports() async {
    try {
      final dir = Directory(await _download.modelsDir);
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.part')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  String _getFriendlyErrorMessage(String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('unknown model architecture') ||
        lower.contains('unsupported model architecture')) {
      return 'This GGUF uses a model architecture that is not supported by the bundled llama.cpp runtime. Update the app runtime or try a GGUF exported for a supported architecture.';
    }
    if (lower.contains('missing key') ||
        lower.contains('failed to load gguf split')) {
      return 'This appears to be a split GGUF model, but one or more required model files are missing. Import every split into the same folder before loading it.';
    }
    if (lower.contains('failed to load model from buffer') ||
        lower.contains('invalid_argument') ||
        lower.contains('invalid gguf') ||
        lower.contains('missing or unreadable') ||
        lower.contains('incomplete') ||
        lower.contains('corrupt')) {
      return 'The model file appears to be incomplete or corrupted. This usually happens when the download is interrupted or the file is invalid.';
    }
    if (lower.contains('out of memory') ||
        lower.contains('allocate') ||
        lower.contains('oom') ||
        lower.contains('cannot allocate')) {
      return 'Your device ran out of memory (RAM) trying to load this model. Mobile devices have strict memory limits; try using a smaller or more highly quantized model (e.g., 1B or 3B parameters, q4_k_m quantized).';
    }
    if (lower.contains('opencl') ||
        lower.contains('vulkan') ||
        lower.contains('opengl') ||
        lower.contains('gpu') ||
        lower.contains('cl_') ||
        lower.contains('driver')) {
      return 'A hardware or GPU driver error occurred while initializing the model. Try disabling GPU acceleration or switching to CPU-only inference in Settings.';
    }
    return 'The native AI engine encountered an unexpected error while loading the model. Please check the technical details below for more information.';
  }

  Widget _buildTipRow(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
