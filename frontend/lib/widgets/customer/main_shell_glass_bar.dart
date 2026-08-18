import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/screens/customer/search/search_results_screen.dart';
import 'package:magang_titc/services/notifications_service.dart';
import 'package:magang_titc/widgets/shared/notifications_popup.dart';
import 'package:magang_titc/widgets/shared/profile_menu.dart';
import 'package:magang_titc/widgets/shared/search_overlay.dart';

/// Versi kaca dari [TitcAppBar], KHUSUS dipakai [MainShell]
/// (Home/Spaces/Courses/Members) yang badannya bergaya glassmorphism.
///
/// Sama seperti dock bawah ([BottomNavBar]), kaca-nya sekarang dipasrahkan
/// sepenuhnya ke package `liquid_glass_widgets` alih-alih `BackdropFilter`
/// hasil racik sendiri — [AdaptiveLiquidGlassLayer] memberi latar kaca
/// bersama untuk seluruh bar (persis cara `GlassTabBar.bottom` internal
/// menyatukan pill-nya), sementara tiap ikon (hamburger/search/lonceng)
/// jadi [GlassIconButton] sendiri-sendiri yang "melebur" organik ke latar
/// itu — persis pola resmi package ini untuk toolbar (lihat contoh
/// "In a Toolbar (Grouped Mode)" di dokumentasi [GlassIconButton]).
///
/// Sengaja BUKAN pakai `Scaffold.appBar` — taruh widget ini LANGSUNG di
/// dalam body (Stack) MainShell, persis seperti header Spaces/Courses/
/// Members. MainShell selalu jadi route pertama (tidak pernah bisa
/// di-pop), jadi judul di sini tidak perlu logika "tap untuk pulang"
/// seperti `TitcAppBar` — KECUALI saat dipakai di layar yang di-push di
/// atas MainShell (mis. Messages), lewat [homeTapEnabled].
class MainShellGlassBar extends StatefulWidget {
  const MainShellGlassBar({
    super.key,
    this.homeTapEnabled = false,
    this.visible,
  });

  /// Saat true, judul "TITC Indonesia" bisa diketuk untuk pulang ke Home —
  /// sama seperti `TitcAppBar` di layar yang `Navigator.canPop()`-nya true.
  /// Dipakai layar yang di-push di atas MainShell (mis. Messages), yang
  /// juga menaruh widget ini langsung di body-nya sendiri (bukan MainShell).
  final bool homeTapEnabled;

  /// Sumber status tampil/sembunyi saat scroll — `true` = tampil, `false` =
  /// disembunyikan (meluncur ke atas + memudar). Null (default) berarti
  /// selalu tampil, tidak bereaksi ke scroll sama sekali.
  ///
  /// Widget ini SENDIRI tidak bisa mendengar event scroll dari scrollable
  /// yang ada di SAUDARA-nya di dalam `Stack` (notifikasi scroll cuma
  /// menjalar ke ANCESTOR lewat widget tree, bukan antar-sibling) — jadi
  /// pemanggil (mis. `MainShell`, `MessagesListScreen`) yang wajib
  /// membungkus body scrollable-nya dengan
  /// `NotificationListener<UserScrollNotification>` dan mengoper hasilnya
  /// ke sini lewat `ValueNotifier<bool>`.
  final ValueListenable<bool>? visible;

  /// Tinggi total (safe-area atas + toolbar) — dipakai layar tab untuk
  /// menghitung offset konten di baliknya.
  static double heightOf(BuildContext context) =>
      MediaQuery.of(context).padding.top + kToolbarHeight;

  @override
  State<MainShellGlassBar> createState() => _MainShellGlassBarState();
}

class _MainShellGlassBarState extends State<MainShellGlassBar> {
  @override
  void initState() {
    super.initState();
    NotificationsService.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final bar = AdaptiveLiquidGlassLayer(
      child: GlassAppBar(
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        leading: GlassIconButton(
          icon: const Icon(PhosphorIconsRegular.list),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: _buildTitle(context),
        actions: [
          GlassIconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
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
              return GlassBadge(
                count: unreadCount,
                child: GlassIconButton(
                  icon: const Icon(PhosphorIconsRegular.bell),
                  onPressed: () => showNotificationsPopup(context),
                ),
              );
            },
          ),
          const ProfileMenuButton(),
        ],
      ),
    );

    if (widget.visible == null) return bar;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.visible!,
      builder: (context, isVisible, child) {
        return IgnorePointer(
          // Saat disembunyikan, jangan tangkap sentuhan sama sekali —
          // supaya tap di area itu tembus ke konten di baliknya, bukan
          // "termakan" oleh bar yang sudah tak terlihat.
          ignoring: !isVisible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            offset: isVisible ? Offset.zero : const Offset(0, -1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              opacity: isVisible ? 1 : 0,
              child: child,
            ),
          ),
        );
      },
      child: bar,
    );
  }

  /// Sama seperti `TitcAppBar._buildTitle` — tap untuk pulang ke Home hanya
  /// aktif kalau [MainShellGlassBar.homeTapEnabled] true (layar yang
  /// di-push, mis. Messages).
  ///
  /// "Indonesia" dibungkus [GlassContentAwareBrightness] supaya warnanya
  /// beradaptasi ke konten yang sedang lewat di BALIK bar (mis. banner
  /// gelap "TITC INDONESIA" di puncak Home) — putih saat gelap, abu-abu
  /// gelap (warna semula) saat terang, persis cara bar iOS 26 menjaga
  /// kontras teksnya. "TITC " tetap warna aksen biru, tidak ikut berubah.
  /// Kalau tidak ada [GlassContentAwareScope] di atas widget ini (mis.
  /// layar yang belum dibungkus), widget ini otomatis jatuh ke brightness
  /// platform ambient — bukan error, cuma tidak beradaptasi.
  Widget _buildTitle(BuildContext context) {
    final label = GlassContentAwareBrightness(
      gridColumns: 2,
      builder: (context, brightness, darkAmount) {
        final indonesiaColor = Color.lerp(
          Colors.black54,
          Colors.white,
          darkAmount,
        )!;
        return RichText(
          text: TextSpan(
            style: GoogleFonts.fredoka(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(
                text: 'TITC ',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: 'Indonesia',
                style: TextStyle(color: indonesiaColor),
              ),
            ],
          ),
        );
      },
    );

    if (!widget.homeTapEnabled) return label;

    return InkWell(
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: label,
      ),
    );
  }
}
