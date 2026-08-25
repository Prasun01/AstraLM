import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import 'chat_view.dart';
import '../core/constants.dart';
import '../services/hive_service.dart';
import 'welcome_guide_view.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const _tabs = [
    _NavItem(
        icon: PhosphorIconsBold.chatCircle,
        activeIcon: PhosphorIconsBold.chatCircleDots,
        label: 'Chat'),
    _NavItem(
        icon: PhosphorIconsBold.database,
        activeIcon: PhosphorIconsBold.database,
        label: 'Server'),
    _NavItem(
        icon: PhosphorIconsBold.gear,
        activeIcon: PhosphorIconsBold.gear,
        label: 'Settings'),
  ];

  bool get _isWide {
    if (kIsWeb) return true;
    return Get.width >= 800;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hive = Get.find<HiveService>();
      final hasSeen =
          hive.getSetting<bool>(AppConstants.keyHasSeenWelcomeGuide, defaultValue: false) ?? false;
      if (!hasSeen && context.mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => const WelcomeGuideView(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 320),
          ),
        );
      } else {
        controller.checkResumeModel(context);
      }
    });
    return Scaffold(
      backgroundColor: scheme.surface,
      body: const ChatView(),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = controller.currentTab.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < _tabs.length; i++) ...[
                Builder(builder: (ctx) {
                  final tab = _tabs[i];
                  final isSelected = current == i;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: InkWell(
                        onTap: () => controller.changeTab(i),
                        borderRadius: BorderRadius.circular(18),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary.withValues(
                                      alpha: isDark ? 0.24 : 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected ? tab.activeIcon : tab.icon,
                                  size: 20,
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tab.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 76,
      color: scheme.surfaceContainerLow,
      child: Column(children: [
        Expanded(child: Obx(() {
          final current = controller.currentTab.value;
          return ListView.builder(
            itemCount: _tabs.length,
            itemBuilder: (_, i) {
              final tab = _tabs[i];
              final sel = current == i;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: Material(
                  color: sel
                      ? scheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => controller.changeTab(i),
                    child: SizedBox(
                      height: 52,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(sel ? tab.activeIcon : tab.icon,
                                color: sel
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                size: 20),
                            const SizedBox(height: 3),
                            Text(tab.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: sel
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant)),
                          ]),
                    ),
                  ),
                ),
              );
            },
          );
        })),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}
