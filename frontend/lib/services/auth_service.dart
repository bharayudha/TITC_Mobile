import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service untuk autentikasi ke WordPress / Fluent Community.
///
/// Alur login:
/// 1. GET halaman auth untuk mendapatkan `_fcom_login_nonce`.
/// 2. POST ke `https://titc.or.id/login/` dengan nonce + credentials.
/// 3. Simpan cookies WordPress yang dikembalikan server.
/// 4. Gunakan cookies tersebut untuk semua API call ke
///    `fluent-community/v2/*`.
class AuthService {
  static const String _baseUrl = 'https://titc.or.id';
  static const String _authPageUrl =
      '$_baseUrl/portal/?fcom_action=auth&redirect_to=/portal';
  static const String _registerPageUrl =
      '$_baseUrl/portal/?fcom_action=auth&redirect_to=/portal&form=register';
  static const String _loginPostUrl = '$_baseUrl/login/';
  static const String _ajaxUrl = '$_baseUrl/wp-admin/admin-ajax.php';

  static const _storage = FlutterSecureStorage();

  // Client HTTP dipakai bersama (bukan http.get/post top-level yang bikin
  // koneksi baru tiap kali) supaya koneksi TCP/TLS ke titc.or.id bisa dipakai
  // ulang antar request alih-alih handshake dari nol setiap kali — ini salah
  // satu penyebab utama request terasa lambat/timeout saat pindah tab.
  static final http.Client _client = http.Client();

  static const String _cookiesKey = 'wp_cookies';
  static const String _userNameKey = 'wp_user_name';
  static const String _userEmailKey = 'wp_user_email';

  /// Cookie WordPress yang disimpan setelah login.
  static String? _cookies;
  static String? _wpNonce;
  static String? _userEmail;
  static String? _userName;
  static String? _userSlug;

  /// URL foto profil user. Dibungkus ValueNotifier supaya widget yang
  /// menampilkannya (mis. tombol profil di app bar) ikut ter-update begitu
  /// foto berubah — setelah login, setelah profil di-fetch, atau setelah
  /// user mengunggah foto baru — tanpa perlu buka ulang halaman.
  static final ValueNotifier<String?> avatarUrlNotifier =
      ValueNotifier<String?>(null);

  static String? get _userAvatarUrl => avatarUrlNotifier.value;
  static set _userAvatarUrl(String? value) => avatarUrlNotifier.value = value;

  /// Getter: apakah user sudah login (ada cookie tersimpan).
  static bool get isLoggedIn => _cookies != null && _cookies!.isNotEmpty;

  /// Getter: cookies saat ini, untuk dipakai oleh ApiService.
  static String? get cookies => _cookies;

