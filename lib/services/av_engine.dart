import 'dart:async';
import 'dart:isolate';
import '../widgets/antivirus_bridge.dart';
import '../utils/defs_loader.dart';
import '../utils/defs_manager.dart';

class AvEngine {
  static Future<int>? _initFuture;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static void prewarm() {
    if (_initFuture != null) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      ensureInitialized();
    });
  }

  static Future<int> ensureInitialized() {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _init();
    return _initFuture!;
  }

  static Future<int> _init() async {
    try {
      // These MUST run on the main isolate
      await ensureAntivirusFiles();
      final (defsPath, keyPath) = await DefsManager.ensureLiteDefinitions();

      // Spawn isolate for heavy Rust init
      final result = await _runRustInit(defsPath, keyPath);

      _initialized = (result == 0);
      return result;
    } catch (_) {
      return -1;
    }
  }

  static Future<int> _runRustInit(String defsPath, String keyPath) async {
    final receivePort = ReceivePort();

    await Isolate.spawn<_InitMessage>(
      _rustInitEntry,
      _InitMessage(sendPort: receivePort.sendPort, defsPath: defsPath, keyPath: keyPath),
    );

    return await receivePort.first as int;
  }
}

class _InitMessage {
  final SendPort sendPort;
  final String defsPath;
  final String keyPath;

  _InitMessage({
    required this.sendPort,
    required this.defsPath,
    required this.keyPath,
  });
}

void _rustInitEntry(_InitMessage msg) {
  try {
    final av = AntivirusBridge();
    final code = av.init(msg.defsPath, msg.keyPath);
    av.free();
    msg.sendPort.send(code);
  } catch (_) {
    msg.sendPort.send(-1);
  }
}
