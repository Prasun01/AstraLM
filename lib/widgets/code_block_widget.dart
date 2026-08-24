import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;

  CodeBlockBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceFirst('language-', '') ?? '';
    final text = element.textContent;

    // Only handle multiline blocks or blocks with explicit language
    if (!text.contains('\n') && language.isEmpty) {
      return null; // fallback to inline code
    }

    return CodeBlockWidget(
      code: text.trimRight(),
      language: language.isNotEmpty ? language : 'code',
      isDark: isDark,
    );
  }
}

class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  final bool isDark;

  const CodeBlockWidget({
    super.key,
    required this.code,
    required this.language,
    required this.isDark,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Code copied to clipboard',
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF141620),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF0F1118) : const Color(0xFFE9EDF5);
    final headerBgColor = isDark ? const Color(0xFF161922) : const Color(0xFFDCE2EE);
    final textColor = isDark ? const Color(0xFFE4E8F2) : const Color(0xFF12141D);
    final langColor = isDark ? const Color(0xFF8E95A8) : const Color(0xFF5A6074);

    final displayLang = widget.language.isEmpty ? 'CODE' : widget.language.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar with Language Badge and Copy Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: headerBgColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.code,
                        size: 15,
                        color: langColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        displayLang,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: langColor,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _copyCode,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            _copied ? PhosphorIconsBold.check : PhosphorIconsBold.copy,
                            size: 14,
                            color: _copied
                                ? const Color(0xFF34C759)
                                : (isDark ? Colors.white : const Color(0xFF141620)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'Copied' : 'Copy',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _copied
                                  ? const Color(0xFF34C759)
                                  : (isDark ? Colors.white : const Color(0xFF141620)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Code Content with Soft Line Wrapping (Whole code visible without scrolling to sides)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                widget.code,
                style: GoogleFonts.firaCode(
                  fontSize: 13,
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
