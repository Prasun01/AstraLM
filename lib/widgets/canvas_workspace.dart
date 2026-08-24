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
  return lower.startsWith('<!doctype html') ||
      lower.startsWith('<!doctype') ||
      lower.startsWith('<html') ||
      (lower.contains('<html') && lower.contains('</html>')) ||
      (lower.contains('<body') && lower.contains('</body>')) ||
      (lower.contains('<head') && lower.contains('</head>')) ||
      (lower.contains('<script') && lower.contains('</script>')) ||
      (lower.contains('<style') && lower.contains('</style>')) ||
      (lower.contains('<div') && lower.contains('</div>')) ||
      (lower.contains('<svg') && lower.contains('</svg>') && clean.startsWith('<svg')) ||
      (lower.contains('<canvas') && lower.contains('</canvas>'));
}

String _detectLanguage(String content) {
  final clean = _extractRenderableHtml(content).trim();
  final lower = clean.toLowerCase();
  if (lower.startsWith('import flutter') ||
      (lower.contains('class ') && lower.contains('extends')) ||
      lower.contains('widget build(')) {
    return 'dart';
  }
  if (lower.startsWith('import ') ||
      lower.startsWith('def ') ||
      lower.startsWith('from ') ||
      lower.contains('if __name__ ==')) {
    return 'python';
  }
  if (lower.startsWith('function ') ||
      lower.startsWith('const ') ||
      lower.startsWith('let ') ||
      lower.startsWith('var ') ||
      lower.contains('console.log') ||
      lower.contains('document.getelementbyid')) {
    return 'javascript';
  }
  if (lower.startsWith('{') && lower.endsWith('}') ||
      lower.startsWith('[') && lower.endsWith(']')) {
    return 'json';
  }
  if (lower.startsWith('select ') || lower.startsWith('create table')) {
    return 'sql';
  }
  if (lower.startsWith('#include') || lower.contains('int main(')) {
    return 'cpp';
  }
  if (lower.startsWith('package main') || lower.startsWith('func main(')) {
    return 'go';
  }
  if (lower.startsWith('fn main(') || lower.contains('pub struct')) {
    return 'rust';
  }
  return 'code';
}

