import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    var res = await http.get(Uri.parse('https://titc.or.id/portal/'));
    var body = res.body;
    
    // Find script tags
    var scriptRegex = RegExp(r'<script[^>]*src="([^"]+)"');
    var matches = scriptRegex.allMatches(body);
    
    for (var match in matches) {
      var url = match.group(1)!;
      if (url.contains('fluent-community') && url.endsWith('.js')) {
         print('Found JS: $url');
         var jsRes = await http.get(Uri.parse(url));
         var jsBody = jsRes.body;
         
         // Search for notification related endpoints
         var endpointRegex = RegExp(r'([a-zA-Z0-9_\-\/]*notifications?[a-zA-Z0-9_\-\/]*)');
         var endpoints = endpointRegex.allMatches(jsBody).map((m) => m.group(0)!).toSet();
         
         print('Endpoints found in $url:');
         for (var ep in endpoints) {
           print('  $ep');
         }
      }
    }
  } catch(e) {
    print('Error: $e');
  }
}
