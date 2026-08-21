import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/screens/auth/login_screen.dart';
import 'package:magang_titc/screens/customer/profile/profile_screen.dart';
import 'package:magang_titc/screens/main_shell.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/theme_service.dart';

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
        if (avatarUrl == null || avatarUrl.isEmpty) return _fallback(context);

        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            // Sama seperti pemuatan gambar lain di app: sebagian media ada di
            // balik privacy WordPress, jadi cookie sesi harus ikut terkirim.
            httpHeaders: AuthService.imageAuthHeaders,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            memCacheWidth: 84,
            memCacheHeight: 84,
            placeholder: (_, _) => _initialCircle(context),
            errorWidget: (_, _, _) => _fallback(context),
          ),
        );
      },
    );
  }

  /// Inisial nama di atas lingkaran abu — dipakai saat foto masih dimuat.
  Widget _initialCircle(BuildContext context) {
    final name = AuthService.userName ?? '';
    if (name.isEmpty) return _fallback(context);

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

  Widget _fallback(BuildContext context) => PhosphorIcon(
    PhosphorIconsRegular.userCircle,
    color: Theme.of(context).colorScheme.onSurface,
    size: _size,
  );
}

/// Pilihan pada popup profil.
enum ProfileMenuAction {
  viewProfile,
  myCourses,
  mySpaces,
  certificate,
  darkMode,
  logout,
}

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
    if (action == ProfileMenuAction.myCourses) {
      MainShell.openTab(context, MainShell.tabCourses);
      return;
    }
    if (action == ProfileMenuAction.mySpaces) {
      MainShell.openTab(context, MainShell.tabSpaces);
      return;
    }
    if (action == ProfileMenuAction.certificate) {
      // Halaman WordPress biasa, bukan portal FCOM — jadi memakai WebView
      // umum yang membersihkan header/footer tema WP, bukan
      // SpaceWebViewScreen yang CSS-nya khusus shell Vue portal.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthenticatedWebViewScreen(
            url: 'https://titc.or.id/certificate-verification/',
            title: 'Certificate',
          ),
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
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProfileMenuAction>(
      icon: const _ProfileAvatarIcon(),
      tooltip: 'Profil',
      // Transparan: latar sungguhan digambar oleh Container di dalam
      // ValueListenableBuilder di bawah, supaya BISA ikut berubah reaktif
      // saat dark mode ditoggle sementara popup masih terbuka. Popup route
      // dari `showMenu` hanya dibangun SEKALI saat dibuka — `color:` di sini
      // (kalau memakai Theme.of(context) seperti sebelumnya) akan membeku
      // pada warna saat itu dan tidak ikut berganti lagi setelahnya.
      color: Colors.transparent,
      elevation: 8,
      padding: EdgeInsets.zero,
      // Digeser ke bawah agar popup muncul di bawah app bar, bukan menimpanya.
      offset: const Offset(0, kToolbarHeight - 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        PopupMenuItem<ProfileMenuAction>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _buildMenuContent(context),
        ),
      ],
    );
  }

  /// Seluruh isi popup (identitas, item menu, toggle dark mode) dibungkus
  /// SATU `ValueListenableBuilder` di sini — bukan disebar satu per item
  /// seperti sebelumnya — supaya latar DAN semua warna teks/ikon ikut
  /// berganti bersamaan begitu dark mode ditoggle, bukan cuma baris
  /// togglenya sendiri sementara sisanya (My Courses, My Spaces, dst) tetap
  /// beku di warna lama karena warnanya sudah kadung "dibekukan" saat popup
  /// pertama kali dibuka.
  Widget _buildMenuContent(BuildContext outerContext) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        final scheme = Theme.of(context).colorScheme;
        final isDark = mode == ThemeMode.dark;

        void select(ProfileMenuAction action) {
          Navigator.of(context).pop();
          _onSelected(outerContext, action);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: scheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => select(ProfileMenuAction.viewProfile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _buildAccountHeader(context, scheme),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                _buildRow(
                  scheme: scheme,
                  emoji: '📘',
                  label: 'My Courses',
                  onTap: () => select(ProfileMenuAction.myCourses),
                ),
                _buildRow(
                  scheme: scheme,
                  emoji: '🔔',
                  label: 'My Spaces',
                  onTap: () => select(ProfileMenuAction.mySpaces),
                ),
                _buildRow(
                  scheme: scheme,
                  emoji: '🎖️',
                  label: 'Certificate',
                  onTap: () => select(ProfileMenuAction.certificate),
                ),
                _buildDarkModeRow(scheme: scheme, isDark: isDark),
                _buildRow(
                  scheme: scheme,
                  icon: PhosphorIconsBold.power,
                  iconColor: _dangerColor,
                  label: 'Log Out',
                  onTap: () => select(ProfileMenuAction.logout),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountHeader(BuildContext context, ColorScheme scheme) {
    final name = AuthService.userName ?? 'User';
    final email = AuthService.userEmail ?? '';
    final avatarUrl = AuthService.userAvatarUrl;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final onSurface = scheme.onSurface;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(
                  avatarUrl,
                  headers: AuthService.imageAuthHeaders,
                  maxWidth: 96,
                  maxHeight: 96,
                )
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Baris menu generik (My Courses/My Spaces/Certificate/Log Out). Diberi
  /// `GestureDetector` + `InkWell` sendiri (bukan `PopupMenuItem` terpisah
  /// lagi) karena semuanya sekarang hidup di dalam SATU item popup yang
  /// sama — lihat `_buildMenuContent`.
  Widget _buildRow({
    required ColorScheme scheme,
    required String label,
    required VoidCallback onTap,
    String? emoji,
    IconData? icon,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Lebar ikon/emoji berbeda antar perangkat, dikunci agar teks
              // sejajar.
              SizedBox(
                width: 28,
                child: icon != null
                    ? PhosphorIcon(icon, color: iconColor, size: 18)
                    : Text(emoji ?? '', style: emojiStyle(size: 16)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: iconColor ?? scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Baris toggle Dark Mode. Tidak memanggil `select()` — menekannya HANYA
  /// mengganti tema, popup sengaja TIDAK ditutup, supaya user langsung
  /// lihat seluruh menu ikut berganti warna sambil popup masih terbuka.
  Widget _buildDarkModeRow({
    required ColorScheme scheme,
    required bool isDark,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ThemeService.setDarkMode(!isDark),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(isDark ? '🌙' : '☀️', style: emojiStyle(size: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.75,
                // `IgnorePointer` supaya Switch tidak ikut menerima tap
                // (sudah ditangani GestureDetector di atas) — tapi
                // `onChanged` tetap diisi (no-op) supaya warnanya tetap
                // vivid seperti switch aktif, bukan pudar seperti switch
                // disabled (`onChanged: null` membuatnya terlihat mati).
                child: IgnorePointer(
                  child: Switch(value: isDark, onChanged: (_) {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
