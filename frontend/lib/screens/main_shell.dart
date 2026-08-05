import 'package:flutter/material.dart';

import 'package:magang_titc/screens/customer/courses/courses_list_screen.dart';
import 'package:magang_titc/screens/customer/home/home_screen.dart';
import 'package:magang_titc/screens/customer/members/members_list_screen.dart';
import 'package:magang_titc/screens/customer/messages/messages_list_screen.dart';
import 'package:magang_titc/screens/customer/preparation_test/preparation_test_webview_screen.dart';
import 'package:magang_titc/screens/customer/spaces/spaces_list_screen.dart';
import 'package:magang_titc/widgets/customer/customer_bottom_nav_bar.dart';
import 'package:magang_titc/widgets/shared/chat_fab_button.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';

/// Kerangka utama aplikasi: app bar, drawer, chat FAB, dan bottom nav dipasang
/// sekali di sini supaya perpindahan tab hanya menganimasikan isi kontennya.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

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
      backgroundColor: Colors.white,
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MessagesListScreen()),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
