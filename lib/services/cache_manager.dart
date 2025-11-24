import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheManager {
  static Future<void> clearAll() async {
    try {
      final tmp = await getTemporaryDirectory();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}