import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import '../services/download_service.dart';
import '../core/constants.dart';
import '../controllers/settings_controller.dart';

class HomeController extends GetxController {
  final currentTab = 0.obs;
  bool _resumeDialogShown = false;

  void changeTab(int index) {
    currentTab.value = index;
  }

  /// Checks and restores the last active model on startup.
  /// If cloud mode is selected, local models are kept unloaded.
  void checkResumeModel(BuildContext context) async {
    if (_resumeDialogShown) return;
    _resumeDialogShown = true;

    final settings = Get.find<SettingsController>();
    if (settings.inferenceMode.value == 'cloud') {
      // User is in online/cloud mode: ensure local model is unloaded and do not load local model.
      final inf = Get.find<InferenceService>();
      if (inf.isModelLoaded.value) {
        await inf.unloadModel();
      }
      return;
    }

    final hive = Get.find<HiveService>();
    final downloadService = Get.find<DownloadService>();

    // Check if the previous model load crashed the app on startup
    final pendingCrashModel =
        hive.getSetting<String>('startup_model_load_pending');
    if (pendingCrashModel != null && pendingCrashModel.isNotEmpty) {
      print('[Startup] Detected crash on last model load ($pendingCrashModel). Resetting local model.');
      await hive.setSetting(AppConstants.keyLocalModelPath, '');
      await hive.setSetting(AppConstants.keyLocalModelName, '');
      await hive.setSetting(AppConstants.keyLocalModelRuntime, '');
      await hive.setSetting('startup_model_load_pending', '');
      return;
    }

    // Check text model
    final textName = hive.getSetting<String>(AppConstants.keyLocalModelName);
    final textPath = hive.getSetting<String>(AppConstants.keyLocalModelPath);
    final textRuntime = hive.getSetting<String>(AppConstants.keyLocalModelRuntime);
    bool hasText = textName != null &&
        textName.isNotEmpty &&
        textPath != null &&
        textPath.isNotEmpty &&
        await downloadService.isModelDownloaded(textName);

    // Check image model
    final imageName = hive.getSetting<String>(AppConstants.keyImageModelName);
    final imagePath = hive.getSetting<String>(AppConstants.keyImageModelPath);
    bool hasImage = imageName != null &&
        imageName.isNotEmpty &&
        imagePath != null &&
        imagePath.isNotEmpty &&
        await downloadService.isModelDownloaded(imageName);

    // Load models safely in the background after UI renders
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 600));

      if (hasText) {
        final inf = Get.find<InferenceService>();
        if (!inf.isModelLoaded.value && !inf.isLoadingModel.value) {
          try {
            await hive.setSetting('startup_model_load_pending', textName);
            final result = await inf.loadModel(
              textPath,
              modelName: textName,
              modelRuntime: textRuntime,
            );
            if (result.startsWith('ERROR:')) {
              await hive.setSetting(AppConstants.keyLocalModelPath, '');
              await hive.setSetting(AppConstants.keyLocalModelName, '');
            }
          } catch (e) {
            print('[Startup] Text model auto-load failed: $e');
            await hive.setSetting(AppConstants.keyLocalModelPath, '');
            await hive.setSetting(AppConstants.keyLocalModelName, '');
          } finally {
            await hive.setSetting('startup_model_load_pending', '');
          }
        }
      }

      if (hasImage) {
        final localImage = Get.find<LocalImageService>();
        if (!localImage.isModelLoaded.value && !localImage.isLoadingModel.value) {
          try {
            await localImage.loadModel(
              imagePath,
              modelName: imageName,
            );
          } catch (e) {
            print('[Startup] Image model auto-load failed: $e');
          }
        }
      }
    });
  }
}
