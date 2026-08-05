import 'package:webview_flutter/webview_flutter.dart';
import 'auth_service.dart';

/// Helper terpusat untuk menyetel cookie WordPress ke cookie jar WebView.
///
/// Dipakai oleh [SpaceWebViewScreen] dan [AuthenticatedWebViewScreen] agar
/// logika cookie setup tidak diduplikasi (DRY). Cookie yang di-set:
///
///  1. Semua cookie sesi WordPress (wordpress_sec_*, wordpress_logged_in_*, dll)
///     yang tersimpan di [AuthService.cookies].
///  2. Cookie `wordpress_test_cookie` — WordPress memerlukan ini untuk
///     memverifikasi bahwa browser mendukung cookie.
///  3. Cookie `_lscache_vary` — LiteSpeed Cache menggunakan ini untuk
///     membedakan respons untuk user logged-in vs tamu. Tanpa cookie ini,
///     server bisa menyajikan versi cache halaman untuk tamu meskipun cookie
///     auth sebenarnya valid.
///
/// Setiap cookie di-set ke DUA domain:
///  - `titc.or.id` (host-only)
///  - `.titc.or.id` (dengan dot prefix, mencakup subdomain)
///
/// WordPress bisa menyetel cookie ke salah satu bentuk, dan perilaku
/// pencocokan domain di WebView Android berbeda-beda antar versi. Dengan
/// menyetel ke kedua domain, kita memastikan cookie terkirim apa pun.
///
/// Nilai cookie di-decode dulu lewat [AuthService.decodeCookieValue] karena
/// `WebViewCookie` meng-encode ulang nilainya; tanpa decode, `%7C` berubah
/// jadi `%257C` dan WordPress gagal membaca cookie login.
class WebViewCookieHelper {
  static const String _domain = 'titc.or.id';
  static const String _dotDomain = '.titc.or.id';

  /// Set semua cookie sesi WordPress ke WebView cookie jar.
  ///
  /// Mengembalikan `true` jika ada cookie yang di-set, `false` jika tidak ada
  /// cookie (user belum login).
  static Future<bool> setupCookies() async {
    final cookieManager = WebViewCookieManager();
    final cookiesString = AuthService.cookies;

    if (cookiesString == null || cookiesString.isEmpty) {
      return false;
    }

    // 1. Set semua cookie sesi dari AuthService
    for (final part in cookiesString.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length >= 2) {
        final name = kv[0].trim();
        final value = kv.sublist(1).join('=');
        final decoded = AuthService.decodeCookieValue(value);

        // Set ke kedua domain untuk memastikan cookie terkirim
        await cookieManager.setCookie(
          WebViewCookie(name: name, value: decoded, domain: _domain, path: '/'),
        );
        await cookieManager.setCookie(
          WebViewCookie(
            name: name,
            value: decoded,
            domain: _dotDomain,
            path: '/',
          ),
        );
      }
    }

    // 2. Pastikan wordpress_test_cookie ada (WordPress memeriksanya)
    if (!cookiesString.contains('wordpress_test_cookie')) {
      for (final d in [_domain, _dotDomain]) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: 'wordpress_test_cookie',
            value: 'WP Cookie check',
            domain: d,
            path: '/',
          ),
        );
      }
    }

    // 3. Pastikan _lscache_vary ada (LiteSpeed Cache memerlukannya).
    //    Nilainya berupa hash yang di-set oleh LiteSpeed saat login. Kita
    //    ambil dari cookie sesi jika ada; kalau tidak ada, generate hash
    //    sederhana dari cookie logged_in supaya LiteSpeed tahu user ini
    //    bukan tamu.
    if (!cookiesString.contains('_lscache_vary')) {
      // Cari hash dari cookie logged_in sebagai vary value
      String varyValue = _generateLscacheVary(cookiesString);
      for (final d in [_domain, _dotDomain]) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: '_lscache_vary',
            value: varyValue,
            domain: d,
            path: '/',
          ),
        );
      }
    }

    return true;
  }

  /// Generate nilai `_lscache_vary` dari cookie string.
  ///
  /// LiteSpeed Cache di sisi server meng-hash beberapa variabel (termasuk
  /// cookie login) untuk membuat vary key. Kita tidak bisa meniru hash yang
  /// persis sama karena algoritmanya internal, tapi cukup menyetel SEBUAH
  /// nilai non-kosong agar LiteSpeed tahu bahwa user ini punya sesi aktif
  /// dan tidak boleh disajikan halaman cache tamu.
  ///
  /// Yang paling akurat: ambil langsung dari cookie string jika sudah ada
  /// (karena server menyetelnya saat login via HTTP header response yang
  /// kita simpan di AuthService).
  static String _generateLscacheVary(String cookies) {
    // Coba cari nilai yang sudah ada di cookie string
    final match = RegExp(r'_lscache_vary=([^;]+)').firstMatch(cookies);
    if (match != null) {
      return AuthService.decodeCookieValue(match.group(1)!);
    }

    // Fallback: gunakan hash sederhana dari cookie logged_in
    final loggedInMatch =
        RegExp(r'wordpress_logged_in_[^=]+=([^;]+)').firstMatch(cookies);
    if (loggedInMatch != null) {
      // Buat hash sederhana 32-char hex dari cookie value
      final value = loggedInMatch.group(1)!;
      var hash = 0x811c9dc5; // FNV-1a offset basis
      for (var i = 0; i < value.length; i++) {
        hash ^= value.codeUnitAt(i);
        hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime
      }
      return hash.toRadixString(16).padLeft(8, '0');
    }

    // Fallback terakhir
    return 'mobile_session';
  }
}
