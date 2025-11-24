import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String versionUrl =
      'https://github.com/phsycologicalfudge/AVDatabase/releases/latest/download/version.json';
  static const String defsUrl =
      'https://github.com/phsycologicalfudge/AVDatabase/releases/latest/download/defs.vxpack';
  static const String keyUrl =
      'https://github.com/phsycologicalfudge/AVDatabase/releases/latest/download/defs_key.bin';

  static Future<Map<String, dynamic>?> checkServerVersion() async {
    try {
      final response = await http.get(
        Uri.parse(versionUrl),
        headers: {
          'User-Agent': 'ColourSwiftAV/1.0 (Flutter; Android)',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  static Future<String> getLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('defs_version') ?? '0.0.0';
  }

  static Future<void> setLocalVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defs_version', version);
  }

  static Future<bool> downloadDatabase({
    required void Function(double) onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final defsPath = '${dir.path}/defs.vxpack';
      final keyPath = '${dir.path}/defs_key.bin';
      final client = http.Client();

      for (final entry in [
        {'url': defsUrl, 'path': defsPath},
        {'url': keyUrl, 'path': keyPath},
      ]) {
        final uri = Uri.parse('${entry['url']}?t=${DateTime.now().millisecondsSinceEpoch}');
        final res = await client.get(uri);
        if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

        final bytes = res.bodyBytes;
        final file = File(entry['path']!);
        final sink = file.openWrite();
        final total = bytes.length;
        int written = 0;
        const chunkSize = 64 * 1024;

        while (written < total) {
          final end = (written + chunkSize).clamp(0, total);
          sink.add(bytes.sublist(written, end));
          written = end;
          onProgress(written / total);
          await Future.delayed(const Duration(milliseconds: 16));
        }

        await sink.close();
        onProgress(1.0);
      }

      client.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
