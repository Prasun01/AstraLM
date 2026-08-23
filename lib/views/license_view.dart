import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/pressable_scale.dart';

class LicenseView extends StatelessWidget {
  const LicenseView({super.key});

  static const String mitLicenseText = '''MIT License

Copyright (c) 2026 AstraLM Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'Licenses & Legal',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: scheme.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AstraLM Brand & Main MIT Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF262A36) : const Color(0xFFE2E6EF),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/icons/appicon.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AstraLM',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'Open Source · MIT License',
                              style: GoogleFonts.openSans(
                                fontSize: 13,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'MIT',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AstraLM is free, privacy-first open-source software. You are free to use, modify, distribute, and build upon this application.',
                    style: GoogleFonts.openSans(
                      fontSize: 13.5,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Privacy & Zero Telemetry Guarantee Card
            _sectionHeader(context, 'PRIVACY & DATA POLICY'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF262A36) : const Color(0xFFE2E6EF),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: Color(0xFF34C759), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '100% Local-First & Zero Telemetry',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• No tracking or telemetry SDKs.\n• Local chat logs, documents, and generated images stay strictly on your physical device.\n• Cloud mode communicates directly from your device to your selected provider using your private API key.',
                    style: GoogleFonts.openSans(
                      fontSize: 13,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // MIT Full Text Box
            _sectionHeader(context, 'APPLICATION LICENSE'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101218) : const Color(0xFFF3F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF222632) : const Color(0xFFE2E6EE),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MIT License Text',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      PressableScale(
                        onTap: () {
                          Clipboard.setData(
                              const ClipboardData(text: mitLicenseText));
                          Get.snackbar(
                            'Copied',
                            'License text copied to clipboard',
                            snackPosition: SnackPosition.TOP,
                            duration: const Duration(seconds: 1),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 14, color: scheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    mitLicenseText,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Core AI & Inference Engines
            _sectionHeader(context, 'NATIVE INFERENCE ENGINES'),
            _groupedCard(context, [
              _licenseTile(
                context,
                title: 'llama.cpp',
                subtitle: 'High-performance local LLM inference engine in C/C++',
                license: 'MIT License',
              ),
              _divider(context),
              _licenseTile(
                context,
                title: 'stable-diffusion.cpp',
                subtitle: 'On-device text-to-image diffusion pipeline',
                license: 'MIT License',
              ),
              _divider(context),
              _licenseTile(
                context,
                title: 'Google LiteRT (TensorFlow Lite)',
                subtitle: 'On-device neural network runtime for Android/NPU',
                license: 'Apache 2.0',
              ),
            ]),
            const SizedBox(height: 28),

            // Typography & Assets
            _sectionHeader(context, 'TYPOGRAPHY & DESIGN ASSETS'),
            _groupedCard(context, [
              _licenseTile(
                context,
                title: 'Playfair Display Font',
                subtitle: 'Claus Eggers Sørensen',
                license: 'SIL OFL 1.1',
              ),
              _divider(context),
              _licenseTile(
                context,
                title: 'Manrope Font',
                subtitle: 'Mikhail Sharanda',
                license: 'SIL OFL 1.1',
              ),
              _divider(context),
              _licenseTile(
                context,
                title: 'Open Sans Font',
                subtitle: 'Steve Matteson',
                license: 'Apache 2.0',
              ),
              _divider(context),
              _licenseTile(
                context,
                title: 'Material Icons',
                subtitle: 'Google LLC',
                license: 'Apache 2.0',
              ),
              _divider(context),
              _licenseTile(
                context,
                title: '3D App Logo Asset',
                subtitle: 'Damascus Vol. 1 Community 3D Pack (Figma Community)',
                license: 'CC BY 4.0',
              ),
            ]),
            const SizedBox(height: 28),

            // Full Package Manifest (Flutter built-in licenses)
            _sectionHeader(context, 'ALL THIRD-PARTY PACKAGES'),
            PressableScale(
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'AstraLM',
                applicationVersion: 'v1.0.0',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icons/appicon.png',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF262A36)
                        : const Color(0xFFE2E6EF),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.source_rounded,
                          color: scheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View Full Package Manifest',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Browse all 130+ Flutter & Dart open-source notices',
                            style: GoogleFonts.openSans(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _groupedCard(BuildContext context, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF242734) : const Color(0xFFE2E6EF),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? const Color(0xFF222632) : const Color(0xFFE6EAF2),
    );
  }

  Widget _licenseTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String license,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              license,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
