import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../main_shell.dart';
import '../../constants/app_colors.dart';
import '../preparation_test/preparation_test_webview_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/side_drawer.dart';
import '../../widgets/top_app_bar.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreparationTestWebviewScreen()),
      );
      return;
    }
    // Kembali ke shell utama pada tab yang dipilih, tanpa menumpuk halaman.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainShell(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Blok header + search dipisahkan dari daftar lewat drop shadow.
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: kShadowDown,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMessagesHeader(),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionLabel('COMMUNITIES'),
            const SizedBox(height: 12),
            _buildPlaceholderBox(height: 420),
            const SizedBox(height: 24),
            _buildSectionLabel('DIRECT MESSAGES'),
            const SizedBox(height: 12),
            _buildPlaceholderBox(height: 200),
            const SizedBox(height: 16),
            _buildPlaceholderBox(height: 180),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: -1,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildMessagesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'MESSAGES',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.paperPlaneTilt,
                  color: Colors.black87,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.dotsThreeVertical,
                  color: Colors.black87,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search conversations',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            color: Colors.grey,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E5AF5)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPlaceholderBox({required double height}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
