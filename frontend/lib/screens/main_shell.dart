import 'package:flutter/material.dart';

import 'courses/courses_list_screen.dart';
import 'home/home_screen.dart';
import 'members/members_list_screen.dart';
import 'messages/messages_list_screen.dart';
import 'preparation_test/preparation_test_webview_screen.dart';
import 'spaces/spaces_list_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/chat_fab_button.dart';
import '../widgets/side_drawer.dart';
import '../widgets/top_app_bar.dart';

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
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: Stack(
        children: [
          AnimatedSwitcher(
            // Selaras dengan prototype Figma: 400ms, easing Slow.
            duration: navAnimDuration,
            switchInCurve: navAnimCurve,
            switchOutCurve: navAnimCurve,
            // Cross-fade murni: konten tidak bergeser naik/turun.
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: _tabs[_currentIndex],
            ),
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
