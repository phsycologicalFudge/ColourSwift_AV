import 'dart:isolate';
import 'dart:io';
import '../widgets/antivirus_bridge.dart';

class ScanParams {
  final String dirPath;
  ScanParams(this.dirPath);
}

class ScanResult {
  final String path;
  final String result;
  ScanResult(this.path, this.result);
}

void scanWorker(SendPort sendPort) async {
  final bridge = AntivirusBridge();
  final receive = ReceivePort();
  sendPort.send(receive.sendPort);

  await for (final message in receive) {
    if (message is ScanParams) {
      final dir = Directory(message.dirPath);
      if (dir.existsSync()) {
        for (final f in dir.listSync(recursive: false)) {
          if (f is File) {
            final res = bridge.scanFile(f.path);
            sendPort.send(ScanResult(f.path, res));
          }
        }
      }
      sendPort.send('done');
    }
  }
}
