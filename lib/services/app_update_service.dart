import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/pressable_scale.dart';
import 'app_log_service.dart';
import 'hive_service.dart';

class AppUpdateService extends GetxService {
  static const String repoOwner = 'Prasun01';
  static const String repoName = 'AstraLM';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String keyAutoDownloadUpdates = 'auto_download_updates_ota';

  final isChecking = false.obs;
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;
  final downloadStatus = ''.obs;
  final downloadedBytes = 0.obs;
  final totalBytes = 0.obs;
  final latestVersion = ''.obs;
  final releaseNotes = ''.obs;
  final apkUrl = ''.obs;
  final hasUpdate = false.obs;

  // Background OTA telemetry
  final isOtaReady = false.obs;
  final otaDownloadedApkPath = ''.obs;
  final isOtaDownloading = false.obs;

  CancelToken? _cancelToken;

  @override
  void onInit() {
    super.onInit();
    // Silently check for updates & start background OTA download on launch
    Future.delayed(const Duration(seconds: 4), () {
      checkAndAutoDownloadOta();
    });
  }

  bool get isAutoDownloadEnabled {
    try {
      final hive = Get.find<HiveService>();
      return hive.getSetting<bool>(keyAutoDownloadUpdates, defaultValue: true) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setAutoDownloadEnabled(bool enabled) async {
    try {
      final hive = Get.find<HiveService>();
      await hive.setSetting(keyAutoDownloadUpdates, enabled);
    } catch (_) {}
  }

  /// Automatically check for and silently download the latest APK in the background
  Future<void> checkAndAutoDownloadOta() async {
    if (!isAutoDownloadEnabled) return;
    if (isChecking.value || isDownloading.value || isOtaDownloading.value) return;

    try {
      final hasNew = await checkForUpdates(isManual: false, isBackgroundAuto: true);
      if (hasNew && apkUrl.value.isNotEmpty && !isOtaReady.value) {
        await _silentBackgroundOtaDownload(apkUrl.value, latestVersion.value);
      }
    } catch (e) {
      Get.find<AppLogService>().error('[AppUpdateService] Auto OTA check failed: $e');
    }
  }

  /// Check GitHub for latest release
  Future<bool> checkForUpdates({
    bool isManual = false,
    bool isBackgroundAuto = false,
    BuildContext? context,
  }) async {
    if (isChecking.value) return false;
    isChecking.value = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ));

      final response = await dio.get(releasesApiUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final rawTag = (data['tag_name'] ?? '').toString().trim();
        final tag = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
        final body = (data['body'] ?? '').toString();
        final assets = data['assets'] as List<dynamic>? ?? [];

        // Find release APK in assets
        String? foundApkUrl;
        for (final a in assets) {
          final name = (a['name'] ?? '').toString().toLowerCase();
          final downloadUrl = (a['browser_download_url'] ?? '').toString();
          if (name.endsWith('.apk') && downloadUrl.isNotEmpty) {
            foundApkUrl = downloadUrl;
            if (name.contains('release')) break;
          }
        }

        latestVersion.value = tag;
        releaseNotes.value = body;
        apkUrl.value = foundApkUrl ?? '';

        final isNewer = _isVersionNewer(tag, currentVersion);
        hasUpdate.value = isNewer;

        if (isNewer && foundApkUrl != null && foundApkUrl.isNotEmpty) {
          if (!isBackgroundAuto) {
            if (context != null && context.mounted) {
              showUpdateDialog(context, currentVersion, tag, body, foundApkUrl);
            } else if (Get.context != null) {
              showUpdateDialog(Get.context!, currentVersion, tag, body, foundApkUrl);
            }
          }
          return true;
        } else if (isManual) {
          Get.snackbar(
            'AstraLM is Up to Date',
            'You are running the latest version (v$currentVersion).',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFF141620),
            colorText: Colors.white,
            icon: const PhosphorIcon(PhosphorIconsBold.checkCircle, color: Color(0xFF22C55E)),
          );
        }
      }
    } catch (e) {
      Get.find<AppLogService>().error('[AppUpdateService] Check failed: $e');
      if (isManual) {
        Get.snackbar(
          'Update Check Failed',
          'Could not connect to GitHub to check for updates.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFF141620),
          colorText: Colors.white,
          icon: const PhosphorIcon(PhosphorIconsBold.warningCircle, color: Color(0xFFEF4444)),
        );
      }
    } finally {
      isChecking.value = false;
    }
    return false;
  }

  /// Download APK silently in the background
  Future<void> _silentBackgroundOtaDownload(String url, String version) async {
    if (isOtaDownloading.value || isDownloading.value) return;
    isOtaDownloading.value = true;

    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/AstraLM-v$version.apk';
      final file = File(apkPath);

      if (await file.exists() && await file.length() > 10 * 1024 * 1024) {
        // Already downloaded in background!
        isOtaReady.value = true;
        otaDownloadedApkPath.value = apkPath;
        _notifyOtaReady(version, apkPath);
        return;
      }

      final dio = Dio();
      await dio.download(
        url,
        apkPath,
      );

      if (await File(apkPath).exists()) {
        isOtaReady.value = true;
        otaDownloadedApkPath.value = apkPath;
        _notifyOtaReady(version, apkPath);
      }
    } catch (e) {
      Get.find<AppLogService>().error('[AppUpdateService] Background OTA download failed: $e');
    } finally {
      isOtaDownloading.value = false;
    }
  }

  void _notifyOtaReady(String version, String apkPath) {
    Get.rawSnackbar(
      titleText: Text(
        'AstraLM v$version Ready to Install',
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      messageText: Text(
        'Update downloaded in background. Tap to apply.',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF94A3B8),
        ),
      ),
      icon: const Padding(
        padding: EdgeInsets.only(left: 12, right: 8),
        child: PhosphorIcon(PhosphorIconsBold.rocket, color: Color(0xFF3DDC84), size: 22),
      ),
      mainButton: TextButton(
        onPressed: () => installDownloadedOta(),
        child: Text(
          'Install Now',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3DDC84),
          ),
        ),
      ),
      duration: const Duration(seconds: 8),
      backgroundColor: const Color(0xFF141A24),
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      snackPosition: SnackPosition.TOP,
    );
  }

  Future<void> installDownloadedOta() async {
    final path = otaDownloadedApkPath.value;
    if (path.isNotEmpty && await File(path).exists()) {
      await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
    } else if (apkUrl.value.isNotEmpty) {
      await downloadAndInstallApk(apkUrl.value);
    }
  }

  /// Download and install the update APK with active progress UI
  Future<void> downloadAndInstallApk(String url) async {
    if (isDownloading.value) return;
    isDownloading.value = true;
    downloadProgress.value = 0.0;
    downloadedBytes.value = 0;
    totalBytes.value = 0;
    downloadStatus.value = 'Connecting…';

    _cancelToken = CancelToken();

    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/AstraLM-update.apk';
      final file = File(apkPath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        url,
        apkPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadedBytes.value = received;
            totalBytes.value = total;
            final progress = received / total;
            downloadProgress.value = progress;
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
            final pct = (progress * 100).toStringAsFixed(0);
            downloadStatus.value = '$pct% · $recMb MB / $totMb MB';
          } else {
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            downloadStatus.value = 'Downloading: $recMb MB';
          }
        },
      );

      downloadStatus.value = 'Download complete. Launching installer…';
      await Future.delayed(const Duration(milliseconds: 300));

      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        downloadStatus.value = 'Installation error: ${result.message}';
      }
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        downloadStatus.value = 'Download cancelled';
      } else {
        downloadStatus.value = 'Download failed: $e';
      }
    } finally {
      isDownloading.value = false;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('Cancelled by user');
    isDownloading.value = false;
    downloadProgress.value = 0.0;
  }

  /// SemVer comparator (returns true if remote > local)
  bool _isVersionNewer(String remote, String local) {
    try {
      final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (lParts.length < 3) {
        lParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > lParts[i]) return true;
        if (rParts[i] < lParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Show professional In-App Update Modal
  void showUpdateDialog(
    BuildContext context,
    String currentVersion,
    String newVersion,
    String notes,
    String downloadUrl,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1118) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const PhosphorIcon(
                          PhosphorIconsBold.rocket,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Available',
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0E1017),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  'v$currentVersion',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const PhosphorIcon(
                                  PhosphorIconsBold.arrowRight,
                                  size: 11,
                                  color: Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'v$newVersion',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF22C55E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (notes.trim().isNotEmpty) ...[
                    Text(
                      "What's New:",
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161822) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: MarkdownBody(
                            data: notes,
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.5,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                              h1: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.bold),
                              h2: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold),
                              listBullet: GoogleFonts.inter(fontSize: 12.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Obx(() {
                    final downloading = isDownloading.value;
                    final progress = downloadProgress.value;
                    final status = downloadStatus.value;
                    final ready = isOtaReady.value;

                    if (downloading) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : null,
                              backgroundColor: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                status,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                                ),
                              ),
                              GestureDetector(
                                onTap: cancelDownload,
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Later',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF6B7284),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: PressableScale(
                            onTap: () {
                              if (ready) {
                                installDownloadedOta();
                              } else {
                                downloadAndInstallApk(downloadUrl);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  ready ? 'Install Ready Update' : 'Update Now',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
