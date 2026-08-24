import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/chat_controller.dart';
import 'code_block_widget.dart';
import 'pressable_scale.dart';

String _extractRenderableHtml(String content) {
  var text = content.trim();
  final codeFenceRegex = RegExp(
      r'^```(?:html|xml|svg|htm)?\s*\n([\s\S]*?)\n?```$',
      caseSensitive: false);
  final match = codeFenceRegex.firstMatch(text);
  if (match != null) {
    text = match.group(1)!.trim();
  } else if (text.startsWith('```')) {
    final lines = text.split('\n');
    if (lines.first.startsWith('```')) {
      lines.removeAt(0);
      if (lines.isNotEmpty && lines.last.trim() == '```') {
        lines.removeLast();
      }
      text = lines.join('\n').trim();
    }
  }
  return text;
}

bool _isHtmlContent(String content) {
  final clean = _extractRenderableHtml(content);
  final lower = clean.toLowerCase();
  return lower.startsWith('<!doctype') ||
      lower.startsWith('<html') ||
      lower.contains('<html') ||
      lower.contains('<head') ||
      lower.contains('<body>') ||
      lower.contains('<body ') ||
      lower.contains('<script') ||
      lower.contains('<style') ||
      lower.contains('<div') ||
      lower.contains('<svg') ||
      lower.contains('<canvas') ||
      lower.contains('<button') ||
      lower.contains('<p>') ||
      lower.contains('<h1') ||
      lower.contains('<h2') ||
      lower.contains('<h3') ||
      lower.contains('<span') ||
      lower.contains('<table') ||
      lower.contains('<form') ||
      lower.contains('<iframe') ||
      lower.contains('<a href');
}

String _generateFullHtmlDocument(String content, bool isDark) {
  final clean = _extractRenderableHtml(content);
  if (clean.isEmpty) return '';

  final lower = clean.toLowerCase();
  final isCompleteHtml = lower.contains('<html') || lower.contains('<!doctype');
  if (isCompleteHtml) return clean;

  final bg = isDark ? '#0A0C11' : '#FFFFFF';
  final fg = isDark ? '#E2E6F2' : '#0F172A';

  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      line-height: 1.6;
      background-color: $bg;
      color: $fg;
      word-wrap: break-word;
    }
  </style>
</head>
<body>
  $clean
