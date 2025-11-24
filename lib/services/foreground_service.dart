import 'package:flutter/services.dart';

import 'package:flutter/services.dart';

class ForegroundService {
  static const _channel = MethodChannel('colourswift/foreground_service');

  static Future<void> start({
    String title = 'CS Security',
    String text = 'Realtime protection active',
  }) async {
    try {
      await _channel.invokeMethod('startService', {
        'title': title,
        'text': text,
      });
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopService');
    } catch (_) {}
  }

  static Future<void> notify({
    required String title,
    required String text,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'text': text,
      });
    } catch (_) {}
  }
}
