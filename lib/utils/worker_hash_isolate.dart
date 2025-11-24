import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'package:crypto/crypto.dart';

class HashRequest {
  final String path;
  final SendPort reply;
  HashRequest(this.path, this.reply);
}

class HashWorker {
  late Isolate _iso;
  late SendPort _send;
  final _controller = StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get stream => _controller.stream;

  Future<void> start() async {
    final receive = ReceivePort();
    _iso = await Isolate.spawn(_entry, receive.sendPort);
    _send = await receive.first;
  }

  void hash(String path) {
    final port = ReceivePort();
    _send.send(HashRequest(path, port.sendPort));
    port.listen((res) {
      _controller.add(res as Map<String, String>);
      port.close();
    });
  }

  static void _entry(SendPort sendBack) {
    final port = ReceivePort();
    sendBack.send(port.sendPort);

    port.listen((msg) {
      final req = msg as HashRequest;
      try {
        final bytes = File(req.path).readAsBytesSync();
        final md5h = md5.convert(bytes).toString();
        final sha = sha256.convert(bytes).toString();
        req.reply.send({'md5': md5h, 'sha': sha});
      } catch (_) {
        req.reply.send({'md5': '', 'sha': ''});
      }
    });
  }
}
