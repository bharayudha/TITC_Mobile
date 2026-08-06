import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/services/api_service.dart';

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
  /// Slug-nya sengaja TIDAK di-hardcode: judul di drawer ditulis manual saat
  /// slicing UI, sementara slug asli hanya diketahui server. Mencocokkan lewat
  /// daftar space yang memang sudah ditarik app membuat menu ini tetap benar
  /// kalau admin mengganti slug di WordPress.
  Future<void> _openSpaceByTitle(BuildContext context, String label) async {
    // Diambil sebelum drawer ditutup: setelah pop, `context` sudah tidak
    // mounted sehingga tidak boleh dipakai lagi.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();

    var space = _findByTitle(ApiService.cachedSpaces, label, (s) => s.title);

    if (space == null) {
      // Tab Spaces belum pernah dibuka, jadi daftarnya harus ditarik dulu.
      // Server TITC bisa lambat (lihat catatan timeout 30 detik), karena itu
      // user diberi tahu alih-alih dibiarkan menatap layar yang diam.
      messenger.showSnackBar(
        SnackBar(content: Text('Membuka $label…'), duration: const Duration(seconds: 2)),
      );
      try {
        space = _findByTitle(await ApiService.fetchSpaces(), label, (s) => s.title);
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal memuat $label. Periksa koneksi lalu coba lagi.')),
        );
        return;
      }
    }

    final resolved = space;
    if (resolved == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Space "$label" tidak ditemukan di akun ini.')),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => SpaceWebViewScreen(
          spaceSlug: resolved.slug,
          title: resolved.title,
        ),
      ),
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

  /// Buka Course berdasarkan judulnya, mengikuti alur `_onCourseAction` di
  /// `courses_list_screen.dart`: yang sudah enroll langsung ke daftar lesson,
  /// yang belum dicoba didaftarkan lebih dulu.
  Future<void> _openCourseByTitle(BuildContext context, String label) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();

    var course = _findByTitle(ApiService.cachedCourses, label, (c) => c.title);

    if (course == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Membuka $label…'), duration: const Duration(seconds: 2)),
      );
      try {
        course = _findByTitle(await ApiService.fetchCourses(), label, (c) => c.title);
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal memuat $label. Periksa koneksi lalu coba lagi.')),
        );
        return;
      }
    }

    final resolved = course;
    if (resolved == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Course "$label" tidak ditemukan di akun ini.')),
      );
      return;
    }

    if (!resolved.isEnrolled) {
      // Course TITC umumnya didaftarkan manual oleh admin setelah pembelian,
      // jadi enroll dari app sering ditolak. Pesan penolakan dari server
      // diteruskan apa adanya karena isinya lebih spesifik daripada kalimat
      // generik buatan app (lihat catatan di ApiService.enrollCourse).
      final error = await ApiService.enrollCourse(resolved.id);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      // Enroll berhasil: daftar course yang tersimpan sudah basi (masih
      // menandai course ini belum enroll), jadi dibuang agar tab Courses
      // menampilkan status terbaru saat dibuka.
      ApiService.cachedCourses = null;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => SpaceWebViewScreen(
          spaceSlug: resolved.slug,
          title: resolved.title,
          portalSegment: 'course',
          initialPath: 'lessons',
        ),
      ),
    );
  }

  /// Samakan bentuk judul sebelum dibandingkan — judul di drawer dan di API
  /// kerap beda kapital, spasi, atau tanda hubung ("TOEFL - Mockup Test"
  /// vs "TOEFL – Mockup Test").
  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Cari entri yang judulnya cocok dengan [label]. Dibuat generik karena
  /// SpaceModel dan CourseModel tidak berbagi supertype, padahal aturan
  /// pencocokannya harus persis sama untuk keduanya.
  T? _findByTitle<T>(List<T>? items, String label, String Function(T) titleOf) {
    if (items == null || items.isEmpty) return null;
    final target = _normalizeTitle(label);

    for (final item in items) {
      if (_normalizeTitle(titleOf(item)) == target) return item;
    }

    // Judul di web kadang punya imbuhan yang tidak ikut ditulis di drawer
    // (mis. "FREE Placement Test 2025"), jadi dicoba sekali lagi dengan
    // pencocokan sebagian sebelum menyerah.
    //
    // Hasilnya baru dipakai kalau cuma ada SATU kandidat. Beberapa course
    // bernama sangat mirip ("3/7/10/15/20 Meeting Courses"), dan membuka
    // course yang salah jauh lebih membingungkan bagi user daripada jujur
    // bilang tidak ketemu.
    final partial = <T>[];
    for (final item in items) {
      final title = _normalizeTitle(titleOf(item));
      if (title.isEmpty) continue;
      if (title.contains(target) || target.contains(title)) partial.add(item);
    }
    return partial.length == 1 ? partial.first : null;
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
