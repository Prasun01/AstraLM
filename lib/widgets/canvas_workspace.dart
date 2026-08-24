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
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
      if (_tabController.index == 1) {
        final controller = Get.find<ChatController>();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        _syncHtmlIfChanged(controller.canvasContent.value, isDark);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _syncHtmlIfChanged(String content, bool isDark) {
    if (_webController != null && content.isNotEmpty) {
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

    return Obx(() {
      if (!controller.isCanvasOpen.value) return const SizedBox.shrink();

      final content = controller.canvasContent.value;
      final isEditing = controller.isCanvasEditing.value;
      final isHtml = _isHtmlContent(content);

      return Container(
        color: isDark ? const Color(0xFF0A0C11) : const Color(0xFFFAFBFD),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // ── Main Content Area with Top & Bottom Fade ──
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.08, 0.92, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
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
              ),

              // ── Floating Top Actions Bar (No Grey Outlines) ──
              Positioned(
                top: 10,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    // Floating Close Button
                    _floatingRoundBtn(
                      icon: PhosphorIconsBold.x,
                      tooltip: 'Close Canvas',
                      isDark: isDark,
                      onTap: controller.closeCanvas,
                    ),
                    const SizedBox(width: 8),

                    // Floating Code / Preview Segmented Tab Switcher
                    if (!isEditing)
                      Expanded(
                        child: Center(
                          child: _buildFloatingSegmentedTabs(isDark, isHtml),
                        ),
                      )
                    else
                      const Spacer(),

                    const SizedBox(width: 8),

                    // Floating Actions: Undo, Edit/Preview, Copy, Share
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.canvasHistory.length > 1) ...[
                          _floatingRoundBtn(
                            icon: PhosphorIconsBold.arrowCounterClockwise,
                            tooltip: 'Undo',
                            isDark: isDark,
                            onTap: controller.undoCanvas,
                          ),
                          const SizedBox(width: 6),
                        ],
                        _floatingRoundBtn(
                          icon: isEditing
                              ? PhosphorIconsBold.eye
                              : PhosphorIconsBold.pencil,
                          tooltip: isEditing ? 'Preview' : 'Edit',
                          isDark: isDark,
                          onTap: () {
                            controller.isCanvasEditing.value = !isEditing;
                            if (!controller.isCanvasEditing.value) {
                              controller.updateCanvasContent(
                                  controller.canvasTextController.text);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        _floatingRoundBtn(
                          icon: PhosphorIconsBold.copy,
                          tooltip: 'Copy',
                          isDark: isDark,
                          onTap: () {
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
                        const SizedBox(width: 6),
                        _floatingRoundBtn(
                          icon: PhosphorIconsBold.shareNetwork,
                          tooltip: 'Share',
                          isDark: isDark,
                          onTap: () => Share.share(content),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Floating Footer Action Chips (No Big Background Bar, Borderless) ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: _buildFloatingFooter(controller, isDark),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Floating Round Button (Borderless, Solid, Subtle Elevation)
  Widget _floatingRoundBtn({
    required PhosphorIconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        pressedScale: 0.90,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF161922) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFFE2E6F2) : const Color(0xFF12141D),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating Code / Preview Segmented Tab Switcher (Borderless)
  Widget _buildFloatingSegmentedTabs(bool isDark, bool isHtml) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF262C3D) : const Color(0xFF141620),
          borderRadius: BorderRadius.circular(15),
        ),
        labelPadding: EdgeInsets.zero,
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B),
        tabs: [
          const Tab(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(PhosphorIconsBold.code, size: 13),
                SizedBox(width: 4),
                Text('Code'),
              ],
            ),
          ),
          Tab(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  isHtml ? PhosphorIconsBold.browsers : PhosphorIconsBold.eye,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(isHtml ? 'Preview' : 'View'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Editor with Soft Line Wrapping
  Widget _buildEditor(ChatController controller, bool isDark) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 84),
      child: TextField(
        controller: controller.canvasTextController,
        onChanged: (v) => controller.canvasContent.value = v,
        maxLines: null,
        expands: true,
        style: GoogleFonts.firaCode(
          fontSize: 13.5,
          height: 1.6,
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

  /// Code View
  Widget _buildCodeView(BuildContext context, String content, bool isDark) {
    if (content.trim().isEmpty) return _empty(isDark);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 84),
      physics: const BouncingScrollPhysics(),
      child: SelectableText(
        content,
        style: GoogleFonts.firaCode(
          fontSize: 13.5,
          color: textColor,
          height: 1.6,
        ),
      ),
    );
  }

  /// Live Web / Markdown Preview View
  Widget _buildPreviewView(
      BuildContext context, String content, bool isHtml, bool isDark) {
    if (content.trim().isEmpty) return _empty(isDark);

    if (isHtml) {
      final fullHtml = _generateFullHtmlDocument(content, isDark);

      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 56, 0, 72),
        child: ClipRect(
          child: InAppWebView(
            key: const ValueKey('canvas_inappwebview_persistent'),
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
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              verticalScrollBarEnabled: true,
              horizontalScrollBarEnabled: true,
              overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
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
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 84),
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
            size: 44,
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

  /// Floating Footer Action Chips with Horizontal Fade (No Big Background Bar)
  Widget _buildFloatingFooter(ChatController controller, bool isDark) {
    return ShaderMask(
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
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            _floatingChip(
              PhosphorIconsBold.chatCircle,
              'Add Comments',
              isDark,
              () => controller.requestCanvasRevision(
                  'Add thorough explanatory comments throughout this code/document.'),
            ),
            const SizedBox(width: 8),
            _floatingChip(
              PhosphorIconsBold.scissors,
              'Make Concise',
              isDark,
              () => controller.requestCanvasRevision(
                  'Make this concise and direct, keeping all essential details.'),
            ),
            const SizedBox(width: 8),
            _floatingChip(
              PhosphorIconsBold.sparkle,
              'Fix & Polish',
              isDark,
              () => controller.requestCanvasRevision(
                  'Review, fix any errors, and polish the structure and clarity.'),
            ),
            const SizedBox(width: 8),
            _floatingChip(
              PhosphorIconsBold.textT,
              'Explain',
              isDark,
              () => controller.requestCanvasRevision(
                  'Expand with deeper explanations and step-by-step breakdown.'),
            ),
            const SizedBox(width: 8),
            _floatingChip(
              PhosphorIconsBold.translate,
              'Translate',
              isDark,
              () => controller.requestCanvasRevision(
                  'Translate this document accurately to Spanish.'),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Action Chip (Borderless, Solid Elevated Surface)
  Widget _floatingChip(
    PhosphorIconData icon,
    String label,
    bool isDark,
    VoidCallback onTap,
  ) {
    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161922) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 13,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1E293B),
              ),
            ),
          ],
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