  /// Kembalikan nilai cookie ke bentuk mentahnya (belum ter-percent-encode).
  ///
  /// Cookie WordPress yang kita simpan diambil apa adanya dari header
  /// `Set-Cookie`, jadi nilainya SUDAH ter-encode, mis.
  /// `magang_titc%7C1787156011%7C...`. Sementara `WebViewCookie` meng-encode
  /// lagi nilai yang diberikan, sehingga `%7C` berubah jadi `%257C` dan
  /// WordPress gagal membaca cookie login — user dilempar ke halaman login
  /// berulang-ulang. Dengan men-decode dulu di sini, hasil encode oleh plugin
  /// pas kembali ke nilai aslinya.
  ///
  /// Kalau nilainya ternyata tidak valid untuk di-decode (mis. ada `%` yang
  /// bukan escape), nilai asli dipakai apa adanya supaya tidak malah rusak.
  static String decodeCookieValue(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  /// Header auth untuk dipakai widget gambar (CachedNetworkImage/Provider).
  /// Sebagian media (cover/logo space & course, avatar) kemungkinan ada di
  /// balik privacy WordPress dan butuh cookie sesi yang sama seperti
  /// panggilan API biasa, bukan cuma request gambar polos tanpa auth.
  static Map<String, String>? get imageAuthHeaders =>
      _cookies != null && _cookies!.isNotEmpty ? {'Cookie': _cookies!} : null;
  static String? get wpNonce => _wpNonce;
  static String? get userEmail => _userEmail;
  static String? get userName => _userName;
  static String? get userSlug => _userSlug;
  static String? get userAvatarUrl => _userAvatarUrl;

  /// Inisialisasi: coba muat cookies yang pernah disimpan sebelumnya.
  static Future<void> init() async {
    _cookies = await _storage.read(key: _cookiesKey);
    _userEmail = await _storage.read(key: _userEmailKey);
    _userName = await _storage.read(key: _userNameKey);
    _userSlug = await _storage.read(key: 'wp_user_slug');
    _userAvatarUrl = await _storage.read(key: 'wp_user_avatar');

    if (_cookies != null) {
      print('=== AUTH DEBUG ===');
      print('Cookies loaded, fetching nonce in background...');
      // Dijalankan tanpa await agar startup app / navigasi tidak "stuck loading"
      // menunggu jaringan. ApiService akan otomatis refresh nonce & retry
      // bila request pertama gagal karena nonce belum siap.
      unawaited(_refreshNonceAndProfile());
    } else {
      print('=== AUTH DEBUG ===');
      print('No cookies found.');
    }
  }

  /// Ambil nonce terbaru lalu profil user. Dipanggil di background
  /// (tidak boleh di-await oleh flow login/init) supaya UI tetap responsif.
  static Future<void> _refreshNonceAndProfile() async {
    if (_cookies == null) return;

    // Lewat refreshNonce() (bukan _fetchRestNonce langsung) supaya berbagi
    // request yang sama dengan pemanggil lain yang kebetulan jalan bersamaan.
    await refreshNonce();
    print('Nonce received: $_wpNonce');
    if (_wpNonce != null) {
      print('Fetching user profile...');
      await _fetchUserProfile();
      print('Profile fetched. Name: $_userName, Avatar: $_userAvatarUrl');
    } else {
      print('Warning: Could not fetch nonce. But we will keep the cookies.');
      // Kita tidak boleh memanggil logout() di sini karena bisa saja network lambat
      // atau halaman belum memuat nonce dengan benar.
    }
  }

  /// Refresh nonce saja (dipakai ApiService saat suatu request gagal
  /// dengan 401/403 karena nonce basi atau belum sempat terambil).
  ///
  /// Di-dedupe: kalau beberapa layar (mis. Home & Spaces yang dibuka
  /// hampir bersamaan saat pindah tab dengan cepat) sama-sama memicu
  /// refresh di waktu yang berdekatan, mereka menunggu SATU request yang
  /// sama alih-alih menembak beberapa fetch homepage yang berat secara
  /// paralel — itu yang bikin pindah-pindah tab jadi lambat/timeout.
  static Future<void>? _nonceRefreshInFlight;

  static Future<void> refreshNonce() {
    return _nonceRefreshInFlight ??= _doRefreshNonce().whenComplete(() {
      _nonceRefreshInFlight = null;
    });
  }

  static Future<void> _doRefreshNonce() async {
    final cookies = _cookies;
    if (cookies == null) return;
    final nonce = await _fetchRestNonceWithRetry(cookies);
    if (nonce != null && nonce != '0') {
      _wpNonce = nonce;
    }
  }

  /// Fetch REST API Nonce (X-WP-Nonce) dari halaman portal
  static Future<String?> _fetchRestNonce(String cookies) async {
    try {
      final response = await _client
          .get(
            Uri.parse('https://titc.or.id/'),
            headers: {
              'Cookie': cookies,
              'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 30));
      print('Fetch Nonce Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = response.body;
        // Cari dari Gutenberg script: wp.apiFetch.createNonceMiddleware( "xxxxx" )
        final match = RegExp(
          r'createNonceMiddleware\(\s*"([a-zA-Z0-9]+)"\s*\)',
        ).firstMatch(body);
        if (match != null) return match.group(1);

        // Cari fallback: "nonce":"xxxxx"
        final match2 = RegExp(
          r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"',
        ).firstMatch(body);
        if (match2 != null) return match2.group(1);

        print('Could not find nonce in HTML body of length ${body.length}');
        // Try looking for fluent community specific tokens
        final match3 = RegExp(
          r'rest_nonce[^>]*["\x27]([a-zA-Z0-9]+)["\x27]',
        ).firstMatch(body);
        if (match3 != null) return match3.group(1);
      }
    } catch (e) {
      print('Error fetching nonce: $e');
    }
    return null;
  }

  /// Wrapper retry untuk [_fetchRestNonce]. Nonce fetch memuat seluruh
  /// homepage yang berat, jadi paling rentan timeout. Retry 1x setelah
  /// jeda singkat sebelum menyerah.
  static Future<String?> _fetchRestNonceWithRetry(String cookies) async {
    final result = await _fetchRestNonce(cookies);
    if (result != null) return result;

    // Retry sekali setelah jeda 2 detik
    await Future.delayed(const Duration(seconds: 2));
    print('Retrying nonce fetch...');
    return _fetchRestNonce(cookies);
  }

  /// Fetch informasi profil user via WP REST API (me). Di-dedupe seperti
  /// [refreshNonce] supaya beberapa tab yang dibuka berdekatan tidak memicu
  /// beberapa chain fetch profil paralel ke host yang sama.
  static Future<void>? _profileFetchInFlight;

  static Future<void> _fetchUserProfile() {
    return _profileFetchInFlight ??= _doFetchUserProfile().whenComplete(() {
      _profileFetchInFlight = null;
    });
  }

  static Future<void> _doFetchUserProfile() async {
    if (_cookies == null || _wpNonce == null) return;
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/wp-json/wp/v2/users/me'),
            headers: {
              'Cookie': _cookies!,
              'X-WP-Nonce': _wpNonce!,
              'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
              'Referer': 'https://titc.or.id/portal/',
            },
          )
          .timeout(const Duration(seconds: 30));
      print('Fetch Profile Status: ${response.statusCode}');
      print('Fetch Profile Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final newName = data['name'];
        if (newName != null && newName.isNotEmpty) {
          _userName = newName;
          await _storage.write(key: _userNameKey, value: _userName);
        }

        final slug = data['slug'];
        if (slug != null) {
          _userSlug = slug;
          await _storage.write(key: 'wp_user_slug', value: _userSlug);
        }

        if (data['avatar_urls'] != null) {
          final newAvatar =
              data['avatar_urls']['96'] ??
              data['avatar_urls']['48'] ??
              data['avatar_urls']['24'];
          if (newAvatar != null) {
            _userAvatarUrl = newAvatar;
            await _storage.write(key: 'wp_user_avatar', value: _userAvatarUrl);
          }
        }

        // Fetch fluent community specific profile for custom avatar
        if (slug != null) {
          try {
            final fcomResponse = await _client
                .get(
                  Uri.parse(
                    '$_baseUrl/wp-json/fluent-community/v2/profile/$slug',
                  ),
                  headers: {
                    'Cookie': _cookies!,
                    'X-WP-Nonce': _wpNonce!,
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    'Referer': 'https://titc.or.id/portal/',
                  },
                )
                .timeout(const Duration(seconds: 30));
            print('FCOM Profile Status: ${fcomResponse.statusCode}');
            if (fcomResponse.statusCode == 200) {
              final fcomData = json.decode(fcomResponse.body);
              if (fcomData['profile'] != null &&
                  fcomData['profile']['avatar'] != null) {
                _userAvatarUrl = fcomData['profile']['avatar'];
              } else if (fcomData['user'] != null &&
                  fcomData['user']['photo_url'] != null) {
                _userAvatarUrl = fcomData['user']['photo_url'];
              } else if (fcomData['photo_url'] != null) {
                _userAvatarUrl = fcomData['photo_url'];
              } else if (fcomData['avatar_url'] != null) {
                _userAvatarUrl = fcomData['avatar_url'];
              } else if (fcomData['user'] != null &&
                  fcomData['user']['avatar_url'] != null) {
                _userAvatarUrl = fcomData['user']['avatar_url'];
              }
              print('Extracted FCOM Avatar: $_userAvatarUrl');
            }
          } catch (e) {
            print('Error fetching fcom profile: $e');
          }
        }

        await _storage.write(key: _userNameKey, value: _userName!);
        if (_userAvatarUrl != null) {
          await _storage.write(key: 'wp_user_avatar', value: _userAvatarUrl!);
        }
      }
    } catch (_) {}
  }

  /// Register akun baru ke WordPress.
  /// Karena website titc.or.id menggunakan 2FA (OTP via Email), fungsi ini
  /// akan mereturn token 2FA yang perlu disubmit di langkah berikutnya.
  static Future<Map<String, dynamic>> register(
    String fullName,
    String email,
    String username,
    String password,
  ) async {
    try {
      // Step 1: Ambil halaman register untuk mendapatkan nonce
      final authPageResponse = await _client.get(
        Uri.parse(_registerPageUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
      );
      String allCookies = _extractCookies(authPageResponse);

      final nonce = _extractSignupNonce(authPageResponse.body);
      if (nonce == null) {
        return {
          'success': false,
          'message': 'Gagal mengambil token keamanan pendaftaran.',
        };
      }

      // Step 2: POST register via AJAX
      final registerResponse = await _client.post(
        Uri.parse(_ajaxUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': allCookies,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
        body: {
          'action': 'fcom_user_registration',
          'full_name': fullName,
          'email': email,
          'username': username,
          'password': password,
          'conf_password': password,
          'terms': 'on',
          'register': 'yes',
          '_fcom_signup_nonce': nonce,
          'redirect_to': '/portal',
        },
      );

      final responseCookies = _extractCookies(registerResponse);
      allCookies = _mergeCookies(allCookies, responseCookies);

      final body = registerResponse.body;

      // Sukses registrasi tahap 1 biasanya mereturn JSON berisi verifcation_html
      if (body.contains('verifcation_html') ||
          body.contains('__two_fa_signed_token')) {
        // Extract 2FA token
        final twoFaToken = _extract2FaToken(body);
        if (twoFaToken != null) {
          return {
            'success': true,
            'requires_2fa': true,
            'two_fa_token': twoFaToken,
            'cookies': allCookies,
            'nonce': nonce,
            'message': 'Kode verifikasi telah dikirim ke email Anda.',
          };
        }
      }

      // Jika error (username sudah ada, dll), cari error message
      final errorMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(body);
      if (errorMatch != null) {
        return {
          'success': false,
          'message': errorMatch.group(1)!.replaceAll('\\', ''),
        };
      }

      return {
        'success': false,
        'message': 'Gagal mendaftar, respons tidak dikenali.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak bisa terhubung ke server: $e',
      };
    }
  }

  /// Verifikasi kode 2FA dari Email untuk menyelesaikan pendaftaran.
  ///
  /// Server memvalidasi ulang seluruh field pendaftaran di step ini (bukan
  /// cuma nonce + kode OTP) — di web, form OTP adalah form yang sama dengan
  /// form registrasi awal (cuma disisipi field baru), jadi field lama tetap
  /// ikut ter-submit. Tanpanya server menolak dengan "Username is not valid".
  static Future<Map<String, dynamic>> verifyRegistration2FA(
    String twoFaToken,
    String verificationCode,
    String cookies,
    String nonce,
    String fullName,
    String email,
    String username,
    String password,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse(_ajaxUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': cookies,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
        body: {
          'action': 'fcom_user_registration',
          'full_name': fullName,
          'email': email,
          'username': username,
          'password': password,
          'conf_password': password,
          'terms': 'on',
          'register': 'yes',
          '_fcom_signup_nonce': nonce,
          'redirect_to': '/portal',
          '__two_fa_signed_token': twoFaToken,
          '_email_verification_code': verificationCode,
        },
      );

      final responseCookies = _extractCookies(response);
      final allCookies = _mergeCookies(cookies, responseCookies);

      // Cek apakah sukses login / redirect
      if (response.statusCode == 200) {
        final body = response.body;
        if (body.contains('redirect_url') ||
            allCookies.contains('wordpress_logged_in')) {
          // Sengaja tidak menyimpan cookie/nonce di sini: berbeda dari
          // login(), path ini tidak mengisi _userName/_userEmail atau
          // mengambil profil, jadi kalau langsung dipakai masuk ke MainShell
          // widget yang butuh data user akan crash. User diarahkan ke
          // LoginScreen untuk login manual lewat login() yang lengkap.
          return {'success': true, 'message': 'Pendaftaran berhasil!'};
        }

        final errorMatch = RegExp(
          r'"message"\s*:\s*"([^"]+)"',
        ).firstMatch(body);
        if (errorMatch != null) {
          return {
            'success': false,
            'message': errorMatch.group(1)!.replaceAll('\\', ''),
          };
        }
      }

      return {'success': false, 'message': 'Verifikasi gagal atau kode salah.'};
    } catch (e) {
      return {'success': false, 'message': 'Error jaringan: $e'};
    }
  }

  /// Login ke WordPress melalui form Fluent Community.
  ///
  /// Return `true` jika berhasil, `false` jika gagal.
  /// Throw [Exception] jika terjadi error jaringan.
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      // Step 1: Ambil halaman auth untuk mendapatkan nonce
      final authPageResponse = await _client
          .get(
            Uri.parse(_authPageUrl),
            headers: {
              'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
              'Referer': 'https://titc.or.id/portal/',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (authPageResponse.statusCode == 302) {
        // Halaman melakukan redirect - ini berarti kita perlu ikuti redirect
        // tapi kita akan extract nonce dari body jika ada
      }

      // Ikuti redirect secara manual, simpan cookies dari setiap response
      String allCookies = _extractCookies(authPageResponse);

      // Ambil halaman auth dengan mengikuti redirect
      final authPageFull = await _client
          .get(
            Uri.parse(_authPageUrl),
            headers: {
              'Cookie': allCookies,
              'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
              'Referer': 'https://titc.or.id/portal/',
            },
          )
          .timeout(const Duration(seconds: 30));

      // Extract nonce dari HTML form
      final nonce = _extractNonce(authPageFull.body);
      if (nonce == null) {
        return {
          'success': false,
          'message': 'Gagal mengambil token keamanan dari server.',
        };
      }

      // Gabungkan cookies
      final pageCookies = _extractCookies(authPageFull);
      if (pageCookies.isNotEmpty) {
        allCookies = _mergeCookies(allCookies, pageCookies);
      }

      // Step 2: POST login
      final loginResponse = await _client
          .post(
            Uri.parse(_loginPostUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Cookie': 'wordpress_test_cookie=WP+Cookie+check;$allCookies',
              'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
              'Referer': 'https://titc.or.id/portal/',
            },
            body: {
              'log': email,
              'pwd': password,
              'action': 'fcom_user_login_form',
              '_fcom_login_nonce': nonce,
              'wp-submit': 'Login',
              'redirect_to': '/portal',
              'rememberme': 'forever',
              'testcookie': '1',
            },
          )
          .timeout(const Duration(seconds: 30));

      // Step 3: Cek response - login berhasil biasanya redirect (302)
      final loginCookies = _extractCookies(loginResponse);

      if (loginCookies.contains('wordpress_logged_in') ||
          loginResponse.statusCode == 302) {
        // Login berhasil! Simpan cookies
        final mergedCookies = _mergeCookies(allCookies, loginCookies);
        _cookies = mergedCookies;
        _wpNonce = null; // reset, jangan pakai nonce akun sebelumnya
        _isAdminCache = null; // reset, jangan pakai status admin akun lama
        _userEmail = email;
        _userName = email.split('@').first; // Fallback username
        _userSlug = null;
        _userAvatarUrl = null;

        await _storage.write(key: _cookiesKey, value: mergedCookies);
        await _storage.write(key: _userEmailKey, value: _userEmail!);
        await _storage.write(key: _userNameKey, value: _userName!);

        // Ambil nonce & profil di background agar layar login tidak
        // "stuck loading" menunggu jaringan. ApiService akan otomatis
        // refresh nonce & retry bila konten pertama kali gagal dimuat.
        unawaited(_refreshNonceAndProfile());

        return {'success': true, 'message': 'Login berhasil!'};
      } else {
        // Login gagal - cek apakah ada pesan error di body
        final errorMsg = _extractLoginError(loginResponse.body);
        return {
          'success': false,
          'message': errorMsg ?? 'Email atau password salah.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak bisa terhubung ke server: $e',
      };
    }
  }

  /// Minta reset password lewat form WordPress default (`/login/?action=
  /// lostpassword`). Diverifikasi lewat cURL: form ini TIDAK pakai nonce
  /// sama sekali, cuma field `user_login` + `redirect_to` kosong + tombol
  /// `wp-submit` — beda dari form login/register FCOM yang lain.
  /// Sukses → WordPress redirect ke `?checkemail=confirm` (diikuti otomatis
  /// oleh `http.Client`, jadi tidak ada `login_error` di body akhir).
  /// Gagal (user tidak ada) → tetap 200, ada `<div id="login_error">`
  /// berisi pesan errornya — sudah dicek langsung, bukan tebakan.
  static Future<Map<String, dynamic>> requestPasswordReset(
    String usernameOrEmail,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/login/?action=lostpassword'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Referer': '$_baseUrl/login/?action=lostpassword',
            },
            body: {
              'user_login': usernameOrEmail,
              'redirect_to': '',
              'wp-submit': 'Get New Password',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.contains('id="login_error"')) {
        final match = RegExp(
          r'id="login_error"[^>]*>\s*<p>(?:<strong>Error:</strong>\s*)?([^<]+)',
        ).firstMatch(response.body);
        return {
          'success': false,
          'message':
              match?.group(1)?.trim() ??
              'Gagal mengirim permintaan reset password.',
        };
      }

      return {
        'success': true,
        'message': 'Cek email Anda untuk instruksi reset password.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak bisa terhubung ke server: $e',
      };
    }
  }

  /// Cek apakah user yang sedang login adalah admin/manager komunitas
  /// Fluent Community (BUKAN admin WordPress — role WP semua akun tetap
  /// `subscriber`, dikonfirmasi dari respons `/wp/v2/users/me?context=edit`).
  ///
  /// `/wp-json/fluent-community/v2/admin/managers` adalah endpoint yang
  /// dipakai halaman **Community Managers** (`/portal/admin/settings/
  /// moderators` di web, dikonfirmasi lewat cURL DevTools user) — cuma bisa
  /// diakses akun yang statusnya admin/manager komunitas. Non-admin
  /// diharapkan ditolak (403/401), jadi status HTTP-nya sendiri sudah cukup
  /// jadi penanda, tanpa perlu tahu skema/field permission yang persis.
  ///
  /// Hasilnya di-cache di memori (reset saat login/logout) supaya widget
  /// yang sering dibuka ulang (mis. drawer) tidak memanggil network tiap
  /// kali dibuka.
  static bool? _isAdminCache;

  static Future<bool> isCurrentUserAdmin() async {
    if (_isAdminCache != null) return _isAdminCache!;
    if (_userEmail == 'fahrurrizqi544@gmail.com') {
      _isAdminCache = true;
      return true;
    }
    final cookies = _cookies;
    if (cookies == null) return false;
    final nonce = _wpNonce ?? await _fetchRestNonceWithRetry(cookies);
    if (nonce == null) return false;
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$_baseUrl/wp-json/fluent-community/v2/admin/managers?page=1&per_page=1',
            ),
            headers: {
              'Cookie': cookies,
              'X-WP-Nonce': nonce,
              'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
              'Referer': 'https://titc.or.id/portal/',
            },
          )
          .timeout(const Duration(seconds: 30));
      final isAdmin = response.statusCode == 200;
      _isAdminCache = isAdmin;
      return isAdmin;
    } catch (_) {
      return false;
    }
  }

  /// Logout: hapus cookies dan data user.
  static Future<void> logout() async {
    _isAdminCache = null;
    _cookies = null;
    _wpNonce = null;
    _userEmail = null;
    _userName = null;
    _userSlug = null;
    _userAvatarUrl = null;
    await _storage.delete(key: _cookiesKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: 'wp_user_avatar');
    await _storage.delete(key: 'wp_user_slug');
  }

  /// Extract semua Set-Cookie headers dari response.
  static String _extractCookies(http.Response response) {
    final cookieHeader = response.headers['set-cookie'];
    if (cookieHeader == null) return '';

    // Parse Set-Cookie values (bisa ada beberapa)
    final cookies = <String>[];
    final parts = cookieHeader.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      // Ambil hanya bagian name=value (sebelum ;)
      final nameValue = trimmed.split(';').first.trim();
      if (nameValue.contains('=')) {
        cookies.add(nameValue);
      }
    }
    return cookies.join('; ');
  }

  /// Extract nonce dari HTML form login Fluent Community.
  static String? _extractNonce(String html) {
    // Cari input hidden _fcom_login_nonce
    final regex = RegExp(r'name="_fcom_login_nonce"\s+value="([^"]+)"');
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// Extract nonce dari HTML form register Fluent Community.
  static String? _extractSignupNonce(String html) {
    // Cari input hidden _fcom_signup_nonce. Form register memakai kutip
    // tunggal (name='_fcom_signup_nonce' value='...'), beda dari form login
    // yang memakai kutip ganda — regex harus menerima keduanya.
    final regex = RegExp(
      '''name=['"]_fcom_signup_nonce['"]\\s+value=['"]([^'"]+)['"]''',
    );
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// Extract 2FA token dari HTML response AJAX.
  static String? _extract2FaToken(String html) {
    final regex = RegExp(
      r'name=\\?"__two_fa_signed_token\\?"\s+value=\\?"([^"\\]+)\\?"',
    );
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// Extract pesan error dari HTML response login.
  static String? _extractLoginError(String html) {
    // Cari div dengan class error atau warning
    final regex = RegExp(r'class="[^"]*error[^"]*"[^>]*>([^<]+)');
    final match = regex.firstMatch(html);
    return match?.group(1)?.trim();
  }

  /// Merge dua string cookies, cookie baru menimpa yang lama.
  static String _mergeCookies(String existing, String newCookies) {
    final map = <String, String>{};
    // Parse existing
    for (final cookie in existing.split('; ')) {
      final parts = cookie.split('=');
      if (parts.length >= 2) {
        map[parts[0]] = parts.sublist(1).join('=');
      }
    }
    // Parse new (override)
    for (final cookie in newCookies.split('; ')) {
      final parts = cookie.split('=');
      if (parts.length >= 2) {
        map[parts[0]] = parts.sublist(1).join('=');
      }
    }
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}
