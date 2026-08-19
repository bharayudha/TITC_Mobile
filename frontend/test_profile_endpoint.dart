import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // 1. Fetch login nonce
    var res = await http.get(Uri.parse('https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal'));
    var cookieStr = res.headers['set-cookie'] ?? '';
    var nonce = RegExp(r'name="_fcom_login_nonce"\s+value="([^"]+)"').firstMatch(res.body)?.group(1);
    
    // 2. Login
    var loginRes = await http.post(
      Uri.parse('https://titc.or.id/login/'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': 'wordpress_test_cookie=WP+Cookie+check; ' + cookieStr,
      },
      body: {
        'log': 'fahrurrizqi544@gmail.com',
        'pwd': 'magang123',
        'action': 'fcom_user_login_form',
        '_fcom_login_nonce': nonce ?? '',
        'wp-submit': 'Login',
        'redirect_to': '/portal',
        'rememberme': 'forever',
        'testcookie': '1'
      }
    );
    var loginCookies = loginRes.headers['set-cookie'] ?? '';
    var allCookies = cookieStr + '; ' + loginCookies;
    
    // 3. Fetch WP-Nonce and slug
    var portalRes = await http.get(
      Uri.parse('https://titc.or.id/portal/'),
      headers: {'Cookie': allCookies}
    );
    var wpNonce = RegExp(r'createNonceMiddleware\(\s*"([a-zA-Z0-9]+)"\s*\)').firstMatch(portalRes.body)?.group(1) ??
                  RegExp(r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"').firstMatch(portalRes.body)?.group(1);
    
    // fetch me
    var meRes = await http.get(
      Uri.parse('https://titc.or.id/wp-json/wp/v2/users/me'),
      headers: {
        'Cookie': allCookies,
        'X-WP-Nonce': wpNonce ?? '',
      }
    );
    var meData = json.decode(meRes.body);
    var slug = meData['slug'];
    print('Slug: $slug');

    // 4. Fetch profile
    var fcomRes = await http.get(
      Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/profile/$slug'),
      headers: {
        'Cookie': allCookies,
        'X-WP-Nonce': wpNonce ?? '',
      }
    );
    print('GET Profile Status: ${fcomRes.statusCode}');
    print('GET Profile: ${fcomRes.body}');
  } catch(e) {
    print('Error: $e');
  }
}
