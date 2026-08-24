import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/chat_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/chat_message.dart';
import '../utils/thought_parser.dart';
import 'attachment_preview.dart';
import 'code_block_widget.dart';
import 'image_viewer.dart';
import 'pressable_scale.dart';
import 'thought_disclosure.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : Colors.black;
    final visibleContent = message.fileName == null
        ? message.content
        : message.content.split('\n\nAttached file:').first;
    final suppress = Get.find<SettingsController>().reasoningEffort.value == 'none';
    final thoughtParts = isUser
        ? const ThoughtParts(thought: '', answer: '', isThinking: false)
        : splitThoughtTags(_cleanAssistantText(visibleContent),
            suppressThoughts: suppress);
    final answerContent = isUser ? visibleContent : thoughtParts.answer.trim();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.fastLinearToSlowEaseIn,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(0, (1 - anim) * 6),
          child: child,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isUser ? 4 : 8,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: isUser
                  ? _buildUserBubble(context, isDark, textColor, visibleContent)
                  : _buildAssistantBubble(context, isDark, scheme, thoughtParts, answerContent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserBubble(
    BuildContext context,
    bool isDark,
    Color textColor,
    String visibleContent,
  ) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1E28) : const Color(0xFFE9EDF5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.decodedImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () =>
                    ImageViewer.show(context, message.imageBase64!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    message.decodedImageBytes!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242836) : const Color(0xFFDFE4F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                          child:
                              PhosphorIcon(PhosphorIconsBold.imageBroken, size: 28)),
                    ),
                  ),
                ),
              ),
            ),
          Text(
            visibleContent,
            style: GoogleFonts.openSans(
              fontSize: 14.5,
              color: textColor,
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (message.fileName != null) ...[
            const SizedBox(height: 6),
            AttachmentPreview(
              fileName: message.fileName!,
              fileType: message.fileType,
              fileSize: message.fileSize,
              imageBase64: message.imageBase64,
              imagePath: message.imagePath,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(
    BuildContext context,
    bool isDark,
    ColorScheme scheme,
    ThoughtParts thoughtParts,
    String answerContent,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image attachment
          if (message.decodedImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () =>
                    ImageViewer.show(context, message.imageBase64!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    message.decodedImageBytes!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                          child:
                              PhosphorIcon(PhosphorIconsBold.imageBroken, size: 28)),
                    ),
                  ),
                ),
              ),
            ),

          // Thought disclosure
          if (thoughtParts.hasThought)
            ThoughtDisclosure(
              thought: thoughtParts.thought,
              durationSeconds: message.thoughtDurationSeconds,
              styleSheet: _thoughtMarkdownStyle(context),
            ),

          // Canvas document card
          if (message.isCanvas || message.canvasTitle != null)
            _buildCanvasCard(context, isDark, scheme, answerContent)
          else if (answerContent.isNotEmpty)
            MarkdownBody(
              data: answerContent,
              selectable: true,
              builders: {
                'code': CodeBlockBuilder(isDark: isDark),
              },
              styleSheet: _markdownStyle(context),
            ),

          // File attachment
          if (message.fileName != null) ...[
            const SizedBox(height: 10),
            AttachmentPreview(
              fileName: message.fileName!,
              fileType: message.fileType,
              fileSize: message.fileSize,
              imageBase64: message.imageBase64,
              imagePath: message.imagePath,
              compact: true,
            ),
          ],

          // Quick Action to open standard responses in Canvas ONLY for code, documents, HTML, and structured content
          if (!message.isCanvas && _isCanvasEligible(answerContent))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PressableScale(
                pressedScale: 0.94,
                onTap: () {
                  Get.find<ChatController>().openCanvas(
                    title: 'Document',
                    content: answerContent,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161924) : const Color(0xFFEFF2F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF222636) : const Color(0xFFDCE2EF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.notepad,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Open in Canvas',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCanvasCard(
    BuildContext context,
    bool isDark,
    ColorScheme scheme,
    String content,
  ) {
    final title = message.canvasTitle ?? 'Canvas Document';
    final preview = content.length > 200 ? '${content.substring(0, 200).trim()}...' : content;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131620) : const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF242938) : const Color(0xFFDFE5F2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(
                  PhosphorIconsBold.notepad,
                  color: scheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: isDark ? Colors.white : const Color(0xFF12141D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Canvas',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Interactive Document Created',
                      style: GoogleFonts.openSans(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF888E9E) : const Color(0xFF6B7284),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.openSans(
              fontSize: 13,
              color: isDark ? const Color(0xFFB5BAC9) : const Color(0xFF4A5162),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PressableScale(
              pressedScale: 0.94,
              onTap: () {
                Get.find<ChatController>().openCanvas(
                  title: title,
                  content: content,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2435) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF31384E) : const Color(0xFFD4DCEB),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsBold.arrowSquareOut,
                      size: 14,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Open in Canvas',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF12141D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFE8EDF5) : const Color(0xFF0E1017);
    final muted = isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B);
    final base = GoogleFonts.inter(fontSize: 15.5, color: color, height: 1.6);
    final codeBlockBg =
        isDark ? const Color(0xFF12141C) : const Color(0xFFF1F4F9);

    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      h1: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w700, color: color, height: 1.3),
      h2: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w700, color: color, height: 1.3),
      h3: GoogleFonts.manrope(
          fontSize: 15.5, fontWeight: FontWeight.w600, color: color, height: 1.3),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      listBullet: base,
      code: GoogleFonts.firaCode(
        fontSize: 13,
        color: color,
        backgroundColor: codeBlockBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBg,
        borderRadius: BorderRadius.circular(10),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: base.copyWith(color: muted),
      blockquoteDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : const Color(0xFFEDF1F8),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  MarkdownStyleSheet _thoughtMarkdownStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF8E95A8) : const Color(0xFF64748B);
    final base = GoogleFonts.inter(
        fontSize: 13, color: muted, height: 1.45, fontStyle: FontStyle.italic);
    final codeBg =
        isDark ? const Color(0xFF12141C) : const Color(0xFFF1F4F9);

    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      listBullet: base,
      code: GoogleFonts.firaCode(
        fontSize: 11,
        color: muted,
        backgroundColor: codeBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  String _cleanAssistantText(String text) {
    return text
        .replaceAll('<|endoftext|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|end|>', '')
        .trim();
  }
}

bool _isCanvasEligible(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return false;

  final lower = trimmed.toLowerCase();

  // 1. HTML content or code blocks
  if (lower.contains('```html') ||
      lower.contains('```xml') ||
      lower.startsWith('<!doctype') ||
      lower.startsWith('<html') ||
      (lower.contains('<body') && lower.contains('</body>')) ||
      (lower.contains('<div') && lower.contains('</div>') && lower.contains('<head')) ||
      (lower.contains('<script') && lower.contains('</script>')) ||
      (lower.contains('<style') && lower.contains('</style>'))) {
    return true;
  }

  // 2. Python code blocks
  if (lower.contains('```python') || lower.contains('```py')) {
    return true;
  }

  // 3. Markdown code blocks
  if (lower.contains('```markdown') || lower.contains('```md')) {
    return true;
  }

  // 4. Structured Markdown document with 2+ headings
  final headingCount =
      RegExp(r'^#{1,4}\s+', multiLine: true).allMatches(trimmed).length;
  if (headingCount >= 2 && trimmed.length > 150) {
    return true;
  }

  return false;
}
