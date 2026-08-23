import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../controllers/server_controller.dart';

class ServerView extends GetView<ServerController> {
  const ServerView({super.key});

  Color _successColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFF9CD0A8)
          : const Color(0xFF4E7A5A);

  Color _warningColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFFD9CC66)
          : const Color(0xFFBDAC37);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Server',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ),
      body: Obx(() {
        final isRunning = controller.isRunning.value;
        final hasKey = controller.apiKey.value.trim().isNotEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
          children: [
            // Status
            _groupedCard(context, children: [
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    _statusPill(context,
                        label: isRunning ? 'RUNNING' : 'STOPPED',
                        color: isRunning
                            ? _successColor(theme)
                            : scheme.onSurfaceVariant),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              isRunning
                                  ? 'API Server Running'
                                  : 'API Server Stopped',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                              isRunning
                                  ? controller.serverStatus.value
                                  : 'Expose your local model as an OpenAI API.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant)),
                        ])),
                    Switch(
                        value: isRunning,
                        onChanged: controller.isStarting.value
                            ? null
                            : (v) => controller.toggleServer(v)),
                  ])),
            ]),
            const SizedBox(height: 24),

            // Model
            _groupedCard(context, children: [
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: (controller.hasLocalModel
                                    ? _successColor(theme)
                                    : _warningColor(theme))
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(
                            controller.hasLocalModel
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 16,
                            color: controller.hasLocalModel
                                ? _successColor(theme)
                                : _warningColor(theme))),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(controller.modelName,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                              controller.hasLocalModel
                                  ? 'Local model ready'
                                  : 'Requires a loaded GGUF or LiteRT-LM model',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant)),
                        ])),
                  ])),
            ]),
            const SizedBox(height: 32),

            // Security
            _sectionLabel(context, 'SECURITY'),
            _groupedCard(context, children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _switchTile(context,
                      title: 'Require API key',
                      subtitle: 'Authorization: Bearer <key>',
                      value: controller.useApiKey.value, onChanged: (v) {
                    controller.useApiKey.value = v;
                    controller.saveSettings();
                  }),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                      controller: controller.apiKeyCtrl,
                      onChanged: (v) => controller.apiKey.value = v,
                      onSubmitted: (_) => controller.saveSettings(),
                      decoration: const InputDecoration(
                          labelText: 'API key', hintText: 'Optional'),
                    )),
                    const SizedBox(width: 6),
                    IconButton(
                        tooltip: 'Generate',
                        onPressed: controller.generateApiKey,
                        icon: Icon(Icons.auto_awesome_rounded,
                            size: 20, color: scheme.primary)),
                    IconButton(
                        tooltip: 'Copy',
                        onPressed: hasKey
                            ? () => controller.copyText(
                                controller.apiKey.value, 'API key')
                            : null,
                        icon: Icon(Icons.copy_outlined,
                            size: 18, color: scheme.onSurfaceVariant)),
                  ]),
                ]),
              ),
            ]),

            if (isRunning) ...[
              const SizedBox(height: 32),
              _sectionLabel(context, 'ENDPOINTS'),
              _groupedCard(context, children: [
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _urlRow(context, 'Local',
                              controller.localUrl.value),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.primary,
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: controller.localUrl.value == null
                                  ? null
                                  : () =>
                                      _testHealth(controller.localUrl.value!),
                              icon: const Icon(Icons.wifi, size: 16),
                              label: const Text('Test local')),
                        ])),
              ]),
              const SizedBox(height: 32),
              _sectionLabel(context, 'USAGE EXAMPLES'),
              _groupedCard(context, children: [
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _codeBlock(context, 'List models',
                              'curl ${controller.baseUrl}/v1/models${_authHeader()}'),
                          _codeBlock(context, 'Chat completion',
                              'curl ${controller.baseUrl}/v1/chat/completions \\\n  -H "Content-Type: application/json"${_authHeader()} \\\n  -d \'{"model":"${controller.inference.loadedModelName.value}","messages":[{"role":"user","content":"Hello"}]}\''),
                          _codeBlock(context, 'Python SDK',
                              'from openai import OpenAI\n\nclient = OpenAI(\n    base_url="${controller.baseUrl}/v1",\n    api_key="${controller.useApiKey.value ? controller.apiKey.value : "not-needed"}"\n)\n\nresponse = client.chat.completions.create(\n    model="${controller.inference.loadedModelName.value}",\n    messages=[{"role": "user", "content": "Hello"}],\n)\nprint(response.choices[0].message.content)'),
                        ])),
              ]),
            ],

            if (controller.lastError.value != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: scheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(controller.lastError.value!,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: scheme.error))),
                    ]),
              ),
            ],
          ],
        );
      }),
    );
  }

  // ── Helpers ──

  Widget _statusPill(BuildContext context,
      {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: color)),
      ]),
    );
  }

  Widget _groupedCard(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  Widget _switchTile(BuildContext context,
      {required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(fontSize: 15, color: scheme.onSurface)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 13, color: scheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ])),
      Switch(value: value, onChanged: onChanged),
    ]);
  }

  Widget _urlRow(BuildContext context, String label, String? url) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
              width: 54,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface))),
          Expanded(
              child: SelectableText(url ?? 'Not available',
                  maxLines: 1,
                  style: GoogleFonts.firaCode(
                      fontSize: 12, color: scheme.onSurfaceVariant))),
          IconButton(
              tooltip: 'Copy',
              onPressed: url == null
                  ? null
                  : () => controller.copyText(url, '$label URL'),
              icon: Icon(Icons.copy_outlined,
                  size: 16, color: scheme.onSurfaceVariant)),
        ]));
  }

  Widget _codeBlock(BuildContext context, String title, String code) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onInverseSurface))),
          IconButton(
              tooltip: 'Copy',
              onPressed: () => controller.copyText(code, title),
              icon: Icon(Icons.copy_outlined,
                  size: 16, color: scheme.onInverseSurface.withValues(alpha: 0.7))),
        ]),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(code,
                style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: scheme.onInverseSurface.withValues(alpha: 0.85)))),
      ]),
    );
  }

  String _authHeader() {
    if (controller.useApiKey.value && controller.apiKey.value.isNotEmpty) {
      return ' \\\n  -H "Authorization: Bearer ${controller.apiKey.value}"';
    }
    return '';
  }

  Future<void> _testHealth(String baseUrl) async {
    try {
      final r = await http
          .get(Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/health'))
          .timeout(const Duration(seconds: 8));
      Get.snackbar('Health check', 'Status ${r.statusCode}');
    } catch (e) {
      Get.snackbar('Health failed', '$e');
    }
  }
}
