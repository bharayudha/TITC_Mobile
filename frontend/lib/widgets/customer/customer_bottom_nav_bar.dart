import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';

class BottomNavItem {
  const BottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const List<BottomNavItem> bottomNavItems = [
  BottomNavItem(icon: PhosphorIconsRegular.house, label: 'Home'),
  BottomNavItem(icon: PhosphorIconsRegular.play, label: 'Spaces'),
  BottomNavItem(icon: PhosphorIconsRegular.bookOpen, label: 'Courses'),
  BottomNavItem(icon: PhosphorIconsRegular.users, label: 'Members'),
  BottomNavItem(icon: PhosphorIconsRegular.headphones, label: 'Prep Test'),
];

/// Mengikuti setelan prototype Figma: Smart animate, easing Slow.
const Duration navAnimDuration = Duration(milliseconds: 300);
const Curve navAnimCurve = Curves.easeInOutCubic;

const double _pillHeight = 56;
const double _maxPillWidth = 68;

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isSpacesTab = false,
    this.isCoursesTab = false,
  });

  /// Index tab aktif. Beri nilai -1 bila tidak ada tab yang aktif.
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Saat true, bottom nav merender gaya glassmorphism cerah agar selaras
  /// dengan background pastel tab Spaces. Tab lain tidak terpengaruh.
  final bool isSpacesTab;
  
  /// Saat true, bottom nav merender gaya glassmorphism ungu cerah agar selaras
  /// dengan background tema violet pada tab Courses.
  final bool isCoursesTab;

  @override
  Widget build(BuildContext context) {
    final bool useGlass = isSpacesTab || isCoursesTab;
    final navContent = SafeArea(
      child: Container(
        margin: isCoursesTab ? const EdgeInsets.only(left: 16, right: 16, bottom: 16) : null,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: isCoursesTab ? BorderRadius.circular(30) : null,
          gradient: useGlass
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isCoursesTab 
                      ? [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.60),
                          Colors.white.withValues(alpha: 0.45),
                        ],
                )
              : null,
          color: useGlass ? null : Colors.white,
          border: useGlass
              ? Border.all(
                  color: isCoursesTab 
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.90),
                  width: 1.5,
                )
              : null,
          boxShadow: useGlass
              ? [
                  BoxShadow(
                    color: isCoursesTab 
                        ? const Color(0xFF4A44F2).withValues(alpha: 0.3)
                        : const Color(0xFF64A0DC).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: isCoursesTab ? const Offset(0, 10) : const Offset(0, -4),
                  )
                ]
              : kShadowUp,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / bottomNavItems.length;
            final pillWidth = math.min(_maxPillWidth, slotWidth - 4);
            // Saat tidak ada tab aktif, pill disembunyikan tapi posisinya
            // ditahan supaya tidak melompat ketika muncul lagi.
            final pillIndex = currentIndex < 0 ? 0 : currentIndex;

            return SizedBox(
              height: _pillHeight,
              child: Stack(
                children: [
                  // Pill yang meluncur antar tab (Smart animate).
                  AnimatedPositioned(
                    duration: navAnimDuration,
                    curve: navAnimCurve,
                    left: slotWidth * pillIndex + (slotWidth - pillWidth) / 2,
                    top: 0,
                    width: pillWidth,
                    height: _pillHeight,
                    child: AnimatedOpacity(
                      duration: navAnimDuration,
                      curve: navAnimCurve,
                      opacity: currentIndex < 0 ? 0 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // Pill aktif: 
                          border: useGlass 
                              ? Border.all(color: Colors.white.withValues(alpha: isCoursesTab ? 0.4 : 0.6), width: 1.2) 
                              : null,
                          color: isCoursesTab 
                              ? Colors.white.withValues(alpha: 0.85) // White pill for violet theme
                              : (isSpacesTab ? const Color(0xFFD6EDFD).withValues(alpha: 0.9) : null),
                          gradient: useGlass
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(bottomNavItems.length, (index) {
                      return Expanded(
                        child: _NavBarItem(
                          item: bottomNavItems[index],
                          selected: index == currentIndex,
                          onTap: () => onTap(index),
                          isSpacesTab: isSpacesTab,
                          isCoursesTab: isCoursesTab,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (useGlass) {
      Widget filtered = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: navContent,
      );
      return isCoursesTab ? ClipRRect(borderRadius: BorderRadius.circular(30), child: filtered) : ClipRect(child: filtered);
    }
    return navContent;
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.isSpacesTab = false,
    this.isCoursesTab = false,
  });

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isSpacesTab;
  final bool isCoursesTab;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: _pillHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<Color?>(
              duration: navAnimDuration,
              curve: navAnimCurve,
              tween: ColorTween(
                end: selected
                    // Ikon aktif
                    ? (isCoursesTab ? const Color(0xFF4A44F2) : (isSpacesTab ? const Color(0xFF0F172A) : Colors.white))
                    // Ikon non-aktif
                    : (isCoursesTab ? Colors.white.withValues(alpha: 0.8) : (isSpacesTab ? const Color(0xFF64748B) : Colors.grey)),
              ),
              builder: (context, color, _) {
                return PhosphorIcon(item.icon, color: color, size: 22);
              },
            ),
            // Label hanya tampil pada tab aktif; tingginya ikut dianimasikan
            // supaya ikon bergeser halus, bukan melompat.
            AnimatedSize(
              duration: navAnimDuration,
              curve: navAnimCurve,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          // Label aktif: Violet di Courses, Gelap di Spaces, putih di tab lain
                          color: isCoursesTab ? const Color(0xFF4A44F2) : (isSpacesTab ? const Color(0xFF0F172A) : Colors.white),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox(height: 0, width: 0),
            ),
          ],
        ),
      ),
    );
  }
}
