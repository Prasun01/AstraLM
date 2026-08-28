import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../controllers/model_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/ai_model.dart';
import '../services/download_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import 'app_ui_kit.dart';
import 'pressable_scale.dart';

class ModelCardItem extends StatefulWidget {
  final AiModel model;
  final VoidCallback? onDetailsTap;

  const ModelCardItem({
    super.key,
    required this.model,
    this.onDetailsTap,
  });

  @override
  State<ModelCardItem> createState() => _ModelCardItemState();
}

class _ModelCardItemState extends State<ModelCardItem> {
  bool _isAdvancedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final controller = Get.find<ModelController>();
    final inference = Get.find<InferenceService>();
    final localImage = Get.find<LocalImageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final isDownloaded = controller.isDownloaded(model.filename);
      final isActive = inference.loadedModelName.value == model.filename ||
          localImage.loadedModelName.value == model.filename;
      final dp = controller.getDownloadProgress(model.filename);
      final isCurrentlyDownloading = dp != null;
      final isAnyModelLoading =
          inference.isLoadingModel.value || localImage.isLoadingModel.value;
      final isThisTextModelLoading = inference.isLoadingModel.value &&
          inference.loadingModelName.value == model.filename;
      final isThisImageModelLoading = localImage.isLoadingModel.value &&
          localImage.loadedModelName.value == model.filename;
      final isThisModelLoading =
          isThisTextModelLoading || isThisImageModelLoading;
      final loadPercent = (inference.modelLoadProgress.value * 100)
          .clamp(0.0, 100.0)
          .toStringAsFixed(0);

      return AstraCard(
        isHighlighted: isActive,
        onTap: widget.onDetailsTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Name, Use-case & Primary Action ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: GoogleFonts.manrope(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          AstraBadge(
                            label: model.bestFor,
                            icon: PhosphorIconsBold.sparkle,
                            isFilled: true,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          AstraBadge(
                            label: model.size,
                            icon: PhosphorIconsBold.hardDrives,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!isCurrentlyDownloading)
                  _buildPrimaryActionButton(
                    context,
                    controller: controller,
                    model: model,
                    isDownloaded: isDownloaded,
                    isActive: isActive,
                    isAnyModelLoading: isAnyModelLoading,
                    isThisModelLoading: isThisModelLoading,
                    isThisImageModelLoading: isThisImageModelLoading,
                    loadPercent: loadPercent,
                  ),
              ],
            ),

            // ── Description ──
            if (model.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                model.description,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: isDark
                      ? const Color(0xFF9AA0B2)
                      : const Color(0xFF5A6074),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Active Download Progress (if downloading / paused) ──
            if (isCurrentlyDownloading) ...[
              const SizedBox(height: 12),
              _buildDownloadProgress(context, controller, model, dp!),
            ],

            // ── Model Loading Indicator ──
            if (isThisModelLoading) ...[
              const SizedBox(height: 12),
              _buildLoadingProgress(context, loadPercent),
            ],

            // ── Collapsible Advanced Specs ──
            const SizedBox(height: 10),
            Row(
              children: [
                PressableScale(
                  pressedScale: 0.95,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isAdvancedExpanded = !_isAdvancedExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          _isAdvancedExpanded
                              ? PhosphorIconsBold.caretUp
                              : PhosphorIconsBold.caretDown,
                          size: 13,
                          color: isDark
                              ? const Color(0xFF8E95A8)
                              : const Color(0xFF6B7284),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isAdvancedExpanded ? 'Hide Specs' : 'Advanced Specs',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF8E95A8)
                                : const Color(0xFF6B7284),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Ready in Memory',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (_isAdvancedExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C0E14)
                      : const Color(0xFFECEFF6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _specItem('Quant', model.quantization, isDark),
                    _specItem('Runtime', model.runtime.toUpperCase(), isDark),
                    _specItem('RAM Req', model.ramRequired, isDark),
                    _specItem('Format', model.filename.split('.').last.toUpperCase(), isDark),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _specItem(String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? const Color(0xFF6B7284) : const Color(0xFF8E95A8),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.firaCode(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton(
    BuildContext context, {
    required ModelController controller,
    required AiModel model,
    required bool isDownloaded,
    required bool isActive,
    required bool isAnyModelLoading,
    required bool isThisModelLoading,
    required bool isThisImageModelLoading,
    required String loadPercent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            onPressed: isActive || isAnyModelLoading
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await Get.find<SettingsController>()
                        .setInferenceMode('local');
                    await controller.loadModel(model.filename);
                  },
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isThisImageModelLoading
                  ? 'Loading...'
                  : isThisModelLoading
                      ? '$loadPercent%'
                      : isActive
                          ? 'Active'
                          : 'Load',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: isActive ? 'Unload model' : 'Delete model',
            onPressed: isAnyModelLoading
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    if (isActive) {
                      await controller.unloadModel();
                    } else {
                      await controller.deleteModel(model.filename);
                    }
                  },
            icon: PhosphorIcon(
              isActive ? PhosphorIconsBold.stop : PhosphorIconsBold.trash,
              size: 16,
              color: isActive ? scheme.primary : scheme.error,
            ),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(28, 28),
            ),
          ),
        ],
      );
    }

    return FilledButton(
      onPressed: isAnyModelLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              controller.downloadModel(model);
            },
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(PhosphorIconsBold.arrowDown, size: 13),
          const SizedBox(width: 4),
          const Text('Get',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(
    BuildContext context,
    ModelController controller,
    AiModel model,
    DownloadProgress dp,
  ) {
    final isPaused = dp.isPaused.value;
    final percent = dp.progress.value * 100;
    final totalLabel = dp.totalBytes.value > 0
        ? DownloadService.formatWholeMb(dp.totalBytes.value)
        : controller.modelSizeLabel(model);
    final remaining = dp.totalBytes.value <= 0
        ? 0
        : (dp.totalBytes.value - dp.downloadedBytes.value)
            .clamp(0, dp.totalBytes.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: dp.progress.value > 0 ? dp.progress.value : null,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: isPaused
                ? const Color(0xFFF59E0B)
                : Theme.of(context).colorScheme.primary,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              isPaused
                  ? 'Paused (${percent.toStringAsFixed(1)}%)'
                  : '${percent.toStringAsFixed(1)}%',
              style: GoogleFonts.firaCode(
                fontSize: 12.5,
                color: isPaused
                    ? const Color(0xFFF59E0B)
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            if (!isPaused)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  DownloadService.formatSpeed(dp.bytesPerSecond.value),
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Spacer(),
            if (isPaused) ...[
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.downloadModel(model);
                },
                icon: PhosphorIcon(PhosphorIconsBold.play, size: 13),
                label: const Text('Resume',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 30),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.pauseDownload(model.filename);
                  controller.deleteModel(model.filename);
                },
                icon: PhosphorIcon(PhosphorIconsBold.trash, size: 16),
                tooltip: 'Delete download',
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ] else ...[
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.pauseDownload(model.filename);
                },
                icon: PhosphorIcon(PhosphorIconsBold.x, size: 16),
                tooltip: 'Cancel download',
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${DownloadService.formatWholeMb(dp.downloadedBytes.value)} / $totalLabel',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (dp.totalBytes.value > 0)
              Text(
                '${DownloadService.formatWholeMb(remaining)} left',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            if (!isPaused)
              Text(
                'ETA: ${DownloadService.formatDuration(dp.eta)}',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingProgress(BuildContext context, String loadPercent) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading weights into memory ($loadPercent%)...',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