String _preparePreviewContent(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.contains('```') ||
      trimmed.startsWith('#') ||
      trimmed.contains('\n# ') ||
      trimmed.contains('\n## ') ||
      trimmed.contains('\n### ') ||
      trimmed.startsWith('> ') ||
      trimmed.startsWith('- ') ||
      trimmed.startsWith('* ')) {
    return content;
  }
  final lang = _detectLanguage(content);
  return '```$lang\n$trimmed\n```';
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

  void _syncHtmlIfChanged(String content, bool isHtml) {
    if (isHtml && _webController != null) {
      final cleanHtml = _extractRenderableHtml(content);
      final fullHtml = (cleanHtml.toLowerCase().contains('<html') ||
              cleanHtml.toLowerCase().contains('<!doctype'))
          ? cleanHtml
          : '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{font-family:system-ui,-apple-system,sans-serif;padding:16px;margin:0;line-height:1.5;color:#E2E6F2;}}</style></head><body>$cleanHtml</body></html>';
      if (fullHtml != _lastLoadedHtml) {
        _lastLoadedHtml = fullHtml;
        _webController!.loadData(
          data: fullHtml,
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

      if (!isEditing) {
        _syncHtmlIfChanged(content, isHtml);
      }

      return Container(
        color: isDark ? const Color(0xFF0A0C11) : const Color(0xFFFAFBFD),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Main Content Area ──
              Positioned.fill(
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

              // ── Top Floating Bar (Round Floating Buttons & Tab Switcher) ──
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    // Floating Round Close Button
                    _roundFloatingBtn(
                      icon: PhosphorIconsBold.x,
                      tooltip: 'Close Canvas',
                      isDark: isDark,
                      onTap: controller.closeCanvas,
                    ),
                    const SizedBox(width: 8),

                    // Floating Round Segmented Tab Switcher (Code / Live Preview)
                    if (!isEditing)
                      _buildFloatingSegmentedTabs(isDark),

                    const Spacer(),

                    // Floating Round Actions (Undo, View/Edit, Copy, Share)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.canvasHistory.length > 1) ...[
                          _roundFloatingBtn(
                            icon: PhosphorIconsBold.arrowCounterClockwise,
                            tooltip: 'Undo',
                            isDark: isDark,
                            onTap: controller.undoCanvas,
                          ),
                          const SizedBox(width: 6),
                        ],
                        _roundFloatingBtn(
                          icon: isEditing ? PhosphorIconsBold.eye : PhosphorIconsBold.pencil,
                          tooltip: isEditing ? 'Read View' : 'Edit Code',
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
                        _roundFloatingBtn(
                          icon: PhosphorIconsBold.copy,
                          tooltip: 'Copy Code',
                          isDark: isDark,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: content));
                            Get.snackbar(
                              'Copied',
                              'Code copied to clipboard.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(12),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _roundFloatingBtn(
                          icon: PhosphorIconsBold.shareNetwork,
                          tooltip: 'Share Code',
                          isDark: isDark,
                          onTap: () => Share.share(content),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Bottom Floating Buttons with Fade Scroll ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: _buildFloatingActionsWithFade(controller, isDark),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Floating Round Segmented Tab Switcher
  Widget _buildFloatingSegmentedTabs(bool isDark) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141620).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF262B3B) : const Color(0xFFDCE2EE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF262B3B) : const Color(0xFF141620),
          borderRadius: BorderRadius.circular(15),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B),
        tabs: const [
          Tab(
            height: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(PhosphorIconsBold.browsers, size: 13),
                SizedBox(width: 4),
                Text('Preview'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Round Floating Action Button
  Widget _roundFloatingBtn({
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
            color: isDark
                ? const Color(0xFF141620).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.95),
            border: Border.all(
              color: isDark ? const Color(0xFF262B3B) : const Color(0xFFDCE2EE),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 17,
              color: isDark ? Colors.white : const Color(0xFF12141D),
            ),
          ),
        ),
      ),
    );
  }

  /// Code View with Soft Text Wrapping (No Horizontal Side Scrolling)
  Widget _buildCodeView(BuildContext context, String content, bool isDark) {
    if (content.trim().isEmpty) return _empty(isDark);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 62, 18, 90), // Top & bottom padding for floating controls
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

  /// Live Preview View
  Widget _buildPreviewView(
      BuildContext context, String content, bool isHtml, bool isDark) {
    if (content.trim().isEmpty) return _empty(isDark);

    if (isHtml) {
      final cleanHtml = _extractRenderableHtml(content);
      final fullHtml = (cleanHtml.toLowerCase().contains('<html') ||
              cleanHtml.toLowerCase().contains('<!doctype'))
          ? cleanHtml
          : '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>body{font-family:system-ui,-apple-system,sans-serif;padding:16px;margin:0;line-height:1.5;${isDark ? 'background:#0A0C11;color:#E2E6F2;' : 'background:#FFFFFF;color:#0F172A;'}}</style></head><body>$cleanHtml</body></html>';

      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 58, 0, 80),
        child: ClipRect(
          child: InAppWebView(
            key: ValueKey(fullHtml.hashCode),
            initialData: InAppWebViewInitialData(
              data: fullHtml,
              mimeType: 'text/html',
              encoding: 'utf-8',
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              hardwareAcceleration: true,
              useHybridComposition: true,
              transparentBackground: false,
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

    final previewMarkdown = _preparePreviewContent(content);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 62, 18, 90),
      physics: const BouncingScrollPhysics(),
      child: MarkdownBody(
        data: previewMarkdown,
        selectable: true,
        builders: {'code': CodeBlockBuilder(isDark: isDark)},
        styleSheet: _canvasMarkdownStyle(context, isDark),
      ),
    );
  }

  /// Editor with Soft Line Wrapping
  Widget _buildEditor(ChatController controller, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0A0C11) : Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 62, 18, 90),
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
          hintText: 'Type or paste code…',
          hintStyle: GoogleFonts.inter(
            color: isDark
                ? const Color(0xFF44495A)
                : const Color(0xFFB0B8C8),
          ),
        ),
      ),
    );
  }

  Widget _empty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIconsBold.code,
            size: 44,
            color: isDark ? const Color(0xFF2E3347) : const Color(0xFFC8D0E2),
          ),
          const SizedBox(height: 12),
          Text(
            'Canvas is waiting for code response…',
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

  /// Floating Buttons with Side Gradient Fades (No Surrounding Box)
  Widget _buildFloatingActionsWithFade(ChatController controller, bool isDark) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            _boldFloatingChip(
              icon: PhosphorIconsBold.chatCircle,
              label: 'Add Comments',
              isDark: isDark,
              onTap: () => controller.requestCanvasRevision(
                  'Add thorough explanatory comments throughout this code.'),
            ),
            const SizedBox(width: 8),
            _boldFloatingChip(
              icon: PhosphorIconsBold.scissors,
              label: 'Make Concise',
              isDark: isDark,
              onTap: () => controller.requestCanvasRevision(
                  'Optimize and make this code concise, keeping all functionality.'),
            ),
            const SizedBox(width: 8),
            _boldFloatingChip(
              icon: PhosphorIconsBold.sparkle,
              label: 'Fix & Polish',
              isDark: isDark,
              onTap: () => controller.requestCanvasRevision(
                  'Review, fix any bugs, and polish code formatting.'),
            ),
            const SizedBox(width: 8),
            _boldFloatingChip(
              icon: PhosphorIconsBold.textT,
              label: 'Explain',
              isDark: isDark,
              onTap: () => controller.requestCanvasRevision(
                  'Explain step-by-step how this code works.'),
            ),
            const SizedBox(width: 8),
            _boldFloatingChip(
              icon: PhosphorIconsBold.translate,
              label: 'Translate',
              isDark: isDark,
              onTap: () => controller.requestCanvasRevision(
                  'Translate any comments and strings into Spanish.'),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual Bigger & Bolder Floating Chip (No Parent Box)
  Widget _boldFloatingChip({
    required PhosphorIconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      pressedScale: 0.92,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF141620).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF262B3B) : const Color(0xFFDCE2EE),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 16,
              color: isDark ? Colors.white : const Color(0xFF12141D),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF12141D),
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
    final base =
        GoogleFonts.inter(fontSize: 15, color: color, height: 1.6);
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
          fontSize: 12.5,
          color: color,
          backgroundColor: codeBlockBg),
      codeblockDecoration:
          BoxDecoration(color: codeBlockBg, borderRadius: BorderRadius.circular(10)),
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
