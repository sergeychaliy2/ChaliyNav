import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Root shell with a glassmorphism bottom navigation bar.
/// The active tab's Navigator is hosted by the StatefulShellRoute.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  List<_Tab> _buildTabs(BuildContext context) {
    final s = AppStrings.of(context);
    return [
      _Tab(
        icon: PhosphorIconsDuotone.compass,
        activeIcon: PhosphorIconsFill.compass,
        label: s.navMap,
      ),
      _Tab(
        icon: PhosphorIconsDuotone.mapPin,
        activeIcon: PhosphorIconsFill.mapPin,
        label: s.navPoints,
      ),
      _Tab(
        icon: PhosphorIconsDuotone.path,
        activeIcon: PhosphorIconsFill.path,
        label: s.navTracks,
      ),
      _Tab(
        icon: PhosphorIconsDuotone.gear,
        activeIcon: PhosphorIconsFill.gear,
        label: s.navSettings,
      ),
    ];
  }

  void _onTap(int i) {
    navigationShell.goBranch(
      i,
      initialLocation: i == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final idx = navigationShell.currentIndex;
    final tabs = _buildTabs(context);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgDeepest.withValues(alpha: 0.7),
              border: Border(
                top: BorderSide(color: AppColors.glassBorder, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(tabs.length, (i) {
                    return _NavItem(
                      tab: tabs[i],
                      active: i == idx,
                      onTap: () => _onTap(i),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryGlow : AppColors.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: AppColors.primary.withValues(alpha: 0.15),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: active
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                active ? tab.activeIcon : tab.icon,
                key: ValueKey(active),
                color: color,
                size: 22,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
