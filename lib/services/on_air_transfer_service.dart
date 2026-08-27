import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/model_controller.dart';
import 'download_service.dart';
import 'app_log_service.dart';

/// Service providing a local Wi-Fi HTTP server for transferring models
/// directly from a PC/Mac browser or another phone into AstraLM over the air.
class OnAirTransferService extends GetxService {
  HttpServer? _server;
  final isRunning = false.obs;
  final serverUrl = ''.obs;
  final localIp = ''.obs;
  final port = 8080.obs;

  // Active incoming transfer telemetry
  final isReceivingFile = false.obs;
  final receivingFilename = ''.obs;
  final receivedBytes = 0.obs;
  final totalBytes = 0.obs;
  final transferSpeed = 0.0.obs;
  final transferStatus = ''.obs;

  @override
  void onClose() {
    stopServer();
    super.onClose();
  }

  Future<String?> getDeviceWifiIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        // Prefer wlan / en / Wi-Fi interfaces
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> startServer({int preferredPort = 8080}) async {
    if (kIsWeb) return false;
    await stopServer();

    try {
      final ip = await getDeviceWifiIp();
      if (ip == null) {
        transferStatus.value = 'Connect phone to Wi-Fi to start On-Air Transfer.';
        return false;
      }
      localIp.value = ip;

      var currentPort = preferredPort;
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          _server = await HttpServer.bind(
            InternetAddress.anyIPv4,
            currentPort,
            shared: true,
          );
          port.value = currentPort;
          break;
        } catch (e) {
          currentPort++;
        }
      }

      if (_server == null) {
        transferStatus.value = 'Failed to bind local port.';
        return false;
      }

      serverUrl.value = 'http://$ip:${port.value}';
      isRunning.value = true;
      transferStatus.value = 'Ready for transfers on $serverUrl';

      _server!.listen(_handleRequest, onError: (e) {
        Get.find<AppLogService>().error('On-Air Server error: $e');
      });

