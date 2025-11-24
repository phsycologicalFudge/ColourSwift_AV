import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import '../widgets/antivirus_bridge.dart';

class ScanRequest {
  final String path;
  final SendPort reply;
  ScanRequest(this.path, this.reply);
}

class ScanWorker {
  late Isolate _iso;
  late SendPort _send;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Future<void> start() async {
    final receive = ReceivePort();
    _iso = await Isolate.spawn(_entry, receive.sendPort);
    _send = await receive.first;
  }

  void scan(String path) {
    final port = ReceivePort();
    _send.send(ScanRequest(path, port.sendPort));
    port.listen((res) {
      _controller.add(res as Map<String, dynamic>);
      port.close();
    });
  }

  static void _entry(SendPort sendBack) {
    final port = ReceivePort();
    sendBack.send(port.sendPort);

    port.listen((msg) {
      final req = msg as ScanRequest;
      try {
        final bridge = AntivirusBridge();
        final raw = bridge.scanFile(req.path);
        final decoded = jsonDecode(raw);
        req.reply.send(decoded);
      } catch (_) {
        req.reply.send({'hits': {}});
      }
    });
  }
}
