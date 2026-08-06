import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/services/portal_navigator.dart';

const Color _dangerColor = Color(0xFFE53935);

/// Versi drawer dengan ikon emoji: tampilannya mengikuti font emoji bawaan
/// perangkat (Noto di Android, Apple Color Emoji di iOS).
class SideDrawer extends StatelessWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const AppDivider(),
            // Daftar menu mengisi ruang tersisa dan bisa di-scroll sendiri,
            // sehingga Settings & Logout tetap menempel di bawah.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSectionLabel('MEMBERSHIP AREAS'),
                  _buildSpaceItem(context, '🔥', 'FREE Placement Test'),
                  _buildSpaceItem(context, '🖥️', 'Institutional Prep Test'),
                  _buildSpaceItem(context, '💻', 'TOEFL - Mockup Test'),
                  _buildSpaceItem(context, '🔖', 'Promo Khusus Member'),
                  _buildSpaceItem(context, '📰', 'Update - Announcement'),
                  _buildSpaceItem(context, '🚀', 'Update - Certification'),
                  const AppDivider(),
                  _buildSectionLabel('TOEFL Preparation'),
                  _buildCourseItem(context, '🎓', '4 Hours Intensive'),
                  _buildCourseItem(context, '🎓', '3 Meeting Courses'),
                  _buildCourseItem(context, '🎓', '7 Meeting Courses'),
                  _buildCourseItem(context, '🎓', '10 Meeting Courses'),
                  _buildCourseItem(context, '🎓', '15 Meeting Courses'),
                  _buildCourseItem(context, '🎓', '20 Meeting Courses'),
                  const AppDivider(),
                  _buildSectionLabel('English for Specific Purposes'),
                  _buildCourseItem(context, '📚', 'Structure and Grammar'),
                  _buildCourseItem(context, '🎧', 'Listening and Reading'),
                  _buildCourseItem(context, '🎙️', 'Speaking and Conversation'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const AppDivider(),
            // Settings & Logout pakai ikon vektor: keduanya aksi sistem,
            // bukan item konten, dan warnanya perlu bisa diatur.
            const SizedBox(height: 4),
            _buildIconItem(
              icon: PhosphorIconsRegular.gear,
              label: 'Settings',
            ),
            _buildIconItem(
              icon: PhosphorIconsRegular.signOut,
              label: 'Logout',
              color: _dangerColor,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: 'TITC ',
                  style: TextStyle(color: AppColors.primary),
                ),
                TextSpan(
                  text: 'Indonesia',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          // Tombol tutup tetap ikon vektor: ini kontrol UI, bukan item menu.
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.x,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Item MEMBERSHIP AREAS. Tiap label di sini adalah judul Space di Fluent
  /// Community, jadi tap-nya membuka halaman space yang sama seperti di web.
  Widget _buildSpaceItem(BuildContext context, String emoji, String label) {
    return _buildItem(
      emoji: emoji,
      label: label,
      onTap: () => _openSpaceByTitle(context, label),
    );
  }

  /// Buka Space berdasarkan judulnya.
  ///
  /// Drawer ditutup lebih dulu, jadi `navigator` & `messenger` diambil
  /// sebelum pop — setelah itu `context` sudah tidak mounted.
  Future<void> _openSpaceByTitle(BuildContext context, String label) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    await PortalNavigator.openSpaceByTitle(
      navigator: navigator,
      messenger: messenger,
      title: label,
    );
  }

  /// Item TOEFL Preparation & English for Specific Purposes. Label di sini
  /// adalah judul Course di Fluent Community — secara teknis Space dengan
  /// `type: "course"`, tapi punya gerbang enrollment sendiri.
  Widget _buildCourseItem(BuildContext context, String emoji, String label) {
    return _buildItem(
      emoji: emoji,
      label: label,
      onTap: () => _openCourseByTitle(context, label),
    );
  }

  Future<void> _openCourseByTitle(BuildContext context, String label) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    await PortalNavigator.openCourseByTitle(
      navigator: navigator,
      messenger: messenger,
      title: label,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildItem({
    required String emoji,
    required String label,
    Color labelColor = Colors.black87,
    VoidCallback? onTap,
  }) {
    return _buildTile(
      // Lebar emoji berbeda-beda antar perangkat, jadi dikunci dalam kotak
      // selebar 24 supaya teks menunya tetap sejajar.
      leading: Center(
        child: Text(emoji, style: emojiStyle()),
      ),
      label: label,
      labelColor: labelColor,
      onTap: onTap,
    );
  }

  Widget _buildIconItem({
    required IconData icon,
    required String label,
    Color color = Colors.black87,
  }) {
    return _buildTile(
      leading: Center(child: PhosphorIcon(icon, color: color, size: 20)),
      label: label,
      labelColor: color,
    );
  }

  Widget _buildTile({
    required Widget leading,
    required String label,
    required Color labelColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: SizedBox(width: 24, child: leading),
      title: Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
      // Menu yang belum tersambung sengaja dibiarkan tanpa handler supaya
      // tidak memberi efek ripple seolah-olah ada yang terjadi saat ditekan.
      onTap: onTap,
    );
  }
}
