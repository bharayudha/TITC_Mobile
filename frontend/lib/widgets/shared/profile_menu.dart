import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/screens/auth/login_screen.dart';
import 'package:magang_titc/screens/customer/profile/profile_screen.dart';
import 'package:magang_titc/services/auth_service.dart';

const Color _dangerColor = Color(0xFFE53935);

/// Pilihan pada popup profil.
enum ProfileMenuAction { viewProfile, myCourses, mySpaces, certificate, logout }

/// Tombol profil di app bar. Saat ditekan menampilkan popup berisi identitas
/// pengguna dan pintasan menu.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key});

  void _onSelected(BuildContext context, ProfileMenuAction action) {
    if (action == ProfileMenuAction.viewProfile) {
      final name = AuthService.userName ?? 'User';
      final username = AuthService.userName ?? 'user';
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(name: name, username: username),
        ),
      );
      return;
    }
    if (action == ProfileMenuAction.logout) {
      AuthService.logout().then((_) {
        // Bersihkan seluruh riwayat halaman supaya tidak bisa di-back
        // kembali ke area yang butuh login.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }
    // TODO: sambungkan aksi lain ke halaman masing-masing.
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProfileMenuAction>(
      icon: const PhosphorIcon(
        PhosphorIconsRegular.userCircle,
        color: Colors.black87,
      ),
      tooltip: 'Profil',
      color: Colors.white,
      elevation: 8,
      // Digeser ke bawah agar popup muncul di bawah app bar, bukan menimpanya.
      offset: const Offset(0, kToolbarHeight - 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (context) => [
        PopupMenuItem<ProfileMenuAction>(
          // Mengetuk identitas membuka halaman profil.
          value: ProfileMenuAction.viewProfile,
          height: 64,
          child: _buildAccountHeader(),
        ),
        const PopupMenuDivider(),
        _buildItem(
          value: ProfileMenuAction.myCourses,
          emoji: '📘',
          label: 'My Courses',
        ),
        _buildItem(
          value: ProfileMenuAction.mySpaces,
          emoji: '🔔',
          label: 'My Spaces',
        ),
        _buildItem(
          value: ProfileMenuAction.certificate,
          emoji: '🎖️',
          label: 'Certificate',
        ),
        PopupMenuItem<ProfileMenuAction>(
          value: ProfileMenuAction.logout,
          height: 44,
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                child: PhosphorIcon(
                  PhosphorIconsBold.power,
                  color: _dangerColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountHeader() {
    final name = AuthService.userName ?? 'User';
    final email = AuthService.userEmail ?? '';
    final avatarUrl = AuthService.userAvatarUrl;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<ProfileMenuAction> _buildItem({
    required ProfileMenuAction value,
    required String emoji,
    required String label,
  }) {
    return PopupMenuItem<ProfileMenuAction>(
      value: value,
      height: 44,
      child: Row(
        children: [
          // Lebar emoji berbeda antar perangkat, dikunci agar teks sejajar.
          SizedBox(
            width: 28,
            child: Text(emoji, style: emojiStyle(size: 16)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
