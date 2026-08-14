import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final email = 'fahrurrizqi544@gmail.com';
  final password = 'magang123';
  print('Logging in...');

  final client = http.Client();
  
  // 1. Get Auth Page
  final authPageRes = await client.get(
    Uri.parse('https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal')
  );
  var cookies = authPageRes.headers['set-cookie'] ?? '';
  
  final authPageFull = await client.get(
    Uri.parse('https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal'),
    headers: {'Cookie': cookies}
  );
  
  final nonceMatch = RegExp(r'name="_fcom_login_nonce"\s+value="([^"]+)"').firstMatch(authPageFull.body);
  final nonce = nonceMatch?.group(1);
  if (nonce == null) {
    print('Failed to get nonce');
    return;
  }
  
  final pageCookies = authPageFull.headers['set-cookie'] ?? '';
  // merge manually
  
  print('Nonce: $nonce');
  // 2. Login
  final loginRes = await client.post(
    Uri.parse('https://titc.or.id/login/'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cookie': 'wordpress_test_cookie=WP+Cookie+check;$pageCookies;$cookies'
    },
    body: {
      'log': email,
      'pwd': password,
      'action': 'fcom_user_login_form',
      '_fcom_login_nonce': nonce,
      'wp-submit': 'Login',
      'redirect_to': '/portal',
      'rememberme': 'forever',
      'testcookie': '1'
    }
  );
  
  final loginCookies = loginRes.headers['set-cookie'] ?? '';
  print('Login Cookies: $loginCookies');
  
  final fullCookies = '$cookies;$pageCookies;$loginCookies';
  
  // Get REST Nonce
  final portalRes = await client.get(
    Uri.parse('https://titc.or.id/'),
    headers: {'Cookie': fullCookies}
  );
  
  final restNonceMatch = RegExp(r'createNonceMiddleware\(\s*"([a-zA-Z0-9]+)"\s*\)').firstMatch(portalRes.body) ?? 
                         RegExp(r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"').firstMatch(portalRes.body);
  final restNonce = restNonceMatch?.group(1);
  
  print('REST Nonce: $restNonce');
  
  // 3. Check WP Admin
  final adminRes = await client.get(
    Uri.parse('https://titc.or.id/wp-json/wp/v2/users/me?context=edit'),
    headers: {
      'Cookie': fullCookies,
      'X-WP-Nonce': restNonce ?? ''
    }
  );
  
  print('WP Admin Check Status: ${adminRes.statusCode}');
  if (adminRes.statusCode == 200) {
     print('Roles: ${jsonDecode(adminRes.body)['roles']}');
  }
}
