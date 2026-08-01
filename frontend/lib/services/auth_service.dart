import 'dart:convert';
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

  static const String _cookiesKey = 'wp_cookies';
  static const String _userNameKey = 'wp_user_name';
  static const String _userEmailKey = 'wp_user_email';

  /// Cookie WordPress yang disimpan setelah login.
  static String? _cookies;
  static String? _wpNonce;
  static String? _userEmail;
  static String? _userName;
  static String? _userAvatarUrl;

  /// Getter: apakah user sudah login (ada cookie tersimpan).
  static bool get isLoggedIn => _cookies != null && _cookies!.isNotEmpty;

  /// Getter: cookies saat ini, untuk dipakai oleh ApiService.
  static String? get cookies => _cookies;
  static String? get wpNonce => _wpNonce;
  static String? get userEmail => _userEmail;
  static String? get userName => _userName;
  static String? get userAvatarUrl => _userAvatarUrl;

  /// Inisialisasi: coba muat cookies yang pernah disimpan sebelumnya.
  static Future<void> init() async {
    _cookies = await _storage.read(key: _cookiesKey);
    _userEmail = await _storage.read(key: _userEmailKey);
    _userName = await _storage.read(key: _userNameKey);
    _userAvatarUrl = await _storage.read(key: 'wp_user_avatar');

    if (_cookies != null) {
      print('=== AUTH DEBUG ===');
      print('Cookies loaded, fetching nonce...');
      // Coba ambil REST nonce dengan cookie yang ada
      final nonce = await _fetchRestNonce(_cookies!);
      print('Nonce received: $nonce');
      if (nonce != null && nonce != '0') {
        _wpNonce = nonce;
        // Ambil info profil terbaru untuk foto
        print('Fetching user profile...');
        await _fetchUserProfile();
        print('Profile fetched. Name: $_userName, Avatar: $_userAvatarUrl');
      } else {
        print('Warning: Could not fetch nonce on init. But we will keep the cookies.');
        // Kita tidak boleh memanggil logout() di sini karena bisa saja network lambat
        // atau halaman belum memuat nonce dengan benar.
      }
    } else {
      print('=== AUTH DEBUG ===');
      print('No cookies found.');
    }
  }

  /// Fetch REST API Nonce (X-WP-Nonce) dari halaman portal
  static Future<String?> _fetchRestNonce(String cookies) async {
    try {
      final response = await http.get(
        Uri.parse('https://titc.or.id/portal/'),
        headers: {
          'Cookie': cookies,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );
      print('Fetch Nonce Status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = response.body;
        // Cari dari Gutenberg script: wp.apiFetch.createNonceMiddleware( "xxxxx" )
        final match = RegExp(r'createNonceMiddleware\(\s*"([a-zA-Z0-9]+)"\s*\)').firstMatch(body);
        if (match != null) return match.group(1);
        
        // Cari fallback: "nonce":"xxxxx"
        final match2 = RegExp(r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"').firstMatch(body);
        if (match2 != null) return match2.group(1);
        
        print('Could not find nonce in HTML body of length ${body.length}');
        // Try looking for fluent community specific tokens
        final match3 = RegExp(r'rest_nonce[^>]*["\x27]([a-zA-Z0-9]+)["\x27]').firstMatch(body);
        if (match3 != null) return match3.group(1);
      }
    } catch (e) {
      print('Error fetching nonce: $e');
    }
    return null;
  }

  /// Fetch informasi profil user via WP REST API (me)
  static Future<void> _fetchUserProfile() async {
    if (_cookies == null || _wpNonce == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wp/v2/users/me'),
        headers: {
          'Cookie': _cookies!,
          'X-WP-Nonce': _wpNonce!,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/'
        },
      );
      print('Fetch Profile Status: ${response.statusCode}');
      print('Fetch Profile Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final newName = data['name'];
        if (newName != null && newName.isNotEmpty) {
          _userName = newName;
          await _storage.write(key: _userNameKey, value: _userName);
        }
        
        if (data['avatar_urls'] != null) {
          final newAvatar = data['avatar_urls']['96'] ?? data['avatar_urls']['48'] ?? data['avatar_urls']['24'];
          if (newAvatar != null) {
            _userAvatarUrl = newAvatar;
            await _storage.write(key: 'wp_user_avatar', value: _userAvatarUrl);
          }
        }
        
        // Fetch fluent community specific profile for custom avatar
        final slug = data['slug'];
        if (slug != null) {
          try {
            final fcomResponse = await http.get(
              Uri.parse('$_baseUrl/wp-json/fluent-community/v2/profile/$slug'),
              headers: {
                'Cookie': _cookies!,
                'X-WP-Nonce': _wpNonce!,
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer': 'https://titc.or.id/portal/'
              },
            );
            print('FCOM Profile Status: ${fcomResponse.statusCode}');
            if (fcomResponse.statusCode == 200) {
              final fcomData = json.decode(fcomResponse.body);
              if (fcomData['profile'] != null && fcomData['profile']['avatar'] != null) {
                _userAvatarUrl = fcomData['profile']['avatar'];
              } else if (fcomData['user'] != null && fcomData['user']['photo_url'] != null) {
                _userAvatarUrl = fcomData['user']['photo_url'];
              } else if (fcomData['photo_url'] != null) {
                _userAvatarUrl = fcomData['photo_url'];
              } else if (fcomData['avatar_url'] != null) {
                _userAvatarUrl = fcomData['avatar_url'];
              } else if (fcomData['user'] != null && fcomData['user']['avatar_url'] != null) {
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
      final authPageResponse = await http.get(
        Uri.parse(_registerPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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
      final registerResponse = await http.post(
        Uri.parse(_ajaxUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': allCookies,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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
      if (body.contains('verifcation_html') || body.contains('__two_fa_signed_token')) {
        // Extract 2FA token
        final twoFaToken = _extract2FaToken(body);
        if (twoFaToken != null) {
          return {
            'success': true,
            'requires_2fa': true,
            'two_fa_token': twoFaToken,
            'cookies': allCookies,
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
  static Future<Map<String, dynamic>> verifyRegistration2FA(
    String twoFaToken,
    String verificationCode,
    String cookies,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_ajaxUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': cookies,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
        body: {
          'action': 'fcom_user_registration',
          '__two_fa_signed_token': twoFaToken,
          '_email_verification_code': verificationCode,
        },
      );

      final responseCookies = _extractCookies(response);
      final allCookies = _mergeCookies(cookies, responseCookies);

      // Cek apakah sukses login / redirect
      if (response.statusCode == 200) {
        final body = response.body;
        if (body.contains('redirect_url') || allCookies.contains('wordpress_logged_in')) {
          _cookies = allCookies;
          _wpNonce = await _fetchRestNonce(allCookies);
          await _storage.write(key: _cookiesKey, value: allCookies);
          return {'success': true, 'message': 'Pendaftaran berhasil!'};
        }
        
        final errorMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(body);
        if (errorMatch != null) {
          return {'success': false, 'message': errorMatch.group(1)!.replaceAll('\\', '')};
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
      String email, String password) async {
    try {
      // Step 1: Ambil halaman auth untuk mendapatkan nonce
      final authPageResponse = await http.get(
        Uri.parse(_authPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
      );

      if (authPageResponse.statusCode == 302) {
        // Halaman melakukan redirect - ini berarti kita perlu ikuti redirect
        // tapi kita akan extract nonce dari body jika ada
      }

      // Ikuti redirect secara manual, simpan cookies dari setiap response
      String allCookies = _extractCookies(authPageResponse);

      // Ambil halaman auth dengan mengikuti redirect
      final authPageFull = await http.get(
        Uri.parse(_authPageUrl),
        headers: {
          'Cookie': allCookies,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
      );

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
      final loginResponse = await http.post(
        Uri.parse(_loginPostUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': 'wordpress_test_cookie=WP+Cookie+check;$allCookies',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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
      );

      // Step 3: Cek response - login berhasil biasanya redirect (302)
      final loginCookies = _extractCookies(loginResponse);

      if (loginCookies.contains('wordpress_logged_in') ||
          loginResponse.statusCode == 302) {
        // Login berhasil! Simpan cookies
        final mergedCookies = _mergeCookies(allCookies, loginCookies);
        _cookies = mergedCookies;
        _wpNonce = await _fetchRestNonce(mergedCookies);
        _userEmail = email;
        _userName = email.split('@').first; // Fallback username
        
        await _storage.write(key: _cookiesKey, value: mergedCookies);
        await _storage.write(key: _userEmailKey, value: _userEmail!);
        await _storage.write(key: _userNameKey, value: _userName!);

        // Ambil profil yang lebih akurat dan avatar
        await _fetchUserProfile();

        return {
          'success': true,
          'message': 'Login berhasil!',
        };
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

  /// Logout: hapus cookies dan data user.
  static Future<void> logout() async {
    _cookies = null;
    _wpNonce = null;
    _userEmail = null;
    _userName = null;
    _userAvatarUrl = null;
    await _storage.delete(key: _cookiesKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: 'wp_user_avatar');
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
    // Cari input hidden _fcom_signup_nonce
    final regex = RegExp(r'name="_fcom_signup_nonce"\s+value="([^"]+)"');
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// Extract 2FA token dari HTML response AJAX.
  static String? _extract2FaToken(String html) {
    final regex = RegExp(r'name=\\?"__two_fa_signed_token\\?"\s+value=\\?"([^"\\]+)\\?"');
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
