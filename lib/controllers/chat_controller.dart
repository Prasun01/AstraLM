import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../controllers/settings_controller.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../ffi/sd_ffi_bindings.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/cloud_service.dart';
import '../services/local_image_service.dart';
import '../services/app_log_service.dart';
import '../services/image_generation_notification_service.dart';
import '../services/document_extractor_service.dart';
import '../utils/thought_parser.dart';

const int _visionImageMaxSide = 768;
const int _visionImageJpegQuality = 72;

Uint8List? _resizeVisionImageBytes(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final longestSide = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longestSide <= _visionImageMaxSide) {
    return bytes;
  }

  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? _visionImageMaxSide : null,
    height: decoded.height > decoded.width ? _visionImageMaxSide : null,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(
    img.encodeJpg(resized, quality: _visionImageJpegQuality),
  );
}

class ChatController extends GetxController {
  final HiveService _hive = Get.find<HiveService>();
  final _uuid = const Uuid();

  // State
  final sessions = <ChatSession>[].obs;
  final messages = <ChatMessage>[].obs;
  final currentSessionId = ''.obs;
  final isLoading = false.obs;
  final isBgWarningDismissed = false.obs;
  final inputText = ''.obs;
  final selectedImagePath = Rxn<String>();
  final selectedImageBase64 = Rxn<String>();
  final selectedFileName = Rxn<String>();
  final selectedFileContent = Rxn<String>();
  final selectedFilePath = Rxn<String>();
  final selectedFileType = Rxn<String>();
  final selectedFileSize = 0.obs;

  // Real-time streaming state — the AI response as it's being generated
  final streamingResponse = ''.obs;
  final isStreaming = false.obs;
  final streamingAttachmentType = Rxn<String>();

  // Image generation progress (lightweight, replaces text-heavy updates)
  final imageGenStep = 0.obs;
  final imageGenTotal = 0.obs;
  final imageGenEstimatedSecs = 0.obs;
  final imageGenStartTime = Rxn<DateTime>();
  final imageGenDecoding = false.obs;

  // Canvas Mode State (Gemini-style interactive document workspace)
  final isCanvasMode = false.obs;
  final isCanvasOpen = false.obs;
  final canvasTitle = 'Document'.obs;
  final canvasContent = ''.obs;
  final isCanvasEditing = false.obs;
  final canvasTextController = TextEditingController();
  final canvasHistory = <String>[].obs;
  final canvasLanguage = 'markdown'.obs;

  // Incognito Mode State (private session, chats not saved to history)
  final isIncognito = false.obs;

  void toggleIncognito() {
    isIncognito.value = !isIncognito.value;
    if (isIncognito.value) {
      messages.clear();
      currentSessionId.value = 'incognito_${_uuid.v4()}';
    } else {
      createNewChat();
    }
  }

  void toggleCanvasMode([bool? force]) {
    if (force != null) {
      isCanvasMode.value = force;
    } else {
      isCanvasMode.value = !isCanvasMode.value;
    }
  }

  void openNewCanvas() {
    canvasTitle.value = 'New Canvas';
    canvasContent.value = '';
    canvasTextController.clear();
    canvasHistory.clear();
    isCanvasEditing.value = true;
    isCanvasOpen.value = true;
    isCanvasMode.value = true;
  }

  void openCanvas({String? title, String? content, String? language}) {
    if (title != null && title.trim().isNotEmpty) {
      canvasTitle.value = title;
    } else if (content == null) {
      canvasTitle.value = 'New Canvas';
    }

    if (content != null) {
      final codeOnly = _extractCodeOnly(content);
      canvasContent.value = codeOnly;
      canvasTextController.text = codeOnly;
      if (!canvasHistory.contains(codeOnly)) {
        canvasHistory.add(codeOnly);
      }
      isCanvasEditing.value = false;
    } else {
      canvasContent.value = '';
      canvasTextController.clear();
      canvasHistory.clear();
      isCanvasEditing.value = true;
    }

    if (language != null) canvasLanguage.value = language;
    isCanvasOpen.value = true;
  }

