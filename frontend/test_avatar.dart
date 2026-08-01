import 'package:http/http.dart' as http;

void main() async {
  var request = http.MultipartRequest('POST', Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/profile/avatar'));
  var response = await request.send();
  print(response.statusCode);
}
