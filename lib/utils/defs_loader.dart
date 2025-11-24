import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ensures antivirus definition files exist and are up to date.
/// 1. Loads local version from defs_version.txt
/// 2. Checks server version from version.json (bundled or fetched)
/// 3. Updates if newer or missing
Future<void> ensureAntivirusFiles() async {
  debugPrint('=== ensureAntivirusFiles() started ===');

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final defsPath = p.join(appDir.path, 'defs.vxpack');
    final keyPath = p.join(appDir.path, 'defs_key.bin');
    final versionPath = p.join(appDir.path, 'defs_version.txt');

    final dir = Directory(appDir.path);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // --- Read local version ---
    String localVersion = '0.0.0';
    if (await File(versionPath).exists()) {
      localVersion = (await File(versionPath).readAsString()).trim();
    }
    debugPrint('Local defs version: $localVersion');

    // --- Read bundled version (from assets/version.json) ---
    String bundledVersion = '0.0.0';
    try {
      final jsonStr = await rootBundle.loadString('assets/defs/version.json');
      final decoded = json.decode(jsonStr);
      bundledVersion = decoded['version'] ?? '0.0.0';
    } catch (_) {
      debugPrint('No bundled version.json found, skipping.');
    }
    debugPrint('Bundled defs version: $bundledVersion');

    bool shouldUpdate = false;

    // Compare version numbers semantically (x.y.z)
    List<int> parseVersion(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localParts = parseVersion(localVersion);
    final bundleParts = parseVersion(bundledVersion);

    for (int i = 0; i < 3; i++) {
      if (bundleParts[i] > localParts[i]) {
        shouldUpdate = true;
        break;
      } else if (bundleParts[i] < localParts[i]) {
        break;
      }
    }

    // --- Copy bundled defs if newer or missing ---
    Future<void> copyAsset(String assetName, String destPath) async {
      final data = await rootBundle.load('assets/defs/$assetName');
      final bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(destPath).writeAsBytes(bytes, flush: true);
      debugPrint('$assetName copied successfully.');
    }

    if (!File(defsPath).existsSync() ||
        !File(keyPath).existsSync() ||
        shouldUpdate) {
      debugPrint(
          shouldUpdate ? 'Updating definitions...' : 'Copying missing defs...');
      await copyAsset('defs.vxpack', defsPath);
      await copyAsset('defs_key.bin', keyPath);
      await File(versionPath).writeAsString(bundledVersion, flush: true);
      debugPrint('Definitions updated to v$bundledVersion');
    } else {
      debugPrint('Definitions up to date, no copy needed.');
    }

    final defsExists = File(defsPath).existsSync();
    final keyExists = File(keyPath).existsSync();
    if (!defsExists || !keyExists) {
      throw Exception('Missing antivirus files after copy.');
    }

    debugPrint('✅ ensureAntivirusFiles() finished successfully');
  } catch (e, st) {
    debugPrint('❌ Error in ensureAntivirusFiles: $e');
    debugPrint('Stack trace: $st');
  }
}
