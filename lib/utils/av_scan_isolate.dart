//FOR THE FILESCREEN APK SCANNER

import 'dart:convert';
import 'dart:io';
import '../widgets/antivirus_bridge.dart';

Map<String, dynamic> scanFilesIsolate(Map<String, dynamic> args) {
  final defs = args['defs'] as (String, String);
  final paths = (args['paths'] as List).cast<String>();

  final av = AntivirusBridge();
  final initCode = av.init(defs.$1, defs.$2);

  final results = <Map<String, dynamic>>[];
  int infected = 0;

  if (initCode == 0) {
    for (final path in paths) {
      final res = av.scanFile(path);
      try {
        final j = json.decode(res);
        bool isInfected = false;
        if (j is Map && j.containsKey('hits')) {
          final hits = (j['hits'] as Map);
          isInfected = hits.isNotEmpty;
        }
        if (isInfected) infected++;
        results.add({
          'path': path,
          'name': path.split('/').isNotEmpty ? path.split('/').last : path,
          'infected': isInfected,
        });
      } catch (_) {
        results.add({
          'path': path,
          'name': path.split('/').isNotEmpty ? path.split('/').last : path,
          'infected': false,
          'error': true,
        });
      }
    }
  }

  av.free();
  return {'infected': infected, 'results': results, 'initCode': initCode};
}
