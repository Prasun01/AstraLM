import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttachmentPreview extends StatelessWidget {
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final String? imagePath;
  final String? imageBase64;
  final VoidCallback? onRemove;
  final bool compact;

  const AttachmentPreview({
    super.key,
    required this.fileName,
    this.fileType,
    this.fileSize,
    this.imagePath,
    this.imageBase64,
    this.onRemove,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = fileType ?? _typeFromName(fileName);
    final color = _colorForType(context, type);
    final label = _labelForType(type);

    return Container(
      constraints: compact ? const BoxConstraints(maxWidth: 260) : null,
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Leading icon/thumbnail
          _leading(context, type, color),
          const SizedBox(width: 10),
          // File info
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 13 : 14,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileSize != null && fileSize! > 0
                      ? '$label · ${formatFileSize(fileSize!)}'
                      : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: scheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _leading(BuildContext context, String type, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final image = _imageThumbnail();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: compact ? 36 : 42,
        height: compact ? 36 : 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: image ??
            Icon(
              _iconForType(type),
              color: color,
              size: compact ? 18 : 20,
            ),
      ),
    );
  }

  Widget? _imageThumbnail() {
    if ((fileType ?? _typeFromName(fileName)) != 'image') return null;
    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(imageBase64!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }
    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }
    return null;
  }


  static String formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round()} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    return '$bytes B';
  }

  String _typeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic'].contains(ext)) {
      return 'image';
    }
    if (['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'].contains(ext)) {
      return 'audio';
    }
    if (ext == 'pdf') return 'pdf';
    if ([
      'txt', 'md', 'json', 'csv', 'log', 'yaml', 'yml', 'xml',
      'dart', 'kt', 'java', 'js', 'ts', 'py'
    ].contains(ext)) {
      return 'text';
    }
    return 'file';
  }

  String _labelForType(String type) {
    switch (type) {
      case 'image':  return 'Image';
      case 'pdf':    return 'PDF';
      case 'audio':  return 'Audio';
      case 'text':   return 'Text file';
      default:       return 'Attachment';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'image':  return Icons.image_outlined;
      case 'pdf':    return Icons.picture_as_pdf_outlined;
      case 'audio':  return Icons.graphic_eq_rounded;
      case 'text':   return Icons.description_outlined;
      default:       return Icons.insert_drive_file_outlined;
    }
  }

  Color _colorForType(BuildContext context, String type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'image':  return scheme.primary;
      case 'pdf':    return scheme.error;
      case 'audio':  return scheme.tertiary;
      case 'text':   return scheme.secondary;
      default:       return scheme.onSurfaceVariant;
    }
  }
}
