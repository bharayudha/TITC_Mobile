import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:magang_titc/screens/customer/courses/courses_list_screen.dart';
import 'package:magang_titc/screens/customer/home/home_screen.dart';
import 'package:magang_titc/screens/customer/members/members_list_screen.dart';
import 'package:magang_titc/screens/customer/messages/messages_list_screen.dart';
import 'package:magang_titc/screens/customer/preparation_test/preparation_test_webview_screen.dart';
import 'package:magang_titc/screens/customer/spaces/spaces_list_screen.dart';
import 'package:magang_titc/services/messages_service.dart';
import 'package:magang_titc/widgets/customer/customer_bottom_nav_bar.dart';
import 'package:magang_titc/widgets/customer/main_shell_glass_bar.dart';
import 'package:magang_titc/widgets/shared/chat_fab_button.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/scroll_hide_controller.dart';

/// Kerangka utama aplikasi: app bar, drawer, chat FAB, dan bottom nav dipasang
/// sekali di sini supaya perpindahan tab hanya menganimasikan isi kontennya.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  /// Urutan tab, sesuai daftar [_MainShellState._tabs] dan ikon bottom nav.
  static const int tabHome = 0;
  static const int tabSpaces = 1;
  static const int tabCourses = 2;
  static const int tabMembers = 3;

  /// Permintaan pindah tab dari luar subtree shell.
  ///
  /// Dibutuhkan karena menu profil menempel di [TitcAppBar], yang juga dipakai
  /// halaman-halaman yang ditumpuk DI ATAS shell (detail Space/Course, Profil,
  /// Messages). Dari sana `findAncestorStateOfType` tidak menemukan shell,
  /// karena mereka berada di route yang berbeda.
  ///
  /// Sengaja tidak memakai `pushAndRemoveUntil(MainShell(initialIndex: ...))`:
  /// itu membuat shell BARU, sehingga tab yang sudah terbuka dibuang dan semua
  /// datanya di-fetch ulang dari nol — persis masalah yang dihindari oleh
  /// mekanisme [_MainShellState._openedTabs] di bawah.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  /// Tutup halaman yang menumpuk di atas shell, lalu pindah ke [index].
  static void openTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    requestedTab.value = index;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex = widget.initialIndex;

  // Status tampil/sembunyi [MainShellGlassBar] mengikuti scroll konten tab
  // yang sedang aktif — lihat [ScrollHideController] untuk aturan threshold
  // jaraknya.
  final _scrollHide = ScrollHideController();

  // Tab yang sudah pernah dibuka sejak shell ini dibuat. Widget-nya baru
  // dibangun (dan initState/fetch datanya jalan) saat pertama kali dibuka,
  // lalu tetap hidup di tree (bukan di-dispose) saat pindah ke tab lain,
  // supaya balik lagi ke tab itu tidak fetch ulang dari nol / gambar tidak
  // ke-download ulang. Sebelumnya AnimatedSwitcher+KeyedSubtree membuang
  // State tab lama setiap pindah tab, itu yang bikin pindah-pindah tab
  // terasa stuck/lambat dan sesekali timeout karena semua fetch tab jalan
  // dari nol lagi.
  late final Set<int> _openedTabs = {_currentIndex};

  static const List<Widget> _tabs = [
    HomeScreen(),
    SpacesListScreen(),
    CoursesListScreen(),
    MembersListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MainShell.requestedTab.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    MainShell.requestedTab.removeListener(_onTabRequested);
    _scrollHide.dispose();
    super.dispose();
  }

  void _onTabRequested() {
    final index = MainShell.requestedTab.value;
    if (index == null) return;
    // Langsung dikosongkan: permintaannya sekali pakai. Ini juga yang membuat
    // permintaan tab yang sama dua kali berturut-turut tetap terkirim —
    // ValueNotifier tidak memberi tahu kalau nilainya tidak berubah.
    MainShell.requestedTab.value = null;
    if (!mounted || index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _openedTabs.add(index);
    });
  }

  void _onNavTap(int index) {
    // Prep Test bukan tab: dibuka sebagai halaman baru di atas shell.
    // Dipakai transisi slide-dari-kanan kustom (bukan MaterialPageRoute
    // bawaan) supaya arahnya konsisten dengan slide antar tab di atas —
    // Prep Test ada di ujung kanan bottom nav, jadi masuk dari kanan.
    if (index == 4) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PreparationTestWebviewScreen(),
          transitionDuration: navAnimDuration,
          reverseTransitionDuration: navAnimDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: navAnimCurve),
                  ),
              child: child,
            );
          },
        ),
      );
      return;
    }
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _openedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Membungkus seluruh Scaffold: sumber sampel warna untuk
    // GlassContentAwareBrightness ("Indonesia" di MainShellGlassBar) yang
    // dipakai untuk membedakan gelap/terang konten di balik bar. Hanya
    // scope-nya di sini — konten yang DISAMPEL ditandai terpisah lewat
    // GlassContentAwareContent di bawah (bar sendiri sengaja TIDAK ikut
    // dibungkus, supaya yang disampel adalah tab di baliknya, bukan bar-nya).
    return GlassContentAwareScope(
      child: Scaffold(
        // Home/Spaces/Courses/Members sekarang sama-sama melukis latar putih
        // sendiri (lihat masing-masing build() di setiap layar) yang menutup
        // SELURUH area tab-nya masing-masing — tapi warna ini masih dipakai
        // sebagai fallback: `AnimatedSlide` saat pindah tab bisa menyisakan
        // celah sepersekian detik (seam antar frame animasi) yang menampakkan
        // warna dasar Scaffold. Disamakan dengan warna latar tiap tab (bukan
        // hitam bawaan) supaya celah itu tidak terlihat mencolok.
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // WAJIB true supaya body (gradient warna-warni tiap tab) menembus
        // sampai ke belakang bottomNavigationBar. Tanpa ini, BackdropFilter
        // blur di BottomNavBar tidak punya apa pun yang berwarna untuk
        // di-blur di baris terakhirnya, sehingga tampil gelap/hitam alih-alih
        // kaca — padahal padding bawah tiap list (mis. bottom: 80/90 di
        // Courses/Members) sudah disiapkan untuk kondisi ini.
        extendBody: true,
        // TIDAK ada `appBar:` di sini — [MainShellGlassBar] (bar "TITC
        // Indonesia" versi kaca) ditaruh langsung di dalam body Stack di
        // bawah, bukan lewat slot `Scaffold.appBar`. Lihat dokumentasi di
        // `main_shell_glass_bar.dart` untuk alasannya (AppBar.flexibleSpace
        // terbukti tidak bisa di-blur meski sudah dicoba berkali-kali).
        drawer: const SideDrawer(),
        body: Stack(
          children: [
            // Konten yang DISAMPEL GlassContentAwareBrightness — bar sendiri
            // (Positioned MainShellGlassBar di bawah) sengaja di LUAR ini,
            // supaya capture-nya melihat tab di belakang bar, bukan bar itu
            // sendiri.
            GlassContentAwareContent(
              child: NotificationListener<ScrollNotification>(
                onNotification: _scrollHide.onNotification,
                child: Stack(
                  children: [
                    for (final index in _openedTabs)
                      // Slide horizontal mengikuti urutan tab di bottom nav:
                      // tab dengan index lebih kecil dari yang aktif digeser
                      // keluar ke kiri, yang lebih besar ke kanan — jadi
                      // berpindah tab terasa seperti geser antar halaman,
                      // bukan cuma fade. `AnimatedSlide` menganimasikan dari
                      // offset SEBELUMNYA, jadi tab yang baru aktif otomatis
                      // "masuk" dari arah yang benar (kiri kalau pindah ke
                      // tab dengan index lebih kecil, kanan kalau lebih
                      // besar).
                      AnimatedSlide(
                        offset: index == _currentIndex
                            ? Offset.zero
                            : Offset(index < _currentIndex ? -1.0 : 1.0, 0),
                        duration: navAnimDuration,
                        curve: navAnimCurve,
                        child: AnimatedOpacity(
                          opacity: index == _currentIndex ? 1 : 0,
                          duration: navAnimDuration,
                          curve: navAnimCurve,
                          child: IgnorePointer(
                            ignoring: index != _currentIndex,
                            child: TickerMode(
                              enabled: index == _currentIndex,
                              child: _tabs[index],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Mengisi seluruh body agar tombol bisa digeser ke mana saja.
            // Area kosongnya tidak menangkap sentuhan, jadi konten di
            // bawahnya tetap bisa ditekan. Diberi padding bawah sebesar
            // tinggi BottomNavBar + safe-area device: sejak Scaffold pakai
            // `extendBody: true` (supaya blur nav bar tembus warna), area
            // body ikut meluas sampai ke belakang nav bar — tanpa padding
            // ini FAB bisa "hilang" karena posisi bawahnya jatuh di
            // belakang nav bar.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      kBottomNavBarContentHeight +
                      MediaQuery.of(context).padding.bottom,
                ),
                child: DraggableChatFab(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MessagesListScreen(),
                      ),
                    );
                    // Badge disegarkan begitu user keluar dari Messages.
                    // Tanpa ini angkanya bertahan sampai putaran polling
                    // berikutnya (60 detik), sehingga terlihat masih ada
                    // pesan belum dibaca padahal barusan dibuka.
                    await MessagesService.refreshUnreadCount();
                  },
                ),
              ),
            ),
            // Bar "TITC Indonesia" versi kaca — child PALING ATAS supaya
            // selalu di depan konten tab & FAB. Lihat main_shell_glass_bar.dart.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MainShellGlassBar(visible: _scrollHide.visible),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          // Sedikit jarak ekstra dari tepi bawah layar supaya dock kaca
          // tidak terlalu mepet — GlassTabBar.bottom sendiri tidak
          // memperhitungkan MediaQuery, jadi tanpa ini dock nempel persis
          // di batas bawah body Scaffold.
          padding: const EdgeInsets.only(bottom: 14),
          child: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            // Sama seperti backgroundColor Scaffold di atas: gaya glass ini
            // sekarang berlaku untuk semua tab, bukan cuma Spaces.
            isSpacesTab: true,
          ),
        ),
      ),
    );
  }
}
