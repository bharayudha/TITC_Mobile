import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

const List<String> _notificationTabs = [
  'Recent',
  'Unread',
  'Mentions',
  'Following',
];

/// Menampilkan popup notifikasi yang menempel di bawah app bar, sejajar
/// dengan ikon lonceng di kanan atas.
Future<void> showNotificationsPopup(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup notifikasi',
    barrierColor: Colors.black12,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const NotificationsPopup();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          // Muncul dari arah app bar, bukan mengambang begitu saja.
          position: Tween<Offset>(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Panel daftar notifikasi.
class NotificationsPopup extends StatefulWidget {
  const NotificationsPopup({super.key});

  @override
  State<NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<NotificationsPopup> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    // Dibatasi lebarnya agar tetap rapi di layar lebar, tetapi menyusut
    // mengikuti layar sempit.
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width - 24 < 360 ? width - 24 : 360.0;

    return Align(
      alignment: Alignment.topRight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight - 8, right: 8),
          child: Material(
            color: Colors.white,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: panelWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildTabs(),
                  _buildBody(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Recent Notifications',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          _buildOutlinedAction(
            label: 'Mark all as read',
            // TODO: tandai semua notifikasi terbaca lewat service.
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: kDividerThickness,
          ),
        ),
      ),
      // Digulir mendatar supaya semua tab tetap terjangkau di layar sempit.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(_notificationTabs.length, (index) {
            final selected = index == _selectedTab;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _notificationTabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : Colors.black87,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // TODO: tampilkan daftar notifikasi dari service sesuai tab terpilih.
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Text(
        'No notifications found',
        style: TextStyle(fontSize: 14, color: Colors.black54),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildOutlinedAction(
          label: 'View All',
          // TODO: buka halaman daftar notifikasi lengkap.
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildOutlinedAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }
}
