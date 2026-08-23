import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import '../services/download_service.dart';
import '../core/constants.dart';

class HomeController extends GetxController {
  final currentTab = 0.obs;
  bool _resumeDialogShown = false;

  void changeTab(int index) {
    currentTab.value = index;
  }

  /// Shows a one-time bottom sheet on startup asking if the user wants to reload
  /// the last used model (text or image). Does not auto-load anything.
  void checkResumeModel(BuildContext context) async {
    if (_resumeDialogShown) return;
    _resumeDialogShown = true;

    final hive = Get.find<HiveService>();
    final downloadService = Get.find<DownloadService>();

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

    if (hasText) {
      final inf = Get.find<InferenceService>();
      if (!inf.isModelLoaded.value && !inf.isLoadingModel.value) {
        inf.loadModel(
          textPath,
          modelName: textName,
          modelRuntime: textRuntime,
        );
      }
    }
    if (hasImage) {
      final localImage = Get.find<LocalImageService>();
      if (!localImage.isModelLoaded.value && !localImage.isLoadingModel.value) {
        localImage.loadModel(
          imagePath,
          modelName: imageName,
        );
      }
    }
    return;
  }
}
