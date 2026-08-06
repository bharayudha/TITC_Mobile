import 'package:flutter/material.dart';

import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/services/api_service.dart';

/// Membuka halaman Space/Course di portal berdasarkan JUDUL-nya.
///
/// Slug sengaja tidak di-hardcode di sisi app: judul ditulis manual saat
/// slicing UI (drawer, shortcut Home), sementara slug asli hanya diketahui
/// server. Dengan mencocokkan lewat daftar yang memang sudah ditarik app,
/// menu tetap benar kalau admin mengganti slug di WordPress.
///
/// Memakai [NavigatorState] dan [ScaffoldMessengerState], bukan
/// [BuildContext]: pemanggil seperti drawer harus menutup dirinya sendiri
/// lebih dulu, dan setelah itu context-nya sudah tidak mounted.
class PortalNavigator {
  const PortalNavigator._();

  static Future<void> openSpaceByTitle({
    required NavigatorState navigator,
    required ScaffoldMessengerState messenger,
    required String title,
  }) async {
    var space = _findByTitle(ApiService.cachedSpaces, title, (s) => s.title);

    if (space == null) {
      // Tab Spaces belum pernah dibuka, jadi daftarnya harus ditarik dulu.
      // Server TITC bisa lambat (toleransi 30 detik), karena itu user diberi
      // tahu alih-alih dibiarkan menatap layar yang diam.
      _notify(messenger, 'Membuka $title…');
      try {
        space = _findByTitle(
          await ApiService.fetchSpaces(),
          title,
          (s) => s.title,
        );
      } catch (_) {
        _notify(messenger, 'Gagal memuat $title. Periksa koneksi lalu coba lagi.');
        return;
      }
    }

    final resolved = space;
    if (resolved == null) {
      _notify(messenger, 'Space "$title" tidak ditemukan di akun ini.');
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

  /// Mengikuti alur `_onCourseAction` di `courses_list_screen.dart`: yang
  /// sudah enroll langsung ke daftar lesson, yang belum dicoba didaftarkan
  /// lebih dulu.
  static Future<void> openCourseByTitle({
    required NavigatorState navigator,
    required ScaffoldMessengerState messenger,
    required String title,
  }) async {
    var course = _findByTitle(ApiService.cachedCourses, title, (c) => c.title);

    if (course == null) {
      _notify(messenger, 'Membuka $title…');
      try {
        course = _findByTitle(
          await ApiService.fetchCourses(),
          title,
          (c) => c.title,
        );
      } catch (_) {
        _notify(messenger, 'Gagal memuat $title. Periksa koneksi lalu coba lagi.');
        return;
      }
    }

    final resolved = course;
    if (resolved == null) {
      _notify(messenger, 'Course "$title" tidak ditemukan di akun ini.');
      return;
    }

    if (!resolved.isEnrolled) {
      // Course TITC umumnya didaftarkan manual oleh admin setelah pembelian,
      // jadi enroll dari app sering ditolak. Pesan penolakan dari server
      // diteruskan apa adanya karena isinya lebih spesifik daripada kalimat
      // generik buatan app (lihat catatan di ApiService.enrollCourse).
      final error = await ApiService.enrollCourse(resolved.id);
      if (error != null) {
        _notify(messenger, error);
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

  static void _notify(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// Samakan bentuk judul sebelum dibandingkan — judul di app dan di API
  /// kerap beda kapital, spasi, atau tanda hubung ("TOEFL - Mockup Test"
  /// vs "TOEFL – Mockup Test").
  static String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Cari entri yang judulnya cocok dengan [label]. Dibuat generik karena
  /// SpaceModel dan CourseModel tidak berbagi supertype, padahal aturan
  /// pencocokannya harus persis sama untuk keduanya.
  static T? _findByTitle<T>(
    List<T>? items,
    String label,
    String Function(T) titleOf,
  ) {
    if (items == null || items.isEmpty) return null;
    final target = _normalizeTitle(label);

    for (final item in items) {
      if (_normalizeTitle(titleOf(item)) == target) return item;
    }

    // Judul di web kadang punya imbuhan yang tidak ikut ditulis di app
    // (mis. "FREE Placement Test 2025"), jadi dicoba sekali lagi dengan
    // pencocokan sebagian sebelum menyerah.
    //
    // Hasilnya baru dipakai kalau cuma ada SATU kandidat. Beberapa course
    // bernama sangat mirip ("3/7/10/15/20 Meeting Courses"), dan membuka
    // yang salah jauh lebih membingungkan bagi user daripada jujur bilang
    // tidak ketemu.
    final partial = <T>[];
    for (final item in items) {
      final title = _normalizeTitle(titleOf(item));
      if (title.isEmpty) continue;
      if (title.contains(target) || target.contains(title)) partial.add(item);
    }
    return partial.length == 1 ? partial.first : null;
  }
}
