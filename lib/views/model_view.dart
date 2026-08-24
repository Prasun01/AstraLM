import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/cloud_model_controller.dart';
import '../controllers/model_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/colors.dart';
import '../core/icons.dart';
import '../models/ai_model.dart';
import '../services/device_info_service.dart';
import '../services/download_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import '../widgets/pressable_scale.dart';

class ModelView extends GetView<ModelController> {
  const ModelView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Models',
            style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, fontSize: 24)),
        actions: [
          Obx(() {
            if (controller.modelScope.value != 'local') {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(AppIcons.linkUrl),
                  tooltip: 'Add Model URL',
                  onPressed: () => _showAddUrlDialog(context),
                ),
                IconButton(
                  icon: Icon(AppIcons.importFromStorage),
                  tooltip: 'Import from Storage',
                  onPressed: () => controller.importModelFromStorage(),
                ),
              ],
            );
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (controller.modelScope.value == 'local') {
            await controller.refreshDownloaded();
          }
        },
        color: Theme.of(context).colorScheme.primary,
        child: Obx(() => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildScopeToggle(context),
                const SizedBox(height: 14),
                // Active model banner
                _buildActiveModelBanner(context),
                const SizedBox(height: 14),

                if (controller.modelScope.value == 'local') ...[
                  _buildImportingProgress(context),
                  _buildRecommendedSection(context),
                  _buildLocalFilterChips(context),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ALL MODELS (${controller.filteredDisplayedModels.length})',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF8E95A8)
                              : const Color(0xFF5A6074),
                          letterSpacing: 1.0,
                        ),
                      ),
                      _buildSortSelector(context),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (controller.filteredDisplayedModels.isEmpty)
                    _buildEmptyLocalState(context)
                  else
                    ...controller.filteredDisplayedModels
                        .map((model) => _buildModelCard(context, model)),
                ] else ...[
                  _buildOnlineProviders(context),
                ],
              ],
            )),
      ),
    );
  }

  Widget _buildScopeToggle(BuildContext context) {
    return Obx(() {
      return SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'local',
            icon: Icon(PhosphorIconsBold.circle),
            label: Text('Local'),
          ),
          ButtonSegment(
            value: 'online',
            icon: Icon(PhosphorIconsBold.cloud),
            label: Text('Online'),
          ),
        ],
        selected: {controller.modelScope.value},
        onSelectionChanged: (selection) =>
            controller.modelScope.value = selection.first,
      );
    });
  }

  Widget _buildLocalActions(BuildContext context) {
    final inference = Get.find<InferenceService>();
    return Row(
      children: [
        Expanded(
          child: Obx(() => OutlinedButton.icon(
                onPressed: controller.isImporting.value ||
                        inference.isLoadingModel.value
                    ? null
                    : () => _showAddUrlDialog(context),
                icon: Icon(AppIcons.linkUrl, size: 16),
                label: const Text('URL'),
              )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => OutlinedButton.icon(
                onPressed: controller.isImporting.value ||
                        inference.isLoadingModel.value
                    ? null
                    : () => controller.importModelFromStorage(),
                icon: Icon(AppIcons.importFromStorage, size: 16),
                label: const Text('Import'),
              )),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recommended = controller.recommendedModels;
    final dev = Get.find<DeviceInfoService>();
    final ramGb = dev.totalRamGB.value > 0
        ? '${dev.totalRamGB.value.toStringAsFixed(0)} GB'
        : 'your';

    if (recommended.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              PhosphorIconsBold.sparkle,
              size: 15,
              color: isDark ? const Color(0xFFBAC0D0) : const Color(0xFF4A5060),
            ),
            const SizedBox(width: 6),
            Text(
              'RECOMMENDED FOR $ramGb RAM',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFBAC0D0) : const Color(0xFF4A5060),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recommended.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final m = recommended[idx];
              final isDownloaded = controller.isDownloaded(m.filename);
              final inference = Get.find<InferenceService>();
              final isActive = inference.loadedModelName.value == m.filename;

              return PressableScale(
                onTap: () => _showModelDetailSheet(context, m),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141620)
                        : const Color(0xFFF3F5F9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.name,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF12141D),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF34C759),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            m.description,
                            style: GoogleFonts.openSans(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF8E95A8)
                                  : const Color(0xFF6B7284),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1F2332)
                                  : const Color(0xFFE4E8F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              controller.modelSizeLabel(m),
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                  ? const Color(0xFFBAC0D0)
                                  : const Color(0xFF4A5060),
                              ),
                            ),
                          ),
                          Text(
                            isDownloaded
                                ? (isActive ? 'Active' : 'Installed')
                                : 'Available',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? const Color(0xFF34C759)
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF12141D)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildSortSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final mode = controller.sortMode.value;
      final label = mode == 'size_asc'
          ? 'Size (Small)'
          : mode == 'size_desc'
              ? 'Size (Large)'
              : mode == 'name'
                  ? 'Name (A-Z)'
                  : 'Popular';

      return PressableScale(
        onTap: controller.toggleSort,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161822) : const Color(0xFFECEFF6),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsBold.circle,
                size: 14,
                color: isDark ? Colors.white : const Color(0xFF141620),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF141620),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLocalFilterChips(BuildContext context) {
    const categoryLabels = {
      'all': 'All',
      'recommended': 'Recommended',
      'downloaded': 'Downloaded',
      'general': 'Chat',
      'vision': 'Vision',
      'image': 'Image Gen',
      'uncensored': 'Uncensored',
    };

    const sizeLabels = {
      'all': 'All Sizes',
      'tiny': '< 1.5 GB',
      'small': '1.5 – 3 GB',
      'medium': '3+ GB',
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final selectedCategory = controller.localFilter.value.isEmpty
          ? controller.defaultLocalFilter
          : controller.localFilter.value;
      final selectedSize = controller.localSizeFilter.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final entry in categoryLabels.entries) ...[
                  Builder(builder: (ctx) {
                    final isSel = selectedCategory == entry.key;
                    final bgColor = isSel
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark
                            ? const Color(0xFF14161E)
                            : const Color(0xFFF0F2F6));
                    final fgColor = isSel
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark
                            ? const Color(0xFFBAC0D0)
                            : const Color(0xFF505462));
                    return PressableScale(
                      onTap: () => controller.setLocalFilter(entry.key),
                      pressedScale: 0.93,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          entry.value,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w600,
                            color: fgColor,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Size Filter Pills Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final entry in sizeLabels.entries) ...[
                  Builder(builder: (ctx) {
                    final isSel = selectedSize == entry.key;
                    final bgColor = isSel
                        ? (isDark ? const Color(0xFF282D3D) : const Color(0xFFD6DBE8))
                        : (isDark ? const Color(0xFF12141C) : const Color(0xFFEAEDF4));
                    final fgColor = isSel
                        ? (isDark ? Colors.white : const Color(0xFF12141D))
                        : (isDark
                            ? const Color(0xFF8E95A8)
                            : const Color(0xFF6B7284));
                    return PressableScale(
                      onTap: () => controller.setSizeFilter(entry.key),
                      pressedScale: 0.94,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          entry.value,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: fgColor,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyLocalState(BuildContext context) {
    final filter = controller.localFilter.value.isEmpty
        ? controller.defaultLocalFilter
        : controller.localFilter.value;
    final title = filter == 'downloaded'
        ? 'No downloaded models yet'
        : 'No ${filter == 'vision' ? 'vision' : filter == 'image' ? 'image generation' : filter} models found';
    final subtitle = filter == 'downloaded'
        ? 'Import a local model or add a downloadable URL.'
        : 'Try another filter or add a custom model URL.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(PhosphorIconsBold.circle,
              size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (filter == 'downloaded') ...[
            const SizedBox(height: 14),
            _buildLocalActions(context),
          ],
        ],
      ),
    );
  }

  void _showAddUrlDialog(BuildContext context) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final filenameController = TextEditingController();
    final sizeController = TextEditingController();
    final templateController = TextEditingController(text: 'chatml');
    final isVision = false.obs;
    final isDetecting = false.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.655),
      builder: (ctx) => _AddModelUrlSheet(
        nameController: nameController,
        urlController: urlController,
        filenameController: filenameController,
        sizeController: sizeController,
        templateController: templateController,
        isVision: isVision,
        isDetecting: isDetecting,
        modelController: controller,
      ),
    );
  }

  Widget _buildActiveModelBanner(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (controller.modelScope.value == 'online') {
        return _buildActiveCloudBanner(context);
      }

      final inference = Get.find<InferenceService>();
      final localImage = Get.find<LocalImageService>();

      // Image model loaded
      if (localImage.isModelLoaded.value) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141620) : const Color(0xFFF3F5F9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : const Color(0xFFE4E8F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  localImage.isUsingGpu.value ? PhosphorIconsBold.lightning : PhosphorIconsBold.cpu,
                  color: isDark ? Colors.white : const Color(0xFF12141D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE IMAGE MODEL',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        color: isDark
                            ? const Color(0xFF8E95A8)
                            : const Color(0xFF6B7284),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localImage.loadedModelName.value,
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF12141D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localImage.isUsingGpu.value ? 'GPU Accelerated' : 'CPU Mode',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFBAC0D0)
                            : const Color(0xFF5A6074),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF34C759),
                ),
              ),
            ],
          ),
        );
      }

      // Text model loaded
      if (!inference.isModelLoaded.value) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141620) : const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2230) : const Color(0xFFE4E8F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                inference.isGpuAccelerated.value
                    ? PhosphorIconsBold.lightning
                    : PhosphorIconsBold.cpu,
                color: isDark ? Colors.white : const Color(0xFF12141D),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE LOCAL MODEL',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      color: isDark
                          ? const Color(0xFF8E95A8)
                          : const Color(0xFF6B7284),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inference.loadedModelName.value,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF12141D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (inference.isGpuAccelerated.value) ...[
                    const SizedBox(height: 2),
                    Text(
                      'GPU: ${inference.gpuName.value}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFBAC0D0)
                            : const Color(0xFF5A6074),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF34C759),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActiveCloudBanner(BuildContext context) {
    final settings = Get.find<SettingsController>();
    final cloudModels = Get.find<CloudModelController>();
    final providerId = settings.cloudProvider.value;
    final provider = cloudModels.providers.firstWhereOrNull(
      (p) => p.id == providerId,
    );
    final providerName = providerId == 'custom'
        ? settings.customCloudName.value
        : provider?.name ?? providerId;
    final model = cloudModels.activeModelFor(providerId);
    final hasSelectedModel =
        cloudModels.canSelectModel(providerId) && model.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PhosphorIconsBold.circle,
                color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLOUD · $providerName',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasSelectedModel ? model : 'No online model selected',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              if (provider == null) return;
              if (providerId == 'custom') {
                _showCustomProviderSheet(context, cloudModels);
              } else {
                _showProviderActionsSheet(context, cloudModels, provider);
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildModelLoadingProgress(BuildContext context, AiModel model) {
    return Obx(() {
      final inference = Get.find<InferenceService>();
      if (!inference.isLoadingModel.value ||
          inference.loadingModelName.value != model.filename) {
        return const SizedBox.shrink();
      }
      final progress = inference.modelLoadProgress.value;

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading into memory',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              model.filename,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: inference.modelLoadProgress.value > 0
                    ? inference.modelLoadProgress.value
                    : null,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: Theme.of(context).colorScheme.primary,
                minHeight: 3,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildImportingProgress(BuildContext context) {
    return Obx(() {
      if (!controller.isImporting.value) return const SizedBox.shrink();
      final percent = controller.importProgress * 100;
      final total = controller.importTotalBytes.value;
      final copied = controller.importCopiedBytes.value;
      final remaining = total <= 0 ? 0 : (total - copied).clamp(0, total);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.importStatus.value
                                  .toLowerCase()
                                  .contains('download')
                              ? 'Downloading'
                              : 'Importing',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (controller.externalDownloadId.value != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: InkWell(
                            onTap: controller.cancelExternalDownload,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(PhosphorIconsBold.x,
                                size: 20,
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.importStatus.value} ${controller.importFileName.value}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.importProgress > 0
                          ? controller.importProgress
                          : null,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: Theme.of(context).colorScheme.primary,
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${DownloadService.formatWholeMb(copied)} / ${DownloadService.formatWholeMb(total)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '${DownloadService.formatWholeMb(remaining)} left',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        DownloadService.formatSpeed(
                            controller.importBytesPerSecond.value),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ignore: unused_element
  Widget _buildDownloadProgress(BuildContext context, DownloadProgress dp) {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Downloading ${dp.filename}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => controller.pauseDownload(dp.filename),
                  child: Text('Pause',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.warning)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: dp.progress.value,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: Theme.of(context).colorScheme.primary,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${DownloadService.formatWholeMb(dp.downloadedBytes.value)} / ${DownloadService.formatWholeMb(dp.totalBytes.value)} · ${(dp.progress.value * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOnlineProviders(BuildContext context) {
    final cloud = Get.find<CloudModelController>();
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROVIDERS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          for (final provider in cloud.providers)
            _buildOnlineProviderRow(context, cloud, provider),
        ],
      );
    });
  }

  Widget _buildOnlineProviderRow(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
  ) {
    final settings = Get.find<SettingsController>();
    final isCustom = provider.id == 'custom';
    final isActive = cloud.activeProvider == provider.id;
    final canUse = cloud.canSelectModel(provider.id);
    final model = cloud.activeModelFor(provider.id);
    final hasSelectedModel = canUse && model.isNotEmpty;
    final modelLabel = hasSelectedModel ? model : 'No model selected';
    final name = isCustom ? settings.customCloudName.value : provider.name;
    final error = cloud.errorByProvider[provider.id];
    final status = isActive && hasSelectedModel
        ? 'ACTIVE'
        : canUse
            ? 'READY'
            : cloud.statusLabel(provider.id).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isActive
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => isCustom
              ? _showCustomProviderSheet(context, cloud)
              : _openProviderFlow(context, cloud, provider),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF191B26)
                            : const Color(0xFFE9EDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF282D3D)
                              : const Color(0xFFD4DAE6),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        provider.icon,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE2E6F2)
                            : const Color(0xFF161822),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name.isEmpty ? provider.name : name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusPill(
                                context,
                                status,
                                configured: canUse,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            modelLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: hasSelectedModel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: hasSelectedModel
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Provider settings',
                      onPressed: () =>
                          _showProviderActionsSheet(context, cloud, provider),
                      icon: Icon(PhosphorIconsBold.dotsThreeVertical, size: 20),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  _buildErrorBox(context, error),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _providerAccent(String provider) {
    return const Color(0xFF8E95A8);
  }

  Future<void> _openProviderFlow(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
  ) async {
    if (!cloud.canSelectModel(provider.id)) {
      _showProviderKeyDialog(
        context,
        cloud,
        provider,
        openModelsAfterSave: true,
      );
      return;
    }

    await cloud.refreshModels(provider.id);
    if ((cloud.errorByProvider[provider.id] ?? '').isNotEmpty) {
      _showProviderKeyDialog(
        context,
        cloud,
        provider,
        openModelsAfterSave: true,
      );
      return;
    }
    _showModelSelectSheet(context, cloud, provider);
  }

  void _showProviderActionsSheet(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
  ) {
    final settings = Get.find<SettingsController>();
    final isCustom = provider.id == 'custom';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final solidBg = isDark ? const Color(0xFF14161E) : Colors.white;

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: solidBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Obx(() {
            final model = cloud.activeModelFor(provider.id);
            final configured = cloud.isConfigured(provider.id);
            final name =
                isCustom ? settings.customCloudName.value : provider.name;
            final accent = _providerAccent(provider.id);

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(provider.icon, color: accent, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? provider.name : name,
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              model.isEmpty ? provider.description : model,
                              style: GoogleFonts.openSans(
                                fontSize: 13.5,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: Get.back,
                        icon: Icon(PhosphorIconsBold.x),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (!isCustom) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Icon(PhosphorIconsBold.key, size: 26),
                      title: Text(
                        configured ? 'Update API key' : 'Add API key',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Required before selecting live models',
                        style: GoogleFonts.openSans(fontSize: 13),
                      ),
                      onTap: () {
                        Get.back();
                        _showProviderKeyDialog(
                          context,
                          cloud,
                          provider,
                          openModelsAfterSave: true,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Icon(
                        isCustom ? PhosphorIconsBold.sliders : PhosphorIconsBold.robot,
                        size: 26),
                    title: Text(
                      isCustom ? 'Configure and select' : 'Select model',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isCustom
                          ? 'Set base URL, key, and model ID'
                          : 'Search provider models or enter a model ID',
                      style: GoogleFonts.openSans(fontSize: 13),
                    ),
                    onTap: () {
                      Get.back();
                      if (isCustom) {
                        _showCustomProviderSheet(context, cloud);
                      } else {
                        _openProviderFlow(context, cloud, provider);
                      }
                    },
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: solidBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProviderCard(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
  ) {
    final isCustom = provider.id == 'custom';
    final isActiveProvider = cloud.activeProvider == provider.id;
    final activeModel = cloud.activeModelFor(provider.id);
    final error = cloud.errorByProvider[provider.id];
    final configured = cloud.isConfigured(provider.id);
    final hasModel = activeModel.isNotEmpty;
    final status = isActiveProvider && hasModel
        ? 'ACTIVE'
        : configured
            ? (hasModel ? 'Ready' : 'No Model')
            : cloud.statusLabel(provider.id);
    final providerName = isCustom
        ? Get.find<SettingsController>().customCloudName.value
        : provider.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF191B26)
                        : const Color(0xFFE9EDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF282D3D)
                          : const Color(0xFFD4DAE6),
                    ),
                  ),
                  child: Icon(
                    provider.icon,
                    size: 18,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE2E6F2)
                        : const Color(0xFF161822),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        providerName.isEmpty ? provider.name : providerName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasModel ? activeModel : provider.description,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: hasModel
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight:
                              hasModel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(context, status, configured: configured),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              _buildErrorBox(context, error),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isCustom) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showProviderKeyDialog(context, cloud, provider),
                      icon: Icon(PhosphorIconsBold.key, size: 16),
                      label: Text(configured ? 'Update Key' : 'Add Key'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => isCustom
                        ? _showCustomProviderSheet(context, cloud)
                        : _showModelSelectSheet(context, cloud, provider),
                    icon: Icon(
                      isCustom ? PhosphorIconsBold.sliders : PhosphorIconsBold.robot,
                      size: 16,
                    ),
                    label: Text(isCustom ? 'Configure' : 'Select Model'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProviderKeyDialog(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider, {
    bool openModelsAfterSave = false,
  }) {
    final keyController = cloud.apiKeyControllerFor(provider.id);
    final obscureKey = true.obs;
    final isVerifying = false.obs;
    final accent = _providerAccent(provider.id);
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(26, 26, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(26, 20, 26, 10),
      actionsPadding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
      title: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(provider.icon, color: accent, size: 29),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'API key required',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => TextField(
                controller: keyController,
                obscureText: obscureKey.value,
                style: GoogleFonts.firaCode(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'API key',
                  hintText: 'Paste ${provider.name} key',
                  prefixIcon: Icon(PhosphorIconsBold.key, size: 23),
                  suffixIcon: IconButton(
                    tooltip: obscureKey.value ? 'Show API key' : 'Hide API key',
                    onPressed: () => obscureKey.value = !obscureKey.value,
                    icon: Icon(
                      obscureKey.value
                          ? PhosphorIconsBold.eye
                          : PhosphorIconsBold.eyeSlash,
                      size: 24,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Obx(() {
              final error = cloud.errorByProvider[provider.id];
              if (error == null || error.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildErrorBox(context, error),
              );
            }),
            Text(
              'Save the key to verify it and load live models.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(closeOverlays: false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final value = keyController.text.trim();
            if (value.isEmpty || isVerifying.value) return;
            isVerifying.value = true;
            await cloud.saveApiKey(provider.id, value);
            await cloud.refreshModels(provider.id);
            isVerifying.value = false;
            if ((cloud.errorByProvider[provider.id] ?? '').isNotEmpty) {
              return;
            }
            Get.back(closeOverlays: false);
            if (openModelsAfterSave) {
              _showModelSelectSheet(context, cloud, provider);
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          child:
              Obx(() => Text(isVerifying.value ? 'Verifying...' : 'Save Key')),
        ),
      ],
    ));
  }

  void _showCustomProviderSheet(
    BuildContext context,
    CloudModelController cloud,
  ) {
    final obscureCustomKey = true.obs;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final solidBg = isDark ? const Color(0xFF14161E) : Colors.white;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: solidBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 26,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Custom Provider',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Use any OpenAI-compatible endpoint. Enter the base URL without /chat/completions.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Obx(() {
                  final profiles = cloud.customProfiles;
                  if (profiles.isEmpty) return const SizedBox.shrink();
                  final selected = cloud.customProfileIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(selected),
                            value: selected >= 0 ? selected : null,
                            decoration: const InputDecoration(
                              labelText: 'Saved provider',
                              prefixIcon: Icon(PhosphorIconsBold.circle),
                            ),
                            items: [
                              for (var i = 0; i < profiles.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    profiles[i]['name']?.isNotEmpty == true
                                        ? profiles[i]['name']!
                                        : profiles[i]['baseUrl'] ??
                                            'Custom API',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (index) {
                              if (index != null) {
                                cloud.selectCustomProfile(index);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Add another provider',
                          onPressed: cloud.beginNewCustomProfile,
                          icon: Icon(PhosphorIconsBold.plus),
                        ),
                      ],
                    ),
                  );
                }),
                Obx(() {
                  final error = cloud.customProviderError.value;
                  if (error.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildErrorBox(context, error),
                  );
                }),
                TextField(
                  controller: cloud.customNameController,
                  decoration: const InputDecoration(
                    labelText: 'Provider name',
                    prefixIcon: Icon(PhosphorIconsBold.circle, size: 23),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: cloud.customBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://example.com/v1',
                    prefixIcon: Icon(PhosphorIconsBold.link, size: 23),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  ),
                ),
                const SizedBox(height: 14),
                Obx(
                  () => TextField(
                    controller: cloud.customApiKeyController,
                    obscureText: obscureCustomKey.value,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      prefixIcon: Icon(PhosphorIconsBold.key, size: 23),
                      suffixIcon: IconButton(
                        tooltip: obscureCustomKey.value
                            ? 'Show API key'
                            : 'Hide API key',
                        onPressed: () =>
                            obscureCustomKey.value = !obscureCustomKey.value,
                        icon: Icon(
                          obscureCustomKey.value
                              ? PhosphorIconsBold.eye
                              : PhosphorIconsBold.eyeSlash,
                          size: 24,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: cloud.customModelController,
                  decoration: const InputDecoration(
                    labelText: 'Model ID',
                    prefixIcon: Icon(PhosphorIconsBold.robot, size: 23),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await cloud.saveCustomProvider();
                      if (cloud.customProviderError.value.isEmpty) {
                        Get.back(closeOverlays: false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: Icon(PhosphorIconsBold.check, size: 22),
                    label: const Text('Save and Select'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await cloud.clearCustomProvider();
                    },
                    child: Obx(() => Text(
                          cloud.customProfileIndex >= 0
                              ? 'Remove selected provider'
                              : 'Clear form',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: solidBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );
}

  void _showModelSelectSheet(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
  ) {
    if (!cloud.canSelectModel(provider.id)) {
      _showProviderKeyDialog(
        context,
        cloud,
        provider,
        openModelsAfterSave: true,
      );
      return;
    }

    cloud.searchByProvider[provider.id] = '';
    if ((cloud.modelsByProvider[provider.id] ?? const <String>[]).isEmpty) {
      cloud.refreshModels(provider.id);
    } else if (cloud.canFetchModels(provider.id) &&
        cloud.fetchedAtByProvider[provider.id] == null) {
      cloud.refreshModels(provider.id);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final solidBg = isDark ? const Color(0xFF14161E) : Colors.white;

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: solidBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Obx(() {
            final isLoading = cloud.isLoadingProvider[provider.id] == true;
            final error = cloud.errorByProvider[provider.id];
            final models = cloud.filteredModelsFor(provider.id);
            final activeModel = cloud.activeModelFor(provider.id);
            final isActiveProvider = cloud.activeProvider == provider.id;
            final canFetch = cloud.canFetchModels(provider.id);
            final freeFirst = cloud.freeFirstByProvider[provider.id] == true;
            final freeModelCount = cloud.freeModelCountFor(provider.id);

            Widget modelList;
            if (isLoading && models.isEmpty) {
              modelList = const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (models.isEmpty) {
              modelList = _buildModelSelectEmptyState(context, provider);
            } else {
              modelList = ListView.separated(
                itemCount: models.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final id = models[index];
                  return _buildCloudModelRow(
                    context,
                    cloud,
                    provider,
                    id,
                    activeModel,
                    isActiveProvider,
                  );
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select ${provider.name} Model',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: Get.back,
                        icon: Icon(PhosphorIconsBold.x),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) =>
                        cloud.searchByProvider[provider.id] = value,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search models...',
                      prefixIcon: Icon(
                        PhosphorIconsBold.magnifyingGlass,
                        size: 23,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${models.length} models - ${cloud.fetchedLabel(provider.id)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (provider.id == 'openrouter' ||
                          freeModelCount > 0) ...[
                        TextButton.icon(
                          onPressed: freeModelCount == 0
                              ? null
                              : () => cloud.toggleFreeFirst(provider.id),
                          icon: Icon(
                            freeFirst
                                ? PhosphorIconsBold.checkCircle
                                : PhosphorIconsBold.circle,
                            size: 16,
                          ),
                          label: Text(
                            freeModelCount == 0
                                ? 'Free'
                                : 'Free first ($freeModelCount)',
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                      TextButton.icon(
                        onPressed: isLoading || !canFetch
                            ? null
                            : () => cloud.refreshModels(provider.id),
                        icon: isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(PhosphorIconsBold.arrowsCounterClockwise, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    _buildErrorBox(context, error),
                  ],
                  const SizedBox(height: 12),
                  Expanded(child: modelList),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showCustomModelIdDialog(context, cloud, provider),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: Icon(PhosphorIconsBold.plus, size: 20),
                      label: const Text('Use custom model ID'),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: solidBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  Widget _buildModelSelectEmptyState(
    BuildContext context,
    CloudProviderInfo provider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No models loaded. Add an API key to update the live list, or use a custom model ID.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _showCustomModelIdDialog(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
  ) {
    final textController =
        TextEditingController(text: cloud.activeModelFor(provider.id));
    Get.dialog(AlertDialog(
      title: Text('Custom ${provider.name} Model',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: textController,
        style: GoogleFonts.firaCode(fontSize: 12),
        decoration: const InputDecoration(
          labelText: 'Model ID',
          prefixIcon: Icon(PhosphorIconsBold.robot, size: 18),
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final value = textController.text.trim();
            if (value.isEmpty) return;
            if (!cloud.canSelectModel(provider.id)) {
              if (provider.id == 'custom') {
                _showCustomProviderSheet(context, cloud);
              } else {
                _showProviderKeyDialog(context, cloud, provider);
              }
              return;
            }
            await cloud.selectModel(
              provider.id,
              value,
              showSnackbar: false,
            );
            Get.back(closeOverlays: false);
            Get.back(closeOverlays: false);
          },
          child: const Text('Select'),
        ),
      ],
    ));
  }

  Widget _buildCloudModelRow(
    BuildContext context,
    CloudModelController cloud,
    CloudProviderInfo provider,
    String id,
    String activeModel,
    bool isActiveProvider,
  ) {
    final providerId = provider.id;
    final normalized =
        providerId == 'google' ? id.replaceFirst('models/', '') : id;
    final canUse = cloud.canSelectModel(providerId);
    final isActive = isActiveProvider && normalized == activeModel && canUse;
    final tags = cloud.modelTagsFor(providerId, id);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    normalized,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final tag in tags) _buildModelTag(context, tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          isActive
              ? _buildStatusPill(context, 'ACTIVE', configured: true)
              : TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onPressed: () async {
                    if (!canUse) {
                      _showProviderKeyDialog(context, cloud, provider);
                      return;
                    }
                    await cloud.selectModel(
                      providerId,
                      id,
                      showSnackbar: false,
                    );
                    Get.back(closeOverlays: false);
                  },
                  child: Text(canUse ? 'Select' : 'Add Key'),
                ),
        ],
      ),
    );
  }

  Widget _buildModelTag(BuildContext context, String label) {
    final isFree = label == 'FREE';
    final color = isFree ? AppColors.success : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusPill(
    BuildContext context,
    String label, {
    required bool configured,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: configured
            ? (isDark ? const Color(0xFF1E2230) : const Color(0xFFE4E7EE))
            : (isDark ? const Color(0xFF161820) : const Color(0xFFEBEEF4)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: configured
              ? (isDark ? const Color(0xFF2F354A) : const Color(0xFFD0D5E0))
              : (isDark ? const Color(0xFF262936) : const Color(0xFFDEE2EC)),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: configured
              ? (isDark ? const Color(0xFFE2E6F2) : const Color(0xFF161822))
              : (isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284)),
        ),
      ),
    );
  }

  Widget _buildErrorBox(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        error,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIconsBold.info,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelBadges(BuildContext context, AiModel model) {
    final scheme = Theme.of(context).colorScheme;
    final badges = <({String label, Color color})>[];
    if (controller.isDownloaded(model.filename)) {
      badges.add((label: 'DOWNLOADED', color: AppColors.success));
    }
    if (controller.isLiteRtModel(model)) {
      badges.add((label: 'LiteRT', color: scheme.primary));
    } else if (controller.isLlamaModel(model)) {
      badges.add((label: 'GGUF', color: AppColors.info));
    }
    if (controller.isUncensoredModel(model)) {
      badges.add((label: 'UNCENSORED', color: Theme.of(context).colorScheme.error));
    }
    if (controller.isVisionModel(model)) {
      badges.add((label: 'VISION', color: AppColors.info));
    }
    if (controller.isImageModel(model)) {
      badges.add((label: 'IMAGE', color: scheme.primary));
    }
    if (model.isImported) {
      badges.add((label: 'IMPORTED', color: scheme.primary));
    }
    if (model.isCustom) {
      badges.add((label: 'CUSTOM', color: AppColors.warning));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in badges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badge.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge.label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: badge.color,
              ),
            ),
          ),
      ],
    );
  }

  void _confirmDownload(BuildContext context, AiModel model,
      {bool isToDownloadsFolder = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              isToDownloadsFolder
                  ? PhosphorIconsBold.circle
                  : PhosphorIconsBold.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isToDownloadsFolder ? 'Save to Downloads' : 'Download Model',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToDownloadsFolder
                  ? 'You are about to save ${model.name} to your phone\'s public Downloads folder.'
                  : 'You are about to download ${model.name} for use in the app.',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsBold.circle, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Size: ${controller.modelSizeLabel(model)}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsBold.wifiHigh, color: AppColors.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A Wi-Fi connection is highly recommended. Please keep the app open during the download.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (isToDownloadsFolder) {
                controller.downloadModelToDownloads(model);
              } else {
                controller.downloadModel(model);
              }
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(isToDownloadsFolder ? 'Save Now' : 'Download Now',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteModel(
      BuildContext context, String filename) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete model?'),
            content:
                Text('$filename will be permanently removed from this device.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await controller.deleteModel(filename);
  }

  Widget _buildModelCard(BuildContext context, AiModel model) {
    return Obx(() {
      final isDownloaded = controller.isDownloaded(model.filename);
      final inference = Get.find<InferenceService>();
      final localImage = Get.find<LocalImageService>();
      final isActive = inference.loadedModelName.value == model.filename ||
          localImage.loadedModelName.value == model.filename;
      final isCurrentlyDownloading =
          controller.isDownloadingModel(model.filename);
      final isAnyModelLoading =
          inference.isLoadingModel.value || localImage.isLoadingModel.value;
      final isThisTextModelLoading = inference.isLoadingModel.value &&
          inference.loadingModelName.value == model.filename;
      final isThisImageModelLoading = localImage.isLoadingModel.value &&
          localImage.loadedModelName.value == model.filename;
      final isThisModelLoading =
          isThisTextModelLoading || isThisImageModelLoading;
      final disableActions = controller.isImporting.value ||
          isAnyModelLoading ||
          isCurrentlyDownloading;
      final loadPercent = (inference.modelLoadProgress.value * 100)
          .clamp(0.0, 100.0)
          .toStringAsFixed(0);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isActive
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showModelDetailSheet(context, model),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: isActive
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _buildModelBadges(context, model),
                        const SizedBox(height: 8),
                        Text(
                          model.description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            color: isActive
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.modelSizeLabel(model),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isActive
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (!isCurrentlyDownloading)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (isDownloaded) ...[
                          FilledButton.tonal(
                            onPressed: isActive || disableActions
                                ? null
                                : () => controller.loadModel(model.filename),
                            style: FilledButton.styleFrom(
                              backgroundColor: isActive
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              foregroundColor: isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer
                                  : Theme.of(context).colorScheme.primary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isThisImageModelLoading
                                  ? 'Loading...'
                                  : isThisTextModelLoading
                                      ? '$loadPercent%'
                                      : isActive
                                          ? 'Active'
                                          : 'Load',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: isActive ? 'Unload model' : 'Delete model',
                            onPressed: disableActions
                                ? null
                                : isActive
                                    ? () => controller.unloadModel()
                                    : () => _confirmDeleteModel(
                                        context, model.filename),
                            icon: Icon(
                              isActive
                                  ? PhosphorIconsBold.circle
                                  : PhosphorIconsBold.circle,
                              size: 20,
                              color: isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ] else ...[
                          FilledButton(
                            onPressed: disableActions
                                ? null
                                : () => _confirmDownload(context, model),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Get',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              if (isCurrentlyDownloading) ...[
                const SizedBox(height: 16),
                _buildInlineDownloadProgress(context, model),
              ],
              if (isThisModelLoading) ...[
                const SizedBox(height: 16),
                _buildModelLoadingProgress(context, model),
              ],
            ],
          ),
        ),
      ),
      );
    });
  }

  void _showModelDetailSheet(BuildContext context, AiModel model) {
    final scheme = Theme.of(context).colorScheme;
    final isDownloaded = controller.isDownloaded(model.filename);
    final inference = Get.find<InferenceService>();
    final localImage = Get.find<LocalImageService>();
    final isActive = inference.loadedModelName.value == model.filename ||
        localImage.loadedModelName.value == model.filename;
    final isDownloading = controller.isDownloadingModel(model.filename);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, animValue, child) => Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, (1 - animValue) * 20),
            child: child,
          ),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with back button and header title
              Row(
                children: [
                  IconButton(
                    icon: Icon(PhosphorIconsBold.arrowLeft),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Model Details',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Headline
                    Text(
                      model.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      model.description.isNotEmpty
                          ? model.description
                          : 'Optimized on-device AI model for local inference.',
                      style: GoogleFonts.openSans(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Details Section
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          _buildDetailRow(context, 'File Size',
                              controller.modelSizeLabel(model)),
                          const Divider(height: 1),
                          _buildDetailRow(context, 'Template',
                              model.template.isNotEmpty ? model.template : 'chatml'),
                          const Divider(height: 1),
                          _buildDetailRow(context, 'Format', 'GGUF / Quantized'),
                          const Divider(height: 1),
                          _buildDetailRow(context, 'Architecture',
                              model.isVision ? 'Multimodal (Vision)' : 'Transformer (Decoder-only)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Variants Section
                    Text(
                      'Available Variants',
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: scheme.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    model.filename.contains('q4')
                                        ? 'Q4_K_M'
                                        : model.filename.contains('q8')
                                            ? 'Q8_0'
                                            : 'Standard',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    'REC',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            controller.modelSizeLabel(model),
                            style: GoogleFonts.openSans(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Balanced',
                            style: GoogleFonts.openSans(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Bottom Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isDownloading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          if (isDownloaded) {
                            if (isActive) {
                              controller.unloadModel();
                            } else {
                              controller.loadModel(model.filename);
                            }
                          } else {
                            _confirmDownload(context, model);
                          }
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDownloaded
                            ? (isActive ? PhosphorIconsBold.circle : PhosphorIconsBold.play)
                            : PhosphorIconsBold.arrowDown,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isDownloaded
                            ? (isActive ? 'Unload Model' : 'Load Model')
                            : 'Download Model',
                        style: GoogleFonts.manrope(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDownloadProgress(BuildContext context, AiModel model) {
    final dp = controller.getDownloadProgress(model.filename)!;
    return Obx(() {
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
              color: Theme.of(context).colorScheme.primary,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: GoogleFonts.firaCode(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DownloadService.formatSpeed(dp.bytesPerSecond.value),
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => controller.pauseDownload(model.filename),
                icon: Icon(PhosphorIconsBold.x, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                '${DownloadService.formatWholeMb(dp.downloadedBytes.value)} / $totalLabel',
                style: GoogleFonts.inter(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (dp.totalBytes.value > 0)
                Text(
                  '${DownloadService.formatWholeMb(remaining)} left',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              Text(
                'ETA: ${DownloadService.formatDuration(dp.eta)}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Model URL — Modern Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddModelUrlSheet extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController filenameController;
  final TextEditingController sizeController;
  final TextEditingController templateController;
  final RxBool isVision;
  final RxBool isDetecting;
  final ModelController modelController;

  const _AddModelUrlSheet({
    required this.nameController,
    required this.urlController,
    required this.filenameController,
    required this.sizeController,
    required this.templateController,
    required this.isVision,
    required this.isDetecting,
    required this.modelController,
  });

  @override
  State<_AddModelUrlSheet> createState() => _AddModelUrlSheetState();
}

class _AddModelUrlSheetState extends State<_AddModelUrlSheet> {
  static const _templates = ['chatml', 'llama3', 'gemma', 'phi3', 'custom'];
  Timer? _urlDebounce;
  final RxString _urlError = ''.obs;
  final RxString _urlWarning = ''.obs;

  @override
  void initState() {
    super.initState();
    widget.urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    widget.urlController.removeListener(_onUrlChanged);
    _urlDebounce?.cancel();
    super.dispose();
  }

  String _detectTemplateFromUrlOrFilename(String url, String filename) {
    final textToSearch = '$url $filename'.toLowerCase();
    if (textToSearch.contains('gemma')) {
      return 'gemma';
    } else if (textToSearch.contains('llama3') ||
        textToSearch.contains('llama-3') ||
        textToSearch.contains('llama_3') ||
        textToSearch.contains('llama 3')) {
      return 'llama3';
    } else if (textToSearch.contains('phi3') ||
        textToSearch.contains('phi-3') ||
        textToSearch.contains('phi_3') ||
        textToSearch.contains('phi 3')) {
      return 'phi3';
    }
    return 'chatml'; // Default fallback
  }

  void _onUrlChanged() {
    final url = widget.urlController.text.trim();
    if (url.isNotEmpty) {
      final filename = widget.modelController.filenameFromUrl(url);
      widget.filenameController.text = filename;
      widget.templateController.text =
          _detectTemplateFromUrlOrFilename(url, filename);
    }

    _urlDebounce?.cancel();
    _urlDebounce = Timer(const Duration(milliseconds: 900), () async {
      if (url.isEmpty) {
        _urlError.value = '';
        _urlWarning.value = '';
        widget.sizeController.text = '';
        return;
      }

      // Check if it is a valid HTTP/HTTPS URL format
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        _urlError.value =
            'Invalid URL format. Must start with http:// or https://';
        _urlWarning.value = '';
        widget.sizeController.text = 'Unknown size';
        return;
      }

      _urlError.value = '';
      _urlWarning.value = '';
      widget.isDetecting.value = true;
      try {
        final sizeLabel = await widget.modelController.detectUrlSize(url);
        if (sizeLabel == 'Unknown size') {
          _urlWarning.value =
              'Could not resolve file size. Ensure the URL is accessible.';
          widget.sizeController.text = 'Unknown size';
        } else {
          _urlWarning.value = '';
          widget.sizeController.text = sizeLabel;
        }
      } catch (e) {
        _urlWarning.value = 'Could not resolve file size: $e';
        widget.sizeController.text = 'Unknown size';
      } finally {
        widget.isDetecting.value = false;
      }
    });
  }

  Future<void> _detectSize() async {
    final url = widget.urlController.text.trim();
    if (url.isEmpty) return;
    widget.isDetecting.value = true;
    try {
      final sizeLabel = await widget.modelController.detectUrlSize(url);
      if (sizeLabel == 'Unknown size') {
        _urlWarning.value =
            'Could not resolve file size. Ensure the URL is accessible.';
        widget.sizeController.text = 'Unknown size';
      } else {
        _urlWarning.value = '';
        widget.sizeController.text = sizeLabel;
      }
    } catch (e) {
      _urlWarning.value = 'Could not resolve file size: $e';
      widget.sizeController.text = 'Unknown size';
    } finally {
      widget.isDetecting.value = false;
    }
  }

  Future<void> _submit() async {
    final url = widget.urlController.text.trim();
    if (url.isEmpty) return;

    // Validate format synchronously
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _urlError.value =
          'Invalid URL format. Must start with http:// or https://';
      return;
    }

    if (_urlError.value.isNotEmpty) return;
    _urlDebounce?.cancel();

    await widget.modelController.addModelFromUrl(
      name: widget.nameController.text.trim().isEmpty
          ? widget.filenameController.text
          : widget.nameController.text.trim(),
      url: url,
      filename: widget.filenameController.text,
      size: widget.sizeController.text.isEmpty
          ? 'Unknown size'
          : widget.sizeController.text,
      description: 'Added custom model via URL',
      template: widget.templateController.text,
      isVision: widget.isVision.value,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final scheme = Theme.of(context).colorScheme;
    final sheetBg = scheme.surfaceContainerLowest;
    final fieldBg = scheme.surfaceContainerHigh;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        margin: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        Icon(PhosphorIconsBold.link, color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Model URL',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Download a GGUF or LiteRT model from any URL',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(PhosphorIconsBold.x,
                        color: scheme.onSurfaceVariant, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(label: 'MODEL URL'),
                    const SizedBox(height: 8),
                    _SheetTextField(
                      controller: widget.urlController,
                      hint: 'https://huggingface.co/…/model.gguf',
                      prefixIcon: PhosphorIconsBold.link,
                      keyboardType: TextInputType.url,
                      bg: fieldBg,
                      border: Colors.transparent,
                    ),
                    Obx(() {
                      if (_urlError.value.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              Icon(PhosphorIconsBold.xCircle,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _urlError.value,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (_urlWarning.value.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              Icon(PhosphorIconsBold.warning,
                                  size: 13, color: Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _urlWarning.value,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 20),

                    const _SectionLabel(label: 'MODEL INFO'),
                    const SizedBox(height: 8),
                    _SheetTextField(
                      controller: widget.nameController,
                      hint: 'Display name  (e.g. Qwen3-0.6B)',
                      prefixIcon: PhosphorIconsBold.tag,
                      bg: fieldBg,
                      border: Colors.transparent,
                    ),
                    const SizedBox(height: 12),
                    _SheetTextField(
                      controller: widget.filenameController,
                      hint: 'Filename  (e.g. qwen3-0.6b.gguf)',
                      prefixIcon: PhosphorIconsBold.file,
                      bg: fieldBg,
                      border: Colors.transparent,
                    ),
                    const SizedBox(height: 20),

                    const _SectionLabel(label: 'FILE SIZE'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SheetTextField(
                            controller: widget.sizeController,
                            hint: 'e.g. 1.2 GB',
                            prefixIcon: PhosphorIconsBold.chartDonut,
                            bg: fieldBg,
                            border: Colors.transparent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Obx(() => _DetectSizeButton(
                              isLoading: widget.isDetecting.value,
                              onTap: _detectSize,
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const _SectionLabel(label: 'CHAT TEMPLATE'),
                    const SizedBox(height: 8),
                    _TemplateSelector(
                      controller: widget.templateController,
                      templates: _templates,
                      bg: fieldBg,
                      border: Colors.transparent,
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),

                    Obx(() => _VisionToggle(
                          value: widget.isVision.value,
                          onChanged: (v) => widget.isVision.value = v,
                          bg: fieldBg,
                          border: Colors.transparent,
                        )),
                    const SizedBox(height: 28),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text('Cancel',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: FilledButton.icon(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: Icon(PhosphorIconsBold.arrowDown,
                                size: 18),
                            label: Text(
                              'Add Model',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ── Styled text field ─────────────────────────────────────────────────────────
class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final Color bg;
  final Color border;

  const _SheetTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(
            fontSize: 14,
            color: scheme.onSurface,
            fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
              fontSize: 13, color: scheme.onSurfaceVariant),
          prefixIcon:
              Icon(prefixIcon, color: scheme.onSurfaceVariant, size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Detect Size button ────────────────────────────────────────────────────────
class _DetectSizeButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _DetectSizeButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color:
              isLoading ? scheme.surfaceContainerHighest : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: scheme.primary),
                )
              : Icon(PhosphorIconsBold.broadcast, color: scheme.primary, size: 22),
        ),
      ),
    );
  }
}

// ── Template selector ─────────────────────────────────────────────────────────
class _TemplateSelector extends StatefulWidget {
  final TextEditingController controller;
  final List<String> templates;
  final Color bg;
  final Color border;
  final Color accentColor;

  const _TemplateSelector({
    required this.controller,
    required this.templates,
    required this.bg,
    required this.border,
    required this.accentColor,
  });

  @override
  State<_TemplateSelector> createState() => _TemplateSelectorState();
}

class _TemplateSelectorState extends State<_TemplateSelector> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.templates.map((t) {
          final sel = widget.controller.text == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => widget.controller.text = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? scheme.secondaryContainer
                      : widget.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t,
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Vision toggle ─────────────────────────────────────────────────────────────
class _VisionToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color bg;
  final Color border;

  const _VisionToggle({
    required this.value,
    required this.onChanged,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = value
        ? scheme.onSecondaryContainer
        : scheme.onSurface;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value ? scheme.secondaryContainer : bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: value
                    ? scheme.surfaceContainerHighest
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                value ? PhosphorIconsBold.eye : PhosphorIconsBold.eyeSlash,
                color:
                    value ? scheme.primary : scheme.onSurfaceVariant,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vision Model',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    'Supports image input (multimodal)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: value
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: scheme.onSecondaryContainer,
              activeTrackColor: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
