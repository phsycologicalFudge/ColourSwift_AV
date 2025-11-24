import 'dart:developer' as dev;

class AvServiceManager {
  static bool _isRunning = true;

  static Future<void> startProtection() async {
    dev.log('Starting ColourSwift AV services...');
    // Future: start isolates, network monitoring, VPN tunnel, etc.
    _isRunning = true;
    await Future.delayed(const Duration(milliseconds: 500));
    dev.log('AV services started.');
  }

  static Future<void> stopProtection() async {
    dev.log('Stopping ColourSwift AV services...');
    // Future: terminate background isolates, stop VPN, disable monitors.
    _isRunning = false;
    await Future.delayed(const Duration(milliseconds: 500));
    dev.log('AV services stopped.');
  }

  static bool get isRunning => _isRunning;
}
