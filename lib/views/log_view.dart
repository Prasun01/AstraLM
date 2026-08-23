import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_log_service.dart';
import '../widgets/pressable_scale.dart';

class LogView extends StatelessWidget {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = Get.find<AppLogService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedFilter = 'ALL'.obs;
    final filters = ['ALL', 'ERROR', 'WARNING', 'INFO', 'DEBUG'];

    Color levelColor(String level) {
      switch (level) {
        case 'ERROR':
          return scheme.error;
        case 'WARNING':
          return scheme.tertiary;
        case 'INFO':
          return scheme.primary;
        case 'DEBUG':
          return scheme.onSurfaceVariant;
        default:
          return scheme.onSurface;
      }
    }

    IconData levelIcon(String level) {
      switch (level) {
        case 'ERROR':
          return Icons.error_outline_rounded;
        case 'WARNING':
          return Icons.warning_amber_rounded;
        case 'INFO':
          return Icons.info_outline_rounded;
        case 'DEBUG':
          return Icons.bug_report_outlined;
        default:
          return Icons.list_alt_rounded;
      }
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Logs',
            style: GoogleFonts.manrope(
                fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Share logs',
            icon: Icon(Icons.ios_share_rounded, size: 20, color: scheme.primary),
            onPressed: () async {
              await logs.copyImportantLogs();
              Get.snackbar('Copied', 'Important logs copied to clipboard.', snackPosition: SnackPosition.BOTTOM);
            },
          ),
          IconButton(
            tooltip: 'Clear logs',
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: scheme.onSurfaceVariant),
            onPressed: logs.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Obx(() => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter.value == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: PressableScale(
                    pressedScale: 0.92,
                    onTap: () => selectedFilter.value = filter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            )),
          ),
          // Log console
          Expanded(
            child: Obx(() {
              final all = logs.entries;
              final filtered = selectedFilter.value == 'ALL'
                  ? all
                  : all.where((e) => e.level == selectedFilter.value).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.check_circle_outline_rounded, size: 28, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('All Clear', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                    const SizedBox(height: 6),
                    Text('No ${selectedFilter.value == 'ALL' ? '' : selectedFilter.value.toLowerCase() + ' '}logs captured yet.', style: GoogleFonts.inter(fontSize: 15, color: scheme.onSurfaceVariant)),
                  ]),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final color = levelColor(entry.level);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                          child: Icon(levelIcon(entry.level), color: color, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(entry.level, style: GoogleFonts.inter(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: color)),
                        const Spacer(),
                        Text(_formatTime(entry.timestamp), style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: 10),
                      SelectableText(entry.message, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurface)),
                      if (entry.details != null && entry.details!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.inverseSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(entry.details!, style: GoogleFonts.firaCode(fontSize: 11, color: scheme.onInverseSurface.withValues(alpha: 0.85))),
                        ),
                      ],
                    ]),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