</body>
</html>''';
}

class CanvasWorkspace extends StatefulWidget {
  const CanvasWorkspace({super.key});

  @override
  State<CanvasWorkspace> createState() => _CanvasWorkspaceState();
}

class _CanvasWorkspaceState extends State<CanvasWorkspace>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  InAppWebViewController? _webController;
  String _lastLoadedHtml = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncHtmlIfChanged(String content, bool isDark) {
    if (_webController != null) {
      final fullHtml = _generateFullHtmlDocument(content, isDark);
      if (fullHtml.isNotEmpty && fullHtml != _lastLoadedHtml) {
        _lastLoadedHtml = fullHtml;
        _webController!.loadData(
          data: fullHtml,
          baseUrl: WebUri('about:blank'),
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      if (!controller.isCanvasOpen.value) return const SizedBox.shrink();

      final title = controller.canvasTitle.value.isEmpty
          ? 'Canvas Document'
          : controller.canvasTitle.value;
      final content = controller.canvasContent.value;
      final isEditing = controller.isCanvasEditing.value;
      final isHtml = _isHtmlContent(content);
      final wordCount = content.trim().isEmpty
          ? 0
          : content.trim().split(RegExp(r'\s+')).length;

      if (!isEditing && isHtml) {
        _syncHtmlIfChanged(content, isDark);
      }

      return Container(
        color: isDark ? const Color(0xFF0A0C11) : const Color(0xFFFAFBFD),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(
                context, controller, title, content, wordCount,
                isEditing, isHtml, isDark, scheme,
              ),

              // ── Sub Tab Bar (for switching between Code and Preview when not in full edit) ──
              if (!isEditing)
                _buildSubTabBar(isDark, scheme, isHtml),

              // ── Main Content Body ──
              Expanded(
                child: isEditing
                    ? _buildEditor(controller, isDark)
                    : TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildCodeView(context, content, isDark),
                          _buildPreviewView(context, content, isHtml, isDark),
                        ],
                      ),
              ),

              // ── Bottom Action Toolbar ──
              _buildBottomToolbar(controller, isDark, scheme),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    ChatController controller,
    String title,
    String content,
    int wordCount,
    bool isEditing,
    bool isHtml,
    bool isDark,
    ColorScheme scheme,
  ) {
    final headerBg = isDark ? const Color(0xFF0F1117) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E222E) : const Color(0xFFECEFF6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsBold.notepad,
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0E1017),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isHtml
                                ? const Color(0xFFEA580C)
                                : (isDark ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB)))
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isHtml ? 'HTML' : 'Canvas',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isHtml
                              ? const Color(0xFFEA580C)
                              : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  isEditing
                      ? 'Editing · $wordCount words'
                      : (isHtml ? 'Live Web Preview · $wordCount words' : '$wordCount words'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF6B7284) : const Color(0xFF8E95A8),
                  ),
                ),
              ],
            ),
          ),
          // Header Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.canvasHistory.length > 1) ...[
                _headerIconBtn(
                  PhosphorIconsBold.arrowCounterClockwise,
                  'Undo',
                  isDark,
                  controller.undoCanvas,
                ),
                const SizedBox(width: 4),
              ],
              _headerIconBtn(
                isEditing ? PhosphorIconsBold.eye : PhosphorIconsBold.pencil,
                isEditing ? 'Preview' : 'Edit',
                isDark,
                () {
                  controller.isCanvasEditing.value = !isEditing;
                  if (!controller.isCanvasEditing.value) {
                    controller.updateCanvasContent(
                        controller.canvasTextController.text);
                  }
                },
              ),
              const SizedBox(width: 4),
              _headerIconBtn(
                PhosphorIconsBold.copy,
                'Copy',
                isDark,
                () {
                  Clipboard.setData(ClipboardData(text: content));
                  Get.snackbar(
                    'Copied',
                    'Canvas content copied to clipboard.',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                    margin: const EdgeInsets.all(12),
                  );
                },
              ),
              const SizedBox(width: 4),
              _headerIconBtn(
                PhosphorIconsBold.shareNetwork,
                'Share',
                isDark,
                () => Share.share(content, subject: title),
              ),
              const SizedBox(width: 4),
              _headerIconBtn(
                PhosphorIconsBold.x,
                'Close',
                isDark,
                controller.closeCanvas,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar(bool isDark, ColorScheme scheme, bool isHtml) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E222E) : const Color(0xFFECEFF6),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: scheme.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: isDark ? Colors.white : const Color(0xFF0E1017),
        unselectedLabelColor:
            isDark ? const Color(0xFF6B7284) : const Color(0xFF8E95A8),
        labelStyle: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(PhosphorIconsBold.code, size: 15),
                SizedBox(width: 6),
                Text('Source Code'),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIconsBold.browsers,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text('Preview'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ChatController controller, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0A0C11) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller.canvasTextController,
        onChanged: (v) => controller.canvasContent.value = v,
        maxLines: null,
        expands: true,
        style: GoogleFonts.firaCode(
          fontSize: 13.5,
          height: 1.55,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Type or edit content in canvas…',
          hintStyle: GoogleFonts.inter(
            color: isDark ? const Color(0xFF44495A) : const Color(0xFFB0B8C8),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeView(BuildContext context, String content, bool isDark) {
    if (content.trim().isEmpty) return _empty(isDark);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      child: SelectableText(
        content,
        style: GoogleFonts.firaCode(
          fontSize: 13.5,
          color: textColor,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildPreviewView(
      BuildContext context, String content, bool isHtml, bool isDark) {
    if (content.trim().isEmpty) return _empty(isDark);

    if (isHtml) {
      final fullHtml = _generateFullHtmlDocument(content, isDark);

      return InAppWebView(
        key: ValueKey(fullHtml.hashCode),
        initialData: InAppWebViewInitialData(
          data: fullHtml,
          baseUrl: WebUri('about:blank'),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          javaScriptCanOpenWindowsAutomatically: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          allowContentAccess: true,
          allowFileAccess: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          hardwareAcceleration: true,
          useHybridComposition: true,
          transparentBackground: false,
          verticalScrollBarEnabled: true,
          horizontalScrollBarEnabled: true,
        ),
        onWebViewCreated: (c) {
          _webController = c;
          _lastLoadedHtml = fullHtml;
        },
        onLoadStop: (c, url) {
          if (isDark) {
            c.evaluateJavascript(source: '''
              if (!document.getElementById('_dark_style')) {
                var s = document.createElement('style');
                s.id = '_dark_style';
                s.textContent = 'html,body{background:#0A0C11!important;color:#E2E6F2!important}';
                document.head.appendChild(s);
              }
            ''');
          }
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      physics: const BouncingScrollPhysics(),
      child: MarkdownBody(
        data: content,
        selectable: true,
        builders: {'code': CodeBlockBuilder(isDark: isDark)},
        styleSheet: _canvasMarkdownStyle(context, isDark),
      ),
    );
  }

  Widget _empty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIconsBold.notepad,
            size: 40,
            color: isDark ? const Color(0xFF2E3347) : const Color(0xFFC8D0E2),
          ),
          const SizedBox(height: 12),
          Text(
            'Canvas is waiting for response…',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF4A5066) : const Color(0xFF9AA0B2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(
      ChatController controller, bool isDark, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E222E) : const Color(0xFFECEFF6),
            width: 1,
          ),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.04, 0.96, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _chip(
                PhosphorIconsBold.chatCircle,
                'Add Comments',
                isDark,
                scheme,
                () => controller.requestCanvasRevision(
                    'Add thorough explanatory comments throughout this code/document.'),
              ),
              const SizedBox(width: 8),
              _chip(
                PhosphorIconsBold.scissors,
                'Make Concise',
                isDark,
                scheme,
                () => controller.requestCanvasRevision(
                    'Make this concise and direct, keeping all essential details.'),
              ),
              const SizedBox(width: 8),
              _chip(
                PhosphorIconsBold.sparkle,
                'Fix & Polish',
                isDark,
                scheme,
                () => controller.requestCanvasRevision(
                    'Review, fix any errors, and polish the structure and clarity.'),
              ),
              const SizedBox(width: 8),
              _chip(
                PhosphorIconsBold.textT,
                'Explain',
                isDark,
                scheme,
                () => controller.requestCanvasRevision(
                    'Expand with deeper explanations and step-by-step breakdown.'),
              ),
              const SizedBox(width: 8),
              _chip(
                PhosphorIconsBold.translate,
                'Translate',
                isDark,
                scheme,
                () => controller.requestCanvasRevision(
                    'Translate this document accurately to Spanish.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    PhosphorIconData icon,
    String label,
    bool isDark,
    ColorScheme scheme,
    VoidCallback onTap,
  ) {
    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1D28)
              : scheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 13,
              color: isDark ? const Color(0xFF8E95A8) : scheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIconBtn(
    PhosphorIconData icon,
    String tooltip,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        pressedScale: 0.88,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C26) : const Color(0xFFF0F3F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _canvasMarkdownStyle(BuildContext context, bool isDark) {
    final color = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF0E1017);
    final muted = isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B);
    final codeBlockBg =
        isDark ? const Color(0xFF12141C) : const Color(0xFFF1F4F9);
    final base = GoogleFonts.inter(fontSize: 15, color: color, height: 1.6);

    return MarkdownStyleSheet(
      p: base,
      h1: GoogleFonts.manrope(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.3),
      h2: GoogleFonts.manrope(
          fontSize: 17.5,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.3),
      h3: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      code: GoogleFonts.firaCode(
          fontSize: 12.5, color: color, backgroundColor: codeBlockBg),
      codeblockDecoration: BoxDecoration(
          color: codeBlockBg, borderRadius: BorderRadius.circular(10)),
      blockquote: base.copyWith(color: muted),
      blockquoteDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF161922) : const Color(0xFFEDF1F8),
          borderRadius: BorderRadius.circular(8),
          border: Border(
              left: BorderSide(
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF2563EB),
                  width: 3))),
      listBullet: base,
    );
  }
}