  static String _extractCodeOnly(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Strip thought/think reasoning tags if present
    text = text.replaceAll(
      RegExp(r'<(?:thought|think)>[\s\S]*?</(?:thought|think)>', caseSensitive: false),
      '',
    ).trim();

    // 1. If text contains markdown code block fences (``` ... ```)
    final firstFenceStart = text.indexOf('```');
    if (firstFenceStart != -1) {
      final newlineAfterStart = text.indexOf('\n', firstFenceStart);
      if (newlineAfterStart != -1) {
        // Collect all closed code blocks
        final codeBlocks = <String>[];
        final fenceRegex = RegExp(r'```[^\n]*\r?\n([\s\S]*?)```', multiLine: true);
        for (final match in fenceRegex.allMatches(text)) {
          final block = match.group(1)?.trimRight();
          if (block != null && block.isNotEmpty) {
            codeBlocks.add(block);
          }
        }
        if (codeBlocks.isNotEmpty) {
          return codeBlocks.join('\n\n').trim();
        }

        // Partial / unclosed code block (e.g. streaming or truncated)
        final codeAfterOpen = text.substring(newlineAfterStart + 1);
        final closingFence = codeAfterOpen.lastIndexOf('```');
        if (closingFence != -1) {
          return codeAfterOpen.substring(0, closingFence).trim();
        } else {
          return codeAfterOpen.trim();
        }
      }
    }

    // 2. Check for pure HTML markup tags (e.g. <!DOCTYPE, <html>...</html>)
    final lower = text.toLowerCase();
    if (lower.contains('<html') && lower.contains('</html>')) {
      final start = lower.indexOf('<html');
      final end = lower.lastIndexOf('</html>');
      if (start != -1 && end != -1) {
        return text.substring(start, end + 7).trim();
      }
    } else if (lower.contains('<!doctype html>')) {
      final start = lower.indexOf('<!doctype html>');
      if (start != -1) {
        final end = lower.lastIndexOf('</html>');
        if (end != -1) {
          return text.substring(start, end + 7).trim();
        }
        return text.substring(start).trim();
      }
    }

    // 3. For Markdown documents, strip conversational intro/greeting before first heading
    final firstHeading = RegExp(r'^#{1,4}\s+', multiLine: true).firstMatch(text);
    if (firstHeading != null && firstHeading.start > 0) {
      return text.substring(firstHeading.start).trim();
    }

    return text;
  }

  void closeCanvas() {
    isCanvasOpen.value = false;
  }

  void updateCanvasContent(String newContent) {
    canvasContent.value = newContent;
    canvasTextController.text = newContent;
    if (canvasHistory.isEmpty || canvasHistory.last != newContent) {
      canvasHistory.add(newContent);
    }
  }

  void undoCanvas() {
    if (canvasHistory.length > 1) {
      canvasHistory.removeLast();
      final prev = canvasHistory.last;
      canvasContent.value = prev;
      canvasTextController.text = prev;
    }
  }

  void requestCanvasRevision(String instruction) {
    final currentDoc = canvasContent.value;
    final prompt = '$instruction\n\nHere is the current canvas document to update:\n```${canvasLanguage.value}\n$currentDoc\n```';
    textController.text = prompt;
    sendMessage();
  }

  String _deriveCanvasTitle(String text) {
    var cleaned = text.trim();
    if (cleaned.toLowerCase().startsWith('write a ') ||
        cleaned.toLowerCase().startsWith('write an ') ||
        cleaned.toLowerCase().startsWith('create a ') ||
        cleaned.toLowerCase().startsWith('draft a ')) {
      final firstSpace = cleaned.indexOf(' ');
      if (firstSpace >= 0) {
        cleaned = cleaned.substring(firstSpace + 1).trim();
        final secondSpace = cleaned.indexOf(' ');
        if (secondSpace >= 0) {
          cleaned = cleaned.substring(secondSpace + 1).trim();
        }
      }
    }
    if (cleaned.length > 30) {
      cleaned = '${cleaned.substring(0, 30).trim()}...';
    }
    if (cleaned.isEmpty) return 'Document';
    return cleaned;
  }

  // Speech-to-text
  final isListening = false.obs;
  final sttAvailable = false.obs;
  final _speech = stt.SpeechToText();

