import 'package:flutter/material.dart';

import 'package:magang_titc/screens/customer/courses/courses_list_screen.dart';
import 'package:magang_titc/screens/customer/home/home_screen.dart';
import 'package:magang_titc/screens/customer/members/members_list_screen.dart';
import 'package:magang_titc/screens/customer/messages/messages_list_screen.dart';
import 'package:magang_titc/screens/customer/preparation_test/preparation_test_webview_screen.dart';
import 'package:magang_titc/screens/customer/spaces/spaces_list_screen.dart';
import 'package:magang_titc/services/messages_service.dart';
import 'package:magang_titc/widgets/customer/customer_bottom_nav_bar.dart';
import 'package:magang_titc/widgets/shared/chat_fab_button.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';

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
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreparationTestWebviewScreen()),
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
    return Scaffold(
      extendBody: _currentIndex == MainShell.tabSpaces,
      backgroundColor: _currentIndex == MainShell.tabSpaces
          ? const Color(0xFFCDE6F7)
          : Colors.white,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: Stack(
        children: [
          Stack(
            children: [
              for (final index in _openedTabs)
                AnimatedOpacity(
                  // Selaras dengan prototype Figma: 300ms, easing Slow.
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
            ],
          ),
          // Mengisi seluruh body agar tombol bisa digeser ke mana saja.
          // Area kosongnya tidak menangkap sentuhan, jadi konten di
          // bawahnya tetap bisa ditekan.
          Positioned.fill(
            child: DraggableChatFab(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MessagesListScreen()),
                );
                // Badge disegarkan begitu user keluar dari Messages. Tanpa
                // ini angkanya bertahan sampai putaran polling berikutnya
                // (60 detik), sehingga terlihat masih ada pesan belum dibaca
                // padahal barusan dibuka.
                await MessagesService.refreshUnreadCount();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        isSpacesTab: _currentIndex == MainShell.tabSpaces,
      ),
    );
  }
}
