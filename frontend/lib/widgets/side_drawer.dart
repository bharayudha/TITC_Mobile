import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

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
                  _buildItem(emoji: '🔥', label: 'FREE Placement Test'),
                  _buildItem(emoji: '🖥️', label: 'Institutional Prep Test'),
                  _buildItem(emoji: '💻', label: 'TOEFL - Mockup Test'),
                  _buildItem(emoji: '🔖', label: 'Promo Khusus Member'),
                  _buildItem(emoji: '📰', label: 'Update - Announcement'),
                  _buildItem(emoji: '🚀', label: 'Update - Certification'),
                  const AppDivider(),
                  _buildSectionLabel('TOEFL Preparation'),
                  _buildItem(emoji: '🎓', label: '4 Hours Intensive'),
                  _buildItem(emoji: '🎓', label: '3 Meeting Courses'),
                  _buildItem(emoji: '🎓', label: '7 Meeting Courses'),
                  const AppDivider(),
                  _buildSectionLabel('English for Specific Purposes'),
                  _buildItem(emoji: '📚', label: 'Structure and Grammar'),
                  _buildItem(emoji: '🎧', label: 'Listening and Reading'),
                  _buildItem(emoji: '🎙️', label: 'Speaking and Conversation'),
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
  }) {
    return _buildTile(
      // Lebar emoji berbeda-beda antar perangkat, jadi dikunci dalam kotak
      // selebar 24 supaya teks menunya tetap sejajar.
      leading: Center(
        child: Text(emoji, style: emojiStyle()),
      ),
      label: label,
      labelColor: labelColor,
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
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: SizedBox(width: 24, child: leading),
      title: Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
      onTap: () {},
    );
  }
}
