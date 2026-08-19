import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final slug = 'arnanda';
  final url = Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/profile/$slug');
  
  final cookies = 'wordpress_test_cookie=WP+Cookie+check; _lscache_vary=d86780fd4d635026731b3b19ec6e3c1a; wordpress_sec_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7Cafc9ac62c4cc1d894597ef021337b8642c0469197bde8eef78cc6237188b7a69; wordpress_logged_in_6e06ac1bcd65a6a92ad299ecc3a04935=arnanda%7C1786813221%7CoODZjZlkzyQCaPvJECu5sMp5TkRk9kxtZ497btU0PqH%7C59eef88339d1bcb337678fec70b138cd12e8327764f184b3b79eb788ff18ab3f';
  final nonce = 'd7537843de';

  final headers = {
    'Content-Type': 'application/json',
    'Cookie': cookies,
    'X-WP-Nonce': nonce,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Referer': 'https://titc.or.id/portal/',
  };

  print('Testing direct payload (no wrapper)...');
  var payload = {
    'short_description': 'hello bio from dart',
    'meta': {
      'headline': 'dart headline',
      'instagram': 'ig_dart'
    }
  };
  var res = await http.put(url, headers: headers, body: json.encode(payload));
  print(res.statusCode);
  print(res.body);

  print('Fetching FCOM profile to see if it saved...');
  var getRes = await http.get(Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/members/$slug'), headers: headers);
  print(getRes.statusCode);
  var member = json.decode(getRes.body);
  print('Bio: ${member['short_description']}');
  print('Headline: ${member['meta']['headline']}');
  print('Instagram: ${member['meta']['instagram']}');

  print('Testing payload with "data" wrapper...');
  payload = {
    'short_description': 'hello bio from dart 2',
    'meta': {
      'headline': 'dart headline 2',
      'instagram': 'ig_dart2'
    }
  };
  res = await http.put(url, headers: headers, body: json.encode({'data': payload}));
  print(res.statusCode);
  
  getRes = await http.get(Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/members/$slug'), headers: headers);
  member = json.decode(getRes.body);
  print('Bio: ${member['short_description']}');
  print('Headline: ${member['meta']['headline']}');
  print('Instagram: ${member['meta']['instagram']}');
}
