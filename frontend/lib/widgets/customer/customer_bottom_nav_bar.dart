import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';

/// Mengikuti setelan prototype Figma: Smart animate, easing Slow. Dipakai di
/// tempat lain (transisi antar tab di `MainShell`, dorong halaman Prep Test)
/// supaya animasinya selaras dengan durasi/kurva bawaan [GlassTabBar].
const Duration navAnimDuration = Duration(milliseconds: 300);
const Curve navAnimCurve = Curves.easeInOutCubic;

/// Tinggi konten dock (barHeight 56 + padding vertikal 8 di atas & bawah).
/// Dipakai `MainShell` untuk menyisakan ruang bagi [DraggableChatFab] — lihat
/// parameter yang sama di [BottomNavBar._buildGlassBar].
const double kBottomNavBarContentHeight = 56 + 8 * 2;

/// Lima tab dock bawah, dipetakan ke [GlassTab] milik package
/// `liquid_glass_widgets`. `PhosphorIconsRegular.*`/`PhosphorIconsFill.*`
/// adalah `IconData` biasa, jadi bisa langsung dibungkus [Icon] standar —
/// [GlassTabBar] mewarnai & mengubah ukurannya sendiri lewat
/// `selectedIconColor`/`unselectedIconColor`/`iconSize`, PERSIS seperti ia
/// memperlakukan `Icon` bawaan Material/Cupertino.
const List<GlassTab> _glassTabs = [
  GlassTab(
    icon: Icon(PhosphorIconsRegular.house),
    activeIcon: Icon(PhosphorIconsFill.house),
    label: 'Home',
  ),
  GlassTab(
    icon: Icon(PhosphorIconsRegular.play),
    activeIcon: Icon(PhosphorIconsFill.play),
    label: 'Spaces',
  ),
  GlassTab(
    icon: Icon(PhosphorIconsRegular.bookOpen),
    activeIcon: Icon(PhosphorIconsFill.bookOpen),
    label: 'Courses',
  ),
  GlassTab(
    icon: Icon(PhosphorIconsRegular.users),
    activeIcon: Icon(PhosphorIconsFill.users),
    label: 'Members',
  ),
  GlassTab(
    icon: Icon(PhosphorIconsRegular.headphones),
    activeIcon: Icon(PhosphorIconsFill.headphones),
    label: 'Prep Test',
  ),
];

/// Dock navigasi bawah — versi kaca sekarang dipasrahkan sepenuhnya ke
/// `GlassTabBar.bottom` dari package `liquid_glass_widgets` (lihat
/// `main.dart` untuk setup `LiquidGlassWidgets.initialize()`/`.wrap()` yang
/// wajib menyertainya).
///
/// Sengaja BUKAN lagi implementasi manual: percobaan sebelumnya membuat
/// shader liquid-glass sendiri (lensa cembung + chromatic aberration)
/// berakhir dengan rentetan bug rendering (teks acak-terbalik, area sentuh
/// meleset, overflow memenuhi layar) meski setiap akar masalahnya sudah
/// ditemukan & diperbaiki satu-satu — hasilnya tetap jauh dari referensi
/// WhatsApp/Telegram/Reddit yang diminta. `liquid_glass_widgets` adalah
/// package terverifikasi (publisher resmi, 225 likes, 160 pub points) yang
/// mengimplementasikan persis spesifikasi "Liquid Glass" Apple (specular
/// highlight yang bergerak, refraksi real-time, chromatic aberration,
/// adaptive shadow) dengan shader yang sudah teruji di banyak perangkat —
/// jauh lebih aman daripada menulis ulang dari nol.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isSpacesTab = false,
  });

  /// Index tab aktif. Beri nilai -1 bila tidak ada tab yang aktif (dipakai
  /// layar Messages, yang di-push di atas MainShell — bukan salah satu dari
  /// 5 tab ini).
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Saat true, dock merender gaya glassmorphism (GlassTabBar). Saat false,
  /// dock jatuh ke bar putih polos tanpa kaca — dipertahankan untuk
  /// kompatibilitas API meski kedua pemanggil saat ini selalu memberi true.
  final bool isSpacesTab;

  @override
  Widget build(BuildContext context) {
    if (!isSpacesTab) return _buildSolidBar();

    // `GlassTabBar.bottom` mengharuskan `selectedIndex` valid (0..4) — tidak
    // menerima -1 seperti API lama. Saat currentIndex == -1 (layar Messages),
    // dipakai index 0 sebagai nilai "aman" secara teknis, tapi indikator
    // pill DISEMBUNYIKAN (`showIndicator: false`) dan warna ikon/label
    // "terpilih" DISAMAKAN dengan warna "tidak terpilih" — supaya tidak ada
    // satu pun tab yang tampak aktif secara visual, sesuai perilaku asli.
    final noneSelected = currentIndex < 0;
    final effectiveIndex = noneSelected ? 0 : currentIndex;
    // `Colors.black54` nyaris tak terlihat di atas kaca gelap dark mode —
    // butuh warna lebih terang di sana untuk kontras yang cukup.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.white70 : Colors.black54;

    return GlassTabBar.bottom(
      tabs: _glassTabs,
      selectedIndex: effectiveIndex,
      onTabSelected: onTap,
      showIndicator: !noneSelected,
      indicatorColor: AppColors.primary.withValues(alpha: 0.16),
      selectedIconColor: noneSelected ? unselectedColor : AppColors.primary,
      unselectedIconColor: unselectedColor,
      selectedLabelColor: noneSelected ? unselectedColor : AppColors.primary,
      unselectedLabelColor: unselectedColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      iconSize: 21,
      labelFontSize: 10,
      barHeight: 56,
      horizontalPadding: 16,
      verticalPadding: 8,
    );
  }

  Widget _buildSolidBar() {
    return Container(
      height: kBottomNavBarContentHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: kShadowUp,
      ),
      child: Row(
        children: [
          for (final tab in _glassTabs)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme(
                      data: const IconThemeData(
                        color: Colors.black54,
                        size: 21,
                      ),
                      child: tab.icon ?? const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label ?? '',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
