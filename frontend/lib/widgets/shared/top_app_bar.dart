import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/widgets/shared/notifications_popup.dart';
import 'package:magang_titc/widgets/shared/profile_menu.dart';
import 'package:magang_titc/widgets/shared/search_overlay.dart';

class TitcAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TitcAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      // Drop shadow lembut, bukan garis datar.
      elevation: 3,
      scrolledUnderElevation: 3,
      shadowColor: kShadowColor,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const PhosphorIcon(
          PhosphorIconsRegular.list,
          color: Colors.black87,
        ),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: _buildTitle(context),
      actions: [
        IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            color: Colors.black87,
          ),
          onPressed: () => showSearchOverlay(context),
        ),
        IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsRegular.bell,
            color: Colors.black87,
          ),
          onPressed: () => showNotificationsPopup(context),
        ),
        const ProfileMenuButton(),
      ],
    );
  }

  /// Judul "TITC Indonesia". Di halaman yang bisa ditutup (mis. detail
  /// Space/Course, Profil), mengetuknya membawa langsung ke Home — bukan
  /// mundur selangkah. Navbar ini tidak punya tombol back sendiri karena
  /// bentuknya mengikuti tampilan web, jadi judulnya yang mengambil peran
  /// "pulang".
  ///
  /// Sengaja BUKAN pop biasa: berpindah antar space/course menumpuk banyak
  /// halaman, sehingga mundur selangkah malah mendarat di space yang tadi
  /// dibuka, bukan kembali ke titik awal.
  ///
  /// Di Home judulnya tidak bisa diketuk: [Navigator.canPop] bernilai false
  /// di sana, dan memberi efek sentuh pada sesuatu yang tidak melakukan
  /// apa-apa justru membingungkan.
  Widget _buildTitle(BuildContext context) {
    final label = RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: 'TITC ', style: TextStyle(color: AppColors.primary)),
          TextSpan(text: 'Indonesia', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );

    if (!Navigator.of(context).canPop()) return label;

    return InkWell(
      // MainShell (Home) selalu jadi route pertama: dipasang lewat `home:`
      // di app.dart saat sesi masih hidup, dan lewat pushReplacement setelah
      // login. Jadi menutup semua halaman sampai yang pertama = pulang ke Home.
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        // Area sentuh diperlebar sedikit supaya tidak perlu mengetuk
        // tepat di hurufnya.
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: label,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
