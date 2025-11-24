import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DefsManager {
  static Future<(String, String)> ensureLiteDefinitions() async {
    final dir = await getApplicationDocumentsDirectory();
    final defsPath = '${dir.path}/defs.vxpack';
    final keyPath = '${dir.path}/defs_key.bin';

    // Ensure defs.vxpack exists
    if (!File(defsPath).existsSync()) {
      final liteData = await rootBundle.load('assets/defs/defs.vxpack');
      await File(defsPath).writeAsBytes(liteData.buffer.asUint8List());
    }

    // Ensure defs_key.bin exists
    if (!File(keyPath).existsSync()) {
      final keyData = await rootBundle.load('assets/defs/defs_key.bin');
      await File(keyPath).writeAsBytes(keyData.buffer.asUint8List());
    }

    return (defsPath, keyPath);
  }
}