      return true;
    } catch (e) {
      Get.find<AppLogService>().error('Failed to start On-Air Server: $e');
      transferStatus.value = 'Error starting server: $e';
      return false;
    }
  }

  Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    isRunning.value = false;
    serverUrl.value = '';
    isReceivingFile.value = false;
    receivingFilename.value = '';
    receivedBytes.value = 0;
    totalBytes.value = 0;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/' || path == '/index.html') {
      await _serveWebUi(request);
      return;
    }

    if (path == '/status') {
      await _serveStatusJson(request);
      return;
    }

    if (path == '/push-url' && request.method == 'POST') {
      await _handlePushUrl(request);
      return;
    }

    if (path == '/upload' && request.method == 'POST') {
      await _handleFileUpload(request);
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    await request.response.close();
  }

  Future<void> _serveWebUi(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    final html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AstraLM — On-Air Model Transfer</title>
  <style>
    :root {
      --bg: #0B0E14;
      --card: #141A24;
      --border: rgba(255, 255, 255, 0.1);
      --green: #3DDC84;
      --blue: #3B82F6;
      --text: #F8FAFC;
      --muted: #94A3B8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      padding: 24px 16px;
      display: flex;
      justify-content: center;
      min-height: 100vh;
    }
    .container { width: 100%; max-width: 640px; }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 24px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--border);
    }
    .brand { font-size: 20px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
    .badge {
      font-size: 11px;
      font-weight: 600;
      background: rgba(61, 220, 132, 0.15);
      color: var(--green);
      padding: 4px 8px;
      border-radius: 20px;
      border: 1px solid rgba(61, 220, 132, 0.3);
    }
    .card {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 20px;
    }
    h2 { font-size: 16px; font-weight: 600; margin-bottom: 8px; }
    p { font-size: 13px; color: var(--muted); line-height: 1.5; margin-bottom: 16px; }
    .dropzone {
      border: 2px dashed rgba(61, 220, 132, 0.4);
      border-radius: 12px;
      padding: 36px 16px;
      text-align: center;
      cursor: pointer;
      background: rgba(61, 220, 132, 0.03);
      transition: all 0.2s ease;
    }
    .dropzone:hover, .dropzone.dragover {
      border-color: var(--green);
      background: rgba(61, 220, 132, 0.08);
    }
    .btn {
      background: var(--green);
      color: #000;
      font-weight: 600;
      border: none;
      padding: 10px 20px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 13px;
    }
    .progress-box { margin-top: 16px; display: none; }
    .progress-bar-bg {
      background: rgba(255, 255, 255, 0.1);
      height: 8px;
      border-radius: 4px;
      overflow: hidden;
      margin-bottom: 8px;
    }
    .progress-bar-fill {
      background: var(--green);
      height: 100%;
      width: 0%;
      transition: width 0.1s linear;
    }
    .input-row { display: flex; gap: 8px; }
    input[type="text"] {
      flex: 1;
      background: #080B10;
      border: 1px solid var(--border);
      color: #fff;
      padding: 10px 14px;
      border-radius: 8px;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="brand">
        <span>AstraLM</span>
        <span class="badge">On-Air Transfer</span>
      </div>
      <div style="font-size: 12px; color: var(--muted);" id="device-info">Connected</div>
    </div>

    <!-- Upload Card -->
    <div class="card">
      <h2>Send Model File from Computer</h2>
      <p>Transfer any <code>.gguf</code>, <code>.litertlm</code>, or <code>.safetensors</code> model directly to your phone over local Wi-Fi at maximum speed.</p>
      
      <div class="dropzone" id="dropzone" onclick="document.getElementById('fileInput').click()">
        <svg style="width: 36px; height: 36px; fill: var(--green); margin-bottom: 8px;" viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
        <div style="font-weight: 600; font-size: 14px; margin-bottom: 4px;">Click to select or drop model file here</div>
        <div style="font-size: 12px; color: var(--muted);">Supports files up to 20GB+ directly into phone storage</div>
      </div>
      <input type="file" id="fileInput" style="display: none" accept=".gguf,.litertlm,.safetensors">

      <div class="progress-box" id="progressBox">
        <div class="progress-bar-bg">
          <div class="progress-bar-fill" id="progressFill"></div>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: var(--muted);">
          <span id="transferStats">Uploading...</span>
          <span id="transferPercent">0%</span>
        </div>
      </div>
    </div>

    <!-- Push Remote URL Card -->
    <div class="card">
      <h2>Push Download URL to Phone</h2>
      <p>Paste a HuggingFace or direct model link below to trigger the download directly on your phone.</p>
      <div class="input-row">
        <input type="text" id="urlInput" placeholder="https://huggingface.co/.../model.gguf">
        <button class="btn" onclick="pushUrl()">Send to Phone</button>
      </div>
      <div id="pushStatus" style="font-size: 12px; margin-top: 8px; color: var(--green); display: none;"></div>
    </div>
  </div>

  <script>
    const dropzone = document.getElementById('dropzone');
    const fileInput = document.getElementById('fileInput');
    const progressBox = document.getElementById('progressBox');
    const progressFill = document.getElementById('progressFill');
    const transferStats = document.getElementById('transferStats');
    const transferPercent = document.getElementById('transferPercent');

    ['dragenter', 'dragover'].forEach(name => {
      dropzone.addEventListener(name, (e) => { e.preventDefault(); dropzone.classList.add('dragover'); });
    });
    ['dragleave', 'drop'].forEach(name => {
      dropzone.addEventListener(name, (e) => { e.preventDefault(); dropzone.classList.remove('dragover'); });
    });
    dropzone.addEventListener('drop', (e) => {
      if (e.dataTransfer.files.length) uploadFile(e.dataTransfer.files[0]);
    });
    fileInput.addEventListener('change', (e) => {
      if (fileInput.files.length) uploadFile(fileInput.files[0]);
    });

    function formatBytes(bytes) {
      if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
      if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
      return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
    }

    function uploadFile(file) {
      progressBox.style.display = 'block';
      const xhr = new XMLHttpRequest();
      let startTime = Date.now();

      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          const percent = (e.loaded / e.total) * 100;
          progressFill.style.width = percent + '%';
          transferPercent.textContent = percent.toFixed(1) + '%';
          const elapsed = (Date.now() - startTime) / 1000;
          const speed = elapsed > 0 ? (e.loaded / elapsed) : 0;
          transferStats.textContent = formatBytes(e.loaded) + ' / ' + formatBytes(e.total) + ' (' + formatBytes(speed) + '/s)';
        }
      });

      xhr.onload = () => {
        if (xhr.status === 200) {
          transferStats.textContent = 'Transfer Complete! Model ready on AstraLM.';
          progressFill.style.background = '#3DDC84';
        } else {
          transferStats.textContent = 'Transfer failed: ' + xhr.responseText;
          progressFill.style.background = '#EF4444';
        }
      };

      xhr.open('POST', '/upload?filename=' + encodeURIComponent(file.name));
      xhr.setRequestHeader('Content-Type', 'application/octet-stream');
      xhr.send(file);
    }

    function pushUrl() {
      const url = document.getElementById('urlInput').value.trim();
      if (!url) return;
      fetch('/push-url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: url })
      }).then(r => r.json()).then(data => {
        const s = document.getElementById('pushStatus');
        s.style.display = 'block';
        s.textContent = data.message || 'Download started on phone!';
      }).catch(err => {
        alert('Error: ' + err);
      });
    }
  </script>
