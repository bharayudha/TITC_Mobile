import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final cookies = 'wordpress_test_cookie=WP+Cookie+check; _lscache_vary=d86780fd4d635026731b3b19ec6e3c1a; wordpress_sec_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7Cafc9ac62c4cc1d894597ef021337b8642c0469197bde8eef78cc6237188b7a69; wordpress_logged_in_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7C59eef88339d1bcb337678fec70b138cd12e8327764f184b3b79eb788ff18ab3f';
  // Use the nonce we found in the previous logs: fae22dd864
  final nonce = 'fae22dd864';
  
  final url = 'https://titc.or.id/wp-json/wp/v2/users/me';
  
  final headers = {
    'Content-Type': 'application/json',
    'Cookie': cookies,
    'X-WP-Nonce': nonce,
    'User-Agent': 'Mozilla/5.0'
  };

  final body = json.encode({
    'first_name': 'Arnanda',
    'last_name': 'TestNative',
    'description': 'Bio updated from native', 'meta': @{'fcom_headline': 'Test Headline'}
  });
  
  final res = await http.post(Uri.parse(url), headers: headers, body: body);
  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}
