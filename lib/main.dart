import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'firebase_options.dart';
import 'controllers/settings_controller.dart';
import 'controllers/cloud_model_controller.dart';
import 'controllers/server_controller.dart';
import 'controllers/model_controller.dart';
import 'core/theme.dart';
//////
import 'core/routes.dart';
import 'services/hive_service.dart';
import 'services/inference_service.dart';
import 'services/cloud_service.dart';
import 'services/download_service.dart';
import 'services/device_info_service.dart';
import 'services/local_image_service.dart';
import 'services/app_log_service.dart';
import 'services/document_export_service.dart';
import 'services/crash_reporting_service.dart';
import 'services/image_generation_notification_service.dart';
import 'core/constants.dart';

void main() {
  final appLogBuffer = <String>[];

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Register logger first so everything routes to it
    final appLog = AppLogService();
    Get.put(appLog);

    // Flush buffered prints
    for (final line in appLogBuffer) {
      appLog.info(line);
    }
    appLogBuffer.clear();

    appLog.info('App started');

    // Initialize Firebase before any Firebase-dependent services
    try {
      // await Firebase.initializeApp(
      //   options: DefaultFirebaseOptions.currentPlatform,
      // );
    } catch (e) {
      appLog.error('[Firebase] Initialization failed', details: e);
    }

    // Support phones and tablets in portrait or landscape.
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // Initialize Hive
    await Hive.initFlutter();

    // Register global services
    await Get.putAsync(() => HiveService().init());
    await Get.putAsync(() => DeviceInfoService().init());

    // Settings controller must be initialized before runApp for theme support
    final settingsController = Get.put(SettingsController());
    Get.put(CloudModelController());

    Get.put(InferenceService());
    Get.put(CloudService());
    Get.put(DownloadService());
    Get.put(LocalImageService());
    Get.put(DocumentExportService());
    final crashReporting =
        await Get.putAsync(() => CrashReportingService().init());
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      appLog.error(
        details.exceptionAsString(),
        details: details.stack?.toString() ?? 'No stack',
      );
      crashReporting.recordFlutterFatal(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      appLog.error(
        error.toString(),
        details: stack.toString(),
      );
      crashReporting.recordFatal(error, stack, reason: 'platform_dispatcher');
      return true;
    };
    final imageNotifications = Get.put(ImageGenerationNotificationService());
    await imageNotifications.init();
    await imageNotifications.configureBackgroundService();
    Get.put(ServerController(), permanent: true);
    Get.put(ModelController());

    // Auto-configure inference settings based on device RAM
    _autoConfigureForDevice();

    // Automatically validate and load the last used model on startup
    _validateAndAutoLoadLastModel();

    runApp(const AstraLMApp());

    // Pre-warm resources, fonts, assets, and animation curves on startup to ensure instant 60/120fps response
    WidgetsBinding.instance.addPostFrameCallback((_) {
      settingsController.setThemeMode(settingsController.themeMode.value);
      if (Get.context != null) {
        _preWarmAllAppAnimationsAndResources(Get.context!);
      }
    });
  }, (error, stack) async {
    if (Get.isRegistered<AppLogService>()) {
      Get.find<AppLogService>().error(
        'Uncaught zone error: $error',
        details: stack.toString(),
      );
    }
    if (Get.isRegistered<CrashReportingService>()) {
      await Get.find<CrashReportingService>()
          .recordFatal(error, stack, reason: 'run_zoned_guarded');
    }
  }, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      if (Get.isRegistered<AppLogService>()) {
        Get.find<AppLogService>().info(line);
      } else {
        appLogBuffer.add(line);
      }
      parent.print(zone, line);
    },
  ));
}