  final textController = TextEditingController();
  final scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _followStreaming = true;
  bool _scrollListenerAttached = false;
  int _generationSerial = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_handleUserScroll);
    _scrollListenerAttached = true;
    loadSessions();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      sttAvailable.value = await _speech.initialize(
        onError: (_) => isListening.value = false,
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListening.value = false;
          }
        },
      );
    } catch (_) {
      sttAvailable.value = false;
    }
  }

  Future<void> toggleListening() async {
    try {
      if (isListening.value) {
        await _speech.stop();
        isListening.value = false;
        return;
      }
      if (!sttAvailable.value) {
        try {
          final ok = await _speech.initialize();
          sttAvailable.value = ok;
        } catch (_) {
          sttAvailable.value = false;
        }
        if (!sttAvailable.value) return;
      }
      await _speech.listen(
        onResult: (result) {
          textController.text = result.recognizedWords;
          inputText.value = result.recognizedWords;
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_US',
      );
      isListening.value = true;
    } catch (_) {
      isListening.value = false;
    }
  }

  @override
  void onClose() {
    _scrollTimer?.cancel();
    if (_scrollListenerAttached) {
      scrollController.removeListener(_handleUserScroll);
    }
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // ─── Session Management ─────────────────────────

  void loadSessions() {
    final raw = _hive.getAllSessions();
    sessions.value = raw.map((m) => ChatSession.fromMap(m)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _ensureActiveSession() {
    if (isIncognito.value) {
      if (currentSessionId.value.isEmpty) {
        currentSessionId.value = 'incognito_${_uuid.v4()}';
      }
      return currentSessionId.value;
    }
    if (currentSessionId.value.isNotEmpty) {
      final exists = sessions.any((s) => s.id == currentSessionId.value);
      if (exists) return currentSessionId.value;
    }
    final id = _uuid.v4();
    final session = ChatSession(id: id, title: 'New Chat');
    _hive.saveSession(id, session.toMap());
    sessions.insert(0, session);
    currentSessionId.value = id;
    return id;
  }

  void createNewChat() {
    // If exiting an incognito session, automatically terminate incognito and clear private chat
    if (isIncognito.value) {
      isIncognito.value = false;
      messages.clear();
      currentSessionId.value = '';
    }
    // Do not allow new chat window if the current window is empty
    if (messages.isEmpty) {
      return;
    }
    final id = _uuid.v4();
    final session = ChatSession(id: id, title: 'New Chat');
    _hive.saveSession(id, session.toMap());
    sessions.insert(0, session);
    openChat(id);
  }

  void _resetInferenceContext() {
    final inference = Get.find<InferenceService>();
    if (inference.isModelLoaded.value) {
      unawaited(inference.resetConversation());
    }
  }

  void openChat(String sessionId) {
    stopGenerating();
    // Switching chats automatically exits and deletes single-session incognito mode
    if (isIncognito.value) {
      isIncognito.value = false;
      messages.clear();
    }
    currentSessionId.value = sessionId;
    final raw = _hive.getMessagesForChat(sessionId);
    messages.value = raw.map((m) => ChatMessage.fromMap(m)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final inference = Get.find<InferenceService>();
    if (inference.isModelLoaded.value) {
      inference.refreshContextInfo();
    }
    _resetInferenceContext();
    _scrollToBottom(force: true);
  }

  void deleteChat(String sessionId) {
    if (currentSessionId.value == sessionId && isLoading.value) {
      stopGenerating();
    }
    _hive.deleteSession(sessionId);
    sessions.removeWhere((s) => s.id == sessionId);
    if (currentSessionId.value == sessionId) {
      currentSessionId.value = '';
      messages.clear();
    }
  }

  // ─── Image Handling ─────────────────────────────

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _visionImageMaxSide.toDouble(),
      maxHeight: _visionImageMaxSide.toDouble(),
      imageQuality: _visionImageJpegQuality,
    );
    if (file != null) {
      selectedImagePath.value = file.path;
      selectedImageBase64.value = null;
      selectedFileName.value = file.name;
      selectedFilePath.value = file.path;
      selectedFileType.value = 'image';
      selectedFileSize.value = await file.length();
      selectedFileContent.value = null;
      _checkVisionSupport();
    }
  }

  Future<void> pickCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _visionImageMaxSide.toDouble(),
      maxHeight: _visionImageMaxSide.toDouble(),
      imageQuality: _visionImageJpegQuality,
    );
    if (file != null) {
      selectedImagePath.value = file.path;
      selectedImageBase64.value = null;
      selectedFileName.value = file.name;
      selectedFilePath.value = file.path;
      selectedFileType.value = 'image';
      selectedFileSize.value = await file.length();
      selectedFileContent.value = null;
      _checkVisionSupport();
    }
  }

  void clearImage({bool deleteFile = true}) {
    final path = selectedImagePath.value;
    selectedImagePath.value = null;
    selectedImageBase64.value = null;
    if (deleteFile && path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    if (selectedFileType.value == 'image') {
      clearFile();
    }
  }

  void _checkVisionSupport() {
    final s = Get.find<SettingsController>();
    if (s.inferenceMode.value != 'cloud') return;
    
    final provider = s.cloudProvider.value;
    String modelName = '';
    switch (provider) {
      case 'anthropic': modelName = s.anthropicModel.value; break;
      case 'google': modelName = s.googleModel.value; break;
      case 'kimi': modelName = s.kimiModel.value; break;
      case 'stability': modelName = s.stabilityModel.value; break;
      case 'nvidia': modelName = s.nvidiaModel.value; break;
      case 'openrouter': modelName = s.openRouterModel.value; break;
      case 'deepseek': modelName = s.deepSeekModel.value; break;
      case 'custom': modelName = s.customCloudModel.value; break;
      default: modelName = s.openaiModel.value; break;
    }
    
    final model = modelName.toLowerCase();
    
    // Known vision keywords in cloud model names
    final isVision = model.contains('vision') || 
                     model.contains('-vl') || 
                     model.contains('gpt-4o') || 
                     model.contains('claude-3') || 
                     model.contains('gemini') || 
                     model.contains('pixtral') || 
                     model.contains('llava') ||
                     model.contains('omni');
                     
    if (!isVision) {
      Get.snackbar(
        'Warning: Text-Only Model',
        'The selected model ($modelName) might not support images. If you get an error, switch to a vision model (like Gemini, GPT-4o, or Claude 3).',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFFFF9500).withValues(alpha: 0.95), // Warning Orange
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'heic',
          'pdf',
          'docx',
          'mp3',
          'm4a',
          'wav',
          'aac',
          'ogg',
          'flac',
          'txt',
          'md',
          'json',
          'csv',
          'log',
          'yaml',
          'yml',
          'xml',
          'dart',
          'kt',
          'java',
          'js',
          'ts',
          'py'
        ],
        withData: kIsWeb,
      );
      if (result == null) return;
      final file = result.files.single;
      final extension = file.extension?.toLowerCase() ?? '';
      final fileType = _attachmentTypeForExtension(extension);

      // Reject unsupported or extension-less files
      if (extension.isEmpty || fileType == 'file') {
        Get.snackbar(
          'Unsupported file',
          'Only images, audio, PDF, DOCX, and text/code files are supported.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (fileType == 'image') {
        final bytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) return;
        final optimizedPath = await _prepareVisionImagePath(
          bytes: bytes,
          originalName: file.name,
          fallbackPath: file.path,
        );

        selectedFileName.value = file.name;
        selectedFilePath.value = optimizedPath;
        selectedFileType.value = 'image';
        selectedFileSize.value = await File(optimizedPath).length();
        selectedFileContent.value = null;
        selectedImagePath.value = optimizedPath;
        selectedImageBase64.value = null;
        _checkVisionSupport();
        return;
      }

      selectedFileName.value = file.name;
      selectedFilePath.value = file.path;
      selectedFileType.value = fileType;
      selectedFileSize.value = file.size;
      selectedFileContent.value = null;

      selectedImagePath.value = null;
      selectedImageBase64.value = null;

      final inferenceMode = _hive.getSetting(
            AppConstants.keyInferenceMode,
            defaultValue: 'local',
          ) ??
          'local';
      final maxDocChars = inferenceMode == 'local' ? 12000 : 500000;

      if (fileType == 'pdf' || fileType == 'docx') {
        final path = file.path;
        if (path != null) {
          try {
            var content = await DocumentExtractorService.extractText(
              path,
              extension,
            );
            if (content.length > maxDocChars) {
              content =
                  '${content.substring(0, maxDocChars)}\n\n[File truncated for context size]';
            }
            selectedFileContent.value = content;
          } catch (e) {
            Get.find<AppLogService>().warning(
              'Document extraction failed',
              details: e,
            );
            selectedFileContent.value =
                '[Could not extract text from ${selectedFileName.value}: $e]';
          }
        }
      } else if (fileType == 'text') {
        final bytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) return;
        selectedFileSize.value = file.size > 0 ? file.size : bytes.length;
        var content = utf8.decode(bytes, allowMalformed: true);
        if (content.length > maxDocChars) {
          content =
              '${content.substring(0, maxDocChars)}\n\n[File truncated for context size]';
        }
        selectedFileContent.value = content;
      }
    } catch (e) {
      Get.find<AppLogService>().warning('File attachment failed', details: e);
      Get.snackbar('File not attached', '$e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void clearFile() {
    selectedFileName.value = null;
    selectedFileContent.value = null;
    selectedFilePath.value = null;
    selectedFileType.value = null;
    selectedFileSize.value = 0;
  }

  Future<String> _prepareVisionImagePath({
    required Uint8List bytes,
    required String originalName,
    String? fallbackPath,
  }) async {
    final resized = await compute(_resizeVisionImageBytes, {'bytes': bytes});
    if (resized == null) {
      if (fallbackPath != null && fallbackPath.isNotEmpty) return fallbackPath;
      final tempDir = await getTemporaryDirectory();
      final failedDecodeFile = File(
        '${tempDir.path}/ai_chat_image_${DateTime.now().millisecondsSinceEpoch}_$originalName',
      );
      await failedDecodeFile.writeAsBytes(bytes, flush: false);
      return failedDecodeFile.path;
    }

    if (resized.length == bytes.length &&
        fallbackPath != null &&
        fallbackPath.isNotEmpty) {
      return fallbackPath;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/ai_chat_vision_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(resized, flush: false);
    return file.path;
  }

  // ─── Send Message ───────────────────────────────

  Future<void> sendMessage({String? customPrompt, bool isSystemObservation = false}) async {
    if (isLoading.value || isStreaming.value) return;

    final text = customPrompt ?? textController.text.trim();
    final hasAttachment =
        !isSystemObservation && (selectedImagePath.value != null || selectedFileName.value != null);
    if (text.isEmpty && !hasAttachment) return;
    final fileName = isSystemObservation ? null : selectedFileName.value;
    final fileContent = isSystemObservation ? null : selectedFileContent.value;
    final filePath = isSystemObservation ? null : selectedFilePath.value;
    final fileType = isSystemObservation ? null : selectedFileType.value;
    final fileSize = isSystemObservation ? 0 : selectedFileSize.value;
    final imagePath = isSystemObservation ? null : selectedImagePath.value;
    final imageBase64 = isSystemObservation ? null : selectedImageBase64.value;
    final visibleText =
        text.isEmpty ? _defaultAttachmentPrompt(fileType) : text;
    final effectiveText = (fileContent != null && fileContent.trim().isNotEmpty)
        ? '$visibleText\n\nAttached file: $fileName\n```text\n$fileContent\n```'
        : visibleText;

    // Create / ensure an active session exists before processing message
    final activeChatId = _ensureActiveSession();

    // Encode image to base64 if it's not already pre-encoded, so the message
    // saved in history contains the image bytes and is 100% stable.
    String? imgBase64 = imageBase64;
    if (imgBase64 == null && imagePath != null && !kIsWeb) {
      try {
        imgBase64 = base64Encode(await File(imagePath).readAsBytes());
      } catch (_) {}
    }

    // Add user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: activeChatId,
      role: 'user',
      content: effectiveText,
      imageBase64: imgBase64, // Always save the encoded base64 string
      imagePath: imagePath,
      fileName: fileName,
      fileContent: fileContent,
      filePath: filePath,
      fileType: fileType,
      fileSize: fileSize > 0 ? fileSize : null,
    );
    messages.add(userMsg);
    if (!isIncognito.value) {
      _hive.saveMessage(userMsg.id, userMsg.toMap());
    }

    // Clear input preview UI state — but KEEP the physical file on disk 
    // because the native inference engine needs to read it during generation.
    textController.clear();
    inputText.value = '';
    clearImage(deleteFile: false); // Reset visual fields, do NOT delete file!
    clearFile();
    _scrollToBottom(force: true);

    // Update session title (use first message as title)
    if (!isIncognito.value && messages.where((m) => m.role == 'user').length == 1) {
      final title = visibleText.length > 40
          ? '${visibleText.substring(0, 40)}...'
          : visibleText;
      final session = sessions.firstWhereOrNull((s) => s.id == activeChatId);
      if (session != null) {
        final updated = session.copyWith(title: title, lastMessage: visibleText);
        _hive.saveSession(updated.id, updated.toMap());
        final idx = sessions.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) sessions[idx] = updated;
      }
    }

    // Start generating
    final generationId = ++_generationSerial;
    isLoading.value = true;
    isStreaming.value = true;
    streamingAttachmentType.value =
        (imagePath != null || fileType == 'audio') ? fileType : null;
    streamingResponse.value = '';

    if (isCanvasMode.value) {
      isCanvasOpen.value = true;
      canvasTitle.value = _deriveCanvasTitle(visibleText);
      canvasContent.value = '';
      canvasTextController.clear();
    }

    _followStreaming = true;
    _scrollToBottom(force: true);

    try {
      DateTime? thoughtStartedAt;
      int? thoughtDurationSeconds;

      void trackThoughtTiming() {
        final parts = splitThoughtTags(streamingResponse.value, isStreaming: true);
        if (parts.hasThought && thoughtStartedAt == null) {
          thoughtStartedAt = DateTime.now();
        }
        if (!parts.isThinking &&
            thoughtStartedAt != null &&
            thoughtDurationSeconds == null) {
          final diff = DateTime.now().difference(thoughtStartedAt!).inSeconds;
          thoughtDurationSeconds = diff > 0 ? diff : 1;
        }
      }

      final inferenceMode = _hive.getSetting(
            AppConstants.keyInferenceMode,
            defaultValue: 'local',
          ) ??
          'local';

      String rawResponse;

      // Build conversation history
      final history = messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {
                'role': m.role,
                'content': m.role == 'assistant'
                    ? splitThoughtTags(m.content).answer
                    : m.content,
              })
          .toList();

      if (inferenceMode == 'local') {
        final localImage = Get.find<LocalImageService>();

        if (localImage.isModelLoaded.value) {
          // Local image generation
          final settings = Get.find<SettingsController>();
          final imageNotifications =
              Get.find<ImageGenerationNotificationService>();
          final steps = _hive.getSetting<int>(AppConstants.keyImageSteps,
              defaultValue: AppConstants.defaultImageSteps) ??
              AppConstants.defaultImageSteps;
          final sizeSetting = settings.imageGenSize.value;
          final sizeLabel =
              sizeSetting == 0 ? 'Auto size' : '${sizeSetting}x$sizeSetting';
          final backendLabel = localImage.currentBackend.value == Backend.cpu
              ? 'CPU'
              : localImage.currentBackend.value.displayName
                  .split(' ')
                  .first
                  .toUpperCase();
          imageGenStep.value = 0;
          imageGenTotal.value = steps;
          imageGenEstimatedSecs.value = 0;
          imageGenStartTime.value = DateTime.now();
          imageGenDecoding.value = false;
          await imageNotifications.start(
            modelName: localImage.loadedModelName.value,
            backend: backendLabel,
            steps: steps,
            sizeLabel: sizeLabel,
          );
          print('[ChatController] Starting image generation for: $text');
          final pngBytes = await localImage.generateImage(
            prompt: text,
            onProgress: (step, total) {
              if (generationId != _generationSerial) return;
              imageGenStep.value = step;
              imageGenTotal.value = total;
              if (step >= total && total > 0) {
                imageGenDecoding.value = true;
                print('[ChatController] Sampling complete, VAE decode in progress');
                imageNotifications.decoding();
              }
              if (step > 0 && total > 0 && step < total) {
                final start = imageGenStartTime.value;
                if (start != null) {
                  final elapsed = DateTime.now().difference(start).inMilliseconds;
                  final avgMsPerStep = elapsed / step;
                  final remainingSteps = total - step;
                  imageGenEstimatedSecs.value =
                      (avgMsPerStep * remainingSteps / 1000).ceil();
                }
              }
              imageNotifications.update(
                step: step,
                total: total,
                etaSeconds: imageGenEstimatedSecs.value,
                elapsedSeconds: imageGenStartTime.value == null
                    ? 0
                    : DateTime.now()
                        .difference(imageGenStartTime.value!)
                        .inSeconds,
              );
              _scrollToBottom();
            },
          );
          // Calculate total generation time
          final genDurationMs = imageGenStartTime.value != null
              ? DateTime.now().difference(imageGenStartTime.value!).inMilliseconds
              : null;
          print('[ChatController] generateImage returned, bytes=${pngBytes?.length}, duration=${genDurationMs}ms');

          if (pngBytes != null) {
            await imageNotifications.complete(durationMs: genDurationMs ?? 0);
            rawResponse = '[IMAGE_BASE64]${base64Encode(pngBytes)}';
          } else {
            await imageNotifications.failed();
            rawResponse = 'Local image generation failed.';
          }
        } else {
          final inference = Get.find<InferenceService>();

          // LiteRT models can consume image/audio attachments. GGUF currently
          // returns a clear unsupported message from the inference layer.

          rawResponse = await inference.generate(
            prompt: effectiveText,
            systemPrompt: _effectiveSystemPrompt,
            conversationHistory: history,
            source: 'chat',
            imagePath: imagePath,
            audioPath: fileType == 'audio' ? filePath : null,
            onToken: (token) {
              // Real-time streaming update
              streamingResponse.value += token;
              trackThoughtTiming();
              if (isCanvasMode.value) {
                final clean = splitThoughtTags(streamingResponse.value).answer;
                canvasContent.value = clean;
                canvasTextController.text = clean;
              }
              _scrollToBottom();
            },
          );
        }
      } else {
        final cloud = Get.find<CloudService>();
        final apiMessages = [
          {'role': 'system', 'content': _effectiveSystemPrompt},
          ...history,
        ];
        rawResponse = await cloud.sendMessage(
          messages: apiMessages,
          imageBase64: imgBase64, // already encoded before clearImage()
          onToken: (token) {
            streamingResponse.value += token;
            trackThoughtTiming();
            if (isCanvasMode.value) {
              final clean = splitThoughtTags(streamingResponse.value).answer;
              canvasContent.value = clean;
              canvasTextController.text = clean;
            }
            _scrollToBottom();
          },
        );
      }

      if (streamingResponse.value.trim().isEmpty &&
          rawResponse.isNotEmpty &&
          !rawResponse.startsWith('ERROR:') &&
          !rawResponse.startsWith('[IMAGE_BASE64]')) {
        // Smooth progressive stream-of-words for non-SSE responses
        final words = rawResponse.split(' ');
        for (int i = 0; i < words.length; i++) {
          if (generationId != _generationSerial) return;
          final space = i == 0 ? '' : ' ';
          streamingResponse.value += '$space${words[i]}';
          _scrollToBottom();
          final delayMs =
              words.length > 200 ? 6 : (words.length > 80 ? 12 : 18);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
        await Future.delayed(const Duration(milliseconds: 80));
      }

      if (thoughtStartedAt != null && thoughtDurationSeconds == null) {
        thoughtDurationSeconds =
            DateTime.now().difference(thoughtStartedAt!).inSeconds;
      }

      if (generationId != _generationSerial) return;

      // Stop streaming UI
      final tps = inferenceMode == 'local'
          ? Get.find<InferenceService>().tokensPerSecond.value
          : null;
      isStreaming.value = false;
      streamingAttachmentType.value = null;
      streamingResponse.value = '';
      imageGenStep.value = 0;
      imageGenTotal.value = 0;
      imageGenDecoding.value = false;

      if (isCanvasMode.value) {
        final finalDoc = splitThoughtTags(rawResponse).answer;
        updateCanvasContent(finalDoc);
      }

      String? outImageBase64;
      if (rawResponse.startsWith('[IMAGE_BASE64]')) {
        outImageBase64 = rawResponse.substring('[IMAGE_BASE64]'.length);
        rawResponse = 'Here is your generated image:';
      }

      // Calculate total generation time for image gen
      final genDurationMs = imageGenStartTime.value != null
          ? DateTime.now().difference(imageGenStartTime.value!).inMilliseconds
          : null;

      // Display response directly (no command processing)
      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        chatId: currentSessionId.value,
        role: 'assistant',
        content: rawResponse,
        imageBase64: outImageBase64,
        isCanvas: isCanvasMode.value,
        canvasTitle: isCanvasMode.value ? canvasTitle.value : null,
        tokensPerSec: tps,
        thoughtDurationSeconds: thoughtDurationSeconds,
        imageGenDurationMs: genDurationMs,
      );
      messages.add(aiMsg);
      if (!isIncognito.value) {
        _hive.saveMessage(aiMsg.id, aiMsg.toMap());
      }
      imageGenStartTime.value = null;

      // Update session
      if (!isIncognito.value) {
        final session =
            sessions.firstWhereOrNull((s) => s.id == currentSessionId.value);
        if (session != null) {
          final updated = session.copyWith(lastMessage: aiMsg.content);
          _hive.saveSession(updated.id, updated.toMap());
          final idx = sessions.indexWhere((s) => s.id == updated.id);
          if (idx >= 0) sessions[idx] = updated;
        }
      }
    } catch (e) {
      if (generationId != _generationSerial) return;
      isStreaming.value = false;
      streamingAttachmentType.value = null;
      streamingResponse.value = '';
      imageGenStep.value = 0;
      imageGenTotal.value = 0;
      imageGenDecoding.value = false;
      if (imageGenStartTime.value != null) {
        await Get.find<ImageGenerationNotificationService>().failed();
      }
      imageGenStartTime.value = null;
      Get.find<AppLogService>().error('Chat response failed', details: e);
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        chatId: currentSessionId.value,
        role: 'assistant',
        content: 'Error: $e',
      );
      messages.add(errorMsg);
      _hive.saveMessage(errorMsg.id, errorMsg.toMap());
    }

    if (generationId == _generationSerial) {
      isLoading.value = false;
      _scrollToBottom();
    }
  }

  void stopGenerating() {
    if (!isLoading.value && !isStreaming.value) return;
    final partialResponse = streamingResponse.value.trim();
    if (partialResponse.isNotEmpty) {
      final tps = Get.find<InferenceService>().tokensPerSecond.value;
      _saveAssistantMessage(
        content: partialResponse,
        tokensPerSec: tps > 0 ? tps : null,
      );
    }
    _generationSerial++;
    isLoading.value = false;
    isStreaming.value = false;
    streamingAttachmentType.value = null;
    streamingResponse.value = '';
    Get.find<ImageGenerationNotificationService>().cancel();
    imageGenStep.value = 0;
    imageGenTotal.value = 0;
    imageGenEstimatedSecs.value = 0;
    imageGenStartTime.value = null;
    imageGenDecoding.value = false;
    // Eagerly mark inference as stopped so next sendMessage() is not blocked.
    final inf = Get.find<InferenceService>();
    inf.isGenerating.value = false;
    unawaited(inf.stopGeneration());
    Get.find<LocalImageService>().cancelGeneration();
  }

  void _saveAssistantMessage({
    required String content,
    String? imageBase64,
    double? tokensPerSec,
    int? thoughtDurationSeconds,
  }) {
    final aiMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: currentSessionId.value,
      role: 'assistant',
      content: content,
      imageBase64: imageBase64,
      tokensPerSec: tokensPerSec,
      thoughtDurationSeconds: thoughtDurationSeconds,
    );
    messages.add(aiMsg);

    if (!isIncognito.value) {
      _hive.saveMessage(aiMsg.id, aiMsg.toMap());

      final session =
          sessions.firstWhereOrNull((s) => s.id == currentSessionId.value);
      if (session != null) {
        final updated = session.copyWith(lastMessage: aiMsg.content);
        _hive.saveSession(updated.id, updated.toMap());
        final idx = sessions.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) sessions[idx] = updated;
      }
    }
  }

  void _handleUserScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (!isStreaming.value) {
      _followStreaming = distanceFromBottom <= 180;
    } else if (distanceFromBottom <= 48) {
      _followStreaming = true;
    }
  }

  void pauseStreamingFollow() {
    if (isStreaming.value) {
      _followStreaming = false;
    }
  }

  void resumeStreamingFollowIfNearBottom() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (distanceFromBottom <= 48) {
      _followStreaming = true;
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && isStreaming.value && !_followStreaming) return;
    if (_scrollTimer?.isActive == true) return;

    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      if (!scrollController.hasClients) return;
      if (!force && isStreaming.value && !_followStreaming) return;
      final target = scrollController.position.maxScrollExtent;
      if ((target - scrollController.position.pixels).abs() < 8) return;
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String get _effectiveSystemPrompt {
    final settings = Get.find<SettingsController>();
    final inference = Get.find<InferenceService>();
    final modelName = settings.inferenceMode.value == 'local'
        ? inference.loadedModelName.value
        : settings.selectedCloudModelName;
    var prompt = settings.effectiveSystemPromptForModel(
      modelName,
    );
    if (isCanvasMode.value) {
      const canvasInstruction =
          'CANVAS WORKSPACE MODE: You are generating or updating content directly into an interactive document/code Canvas editor. Focus on delivering clean, complete, well-formatted markdown or code without conversational preambles so that the document is immediately usable.';
      prompt = prompt.isEmpty ? canvasInstruction : '$prompt\n\n$canvasInstruction';
    }

    final effort = settings.reasoningEffort.value;
    if (effort == 'none') {
      const noReasoningInstruction =
          'DIRECT RESPONSE DIRECTIVE: Respond directly, accurately, and concisely. Do NOT generate internal reasoning or thought blocks. Provide the direct answer immediately.';
      prompt = prompt.isEmpty ? noReasoningInstruction : '$prompt\n\n$noReasoningInstruction';
    } else if (effort == 'deep') {
      const deepReasoningInstruction =
          'DEEP REASONING DIRECTIVE: Perform exhaustive, step-by-step reasoning inside <think> tags. Explore assumptions, multiple angles, and verify edge cases thoroughly before writing your final answer.';
      prompt = prompt.isEmpty ? deepReasoningInstruction : '$prompt\n\n$deepReasoningInstruction';
    }

    return prompt;
  }

  String _attachmentTypeForExtension(String extension) {
    const imageExtensions = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'heic'};
    const audioExtensions = {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'};
    const textExtensions = {
      'txt',
      'md',
      'json',
      'csv',
      'log',
      'yaml',
      'yml',
      'xml',
      'dart',
      'kt',
      'java',
      'js',
      'ts',
      'py',
    };
    if (imageExtensions.contains(extension)) return 'image';
    if (audioExtensions.contains(extension)) return 'audio';
    if (extension == 'pdf') return 'pdf';
    if (extension == 'docx') return 'docx';
    if (textExtensions.contains(extension)) return 'text';
    return 'file';
  }

  String _defaultAttachmentPrompt(String? fileType) {
    switch (fileType) {
      case 'image':
        return 'Describe this image.';
      case 'pdf':
        return 'Summarize this PDF.';
      case 'docx':
        return 'Summarize this document.';
      case 'audio':
        return 'Transcribe or analyze this audio.';
      case 'text':
        return 'Review this file.';
      default:
        return 'Review this attachment.';
    }
  }
}
