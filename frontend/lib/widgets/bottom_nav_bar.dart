import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_colors.dart';

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
  });

  /// Index tab aktif. Beri nilai -1 bila tidak ada tab yang aktif.
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: kShadowUp,
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
                  // Pill biru yang meluncur antar tab (Smart animate).
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
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
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
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

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
              tween: ColorTween(end: selected ? Colors.white : Colors.grey),
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
                        style: const TextStyle(
                          color: Colors.white,
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
