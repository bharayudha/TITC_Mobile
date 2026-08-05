import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/screens/auth/login_screen.dart';
import 'package:magang_titc/screens/customer/profile/profile_screen.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';

const Color _dangerColor = Color(0xFFE53935);

/// Foto profil user sebagai ikon tombol di app bar — mengikuti tampilan web,
/// bukan ikon orang generik. Kalau user belum punya foto (atau URL-nya gagal
/// dimuat), jatuh kembali ke inisial nama, lalu ke ikon default.
class _ProfileAvatarIcon extends StatelessWidget {
  const _ProfileAvatarIcon();

  /// Sedikit lebih kecil dari ikon app bar lain (24) supaya lingkaran foto
  /// tidak terlihat lebih "berat" dari ikon search & bell di sebelahnya.
  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AuthService.avatarUrlNotifier,
      builder: (context, avatarUrl, _) {
        if (avatarUrl == null || avatarUrl.isEmpty) return _fallback();

        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            // Sama seperti pemuatan gambar lain di app: sebagian media ada di
            // balik privacy WordPress, jadi cookie sesi harus ikut terkirim.
            httpHeaders: AuthService.imageAuthHeaders,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            placeholder: (_, _) => _initialCircle(),
            errorWidget: (_, _, _) => _fallback(),
          ),
        );
      },
    );
  }

  /// Inisial nama di atas lingkaran abu — dipakai saat foto masih dimuat.
  Widget _initialCircle() {
    final name = AuthService.userName ?? '';
    if (name.isEmpty) return _fallback();

    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _fallback() => const PhosphorIcon(
    PhosphorIconsRegular.userCircle,
    color: Colors.black87,
    size: _size,
  );
}

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
      ApiService.clearCache();
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
      icon: const _ProfileAvatarIcon(),
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
              ? CachedNetworkImageProvider(avatarUrl, headers: AuthService.imageAuthHeaders)
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
