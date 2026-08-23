import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/server_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/constants.dart';
import '../services/inference_service.dart';
import '../services/hive_service.dart';
import '../services/local_image_service.dart';
import '../services/device_info_service.dart';
import '../services/device_info_native.dart' as platform_info;
import '../ffi/sd_ffi_bindings.dart';
import '../widgets/pressable_scale.dart';
import 'log_view.dart';
import 'server_view.dart';
import 'welcome_guide_view.dart';
import 'license_view.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090A0E) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings & Hardware',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0E1017),
          ),
        ),
        toolbarHeight: 56,
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ── APPEARANCE ──
            _sectionLabel(context, 'APPEARANCE'),
            _appleGroupedCard(context, children: [
              for (final mode in [
                ThemeMode.light,
                ThemeMode.dark,
                ThemeMode.system
              ])
                _appleListTile(
                  context,
                  leading: _iconBox(context, _themeModeIcon(mode)),
                  title: _themeModeName(mode),
                  trailing: controller.themeMode.value == mode
                      ? Icon(Icons.check_rounded,
                          size: 18, color: isDark ? Colors.white : const Color(0xFF141620))
                      : null,
                  showDivider: mode != ThemeMode.system,
                  onTap: () => controller.setThemeMode(mode),
                ),
            ]),
            const SizedBox(height: 28),

            // ── INFERENCE ENGINE & MODE ──
            _sectionLabel(context, 'INFERENCE MODE'),
            _appleGroupedCard(context, children: [
              _appleListTile(
                context,
                leading: _iconBox(context, Icons.memory_rounded),
                title: 'Local On-Device Engine',
                subtitle: _localSubtitle(),
                trailing: controller.inferenceMode.value == 'local'
                    ? Icon(Icons.check_rounded,
                        size: 18, color: isDark ? Colors.white : const Color(0xFF141620))
                    : null,
                showDivider: true,
                onTap: () => controller.setInferenceMode('local'),
              ),
              _appleListTile(
                context,
                leading: _iconBox(context, Icons.hub_outlined),
                title: 'Cloud API Provider',
                subtitle: controller.cloudProvider.value.toUpperCase(),
                trailing: controller.inferenceMode.value == 'cloud'
                    ? Icon(Icons.check_rounded,
                        size: 18, color: isDark ? Colors.white : const Color(0xFF141620))
                    : null,
                showDivider: false,
                onTap: () => controller.setInferenceMode('cloud'),
              ),
            ]),
            const SizedBox(height: 28),

            // ── DEVICE HARDWARE CALIBRATION ──
            _sectionLabel(context, 'DEVICE CALIBRATION'),
            _buildDeviceCard(context),
            const SizedBox(height: 28),

            // ── LOCAL API SERVER ──
            _buildServerSection(context),
            const SizedBox(height: 28),

            // ── GLOBAL SYSTEM PROMPT ──
            _sectionLabel(context, 'GLOBAL SYSTEM PROMPT'),
            _appleGroupedCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Applies across local GGUF, LiteRT, and cloud sessions',
                      style: GoogleFonts.openSans(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller.globalSystemPromptController,
                      minLines: 3,
                      maxLines: 6,
                      style: GoogleFonts.openSans(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF12141D),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161922) : const Color(0xFFF1F3F8),
                        hintText: AppConstants.systemPrompt,
                        hintStyle: GoogleFonts.openSans(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF5A6074) : const Color(0xFF9EA5B6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF282D3D) : const Color(0xFFD6DBE8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF282D3D) : const Color(0xFFD6DBE8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white : const Color(0xFF12141D),
                            width: 1.2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 20,
                            color: isDark ? Colors.white : const Color(0xFF12141D),
                          ),
                          onPressed: () => controller.setGlobalSystemPrompt(
                            controller.globalSystemPromptController.text,
                          ),
                        ),
                      ),
                      onSubmitted: (v) => controller.setGlobalSystemPrompt(v),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 28),

            // ── MODEL PARAMETERS & TUNING ──
            _sectionLabel(context, 'MODEL PARAMETERS'),
            _buildLiteRtCard(context),
            const SizedBox(height: 16),
            _buildModelParametersCard(context),
            const SizedBox(height: 28),

            // ── IMAGE GENERATION PARAMETERS ──
            _sectionLabel(context, 'IMAGE GENERATION PARAMETERS'),
            _buildImageGenerationCard(context),
            const SizedBox(height: 28),

            // ── DIAGNOSTICS & LOGS ──
            _sectionLabel(context, 'DIAGNOSTICS & SYSTEM'),
            _appleGroupedCard(context, children: [
              _appleListTile(
                context,
                leading: _iconBox(context, Icons.terminal_rounded),
                title: 'Diagnostics & Logs',
                subtitle: 'Real-time engine logs, token speed & debug events',
                trailing: const Icon(Icons.chevron_right, size: 18),
                showDivider: false,
                onTap: () => Get.to(() => const LogView()),
              ),
            ]),
            const SizedBox(height: 28),

            // ── ABOUT & LEGAL ──
            _sectionLabel(context, 'ABOUT & LEGAL'),
            _appleGroupedCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D28) : const Color(0xFFE9EDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B3042) : const Color(0xFFD4DAE6),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          'assets/icons/appicon.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.blur_on_rounded,
                            size: 24,
                            color: isDark ? Colors.white : const Color(0xFF141620),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AstraLM',
                          style: GoogleFonts.manrope(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0E1017),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.appVersion.value.isEmpty
                              ? 'Version 2.0.0 · Local AI Platform'
                              : 'v${controller.appVersion.value} · Local AI Platform',
                          style: GoogleFonts.openSans(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _appleListTile(
                context,
                leading: _iconBox(context, Icons.auto_awesome_rounded),
                title: 'Welcome Walkthrough',
                subtitle: 'Replay animated AstraLM introduction tour',
                trailing: const Icon(Icons.chevron_right, size: 18),
                showDivider: true,
                onTap: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (_, __, ___) =>
                        const WelcomeGuideView(isReplay: true),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 320),
                  ),
                ),
              ),
              _appleListTile(
                context,
                leading: _iconBox(context, Icons.gavel_rounded),
                title: 'Licenses & Legal Policy',
                subtitle: 'MIT open-source license & privacy guarantees',
                trailing: const Icon(Icons.chevron_right, size: 18),
                showDivider: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicenseView()),
                ),
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── AstraLM Monochrome Grouped Card Container ──
  Widget _appleGroupedCard(BuildContext context,
      {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  // ── AstraLM Monochrome List Tile ──
  Widget _appleListTile(
    BuildContext context, {
    Widget? leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressableScale(
          onTap: onTap,
          pressedScale: 0.98,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.openSans(
                            fontSize: 12.5,
                            color: isDark
                                ? const Color(0xFF8E95A8)
                                : const Color(0xFF6B7284),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 64,
            color: isDark ? const Color(0xFF1D212F) : const Color(0xFFECEFF6),
          ),
      ],
    );
  }

  // ── Clean Space Gray / Monochrome Icon Badge ──
  Widget _iconBox(BuildContext context, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D27) : const Color(0xFFECEFF5),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: isDark ? const Color(0xFFE2E6F2) : const Color(0xFF161822),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF636A7D),
        ),
      ),
    );
  }

  String _localSubtitle() {
    final inf = Get.find<InferenceService>();
    final localImage = Get.find<LocalImageService>();
    if (inf.isModelLoaded.value) {
      return 'Active: ${inf.loadedModelName.value}';
    } else if (localImage.isModelLoaded.value) {
      return 'Active: ${localImage.loadedModelName.value}';
    }
    return 'No model loaded';
  }

  Widget _buildDeviceCard(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final device = Get.find<DeviceInfoService>();

      final soc = device.socFamily.value;
      final quantWarning = soc.quantWarning;

      return _appleGroupedCard(context, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _iconBox(context, Icons.smartphone_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.tierDescription,
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0E1017),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Available: ${device.availableRamGB.value.toStringAsFixed(1)}GB · Context: ${device.recommendedContextSize} · Tokens: ${device.recommendedMaxTokens}',
                      style: GoogleFonts.openSans(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // SoC + quantization recommendation
        if (soc != platform_info.SocFamily.unknown) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _iconBox(context, Icons.memory_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soc.displayName,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recommended: ${soc.recommendedQuant}',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // Warning banner for problematic SoCs
        if (quantWarning != null) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222634) : const Color(0xFFECEFF6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF32384C) : const Color(0xFFD4DAE8),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFFBAC0D0) : const Color(0xFF4A5060),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quantWarning,
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFBAC0D0) : const Color(0xFF4A5060),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]);
    });
  }

  Widget _buildLiteRtCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modes = [
      (
        value: 'auto_fast',
        title: 'Auto Fast',
        subtitle: 'Try GPU first, then CPU fallback',
        icon: Icons.auto_awesome_rounded
      ),
      (
        value: 'gpu_fast',
        title: 'GPU Fast',
        subtitle: 'Maximum speed, may crash on some devices',
        icon: Icons.bolt_rounded
      ),
      (
        value: 'cpu_safe',
        title: 'CPU Safe',
        subtitle: 'Stable mode with lower speed',
        icon: Icons.shield_outlined
      ),
    ];
    return _appleGroupedCard(context, children: [
      for (var i = 0; i < modes.length; i++)
        _appleListTile(
          context,
          leading: _iconBox(context, modes[i].icon),
          title: modes[i].title,
          subtitle: modes[i].subtitle,
          trailing: controller.liteRtPerformanceMode.value == modes[i].value
              ? Icon(Icons.check_rounded,
                  size: 18, color: isDark ? Colors.white : const Color(0xFF141620))
              : null,
          showDivider: i < modes.length - 1,
          onTap: () => controller.setLiteRtPerformanceMode(modes[i].value),
        ),
    ]);
  }

  Widget _buildModelParametersCard(BuildContext context) {
    return _appleGroupedCard(context, children: [
      _modelParameterSlider(
        context,
        label: 'Temperature',
        value: controller.temperature.value,
        min: 0.0,
        max: 2.0,
        divisions: 20,
        safeMax: 1.0,
        onChanged: (v) => controller.setTemperature(v),
        icon: Icons.thermostat_rounded,
        warning: 'High temperature = unpredictable output!',
      ),
      const Divider(height: 1),
      _modelParameterSlider(
        context,
        label: 'Max Tokens',
        subtitle:
            'Local models are strictly instructed and constrained to generate under this token limit.',
        value: controller.maxTokens.value.toDouble(),
        min: 64,
        max: 4096,
        divisions: 63,
        safeMax: Get.find<DeviceInfoService>().maxSafeTokens.toDouble(),
        onChanged: (v) => controller.setMaxTokens(v.toInt()),
        displayValue: controller.maxTokens.value.toString(),
        icon: Icons.tag_rounded,
        warning: 'Your phone may crash with this value!',
      ),
      const Divider(height: 1),
      (() {
        final inference = Get.find<InferenceService>();
        final savedRuntime = Get.find<HiveService>()
                .getSetting<String>(AppConstants.keyLocalModelRuntime) ??
            '';
        final isLiteRtActive = (inference.isModelLoaded.value &&
                inference.loadedModelRuntime.value == 'litert') ||
            (!inference.isModelLoaded.value &&
                savedRuntime.toLowerCase() == 'litert');
        final maxContext = isLiteRtActive ? 4096.0 : 8192.0;
        final divisions = isLiteRtActive ? 7 : 15;
        final currentValue =
            controller.contextSize.value.toDouble().clamp(512.0, maxContext);

        if (currentValue != controller.contextSize.value.toDouble()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.setContextSize(currentValue.toInt());
          });
        }

        return _modelParameterSlider(
          context,
          label: 'Context Size',
          value: currentValue,
          min: 512,
          max: maxContext,
          divisions: divisions,
          safeMax: Get.find<DeviceInfoService>().maxSafeContextSize.toDouble(),
          onChanged: (v) => controller.setContextSize(v.toInt()),
          displayValue: currentValue.toInt().toString(),
          icon: Icons.memory_rounded,
          warning: isLiteRtActive
              ? 'Context capped at 4096 to prevent driver memory crash for LiteRT models.'
              : 'Context this large will eat all your RAM!',
        );
      })(),
    ]);
  }

  Widget _buildImageGenerationCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stepsValue = controller.imageSteps.value.toDouble();
    const safeMax = 8.0;
    final isOver = stepsValue > safeMax;
    final selectedBackend = controller.imageGenBackend.value;
    final gpuBackend = controller.recommendedImageGpuBackend();
    final gpuAvailable = gpuBackend != Backend.cpu;

    return _appleGroupedCard(context, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBox(context, Icons.image_rounded),
            const SizedBox(width: 12),
            Text(
              'Image Gen Steps',
              style: GoogleFonts.manrope(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0E1017),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E212E) : const Color(0xFFECEFF6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D3346) : const Color(0xFFD4DAE8),
                ),
              ),
              child: Text(
                controller.imageSteps.value.toString(),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF141620),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Recommended max: 8',
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
              ),
            ),
          ),
          Slider(
            value: stepsValue.clamp(1, 20),
            min: 1,
            max: 20,
            divisions: 19,
            activeColor: isDark ? Colors.white : const Color(0xFF141620),
            inactiveColor: isDark ? const Color(0xFF262B3B) : const Color(0xFFD6DBE8),
            onChanged: (v) => controller.setImageSteps(v.toInt()),
          ),
          if (isOver)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E212D) : const Color(0xFFECEFF6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'More steps = better quality but MUCH slower!',
                style: GoogleFonts.openSans(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFFBAC0D0) : const Color(0xFF4A5060),
                ),
              ),
            ),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBox(context, Icons.photo_size_select_large_rounded),
            const SizedBox(width: 12),
            Text(
              'Image Size',
              style: GoogleFonts.manrope(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0E1017),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E212E) : const Color(0xFFECEFF6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D3346) : const Color(0xFFD4DAE8),
                ),
              ),
              child: Text(
                controller.imageGenSize.value == 0
                    ? 'Auto'
                    : '${controller.imageGenSize.value}px',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF141620),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Text(
              'Auto recommended. Bigger size = better detail, but much slower.',
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                (value: 0, label: 'Auto'),
                (value: 256, label: '256'),
                (value: 320, label: '320'),
                (value: 384, label: '384'),
                (value: 512, label: '512'),
              ])
                ChoiceChip(
                  label: Text(option.label),
                  selected: controller.imageGenSize.value == option.value,
                  onSelected: (_) => controller.setImageGenSize(option.value),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                    color: controller.imageGenSize.value == option.value
                        ? (isDark ? Colors.white : const Color(0xFF141620))
                        : (isDark ? const Color(0xFF282D3D) : const Color(0xFFD4D9E6)),
                  ),
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: controller.imageGenSize.value == option.value
                        ? (isDark ? const Color(0xFF090A0E) : Colors.white)
                        : (isDark ? const Color(0xFFBAC0D0) : const Color(0xFF4A5060)),
                  ),
                  selectedColor: isDark ? Colors.white : const Color(0xFF141620),
                  backgroundColor: isDark ? const Color(0xFF181B26) : const Color(0xFFECEFF5),
                  showCheckmark: false,
                ),
            ],
          ),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBox(
              context,
              selectedBackend == Backend.cpu
                  ? Icons.memory_rounded
                  : Icons.bolt_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Image Backend',
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0E1017),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.imageGpuLabel(),
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.memory_rounded, size: 16),
                  label: Text('CPU'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.bolt_rounded, size: 16),
                  label: Text('GPU'),
                ),
              ],
              selected: {selectedBackend != Backend.cpu},
              onSelectionChanged: (values) {
                final useGpu = values.first;
                if (useGpu && !gpuAvailable) return;
                controller.setImageBackendMode(useGpu);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _modelParameterSlider(
    BuildContext context, {
    required String label,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required double safeMax,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required String warning,
    String? displayValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(context, icon),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0E1017),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E212E) : const Color(0xFFECEFF6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF2D3346) : const Color(0xFFD4DAE8),
              ),
            ),
            child: Text(
              displayValue ?? value.toStringAsFixed(2),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF141620),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        if (subtitle != null && subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              subtitle,
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                height: 1.35,
              ),
            ),
          ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: isDark ? Colors.white : const Color(0xFF141620),
          inactiveColor: isDark ? const Color(0xFF262B3B) : const Color(0xFFD6DBE8),
          onChanged: (v) {
            if (v > safeMax && value <= safeMax) {
              HapticFeedback.heavyImpact();
            }
            onChanged(v);
          },
        ),
      ]),
    );
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.dark:
        return 'Dark Theme (AstraLM Space Obsidian)';
      case ThemeMode.system:
        return 'Match System Appearance';
    }
  }

  Widget _buildServerSection(BuildContext context) {
    final serverController = Get.find<ServerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isRunning = serverController.isRunning.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, 'LOCAL API SERVER'),
          _appleGroupedCard(context, children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E212E) : const Color(0xFFECEFF6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2D3346) : const Color(0xFFD4DAE8),
                      ),
                    ),
                    child: Text(
                      isRunning ? 'RUNNING' : 'STOPPED',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF141620),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRunning ? 'OpenAI API Running' : 'OpenAI API Stopped',
                          style: GoogleFonts.manrope(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0E1017),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRunning
                              ? 'http://localhost:8080/v1'
                              : 'Expose local model to other apps & LAN',
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isRunning,
                    activeColor: isDark ? Colors.white : const Color(0xFF141620),
                    onChanged: serverController.isStarting.value
                        ? null
                        : (v) => serverController.toggleServer(v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _appleListTile(
              context,
              leading: _iconBox(context, Icons.dns_outlined),
              title: 'Server Dashboard & Endpoints',
              subtitle: 'API keys, CORS, docs & client examples',
              trailing: const Icon(Icons.chevron_right, size: 18),
              showDivider: false,
              onTap: () => Get.to(() => const ServerView()),
            ),
          ]),
        ],
      );
    });
  }
}