</body>
</html>''';

    request.response.write(html);
    await request.response.close();
  }

  Future<void> _serveStatusJson(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    final models = await Get.find<DownloadService>().getDownloadedModels();
    request.response.write(jsonEncode({
      'status': 'online',
      'device': 'Android',
      'models': models,
    }));
    await request.response.close();
  }

  Future<void> _handlePushUrl(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final url = data['url'] as String? ?? '';
      if (url.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': 'URL is required'}));
        await request.response.close();
        return;
      }

      final modelCtrl = Get.find<ModelController>();
      final filename = modelCtrl.filenameFromUrl(url);
      unawaited(modelCtrl.downloadModelFromUrlDirect(url, filename));

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'started',
        'filename': filename,
        'message': 'Download started on device for $filename'
      }));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': '$e'}));
      await request.response.close();
    }
  }

  Future<void> _handleFileUpload(HttpRequest request) async {
    final queryName = request.uri.queryParameters['filename'] ?? 'uploaded_model.gguf';
    final downloadService = Get.find<DownloadService>();
    final modelsDir = await downloadService.modelsDir;
    final targetPath = '$modelsDir/$queryName';
    final tempPath = '$targetPath.part';

    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    isReceivingFile.value = true;
    receivingFilename.value = queryName;
    receivedBytes.value = 0;
    totalBytes.value = request.contentLength;
    transferStatus.value = 'Receiving $queryName over Wi-Fi...';

    final startTime = DateTime.now();
    IOSink? sink;
    try {
      sink = tempFile.openWrite();
      await for (final chunk in request) {
        sink.add(chunk);
        receivedBytes.value += chunk.length;
        final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        if (elapsed > 0) {
          transferSpeed.value = receivedBytes.value / elapsed;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      final finalFile = File(targetPath);
      if (await finalFile.exists()) {
        try {
          await finalFile.delete();
        } catch (_) {}
      }
      await tempFile.rename(targetPath);

      isReceivingFile.value = false;
      transferStatus.value = 'Model $queryName transferred successfully!';

      // Refresh downloaded models in AstraLM
      try {
        await Get.find<ModelController>().refreshDownloaded();
        Get.snackbar(
          'On-Air Transfer Complete',
          '$queryName is ready to use.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      } catch (_) {}

      request.response.statusCode = HttpStatus.ok;
      request.response.write('OK');
      await request.response.close();
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      isReceivingFile.value = false;
      transferStatus.value = 'Transfer failed: $e';
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Upload failed: $e');
      await request.response.close();
    }
  }
}
