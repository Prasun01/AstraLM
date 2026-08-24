import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/chat_controller.dart';
import 'code_block_widget.dart';
import 'pressable_scale.dart';

class CanvasWorkspace extends StatelessWidget {
  const CanvasWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      if (!controller.isCanvasOpen.value) return const SizedBox.shrink();

      final title = controller.canvasTitle.value;
      final content = controller.canvasContent.value;
      final isEditing = controller.isCanvasEditing.value;
      final wordCount = content.trim().isEmpty
          ? 0
          : content.trim().split(RegExp(r'\s+')).length;
      final charCount = content.length;

      return Container(
        color: isDark ? const Color(0xFF0C0E14) : const Color(0xFFF7F9FC),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header Bar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13161F) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF222634) : const Color(0xFFE5E9F2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Canvas Document Icon
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & Badge
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF12141D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Canvas',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            isEditing ? 'Editing document' : 'Interactive document preview',
                            style: GoogleFonts.openSans(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF888E9E) : const Color(0xFF6B7284),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit / Preview Toggle
                        _HeaderIconButton(
                          icon: isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
                          tooltip: isEditing ? 'Preview Markdown' : 'Edit Document',
                          isDark: isDark,
                          onTap: () {
                            controller.isCanvasEditing.value = !isEditing;
                            if (!controller.isCanvasEditing.value) {
                              controller.updateCanvasContent(controller.canvasTextController.text);
                            }
                          },
                        ),
                        const SizedBox(width: 4),

                        // Undo
                        if (controller.canvasHistory.length > 1) ...[
                          _HeaderIconButton(
                            icon: Icons.undo_rounded,
                            tooltip: 'Revert Revision',
                            isDark: isDark,
                            onTap: controller.undoCanvas,
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Copy
                        _HeaderIconButton(
                          icon: Icons.copy_rounded,
                          tooltip: 'Copy Content',
                          isDark: isDark,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: content));
                            Get.snackbar(
                              'Copied to clipboard',
                              'Canvas content copied.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(12),
                            );
                          },
                        ),
                        const SizedBox(width: 4),

                        // Share
                        _HeaderIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'Share Document',
                          isDark: isDark,
                          onTap: () {
                            Share.share(content, subject: title);
                          },
                        ),
                        const SizedBox(width: 4),

                        // Close
                        _HeaderIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close Canvas',
                          isDark: isDark,
                          onTap: controller.closeCanvas,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Main Content Editor / Preview ──
              Expanded(
                child: Container(
                  color: isDark ? const Color(0xFF0C0E14) : Colors.white,
                  child: isEditing
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: controller.canvasTextController,
                            onChanged: (v) => controller.canvasContent.value = v,
                            maxLines: null,
                            expands: true,
                            style: GoogleFonts.firaCode(
                              fontSize: 13.5,
                              height: 1.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Type or edit content in canvas...',
                              hintStyle: GoogleFonts.openSans(
                                color: isDark ? const Color(0xFF62687A) : const Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          child: content.trim().isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 80),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.draw_outlined,
                                          size: 40,
                                          color: isDark ? const Color(0xFF3B4154) : const Color(0xFFB0B8C8),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Canvas is waiting for response...',
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            color: isDark ? const Color(0xFF6B7284) : const Color(0xFF888E9E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : MarkdownBody(
                                  data: content,
                                  selectable: true,
                                  builders: {
                                    'code': CodeBlockBuilder(isDark: isDark),
                                  },
                                  styleSheet: _canvasMarkdownStyle(context, isDark),
                                ),
                        ),
                ),
              ),

              // ── Quick AI Canvas Toolbar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13161F) : const Color(0xFFF1F4FA),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF222634) : const Color(0xFFE5E9F2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$wordCount words · $charCount characters',
                          style: GoogleFonts.openSans(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF888E9E) : const Color(0xFF6B7284),
                          ),
                        ),
                        Text(
                          'Markdown & Code Supported',
                          style: GoogleFonts.openSans(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF5E6578) : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Action Chips (NO EMOJIS, pure vector icons)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CanvasActionChip(
                            icon: Icons.add_comment_outlined,
                            label: 'Add Comments',
                            isDark: isDark,
                            onTap: () => controller.requestCanvasRevision('Add thorough explanatory comments throughout this code/document.'),
                          ),
                          const SizedBox(width: 6),
                          _CanvasActionChip(
                            icon: Icons.compress_rounded,
                            label: 'Make Concise',
                            isDark: isDark,
                            onTap: () => controller.requestCanvasRevision('Make this document concise and direct, keeping all essential details.'),
                          ),
                          const SizedBox(width: 6),
                          _CanvasActionChip(
                            icon: Icons.auto_fix_high_rounded,
                            label: 'Fix & Polish',
                            isDark: isDark,
                            onTap: () => controller.requestCanvasRevision('Review, fix any errors, and polish the structure and clarity.'),
                          ),
                          const SizedBox(width: 6),
                          _CanvasActionChip(
                            icon: Icons.expand_outlined,
                            label: 'Explain in Detail',
                            isDark: isDark,
                            onTap: () => controller.requestCanvasRevision('Expand on the key concepts with deeper explanations and step-by-step breakdown.'),
                          ),
                          const SizedBox(width: 6),
                          _CanvasActionChip(
                            icon: Icons.translate_rounded,
                            label: 'Translate to Spanish',
                            isDark: isDark,
                            onTap: () => controller.requestCanvasRevision('Translate this document accurately to Spanish.'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  MarkdownStyleSheet _canvasMarkdownStyle(BuildContext context, bool isDark) {
    final color = isDark ? Colors.white : Colors.black;
    final muted = isDark ? const Color(0xFFC0C4D0) : const Color(0xFF404450);
    final base = GoogleFonts.openSans(fontSize: 15.5, color: color, height: 1.6);
    final codeBlockBg = isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5);

    return MarkdownStyleSheet(
      p: base,
      h1: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      h2: GoogleFonts.manrope(
        fontSize: 18.5,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      h3: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      ),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      code: GoogleFonts.firaCode(
        fontSize: 13,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
        backgroundColor: codeBlockBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF262C3D) : const Color(0xFFD8DFEC),
          width: 1,
        ),
      ),
      blockquote: base.copyWith(color: muted, fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
            width: 3.5,
          ),
        ),
      ),
      listBullet: base,
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        pressedScale: 0.90,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222F) : const Color(0xFFEBF0F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 17,
              color: isDark ? const Color(0xFFD0D5E2) : const Color(0xFF333846),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _CanvasActionChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3042) : const Color(0xFFD9E0EC),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
