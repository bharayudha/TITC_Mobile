import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final slug = 'magang_titc'; // Use the user's slug
  final url = Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/profile/$slug');
  
  final res = await http.get(url);
  print(res.statusCode);
  print(res.body);
}
