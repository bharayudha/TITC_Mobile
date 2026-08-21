import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/screens/customer/search/search_results_screen.dart';
import 'package:magang_titc/widgets/shared/notifications_popup.dart';
import 'package:magang_titc/widgets/shared/profile_menu.dart';
import 'package:magang_titc/widgets/shared/search_overlay.dart';
import 'package:magang_titc/services/notifications_service.dart';

class TitcAppBar extends StatefulWidget implements PreferredSizeWidget {
  const TitcAppBar({super.key});

  @override
  State<TitcAppBar> createState() => _TitcAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _TitcAppBarState extends State<TitcAppBar> {
  @override
  void initState() {
    super.initState();
    NotificationsService.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      // Efek Material 3 "scrolled under": app bar dapat tint/bayangan halus
      // begitu konten di bawahnya mulai discroll — mengikuti default
      // `colorScheme.surfaceTint` (theme-aware, sudah pas untuk light & dark
      // mode) alih-alih dimatikan lewat `surfaceTintColor: transparent`.
      scrolledUnderElevation: 3,
      shadowColor: kShadowColor,
      // Default Flutter (16dp) membuat "TITC Indonesia" terlalu jauh dari
      // ikon ☰ dibanding web, di mana keduanya lebih rapat.
      titleSpacing: 0,
      leading: IconButton(
        icon: PhosphorIcon(PhosphorIconsRegular.list, color: onSurface),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: _buildTitle(context),
      actions: [
        IconButton(
          icon: PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            color: onSurface,
          ),
          // Hasil overlay WAJIB ditunggu. Sebelumnya dipanggil sebagai
          // `() => showSearchOverlay(context)`, dan karena onPressed bertipe
          // VoidCallback, Future berisi kata kuncinya terbuang — user
          // mengetik lalu tidak terjadi apa-apa.
          onPressed: () async {
            final request = await showSearchOverlay(context);
            if (request == null || !context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SearchResultsScreen(request: request),
              ),
            );
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: NotificationsService.unreadCountNotifier,
          builder: (context, unreadCount, child) {
            return IconButton(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                backgroundColor: Colors.red,
                child: PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: onSurface,
                ),
              ),
              onPressed: () => showNotificationsPopup(context),
            );
          },
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
        style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.bold),
        children: [
          TextSpan(
            text: 'TITC ',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(
            text: 'Indonesia',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
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
      // Padding HORIZONTAL sengaja dihapus (dulu ada, `horizontal: 6`) —
      // itu membuat teksnya geser sedikit ke kanan dibanding versi di Home
      // (yang tidak bisa pop, jadi tidak lewat Padding ini sama sekali),
      // padahal keduanya harus di posisi PERSIS sama. Padding vertikal
      // dipertahankan (tidak mempengaruhi posisi horizontal) supaya area
      // sentuhnya tetap sedikit lebih tinggi dari tinggi teks aslinya.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: label,
      ),
    );
  }
}
