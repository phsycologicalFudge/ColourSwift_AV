import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudScanner {
  final String endpoint;
  final String apiKey;

  CloudScanner({required this.endpoint, required this.apiKey});

  Future<List<String>> checkBatch(List<String> hashes) async {
    try {
      final uri = Uri.parse('$endpoint/check_batch');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-cs-key': apiKey,
        },
        body: jsonEncode(hashes),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final found = List<String>.from(data['found'] ?? []);
        return found;
      }
    } catch (_) {}
    return [];
  }
}
