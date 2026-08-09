import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // 1. Fetch login nonce
    print('Fetching auth page...');
    var res = await http.get(Uri.parse('https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal'));
    
    var cookieStr = res.headers['set-cookie'] ?? '';
    var nonceMatch = RegExp(r'name="_fcom_login_nonce"\s+value="([^"]+)"').firstMatch(res.body);
    var nonce = nonceMatch?.group(1);
    
    if (nonce == null) {
      print('Could not find nonce');
      return;
    }
    
    // 2. Login
    print('Logging in with nonce: $nonce...');
    var loginRes = await http.post(
      Uri.parse('https://titc.or.id/login/'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': 'wordpress_test_cookie=WP+Cookie+check; ' + cookieStr,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
        'Referer': 'https://titc.or.id/portal/'
      },
      body: {
        'log': 'fahrurrizqi544@gmail.com',
        'pwd': 'magang123',
        'action': 'fcom_user_login_form',
        '_fcom_login_nonce': nonce,
        'wp-submit': 'Login',
        'redirect_to': '/portal',
        'rememberme': 'forever',
        'testcookie': '1'
      }
    );
    
    var loginCookies = loginRes.headers['set-cookie'] ?? '';
    var allCookies = cookieStr + '; ' + loginCookies;
    
    // 3. Fetch WP-Nonce
    print('Fetching portal for WP Nonce...');
    var portalRes = await http.get(
      Uri.parse('https://titc.or.id/portal/'),
      headers: {
        'Cookie': allCookies,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
      }
    );
    var wpNonceMatch = RegExp(r'createNonceMiddleware\(\s*"([a-zA-Z0-9]+)"\s*\)').firstMatch(portalRes.body) ??
                       RegExp(r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"').firstMatch(portalRes.body) ??
                       RegExp(r'rest_nonce[^>]*["\x27]([a-zA-Z0-9]+)["\x27]').firstMatch(portalRes.body);
    var wpNonce = wpNonceMatch?.group(1);
    
    print('WP Nonce: $wpNonce');
    
    // 4. Fetch notifications
    print('Fetching notifications...');
    var notifRes = await http.get(
      Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/notifications'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': allCookies,
        'X-WP-Nonce': wpNonce ?? '',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
        'Referer': 'https://titc.or.id/portal/'
      }
    );
    
    print('Status: ${notifRes.statusCode}');
    print('Body: ${notifRes.body}');
  } catch(e) {
    print('Error: $e');
  }
}
