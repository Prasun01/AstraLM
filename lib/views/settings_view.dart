import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/settings_controller.dart';
import '../core/constants.dart';
import '../services/inference_service.dart';
import '../services/hive_service.dart';
import '../services/device_info_service.dart';
import '../services/device_info_native.dart' as platform_info;
import '../ffi/sd_ffi_bindings.dart';
import '../widgets/pressable_scale.dart';
import 'log_view.dart';
import 'server_view.dart';
import 'welcome_guide_view.dart';
import 'license_view.dart';
import '../services/app_update_service.dart';

// ─────────────────────────────────────────────────────────────
// MAIN SETTINGS HUB (BORDERLESS STRICT MONOCHROME)
// ─────────────────────────────────────────────────────────────

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final deviceInfo = Get.find<DeviceInfoService>();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIconsBold.caretLeft,
              size: 20,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        toolbarHeight: 56,
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            // ── INTERFACE ──
            _sectionLabel(context, 'INTERFACE'),
            _monoGroupedCard(context, children: [
              _monoListTile(
                context,
                title: 'Appearance & Theme',
                subtitle: null,
                trailing: _chevronTrailing(isDark),
                showDivider: false,
                onTap: () => Get.to(() => const AppearanceSubView()),
              ),
            ]),
            const SizedBox(height: 22),

            // ── AI & INFERENCE ──
            _sectionLabel(context, 'AI & INFERENCE'),
            _monoGroupedCard(context, children: [
              _monoListTile(
                context,
                title: 'Inference & Model Parameters',
                subtitle: null,
                trailing: _chevronTrailing(isDark),
                showDivider: true,
                onTap: () => Get.to(() => const InferenceSettingsSubView()),
              ),
              _monoListTile(
                context,
                title: 'Cloud Providers & API Keys',
                subtitle: null,
                trailing: _chevronTrailing(isDark),
                showDivider: true,
                onTap: () => Get.to(() => const CloudProvidersSubView()),
              ),
              _monoListTile(
                context,
                title: 'Local API Server',
                subtitle: null,
                trailing: _chevronTrailing(isDark),
                showDivider: false,
                onTap: () => Get.to(() => const ServerView()),
              ),
            ]),
            const SizedBox(height: 22),

            // ── SYSTEM & HARDWARE ──
            _sectionLabel(context, 'SYSTEM & HARDWARE'),
            _monoGroupedCard(context, children: [
              _monoListTile(
                context,
                title: 'Device Hardware & Calibration',
                subtitle: '${deviceInfo.tierDescription} · ${deviceInfo.availableRamGB.value.toStringAsFixed(1)}GB RAM Available',
                trailing: _chevronTrailing(isDark),
                showDivider: true,
                onTap: () => Get.to(() => const DeviceCalibrationSubView()),
              ),
              _monoListTile(
                context,
                title: 'Diagnostics & Live Logs',
                subtitle: null,
                trailing: _chevronTrailing(isDark),
                showDivider: false,
                onTap: () => Get.to(() => const LogView()),
              ),
            ]),
            const SizedBox(height: 22),

            // ── ABOUT ──
            _sectionLabel(context, 'ABOUT'),
            _monoGroupedCard(context, children: [
              _monoListTile(
                context,
                title: 'About AstraLM',
                subtitle: null,
                trailing: _chevronTrailing(isDark),
                showDivider: false,
                onTap: () => Get.to(() => const AboutSubView()),
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-VIEW 1: APPEARANCE SUB-SETTINGS
// ─────────────────────────────────────────────────────────────

class AppearanceSubView extends GetView<SettingsController> {
  const AppearanceSubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIconsBold.caretLeft,
              size: 20,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Appearance & Theme',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            _sectionLabel(context, 'COLOR THEME'),
            _monoGroupedCard(context, children: [
              _monoListTile(
                context,
                title: 'Light',
                trailing: controller.themeMode.value == ThemeMode.light
                    ? PhosphorIcon(PhosphorIconsBold.check,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black)
                    : null,
                showDivider: true,
                onTap: () => controller.setThemeMode(ThemeMode.light),
              ),
              _monoListTile(
                context,
                title: 'Dark',
                trailing: controller.themeMode.value == ThemeMode.dark
                    ? PhosphorIcon(PhosphorIconsBold.check,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black)
                    : null,
                showDivider: true,
                onTap: () => controller.setThemeMode(ThemeMode.dark),
              ),
              _monoListTile(
                context,
                title: 'System',
                trailing: controller.themeMode.value == ThemeMode.system
                    ? PhosphorIcon(PhosphorIconsBold.check,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black)
                    : null,
                showDivider: false,
                onTap: () => controller.setThemeMode(ThemeMode.system),
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-VIEW 2: INFERENCE & MODEL PARAMETERS
// ─────────────────────────────────────────────────────────────

class InferenceSettingsSubView extends GetView<SettingsController> {
  const InferenceSettingsSubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIconsBold.caretLeft,
              size: 20,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Inference & Parameters',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            // ── INFERENCE MODE ──
            _sectionLabel(context, 'DEFAULT INFERENCE MODE'),
            _monoGroupedCard(context, children: [
              _monoListTile(
                context,
                title: 'Local On-Device Engine',
                trailing: controller.inferenceMode.value == 'local'
                    ? PhosphorIcon(PhosphorIconsBold.check,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black)
                    : null,
                showDivider: true,
                onTap: () => controller.setInferenceMode('local'),
              ),
              _monoListTile(
                context,
                title: 'Cloud API Provider',
                trailing: controller.inferenceMode.value == 'cloud'
                    ? PhosphorIcon(PhosphorIconsBold.check,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black)
                    : null,
                showDivider: false,
                onTap: () => controller.setInferenceMode('cloud'),
              ),
            ]),
            const SizedBox(height: 22),

            // ── DEVELOPER & SYSTEM INSTRUCTIONS ──
            _sectionLabel(context, 'DEVELOPER & SYSTEM INSTRUCTIONS'),
            _monoGroupedCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Preset Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _developerPresetChip(
                            '⚡ Default',
                            () => controller.setGlobalSystemPrompt(AppConstants.systemPrompt),
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _developerPresetChip(
                            '💻 Senior Dev',
                            () => controller.setGlobalSystemPrompt(SettingsController.developerPromptSeniorDev),
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _developerPresetChip(
                            '✂️ Concise',
                            () => controller.setGlobalSystemPrompt(SettingsController.developerPromptConcise),
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller.globalSystemPromptController,
                      minLines: 4,
                      maxLines: 8,
                      style: GoogleFonts.firaCode(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF181818) : const Color(0xFFEFEFEF),
                        hintText: 'Enter custom developer directives or system prompt…',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => controller.setGlobalSystemPrompt(AppConstants.systemPrompt),
                          child: Text(
                            'Reset Default',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8E95A8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            controller.setGlobalSystemPrompt(controller.globalSystemPromptController.text);
                            Get.snackbar(
                              'Instructions Saved',
                              'Developer system directives updated.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(12),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Save Directives',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 22),

            // ── LITERTLM PERFORMANCE MODE ──
            _sectionLabel(context, 'LITERTLM GPU/CPU MODE'),
            _buildLiteRtCard(context, controller),
            const SizedBox(height: 22),

            // ── MODEL PARAMETERS & TUNING ──
            _sectionLabel(context, 'LOCAL MODEL TUNING'),
            _buildModelParametersCard(context, controller),
            const SizedBox(height: 22),

            // ── IMAGE GENERATION PARAMETERS ──
            _sectionLabel(context, 'IMAGE GENERATION PARAMETERS'),
            _buildImageGenerationCard(context, controller),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _developerPresetChip(String label, VoidCallback onTap, bool isDark) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-VIEW 3: CLOUD API PROVIDERS & KEYS
// ─────────────────────────────────────────────────────────────

class CloudProvidersSubView extends GetView<SettingsController> {
  const CloudProvidersSubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final providers = [
      (id: 'openrouter', name: 'OpenRouter', icon: PhosphorIconsBold.stack),
      (id: 'openai', name: 'OpenAI', icon: PhosphorIconsBold.sparkle),
      (id: 'anthropic', name: 'Anthropic Claude', icon: PhosphorIconsBold.brain),
      (id: 'google', name: 'Google Gemini', icon: PhosphorIconsBold.sparkle),
      (id: 'deepseek', name: 'DeepSeek', icon: PhosphorIconsBold.lightning),
      (id: 'kimi', name: 'Moonshot Kimi', icon: PhosphorIconsBold.sparkle),
      (id: 'nvidia', name: 'NVIDIA NIM', icon: PhosphorIconsBold.cpu),
      (id: 'stability', name: 'Stability AI', icon: PhosphorIconsBold.image),
      (id: 'custom', name: 'Custom OpenAI-Compatible', icon: PhosphorIconsBold.database),
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIconsBold.caretLeft,
              size: 20,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cloud Providers & Keys',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            _sectionLabel(context, 'ACTIVE CLOUD PROVIDER'),
            _monoGroupedCard(context, children: [
              for (var i = 0; i < providers.length; i++)
                _monoListTile(
                  context,
                  title: providers[i].name,
                  trailing: controller.cloudProvider.value == providers[i].id
                      ? PhosphorIcon(PhosphorIconsBold.check,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black)
                      : null,
                  showDivider: i < providers.length - 1,
                  onTap: () {
                    controller.setCloudProvider(providers[i].id);
                    controller.setInferenceMode('cloud');
                  },
                ),
            ]),
            const SizedBox(height: 22),

            _sectionLabel(context, 'API KEYS'),
            _monoGroupedCard(context, children: [
              _buildApiKeyField(
                context,
                title: 'OpenRouter',
                controller: controller.openRouterKeyController,
                onChanged: (v) => controller.setApiKey('openrouter', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'Google Gemini',
                controller: controller.googleKeyController,
                onChanged: (v) => controller.setApiKey('google', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'DeepSeek',
                controller: controller.deepSeekKeyController,
                onChanged: (v) => controller.setApiKey('deepseek', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'OpenAI',
                controller: controller.openaiKeyController,
                onChanged: (v) => controller.setApiKey('openai', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'Anthropic Claude',
                controller: controller.anthropicKeyController,
                onChanged: (v) => controller.setApiKey('anthropic', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'Moonshot Kimi',
                controller: controller.kimiKeyController,
                onChanged: (v) => controller.setApiKey('kimi', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'NVIDIA NIM',
                controller: controller.nvidiaKeyController,
                onChanged: (v) => controller.setApiKey('nvidia', v),
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildApiKeyField(
                context,
                title: 'Stability AI',
                controller: controller.stabilityKeyController,
                onChanged: (v) => controller.setApiKey('stability', v),
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 22),

            _sectionLabel(context, 'CUSTOM OPENAI ENDPOINT'),
            _monoGroupedCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _customEndpointTextField(
                      controller: controller.customCloudBaseUrlController,
                      hint: 'http://192.168.1.100:11434/v1',
                      label: 'Base URL',
                      isDark: isDark,
                      onChanged: (v) => controller.setCustomCloudBaseUrl(v),
                    ),
                    const SizedBox(height: 10),
                    _customEndpointTextField(
                      controller: controller.customCloudKeyController,
                      hint: 'API Key (optional)',
                      label: 'API Key',
                      isDark: isDark,
                      obscure: true,
                      onChanged: (v) => controller.setCustomCloudKey(v),
                    ),
                    const SizedBox(height: 10),
                    _customEndpointTextField(
                      controller: controller.customCloudModelController,
                      hint: 'model-id (e.g. llama3:8b)',
                      label: 'Model Name',
                      isDark: isDark,
                      onChanged: (v) => controller.setCustomCloudModel(v),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyField(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: true,
            onChanged: onChanged,
            style: GoogleFonts.firaCode(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF181818) : const Color(0xFFEFEFEF),
              hintText: 'Paste API key…',
              hintStyle: GoogleFonts.inter(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customEndpointTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required bool isDark,
    bool obscure = false,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? const Color(0xFF888888) : const Color(0xFF666666),
        ),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF181818) : const Color(0xFFEFEFEF),
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-VIEW 4: DEVICE HARDWARE CALIBRATION
// ─────────────────────────────────────────────────────────────

class DeviceCalibrationSubView extends StatelessWidget {
  const DeviceCalibrationSubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final device = Get.find<DeviceInfoService>();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIconsBold.caretLeft,
              size: 20,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Device Calibration',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Obx(() {
        final soc = device.socFamily.value;
        final quantWarning = soc.quantWarning;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            _sectionLabel(context, 'HARDWARE PROFILE'),
            _monoGroupedCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.tierDescription,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total RAM: ${device.totalRamGB.value.toStringAsFixed(1)} GB · Available: ${device.availableRamGB.value.toStringAsFixed(1)} GB',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF888888) : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _monoListTile(
                context,
                title: 'Recommended Context Size',
                subtitle: '${device.recommendedContextSize} tokens',
                showDivider: true,
              ),
              _monoListTile(
                context,
                title: 'Recommended Max Tokens',
                subtitle: '${device.recommendedMaxTokens} tokens',
                showDivider: false,
              ),
            ]),
            const SizedBox(height: 22),

            if (soc != platform_info.SocFamily.unknown) ...[
              _sectionLabel(context, 'CHIPSET & QUANTIZATION'),
              _monoGroupedCard(context, children: [
                _monoListTile(
                  context,
                  title: soc.displayName,
                  subtitle: 'Recommended: ${soc.recommendedQuant}',
                  showDivider: false,
                ),
              ]),
              const SizedBox(height: 22),
            ],

            if (quantWarning != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141414) : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsBold.info,
                      size: 18,
                      color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        quantWarning,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 48),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-VIEW 5: ABOUT & LEGAL SUB-SETTINGS
// ─────────────────────────────────────────────────────────────

class AboutSubView extends GetView<SettingsController> {
  const AboutSubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIconsBold.caretLeft,
              size: 20,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About AstraLM',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        children: [
          _sectionLabel(context, 'APPLICATION'),
          _monoGroupedCard(context, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AstraLM',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Obx(
                    () => Text(
                      controller.appVersion.value.isEmpty
                          ? 'Version 1.0.6 · Local AI Platform'
                          : 'v${controller.appVersion.value} · Local AI Platform',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF888888) : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _monoListTile(
              context,
              title: 'Check for Updates',
              subtitle: 'GitHub Releases · Prasun01/AstraLM',
              trailing: Obx(() {
                final updateService = Get.find<AppUpdateService>();
                if (updateService.isChecking.value) {
                  return const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return _chevronTrailing(isDark);
              }),
              showDivider: false,
              onTap: () => Get.find<AppUpdateService>().checkForUpdates(
                isManual: true,
                context: context,
              ),
            ),
          ]),
          const SizedBox(height: 22),

          _sectionLabel(context, 'LEGAL & TOUR'),
          _monoGroupedCard(context, children: [
            _monoListTile(
              context,
              title: 'Welcome Walkthrough',
              subtitle: null,
              trailing: _chevronTrailing(isDark),
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
            _monoListTile(
              context,
              title: 'Licenses & Legal Policy',
              subtitle: null,
              trailing: _chevronTrailing(isDark),
              showDivider: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LicenseView()),
              ),
            ),
          ]),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED BORDERLESS MONOCHROME REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────

Widget _chevronTrailing(bool isDark) {
  return PhosphorIcon(
    PhosphorIconsBold.caretRight,
    size: 16,
    color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
  );
}

Widget _monoGroupedCard(BuildContext context,
    {required List<Widget> children}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

Widget _monoListTile(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF888888)
                              : const Color(0xFF666666),
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
          indent: 16,
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEDEDED),
        ),
    ],
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
        letterSpacing: 1.1,
        color: isDark ? const Color(0xFF777777) : const Color(0xFF888888),
      ),
    ),
  );
}

Widget _buildLiteRtCard(BuildContext context, SettingsController controller) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final modes = [
    (
      value: 'auto_fast',
      title: 'Auto Fast',
      icon: PhosphorIconsBold.sparkle
    ),
    (
      value: 'gpu_fast',
      title: 'GPU Fast',
      icon: PhosphorIconsBold.lightning
    ),
    (
      value: 'cpu_safe',
      title: 'CPU Safe',
      icon: PhosphorIconsBold.shieldCheck
    ),
  ];
  return _monoGroupedCard(context, children: [
    for (var i = 0; i < modes.length; i++)
      _monoListTile(
        context,
        title: modes[i].title,
        trailing: controller.liteRtPerformanceMode.value == modes[i].value
            ? PhosphorIcon(PhosphorIconsBold.check,
                size: 18, color: isDark ? Colors.white : Colors.black)
            : null,
        showDivider: i < modes.length - 1,
        onTap: () => controller.setLiteRtPerformanceMode(modes[i].value),
      ),
  ]);
}

Widget _buildModelParametersCard(BuildContext context, SettingsController controller) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return _monoGroupedCard(context, children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIconsBold.brain,
                size: 17,
                color: isDark ? const Color(0xFFBAC0CC) : const Color(0xFF5A6070),
              ),
              const SizedBox(width: 8),
              Text(
                'Reasoning Effort',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final current = controller.reasoningEffort.value;
            return Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1E28) : const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _effortOption('none', 'Direct (Off)', PhosphorIconsBold.lightning, current == 'none', isDark, () => controller.setReasoningEffort('none')),
                  _effortOption('standard', 'Standard', PhosphorIconsBold.brain, current == 'standard', isDark, () => controller.setReasoningEffort('standard')),
                  _effortOption('deep', 'Deep', PhosphorIconsBold.sparkle, current == 'deep', isDark, () => controller.setReasoningEffort('deep')),
                ],
              ),
            );
          }),
        ],
      ),
    ),
    const Divider(height: 1),
    _modelParameterSlider(
      context,
      label: 'Temperature',
      value: controller.temperature.value,
      min: 0.0,
      max: 2.0,
      divisions: 20,
      safeMax: 1.0,
      onChanged: (v) => controller.setTemperature(v),
      icon: PhosphorIconsBold.thermometer,
    ),
    const Divider(height: 1),
    _modelParameterSlider(
      context,
      label: 'Max Tokens',
      value: controller.maxTokens.value.toDouble(),
      min: 64,
      max: 4096,
      divisions: 63,
      safeMax: Get.find<DeviceInfoService>().maxSafeTokens.toDouble(),
      onChanged: (v) => controller.setMaxTokens(v.toInt()),
      displayValue: controller.maxTokens.value.toString(),
      icon: PhosphorIconsBold.tag,
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
        icon: PhosphorIconsBold.cpu,
      );
    })(),
  ]);
}

Widget _buildImageGenerationCard(BuildContext context, SettingsController controller) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final stepsValue = controller.imageSteps.value.toDouble();
  final selectedBackend = controller.imageGenBackend.value;
  final gpuBackend = controller.recommendedImageGpuBackend();
  final gpuAvailable = gpuBackend != Backend.cpu;

  return _monoGroupedCard(context, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          
          const SizedBox(width: 12),
          Text(
            'Image Steps',
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              controller.imageSteps.value.toString(),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        Slider(
          value: stepsValue.clamp(1, 20),
          min: 1,
          max: 20,
          divisions: 19,
          activeColor: isDark ? Colors.white : Colors.black,
          inactiveColor: isDark ? const Color(0xFF262626) : const Color(0xFFDCDCDC),
          onChanged: (v) => controller.setImageSteps(v.toInt()),
        ),
      ]),
    ),
    const Divider(height: 1),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          
          const SizedBox(width: 12),
          Text(
            'Image Size',
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              controller.imageGenSize.value == 0
                  ? 'Auto'
                  : '${controller.imageGenSize.value}px',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide.none,
                labelStyle: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: controller.imageGenSize.value == option.value
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? const Color(0xFFAAAAAA) : const Color(0xFF444444)),
                ),
                selectedColor: isDark ? Colors.white : Colors.black,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFEFEF),
                showCheckmark: false,
              ),
          ],
        ),
      ]),
    ),
    const Divider(height: 1),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Image Backend',
              style: GoogleFonts.manrope(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: PhosphorIcon(PhosphorIconsBold.cpu, size: 16),
                label: const Text('CPU'),
              ),
              ButtonSegment(
                value: true,
                icon: PhosphorIcon(PhosphorIconsBold.lightning, size: 16),
                label: const Text('GPU'),
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              side: const WidgetStatePropertyAll(BorderSide.none),
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
  required double value,
  required double min,
  required double max,
  required int divisions,
  required double safeMax,
  required ValueChanged<double> onChanged,
  required PhosphorIconData icon,
  String? displayValue,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            displayValue ?? value.toStringAsFixed(2),
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: isDark ? Colors.white : Colors.black,
        inactiveColor: isDark ? const Color(0xFF262626) : const Color(0xFFDCDCDC),
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

Widget _effortOption(
  String effort,
  String label,
  PhosphorIconData icon,
  bool isSelected,
  bool isDark,
  VoidCallback onTap,
) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E3342) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              icon,
              size: 13,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
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