/// Pre-warms animation engines, Bezier curve transforms, fonts, button physics, and screen transition animations at startup
void _preWarmAllAppAnimationsAndResources(BuildContext context) {
  try {
    precacheImage(const AssetImage('assets/icons/appicon.png'), context);
    // Pre-load common GoogleFonts styles
    GoogleFonts.manrope(fontSize: 14);
    GoogleFonts.openSans(fontSize: 14);
    GoogleFonts.firaCode(fontSize: 12);

    // Pre-evaluate animation curves for button clicking & transitions
    const testCurves = [
      Curves.easeOutCubic,
      Curves.easeInCubic,
      Curves.easeInOutCubic,
      Curves.fastOutSlowIn,
      Curves.easeOutQuad,
      Curves.easeInQuad,
      Curves.linear,
    ];
    for (final c in testCurves) {
      c.transform(0.0);
      c.transform(0.25);
      c.transform(0.5);
      c.transform(0.75);
      c.transform(1.0);
    }

    // Pre-warm Tween transforms for button clicks and page transitions
    final scaleTween = Tween<double>(begin: 1.0, end: 0.96);
    scaleTween.transform(0.5);
    final opacityTween = Tween<double>(begin: 1.0, end: 0.85);
    opacityTween.transform(0.5);
    final slideTween =
        Tween<Offset>(begin: const Offset(0.04, 0.0), end: Offset.zero);
    slideTween.transform(0.5);
    final topSlideTween =
        Tween<Offset>(begin: const Offset(0.0, -0.05), end: Offset.zero);
    topSlideTween.transform(0.5);
  } catch (_) {}
}

/// Validates and automatically loads the last used model on startup.
void _validateAndAutoLoadLastModel() async {
  final hive = Get.find<HiveService>();
  final downloadService = Get.find<DownloadService>();

  // Validate last text/LLM model
  final textModelName = hive.getSetting<String>(AppConstants.keyLocalModelName);
  final textModelPath = hive.getSetting<String>(AppConstants.keyLocalModelPath);
  if (textModelName != null &&
      textModelName.isNotEmpty &&
      textModelPath != null &&
      textModelPath.isNotEmpty) {
    if (!await downloadService.isModelDownloaded(textModelName)) {
      await hive.setSetting(AppConstants.keyLocalModelPath, '');
      await hive.setSetting(AppConstants.keyLocalModelName, '');
    }
  }

  // Validate last image model
  final imageModelName =
      hive.getSetting<String>(AppConstants.keyImageModelName);
  final imageModelPath =
      hive.getSetting<String>(AppConstants.keyImageModelPath);
  if (imageModelName != null &&
      imageModelName.isNotEmpty &&
      imageModelPath != null &&
      imageModelPath.isNotEmpty) {
    if (!await downloadService.isModelDownloaded(imageModelName)) {
      await hive.setSetting(AppConstants.keyImageModelPath, '');
      await hive.setSetting(AppConstants.keyImageModelName, '');
    }
  }
}

/// Auto-set optimized inference params based on device RAM (only on first launch).
void _autoConfigureForDevice() {
  final hive = Get.find<HiveService>();
  final device = Get.find<DeviceInfoService>();

  // Only auto-configure if user hasn't already set values (first launch)
  final hasConfigured =
      hive.getSetting<bool>('device_auto_configured') ?? false;
  if (hasConfigured) return;

  hive.setSetting(AppConstants.keyContextSize, device.recommendedContextSize);
  hive.setSetting(AppConstants.keyMaxTokens, device.recommendedMaxTokens);
  hive.setSetting(AppConstants.keyTemperature, 0.3);
  hive.setSetting('device_auto_configured', true);

  Get.find<AppLogService>().info(
      '[AutoConfig] Set context=${device.recommendedContextSize}, '
      'maxTokens=${device.recommendedMaxTokens} for ${device.totalRamGB.value.toStringAsFixed(1)}GB RAM');
}

class AstraLMApp extends StatelessWidget {
  const AstraLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(() {
      final themeMode = settings.themeMode.value;
      final scale = settings.fontScale.value; // read here → Obx tracks it
      return GetMaterialApp(
        title: 'AstraLM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        defaultTransition: Transition.rightToLeftWithFade,
        transitionDuration: const Duration(milliseconds: 260),
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      );
    });
  }
}
