import 'package:http/http.dart' as http;

void main() async {
  final cookies = 'wordpress_test_cookie=WP+Cookie+check; _lscache_vary=d86780fd4d635026731b3b19ec6e3c1a; wordpress_sec_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7Cafc9ac62c4cc1d894597ef021337b8642c0469197bde8eef78cc6237188b7a69; wordpress_logged_in_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7C59eef88339d1bcb337678fec70b138cd12e8327764f184b3b79eb788ff18ab3f';
  
  final response = await http.get(
    Uri.parse('https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal'),
    headers: {
      'Cookie': cookies,
      'User-Agent': 'Mozilla/5.0'
    }
  );
  
  final body = response.body;
  print('Status: ${response.statusCode}');
  
  final match = RegExp(r'createNonceMiddleware\(\s*"([a-zA-Z0-9]+)"\s*\)').firstMatch(body);
  if (match != null) print('Match 1: ${match.group(1)}');
  
  final match2 = RegExp(r'"nonce"\s*:\s*"([a-zA-Z0-9]+)"').firstMatch(body);
  if (match2 != null) print('Match 2: ${match2.group(1)}');
  
  final match3 = RegExp(r'rest_nonce[^>]*["\x27]([a-zA-Z0-9]+)["\x27]').firstMatch(body);
  if (match3 != null) print('Match 3: ${match3.group(1)}');
  
  if (match == null && match2 == null && match3 == null) {
     print('No match found!');
  }
}
