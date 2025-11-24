import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/exclusions_store.dart';
import '../widgets/antivirus_bridge.dart';
import 'av_engine.dart';
import 'foreground_service.dart';
import 'quarantine_service.dart';

bool scanFileIsolate(String path) {
  try {
    final bridge = AntivirusBridge();
    final res = bridge.scanFile(path);
    final decoded = jsonDecode(res);
    final hits = decoded['hits'] as Map?;
    return hits != null && hits.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class RealtimeProtectionService {
  static bool _running = false;
  static Map<String, int> _seen = {};
  static StreamSubscription? _eventSub;

  static const _eventChannel = EventChannel('colourswift/realtime_stream');

  static const _allowed = {
    'com', 'apk', 'zip', 'rar', '7z', 'pdf', 'txt', 'md', 'json'
  };
  static const _skip = {
    'mp3', 'mp4', 'm4a', 'mov', 'jpg', 'png', 'jpeg', 'heic', 'webp'
  };
  static const _maxSize = 100 * 1024 * 1024;

  static Future<void> start() async {
    if (_running) return;
    _running = true;
    await _loadIndex();
    await ExclusionsStore.instance.init();
    await AvEngine.ensureInitialized();
    await ForegroundService.start(title: 'CS Security+', text: 'Realtime protection active');
    _eventSub = _eventChannel.receiveBroadcastStream().listen((dynamic event) async {
      if (event is! String) return;
      final name = p.basename(event);
      if (name.startsWith('.pending-')) return;
      await _scanSingleFile(event);
    }, onError: (e) {});
  }

  static Future<void> stop() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _running = false;
    await _saveIndex();
    await ForegroundService.stop();
  }

  static Future<bool> _waitUntilStable(File f, {Duration timeout = const Duration(seconds: 6), Duration poll = const Duration(milliseconds: 250)}) async {
    final deadline = DateTime.now().add(timeout);
    int? lastSig;
    int stableHits = 0;
    while (DateTime.now().isBefore(deadline)) {
      if (!await f.exists()) return false;
      final stat = await f.stat();
      final sig = stat.size ^ stat.modified.millisecondsSinceEpoch;
      if (lastSig != null && sig == lastSig) {
        stableHits++;
        if (stableHits >= 2) return true;
      } else {
        stableHits = 0;
        lastSig = sig;
      }
      await Future.delayed(poll);
    }
    return false;
  }

  static Future<void> _scanSingleFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return;
      if (ExclusionsStore.instance.isExcluded(path)) return;

      final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
      if (_skip.contains(ext)) return;
      if (_allowed.isNotEmpty && !_allowed.contains(ext)) return;

      final size = await f.length();
      if (size <= 0 || size > _maxSize) return;

      final mtime = (await f.lastModified()).millisecondsSinceEpoch;
      final seenMtime = _seen[path];
      if (seenMtime != null && mtime <= seenMtime) return;

      await Future.delayed(const Duration(milliseconds: 180));

      final infected = await compute(scanFileIsolate, path);
      if (infected) {
        if (!ExclusionsStore.instance.isExcluded(path)) {
          await _handleDetection(path);
        }
      }

      _seen[path] = mtime;
      await _saveIndex();
    } catch (_) {}
  }

  static Future<void> _handleDetection(String path) async {
    try {
      final meta = await QuarantineService.quarantineFile(path);
      await ForegroundService.notify(
        title: 'Threat Detected',
        text: 'A file was quarantined: ${path.split('/').last}',
      );
    } catch (_) {
      await ForegroundService.notify(
        title: 'Threat Detected',
        text: 'Failed to quarantine: ${path.split('/').last}',
      );
    }
  }

  static Future<File> _indexFile() async {
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}/rt_seen.json');
    if (!await f.exists()) await f.create(recursive: true);
    return f;
  }

  static Future<void> _loadIndex() async {
    try {
      final f = await _indexFile();
      final s = await f.readAsString();
      if (s.isEmpty) return;
      final m = jsonDecode(s) as Map<String, dynamic>;
      _seen = m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      _seen = {};
    }
  }

  static Future<void> _saveIndex() async {
    try {
      final f = await _indexFile();
      await f.writeAsString(jsonEncode(_seen));
    } catch (_) {}
  }
}
