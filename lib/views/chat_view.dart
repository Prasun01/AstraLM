import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/chat_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/model_controller.dart';
import '../models/chat_session.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import '../ffi/sd_ffi_bindings.dart';
import '../utils/thought_parser.dart';
import '../widgets/attachment_preview.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/thought_disclosure.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/canvas_workspace.dart';
import 'model_view.dart';
import 'settings_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/icons.dart';

class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCanvasOpen = controller.isCanvasOpen.value;
      return Scaffold(
        drawer: _buildSidebarDrawer(context),
        drawerEnableOpenDragGesture: true,
        drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.45,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: isCanvasOpen ? null : _appBar(context),
        body: Builder(
          builder: (scaffoldCtx) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 280) {
                Scaffold.of(scaffoldCtx).openDrawer();
              }
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    _modelLoadingBar(context),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Obx(() {
                    if (controller.currentSessionId.value.isEmpty ||
                        controller.messages.isEmpty) {
                      return _emptyState(context);
                    }
                    final streaming = controller.isStreaming.value;
                    final text = controller.streamingResponse.value;
                    final n = controller.messages.length;
                    return NotificationListener<ScrollUpdateNotification>(
                      onNotification: (note) {
                        if (note.dragDetails != null && streaming) {
                          if ((note.scrollDelta ?? 0) < 0) {
                            controller.pauseStreamingFollow();
                          } else {
                            controller.resumeStreamingFollowIfNearBottom();
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: controller.scrollController,
                        padding: const EdgeInsets.only(top: 14, bottom: 20),
                        itemCount: n + (streaming ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == n && streaming) {
                            return _streamBubble(context, text);
                          }
                          return ChatBubble(
                            message: controller.messages[i],
                          );
                        },
                      ),
                    );
                  }),
                ),
                // Slight top gradient fade
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 24,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).scaffoldBackgroundColor,
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Spread bottom gradient fade behind floating input bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 64,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withValues(alpha: 0.95),
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withValues(alpha: 0.5),
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              ),
            ),
            _inputBar(context),
          ],
        ),
        const Positioned.fill(
          child: CanvasWorkspace(),
        ),
      ],
    ),
  ),
),
      );
    });
  }

  // ── AppBar ──
  PreferredSizeWidget _appBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 64,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: Builder(
            builder: (ctx) => PressableScale(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141620) : const Color(0xFFE9EDF5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIconsBold.list,
                    size: 20,
                    color: isDark ? const Color(0xFFE2E6F2) : const Color(0xFF161822),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      title: Obx(() {
        final settings = Get.find<SettingsController>();
        final inf = Get.find<InferenceService>();
        final localImage = Get.find<LocalImageService>();
        final isLocal = settings.inferenceMode.value == 'local';
        String model;
        bool isModelActive = false;

        if (isLocal) {
          if (inf.isModelLoaded.value) {
            isModelActive = true;
            model = inf.loadedModelName.value
                .replaceAll('.gguf', '')
                .replaceAll('.GGUF', '');
          } else if (localImage.isModelLoaded.value) {
            isModelActive = true;
            final backend = localImage.currentBackend.value;
            final backendName = backend.displayName.split(' ').first;
            model =
                '$backendName · ${localImage.loadedModelName.value.replaceAll('.gguf', '').replaceAll('.GGUF', '')}';
          } else {
            model = 'No model loaded';
          }
          if (model.length > 24) model = '${model.substring(0, 24)}…';
        } else {
          isModelActive = true;
          final p = settings.cloudProvider.value;
          model = p == 'openai'
              ? settings.openaiModel.value
              : p == 'anthropic'
                  ? settings.anthropicModel.value
                  : p == 'google'
                      ? settings.googleModel.value
                      : p == 'stability'
                          ? settings.stabilityModel.value
                          : p == 'nvidia'
                              ? settings.nvidiaModel.value
                              : p == 'openrouter'
                                  ? settings.openRouterModel.value
                                  : p == 'custom'
                                      ? settings.customCloudModel.value
                                      : settings.kimiModel.value;
          if (p == 'custom' && model.isNotEmpty) {
            model = '${settings.customCloudName.value}: $model';
          }
          if (model.length > 24) model = '${model.substring(0, 24)}…';
        }

        return PressableScale(
          onTap: () => Navigator.of(context).push(
            _topFillTransitionRoute(const ModelView()),
          ),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.62,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141620) : const Color(0xFFE9EDF5),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7.5,
                  height: 7.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isModelActive
                        ? const Color(0xFF34C759)
                        : const Color(0xFF8E95A8),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    model,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF12141D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLocal && inf.isGpuAccelerated.value) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF222634) : const Color(0xFFDCE2EC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GPU',
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF12141D),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
      actions: [
        // Small Incognito Button
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(
            child: Obx(() {
              final active = controller.isIncognito.value;
              return PressableScale(
                onTap: controller.toggleIncognito,
                child: Tooltip(
                  message: active ? 'Incognito Mode: ON' : 'Incognito Mode: OFF',
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: active
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? const Color(0xFF141620) : const Color(0xFFE9EDF5)),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        active ? PhosphorIconsBold.maskHappy : PhosphorIconsBold.detective,
                        size: 18,
                        color: active
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? const Color(0xFFE2E6F2) : const Color(0xFF161822)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Model Loading Top Island ──
  Widget _modelLoadingBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final inf = Get.find<InferenceService>();
      final localImage = Get.find<LocalImageService>();
      final isLoading =
          inf.isLoadingModel.value || localImage.isLoadingModel.value;
      if (!isLoading) return const SizedBox.shrink();

      final modelName = inf.isLoadingModel.value
          ? inf.loadingModelName.value
              .replaceAll('.gguf', '')
              .replaceAll('.GGUF', '')
          : (localImage.loadedModelName.value.isNotEmpty
              ? localImage.loadedModelName.value
              : 'Image Model');
      final progressVal =
          inf.isLoadingModel.value ? inf.modelLoadProgress.value : 0.0;
      final pct = (progressVal * 100).toStringAsFixed(0);

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1D25) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3240) : const Color(0xFFD6DBE5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                value: progressVal > 0 ? progressVal : null,
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    modelName.isNotEmpty ? modelName : 'Loading Model',
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progressVal > 0
                        ? 'Allocating memory · $pct%'
                        : 'Initializing model runtime...',
                    style: GoogleFonts.openSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (progressVal > 0)
              Text(
                '$pct%',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
          ],
        ),
      );
    });
  }

  // ── Empty State ──
  Widget _emptyState(BuildContext context) {
    final suggestions = [
      'Write a poem',
      'Explain quantum physics',
      'Summarize a complex text',
      'Help me debug my code'
    ];
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, anim, child) => Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1 - anim) * 14),
            child: child,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Obx(() {
              final inf = Get.find<InferenceService>();
              final loadedName = inf.loadedModelName.value;
              final modelTitle = loadedName.isNotEmpty
                  ? loadedName.replaceAll('.gguf', '').replaceAll('.GGUF', '')
                  : 'AstraLM';
              return Column(
                children: [
                  const _RotatingAppLogo(size: 84),
                  const SizedBox(height: 20),
                  Text(
                    modelTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How can I help you today?',
                    style: GoogleFonts.inter(
                      fontSize: 15.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),
            Obx(() {
              final settings = Get.find<SettingsController>();
              final models = Get.find<ModelController>();
              final isLocal = settings.inferenceMode.value == 'local';
              if (isLocal && models.downloadedCount == 0) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    PhosphorIcon(PhosphorIconsBold.arrowDown,
                        color: scheme.primary, size: 36),
                    const SizedBox(height: 14),
                    Text('No Local Models',
                        style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                        'You need to download a model to use local inference on your device.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ModelView())),
                      icon: PhosphorIcon(PhosphorIconsBold.arrowDown, size: 18),
                      label: const Text('Go to Models'),
                      style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: GoogleFonts.manrope(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                );
              }
              return Column(
                children: suggestions
                    .map((s) => _suggestionChip(context, s))
                    .toList(),
              );
            }),
          ],
        ),
      ),
    ),
    );
  }

  Widget _suggestionChip(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFD0D5E4) : const Color(0xFF2C3140);
    final iconColor = isDark ? const Color(0xFF6B7285) : const Color(0xFF9AA0B0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: PressableScale(
        pressedScale: 0.97,
        onTap: () {
          controller.createNewChat();
          controller.textController.text = text;
          controller.inputText.value = text;
          controller.sendMessage();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.openSans(
                    fontSize: 15,
                    color: textColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              PhosphorIcon(
                PhosphorIconsBold.arrowRight,
                size: 16,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Streaming message (assistant: no bubble — text on scaffold) ──
  Widget _streamBubble(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final attType = controller.streamingAttachmentType.value;
    final isImageGen = controller.imageGenTotal.value > 0;
    final clean = _cleanStream(text).trimLeft();
    final parts = splitThoughtTags(clean, isStreaming: true);
    final answer = parts.answer.trimLeft();
    final hasThought = parts.hasThought;
    final hasAnswer = _hasPrintable(answer);
    final hasText = hasThought || hasAnswer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImageGen)
                  _ImageGenIndicator(controller: controller)
                else if (!hasText)
                  _typingHint(context, attachmentType: attType)
                else ...[
                  if (hasThought)
                    ThoughtDisclosure(
                      thought: parts.thought,
                      isThinking: parts.isThinking,
                      styleSheet: _thoughtMd(context),
                    ),
                  if (hasAnswer)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: MarkdownBody(
                        data: answer,
                        selectable: true,
                        styleSheet: _streamMd(context),
                      ),
                    ),
                ],
                if (hasText && !isImageGen)
                  Obx(() {
                    final inf = Get.find<InferenceService>();
                    if (inf.tokensPerSecond.value <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: ShapeDecoration(
                          color: scheme.surfaceContainer,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          '${inf.tokensPerSecond.value.toStringAsFixed(1)} tok/s',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typingHint(BuildContext context, {String? attachmentType}) {
    final scheme = Theme.of(context).colorScheme;
    final msg = attachmentType == 'image'
        ? 'Reading image…'
        : attachmentType == 'audio'
            ? 'Listening to audio…'
            : null;
    if (msg == null) return _TypingDots(isDark: false);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _TypingDots(isDark: false),
      const SizedBox(width: 10),
      Flexible(
          child: Text(msg,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400))),
    ]);
  }

  // ── Input Bar (Floating Space Gray Island) ──
  Widget _inputBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Attachment preview
          Obx(() {
            final name = controller.selectedFileName.value;
            if (name == null) return const SizedBox.shrink();
            return Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: AttachmentPreview(
                  fileName: name,
                  fileType: controller.selectedFileType.value,
                  fileSize: controller.selectedFileSize.value > 0
                      ? controller.selectedFileSize.value
                      : null,
                  imagePath: controller.selectedImagePath.value,
                  imageBase64: controller.selectedImageBase64.value,
                  onRemove: () {
                    controller.clearImage();
                    controller.clearFile();
                  },
                ));
          }),
          // STT listening indicator
          Obx(() {
            if (!controller.isListening.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const _PulsingDot(),
                  const SizedBox(width: 8),
                  Text('Listening… tap mic to stop',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.error,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            );
          }),
          Obx(() {
            final settings = Get.find<SettingsController>();
            final localImage = Get.find<LocalImageService>();
            if (settings.inferenceMode.value != 'local' ||
                !localImage.isModelLoaded.value) {
              return const SizedBox.shrink();
            }
            final steps = settings.imageSteps.value;
            final size = settings.imageGenSize.value;
            final sizeLabel = size == 0 ? 'Auto' : '${size}px';
            final backend = localImage.currentBackend.value;
            final backendLabel = backend == Backend.cpu
                ? 'CPU'
                : backend.displayName.split(' ').first.toUpperCase();
            final accent =
                backend == Backend.cpu ? scheme.tertiary : scheme.primary;
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsBold.sparkle,
                              size: 13, color: accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Image gen · $steps ${steps == 1 ? "step" : "steps"} · $sizeLabel · $backendLabel',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepButton(
                          icon: PhosphorIconsBold.minus,
                          enabled: steps > 1,
                          onTap: () => settings.setImageSteps(steps - 1),
                        ),
                        Text(
                          steps.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _StepButton(
                          icon: PhosphorIconsBold.plus,
                          enabled: steps < 20,
                          onTap: () => settings.setImageSteps(steps + 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            if (!controller.isCanvasMode.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                            : const Color(0xFF2563EB).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsBold.notepad,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Canvas',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => controller.toggleCanvasMode(false),
                          child: Icon(
                            PhosphorIconsBold.x,
                            size: 14,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          // Floating pill container
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12141A) : const Color(0xFFF3F5F9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Attach button (image, camera, file)
                _AttachButton(
                  isDark: isDark,
                  isCloud: Get.find<SettingsController>().inferenceMode.value == 'cloud',
                  onImage: controller.pickImage,
                  onCamera: controller.pickCamera,
                  onFile: controller.pickFile,
                ),
                const SizedBox(width: 2),
                // Text field with Open Sans font, matching single-line button height
                Expanded(
                  child: TextField(
                    controller: controller.textController,
                    onChanged: (v) => controller.inputText.value = v,
                    maxLines: 5,
                    minLines: 1,
                    style: GoogleFonts.openSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.35,
                    ),
                    cursorColor: isDark ? Colors.white : Colors.black,
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      hintText: 'Message…',
                      hintStyle: GoogleFonts.openSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? const Color(0xFF888E9E)
                            : const Color(0xFF6E7484),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => controller.sendMessage(),
                  ),
                ),
                const SizedBox(width: 4),
                // Floating Models Icon Button on the Right
                Builder(
                  builder: (btnCtx) => PressableScale(
                    onTap: () => _showQuickAvailableModelSelector(btnCtx),
                    pressedScale: 0.90,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1E29) : const Color(0xFFE4E8F2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIconsBold.squaresFour,
                          size: 17,
                          color: isDark ? Colors.white : const Color(0xFF12141D),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // High-contrast unified mic / send / stop button
                Obx(() {
                  final loading = controller.isLoading.value;
                  final listening = controller.isListening.value;
                  final hasContent = controller.inputText.value.isNotEmpty ||
                      controller.selectedFileName.value != null ||
                      controller.selectedImagePath.value != null;

                  final Color bgColor;
                  final Color fgColor;
                  final IconData iconData;
                  final VoidCallback? onTap;

                  if (loading || listening) {
                    bgColor = scheme.error;
                    fgColor = scheme.onError;
                    iconData = PhosphorIconsBold.stop;
                    onTap = loading
                        ? controller.stopGenerating
                        : controller.toggleListening;
                  } else if (hasContent) {
                    bgColor = isDark ? Colors.white : Colors.black;
                    fgColor = isDark ? Colors.black : Colors.white;
                    iconData = PhosphorIconsBold.arrowUp;
                    onTap = controller.sendMessage;
                  } else {
                    bgColor = isDark
                        ? const Color(0xFF1E212A)
                        : const Color(0xFFE4E8F0);
                    fgColor = isDark ? Colors.white : Colors.black;
                    iconData = PhosphorIconsBold.microphone;
                    onTap = controller.toggleListening;
                  }

                  final button = PressableScale(
                    onTap: onTap,
                    pressedScale: 0.90,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          iconData,
                          key: ValueKey(iconData),
                          color: fgColor,
                          size: iconData == PhosphorIconsBold.microphone ? 19 : 20,
                        ),
                      ),
                    ),
                  );

                  final enabled = loading || listening || hasContent;
                  return Opacity(
                    opacity: enabled ? 1.0 : 0.85,
                    child: button,
                  );
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Chat History & Sidebar Drawer ──
  Widget _buildSidebarDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchFilter = ''.obs;

    return Drawer(
      width: math.min(MediaQuery.of(context).size.width * 0.85, 340),
      backgroundColor: isDark ? const Color(0xFF0C0E14) : const Color(0xFFF5F7FA),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header: App Branding & Close Button
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icons/appicon.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Conversations',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                  ),
                  const Spacer(),
                  PressableScale(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1E29) : const Color(0xFFE4E8F2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIconsBold.x,
                        size: 17,
                        color: isDark ? const Color(0xFFBAC0D0) : const Color(0xFF5A6074),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // "+ New Chat" Button
              PressableScale(
                onTap: () {
                  Navigator.pop(context);
                  controller.createNewChat();
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : const Color(0xFF141620),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIconsBold.plus,
                        size: 18,
                        color: isDark ? const Color(0xFF090A0E) : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF090A0E) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Search past conversations
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141722) : const Color(0xFFE9EDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      size: 17,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => searchFilter.value = v.trim().toLowerCase(),
                        cursorColor: isDark ? Colors.white : const Color(0xFF141620),
                        decoration: InputDecoration(
                          hintText: 'Search chats…',
                          hintStyle: GoogleFonts.openSans(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF6A7185) : const Color(0xFF8E95A8),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: GoogleFonts.openSans(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF141620),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // List of conversations with top and bottom fade
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Obx(() {
                        final sessions = controller.sessions;
                        final q = searchFilter.value.trim().toLowerCase();
                        final filtered = q.isEmpty
                            ? sessions
                            : sessions
                                .where((s) => s.title.toLowerCase().contains(q))
                                .toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                q.isEmpty ? 'No conversations yet' : 'No matching chats',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                                ),
                              ),
                            ),
                          );
                        }

                        return ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.03, 0.85, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 2),
                            itemBuilder: (c, i) {
                              final s = filtered[i];
                              final active = controller.currentSessionId.value == s.id;
                              return Container(
                                decoration: BoxDecoration(
                                  color: active
                                      ? (isDark ? const Color(0xFF191D2A) : const Color(0xFFE5EAF3))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding:
                                      const EdgeInsets.only(left: 12, right: 4),
                                  title: Text(
                                    s.title,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13.5,
                                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    _fmtDate(s.updatedAt),
                                    style: GoogleFonts.openSans(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: Icon(
                                      PhosphorIconsBold.dotsThreeVertical,
                                      size: 18,
                                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                                    ),
                                    color: isDark ? const Color(0xFF181B26) : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'share') {
                                        _shareConversation(s);
                                      } else if (value == 'delete') {
                                        _confirmDeleteChat(context, s);
                                      }
                                    },
                                    itemBuilder: (BuildContext ctx) => [
                                      PopupMenuItem<String>(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(PhosphorIconsBold.shareNetwork,
                                                size: 16,
                                                color: isDark ? Colors.white : const Color(0xFF141620)),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Share',
                                              style: GoogleFonts.manrope(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF141620),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(PhosphorIconsBold.trash,
                                                size: 16, color: Colors.redAccent),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Delete',
                                              style: GoogleFonts.manrope(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    controller.openChat(s.id);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 36,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                (isDark ? const Color(0xFF0C0E14) : const Color(0xFFF5F7FA)),
                                (isDark ? const Color(0xFF0C0E14) : const Color(0xFFF5F7FA)).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Footer: Settings Button
              PressableScale(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    _smoothTransitionRoute(const SettingsView()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141620) : const Color(0xFFE9EDF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.gear,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      PhosphorIcon(
                        PhosphorIconsBold.caretRight,
                        size: 16,
                        color: isDark ? const Color(0xFF888888) : const Color(0xFF666666),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context, ChatSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141724) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIconsBold.trash,
                  color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Chat?',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0E1017),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${session.title}"? This conversation history cannot be recovered.',
          style: GoogleFonts.openSans(
            fontSize: 13.5,
            color: isDark ? const Color(0xFFB5BACB) : const Color(0xFF555B6E),
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteChat(session.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _shareConversation(ChatSession session) {
    final hive = Get.find<HiveService>();
    final rawMsgs = hive.getMessagesForChat(session.id);
    if (rawMsgs.isEmpty) {
      Share.share('AstraLM Conversation: ${session.title}');
      return;
    }
    rawMsgs.sort((a, b) => (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? ''));
    final sb = StringBuffer();
    sb.writeln('# ${session.title}\n');
    for (final m in rawMsgs) {
      final role = (m['role'] ?? 'user') == 'user' ? 'User' : 'Assistant';
      final text = m['content'] ?? '';
      sb.writeln('**$role:**\n$text\n');
    }
    Share.share(sb.toString().trim(), subject: session.title);
  }

  // ── Quick Available Model Selector (Attached Floating Popover - Strict Monochrome) ──
  void _showQuickAvailableModelSelector(BuildContext buttonContext) {
    final isDark = Theme.of(buttonContext).brightness == Brightness.dark;
    final settings = Get.find<SettingsController>();
    final modelCtrl = Get.find<ModelController>();
    final inf = Get.find<InferenceService>();

    showGeneralDialog(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Model Selector',
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, anim1, anim2) {
        final keyboardBottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                bottom: keyboardBottom + 74,
                right: 14,
                child: Obx(() {
                  final downloaded = modelCtrl.downloadedFiles;
                  final availableCloud = <Map<String, dynamic>>[];

                  if (settings.openaiKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'openai',
                      'name': 'OpenAI',
                      'model': settings.openaiModel.value.isNotEmpty
                          ? settings.openaiModel.value
                          : 'gpt-4o',
                      'icon': PhosphorIconsBold.sparkle,
                    });
                  }
                  if (settings.anthropicKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'anthropic',
                      'name': 'Anthropic Claude',
                      'model': settings.anthropicModel.value.isNotEmpty
                          ? settings.anthropicModel.value
                          : 'claude-3-7-sonnet-latest',
                      'icon': PhosphorIconsBold.brain,
                    });
                  }
                  if (settings.googleKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'google',
                      'name': 'Google Gemini',
                      'model': settings.googleModel.value.isNotEmpty
                          ? settings.googleModel.value
                          : 'gemini-2.0-flash',
                      'icon': PhosphorIconsBold.sparkle,
                    });
                  }
                  if (settings.deepSeekKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'deepseek',
                      'name': 'DeepSeek',
                      'model': settings.deepSeekModel.value.isNotEmpty
                          ? settings.deepSeekModel.value
                          : 'deepseek-chat',
                      'icon': PhosphorIconsBold.brain,
                    });
                  }
                  if (settings.openRouterKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'openrouter',
                      'name': 'OpenRouter',
                      'model': settings.openRouterModel.value,
                      'icon': PhosphorIconsBold.gitBranch,
                    });
                  }
                  if (settings.nvidiaKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'nvidia',
                      'name': 'NVIDIA NIM',
                      'model': settings.nvidiaModel.value,
                      'icon': PhosphorIconsBold.cpu,
                    });
                  }
                  if (settings.kimiKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'kimi',
                      'name': 'Moonshot Kimi',
                      'model': settings.kimiModel.value,
                      'icon': PhosphorIconsBold.moon,
                    });
                  }
                  if (settings.customCloudKey.value.trim().isNotEmpty) {
                    availableCloud.add({
                      'provider': 'custom',
                      'name': settings.customCloudName.value.isNotEmpty
                          ? settings.customCloudName.value
                          : 'Custom Cloud',
                      'model': settings.customCloudModel.value,
                      'icon': PhosphorIconsBold.database,
                    });
                  }

                  final hasAny = downloaded.isNotEmpty || availableCloud.isNotEmpty;

                  return Container(
                    width: 260,
                    constraints: const BoxConstraints(maxHeight: 330),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14161C) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Minimal Header (Monochrome)
                        Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIconsBold.squaresFour,
                              size: 13,
                              color: isDark ? const Color(0xFFBAC0CC) : const Color(0xFF5A6070),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Models',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            PressableScale(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Navigator.of(buttonContext).push(_topFillTransitionRoute(const ModelView()));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Manage',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFBAC0CC) : const Color(0xFF5A6070),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    PhosphorIcon(
                                      PhosphorIconsBold.caretRight,
                                      size: 9,
                                      color: isDark ? const Color(0xFFBAC0CC) : const Color(0xFF5A6070),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? const Color(0xFF222634) : const Color(0xFFECEFF4),
                        ),
                        const SizedBox(height: 6),

                        // Reasoning Effort Selector Bar
                        Obx(() {
                          final currentEffort = settings.reasoningEffort.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C1E26) : const Color(0xFFE8EBF2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _buildReasoningTab(
                                  effort: 'none',
                                  label: 'Direct',
                                  icon: PhosphorIconsBold.lightning,
                                  isSelected: currentEffort == 'none',
                                  isDark: isDark,
                                  onTap: () => settings.setReasoningEffort('none'),
                                ),
                                _buildReasoningTab(
                                  effort: 'standard',
                                  label: 'Reason',
                                  icon: PhosphorIconsBold.brain,
                                  isSelected: currentEffort == 'standard',
                                  isDark: isDark,
                                  onTap: () => settings.setReasoningEffort('standard'),
                                ),
                                _buildReasoningTab(
                                  effort: 'deep',
                                  label: 'Deep',
                                  icon: PhosphorIconsBold.sparkle,
                                  isSelected: currentEffort == 'deep',
                                  isDark: isDark,
                                  onTap: () => settings.setReasoningEffort('deep'),
                                ),
                              ],
                            ),
                          );
                        }),

                        if (!hasAny)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsBold.tray,
                                  size: 24,
                                  color: isDark ? const Color(0xFF7E8494) : const Color(0xFF8E95A4),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No active models',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFFBAC0CC) : const Color(0xFF6B7284),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.zero,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (downloaded.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 4, top: 2),
                                      child: Text(
                                        'LOCAL',
                                        style: GoogleFonts.firaCode(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF7E8494) : const Color(0xFF8E95A4),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ...downloaded.map((file) {
                                      final isLoaded = settings.inferenceMode.value == 'local' &&
                                          inf.loadedModelName.value == file;
                                      final cleanName = file.replaceAll('.gguf', '').replaceAll('.GGUF', '');
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: InkWell(
                                          onTap: () async {
                                            Navigator.of(ctx).pop();
                                            settings.setInferenceMode('local');
                                            await modelCtrl.loadModel(file);
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isLoaded
                                                  ? (isDark ? const Color(0xFF222634) : const Color(0xFFE8ECF4))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                PhosphorIcon(
                                                  PhosphorIconsBold.cube,
                                                  size: 14,
                                                  color: isLoaded
                                                      ? (isDark ? Colors.white : Colors.black)
                                                      : (isDark ? const Color(0xFF7E8494) : const Color(0xFF8E95A4)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    cleanName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 12,
                                                      fontWeight: isLoaded ? FontWeight.w700 : FontWeight.w500,
                                                      color: isLoaded
                                                          ? (isDark ? Colors.white : Colors.black)
                                                          : (isDark ? const Color(0xFFD4D8E2) : const Color(0xFF1E2230)),
                                                    ),
                                                  ),
                                                ),
                                                if (isLoaded)
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.white : Colors.black,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                  if (availableCloud.isNotEmpty) ...[
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                        top: downloaded.isNotEmpty ? 6 : 2,
                                      ),
                                      child: Text(
                                        'CLOUD',
                                        style: GoogleFonts.firaCode(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF7E8494) : const Color(0xFF8E95A4),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ...availableCloud.map((item) {
                                      final provider = item['provider'] as String;
                                      final isCurrent = settings.inferenceMode.value == 'cloud' &&
                                          settings.cloudProvider.value == provider;
                                      final iconData = item['icon'] as PhosphorIconData;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(ctx).pop();
                                            settings.setInferenceMode('cloud');
                                            settings.setCloudProvider(provider);
                                            Get.find<InferenceService>().unloadModel();
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isCurrent
                                                  ? (isDark ? const Color(0xFF222634) : const Color(0xFFE8ECF4))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                PhosphorIcon(
                                                  iconData,
                                                  size: 14,
                                                  color: isCurrent
                                                      ? (isDark ? Colors.white : Colors.black)
                                                      : (isDark ? const Color(0xFF7E8494) : const Color(0xFF8E95A4)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${item['name']} · ${item['model']}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 12,
                                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                                      color: isCurrent
                                                          ? (isDark ? Colors.white : Colors.black)
                                                          : (isDark ? const Color(0xFFD4D8E2) : const Color(0xFF1E2230)),
                                                    ),
                                                  ),
                                                ),
                                                if (isCurrent)
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.white : Colors.black,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          alignment: Alignment.bottomRight,
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
    );
  }

  Widget _buildReasoningTab({
    required String effort,
    required String label,
    required PhosphorIconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2E3342) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 11,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284)),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Markdown styles ──
  MarkdownStyleSheet _streamMd(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF0E1017);
    final base = GoogleFonts.inter(fontSize: 15.5, color: color, height: 1.6);
    final codeBg =
        isDark ? const Color(0xFF12141C) : const Color(0xFFF1F4F9);
    return MarkdownStyleSheet.fromTheme(Theme.of(c)).copyWith(
      p: base,
      h1: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w700, color: color, height: 1.3),
      h2: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w700, color: color, height: 1.3),
      h3: GoogleFonts.manrope(
          fontSize: 15.5, fontWeight: FontWeight.w600, color: color, height: 1.3),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      listBullet: base,
      code: GoogleFonts.firaCode(
          fontSize: 13, color: color, backgroundColor: codeBg),
      codeblockDecoration: BoxDecoration(
          color: codeBg, borderRadius: BorderRadius.circular(10)),
      codeblockPadding: const EdgeInsets.all(12),
    );
  }

  MarkdownStyleSheet _thoughtMd(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B);
    final base = GoogleFonts.inter(
        fontSize: 13, color: muted, height: 1.45, fontStyle: FontStyle.italic);
    final codeBg =
        isDark ? const Color(0xFF12141C) : const Color(0xFFF1F4F9);
    return MarkdownStyleSheet.fromTheme(Theme.of(c)).copyWith(
        p: base,
        strong: base.copyWith(fontWeight: FontWeight.w700),
        em: base.copyWith(fontStyle: FontStyle.italic),
        listBullet: base,
        code: GoogleFonts.firaCode(
            fontSize: 11, color: muted, backgroundColor: codeBg),
        codeblockDecoration: BoxDecoration(
            color: codeBg, borderRadius: BorderRadius.circular(8)));
  }

  // ── Helpers ──
  String _cleanStream(String t) => t
      .replaceAll(
          RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]'), '')
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .replaceAll('\uFFFD', '')
      .replaceAll('<|endoftext|>', '')
      .replaceAll('<|im_end|>', '')
      .replaceAll('<|end|>', '');

  bool _hasPrintable(String t) {
    for (final r in t.runes) {
      if (r > 32 &&
          r != 0x7F &&
          r != 0x200B &&
          r != 0x200C &&
          r != 0x200D &&
          r != 0xFEFF &&
          r != 0xFFFD) return true;
    }
    return false;
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _fmtK(int v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}K'
          : v.toString();
}

// ── Attach Button with Composited Dynamic Anchor ──
class _AttachButton extends StatefulWidget {
  final bool isDark;
  final bool isCloud;
  final VoidCallback onImage;
  final VoidCallback onCamera;
  final VoidCallback onFile;

  const _AttachButton({
    required this.isDark,
    required this.isCloud,
    required this.onImage,
    required this.onCamera,
    required this.onFile,
  });

  @override
  State<_AttachButton> createState() => _AttachButtonState();
}

class _AttachButtonState extends State<_AttachButton> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF12141D);
    final iconColor = isDark ? const Color(0xFFD4D8E2) : const Color(0xFF323644);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return Stack(
            children: [
              // Full-screen dismiss barrier
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _overlayController.hide(),
                ),
              ),
              // Physically anchored directly above the '+' button
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: const Offset(0, -8),
                showWhenUnlinked: false,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) => Transform.scale(
                    scale: 0.75 + (0.25 * val),
                    alignment: Alignment.bottomLeft,
                    child: Opacity(
                      opacity: val.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                  child: Container(
                    width: 175,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161922) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF282C3A)
                            : const Color(0xFFE4E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _compactItem(
                          icon: PhosphorIconsBold.images,
                          title: 'Photo Library',
                          textColor: textColor,
                          iconColor: iconColor,
                          onTap: () {
                            _overlayController.hide();
                            widget.onImage();
                          },
                        ),
                        _compactItem(
                          icon: PhosphorIconsBold.camera,
                          title: 'Camera',
                          textColor: textColor,
                          iconColor: iconColor,
                          onTap: () {
                            _overlayController.hide();
                            widget.onCamera();
                          },
                        ),
                        _compactItem(
                          icon: PhosphorIconsBold.file,
                          title: 'Document',
                          textColor: textColor,
                          iconColor: iconColor,
                          onTap: () {
                            _overlayController.hide();
                            widget.onFile();
                          },
                        ),
                        _compactItem(
                          icon: PhosphorIconsBold.notepad,
                          title: 'Canvas',
                          textColor: textColor,
                          iconColor: iconColor,
                          onTap: () {
                            _overlayController.hide();
                            final chatCtrl = Get.find<ChatController>();
                            if (chatCtrl.canvasContent.value.isNotEmpty) {
                              chatCtrl.openCanvas();
                            } else {
                              chatCtrl.toggleCanvasMode();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: PressableScale(
          onTap: () => _overlayController.toggle(),
          pressedScale: 0.90,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E29) : const Color(0xFFE4E8F2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                PhosphorIconsBold.plus,
                color: isDark ? Colors.white : const Color(0xFF12141D),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactItem({
    required IconData icon,
    required String title,
    required Color textColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      pressedScale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 19),
            const SizedBox(width: 11),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing Dot (STT indicator) ──
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Image Generation Indicator ──
class _ImageGenIndicator extends StatefulWidget {
  final ChatController controller;
  final bool isDark;
  const _ImageGenIndicator({required this.controller, this.isDark = false});

  @override
  State<_ImageGenIndicator> createState() => _ImageGenIndicatorState();
}

class _ImageGenIndicatorState extends State<_ImageGenIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Timer _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = widget.controller.imageGenStartTime.value;
      if (start != null) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(start).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _c.dispose();
    super.dispose();
  }

  String _fmtEta(int seconds) {
    if (seconds <= 0) return '';
    if (seconds < 60) return '~$seconds s remaining';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '~$m m $s s remaining' : '~$m m remaining';
  }

  String _fmtElapsed(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  Widget _backendChip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localImage = Get.find<LocalImageService>();
    final backend = localImage.currentBackend.value;
    final isCpu = backend == Backend.cpu;
    final color = isCpu ? scheme.tertiary : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Text(
        isCpu
            ? 'CPU · Slow'
            : backend.displayName.split(' ').first.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final dots = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value - i * 0.18) % 1.0).clamp(0.0, 1.0);
            final pulse = math.sin(t * math.pi).clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Opacity(
                opacity: 0.25 + 0.75 * pulse,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }),
        );

        return Obx(() {
          final step = widget.controller.imageGenStep.value;
          final total = widget.controller.imageGenTotal.value;
          final eta = widget.controller.imageGenEstimatedSecs.value;
          final decoding = widget.controller.imageGenDecoding.value;
          final hasProgress = total > 0;
          final pct = hasProgress ? (step / total).clamp(0.0, 1.0) : 0.0;
          final isDone = decoding || (hasProgress && step >= total);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              dots,
              const SizedBox(height: 10),
              Text(
                isDone ? 'Decoding image' : 'Generating image',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (hasProgress) ...[
                const SizedBox(height: 10),
                // Progress bar (pulse at 100% during decode)
                Container(
                  width: 160,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: isDone ? 1.0 : pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Percentage + steps / decoding message
                Text(
                  isDone
                      ? 'VAE decode in progress…'
                      : '${(pct * 100).toStringAsFixed(0)}% · Step $step of $total',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Backend badge
                const SizedBox(height: 5),
                _backendChip(context),
                // Elapsed time
                const SizedBox(height: 3),
                Text(
                  'Elapsed: ${_fmtElapsed(_elapsedSeconds)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
                // ETA (only if we have a real estimate and not done)
                if (eta > 0 && step >= 2 && !isDone) ...[
                  const SizedBox(height: 3),
                  Text(
                    _fmtEta(eta),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Cancel button
                GestureDetector(
                  onTap: widget.controller.stopGenerating,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: ShapeDecoration(
                      color: scheme.error.withValues(alpha: 0.1),
                      shape: StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsBold.stop, size: 12, color: scheme.error),
                        const SizedBox(width: 4),
                        Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        });
      },
    );
  }
}

// ── Smooth 60fps Rotating App Logo ──
class _RotatingAppLogo extends StatefulWidget {
  final double size;
  const _RotatingAppLogo({this.size = 80});

  @override
  State<_RotatingAppLogo> createState() => _RotatingAppLogoState();
}

class _RotatingAppLogoState extends State<_RotatingAppLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0x3538BDF8)
                  : const Color(0x2038BDF8),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/appicon.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}


// ── 60fps Silky Typing Dots ──
class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = scheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value * 2 * math.pi) - (i * 0.6);
            final bounce = math.sin(phase).clamp(-1.0, 1.0);
            final normalized = (bounce + 1.0) / 2.0; // 0.0 -> 1.0
            final dy = -4.5 * normalized;
            final scale = 0.85 + 0.28 * normalized;
            final opacity = 0.35 + 0.65 * normalized;

            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.25 * normalized),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}


PageRouteBuilder<T> _smoothTransitionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

PageRouteBuilder<T> _topFillTransitionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.05),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}
