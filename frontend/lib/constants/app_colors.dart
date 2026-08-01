import 'package:flutter/material.dart';

/// Warna-warna yang dipakai berulang di seluruh aplikasi.
class AppColors {
  const AppColors._();

  /// Biru utama TITC (tombol, tab aktif, link).
  static const Color primary = Color(0xFF1E5AF5);

  /// Biru gelap untuk ujung gradient tab aktif.
  static const Color primaryDark = Color(0xFF0B3FD1);

  /// Garis pembatas antar section (app bar, header, bottom nav).
  static const Color divider = Color(0xFFE0E0E0);

  /// Garis tepi input field.
  static const Color inputBorder = Color(0xFFDDDDDD);
}

/// Ketebalan garis pembatas standar.
const double kDividerThickness = 1;

/// Warna bayangan lembut (8% hitam) untuk pembatas antar section.
const Color kShadowColor = Color(0x14000000);

/// Bayangan turun ke bawah: dipakai app bar dan header halaman.
const List<BoxShadow> kShadowDown = [
  BoxShadow(color: kShadowColor, blurRadius: 8, offset: Offset(0, 2)),
];

/// Bayangan naik ke atas: dipakai bottom navigation bar.
const List<BoxShadow> kShadowUp = [
  BoxShadow(color: kShadowColor, blurRadius: 8, offset: Offset(0, -2)),
];

/// Garis pembatas horizontal setipis 1px, dipakai bila butuh pembatas datar.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: kDividerThickness,
      width: double.infinity,
      child: ColoredBox(color: AppColors.divider),
    );
  }
}
