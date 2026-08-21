import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final cookies = 'wordpress_test_cookie=WP+Cookie+check; _lscache_vary=d86780fd4d635026731b3b19ec6e3c1a; wordpress_sec_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7Cafc9ac62c4cc1d894597ef021337b8642c0469197bde8eef78cc6237188b7a69; wordpress_logged_in_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7C59eef88339d1bcb337678fec70b138cd12e8327764f184b3b79eb788ff18ab3f';
  // Use a fresh nonce if possible, or the one from the app.
  // Actually, wait, the nonce might be expired since the last time.
  // Let me just fetch a new one.
  
  final portalRes = await http.get(Uri.parse('https://titc.or.id/portal/'), headers: {'Cookie': cookies});
  final nonceMatch = RegExp(r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"').firstMatch(portalRes.body) ?? RegExp(r'rest_nonce[^>]*["\x27]([a-zA-Z0-9]+)["\x27]').firstMatch(portalRes.body);
  final nonce = nonceMatch?.group(1) ?? 'fae22dd864';
  
  final slug = 'magang_titc'; // The test user slug
  final url = Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/profile/$slug');
  
  final headers = {
    'Content-Type': 'application/json',
    'Cookie': cookies,
    'X-WP-Nonce': nonce,
    'User-Agent': 'Mozilla/5.0'
  };

  print('Testing PUT with top-level data...');
  final res1 = await http.put(url, headers: headers, body: json.encode({
    'data': {
      'headline': 'Test Headline 1',
      'short_description': 'Test Bio 1',
      'instagram': 'https://inst.com'
    }
  }));
  print('Res1 Status: ${res1.statusCode}');
  print('Res1 Body: ${res1.body}');

  print('Testing PUT with meta object...');
  final res2 = await http.put(url, headers: headers, body: json.encode({
    'data': {
      'short_description': 'Test Bio 2',
      'meta': {
        'headline': 'Test Headline 2',
        'instagram': 'https://inst2.com'
      }
    }
  }));
  print('Res2 Status: ${res2.statusCode}');
  print('Res2 Body: ${res2.body}');
}
