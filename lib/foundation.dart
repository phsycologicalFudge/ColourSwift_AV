import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/antivirus_bridge.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  bool _scanning = false;
  int scanned = 0;
  int infected = 0;
  final List<Map<String, dynamic>> _results = [];
  late AnimationController _pulseController;
  final _bridge = AntivirusBridge();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required')),
      );
      return;
    }

    setState(() {
      _scanning = true;
      scanned = 0;
      infected = 0;
      _results.clear();
    });

    // Collect files first
    final List<String> files = [];
    final root = Directory('/storage/emulated/0');
    if (root.existsSync()) {
      for (final e in root.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          final path = e.path.toLowerCase();
          if (!path.contains('/android/obb') && !path.endsWith('.tmp') && !path.endsWith('.log')) {
            files.add(e.path);
          }
        }
      }
    }

    // Add APKs
    try {
      final result = await Process.run('pm', ['list', 'packages', '-f']);
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split('\n')) {
          if (line.contains('.apk')) {
            final path = line.split('=').first.replaceFirst('package:', '').trim();
            if (File(path).existsSync()) files.add(path);
          }
        }
      }
    } catch (_) {}

    // Split into batches and scan
    for (final path in files.take(5000)) {
      final result = await compute(_scanFileTask, path);
      scanned++;
      if (result['infected']) infected++;
      _results.add(result);
      if (mounted) setState(() {});
    }

    _bridge.free();
    setState(() => _scanning = false);
  }

  static Map<String, dynamic> _scanFileTask(String path) {
    final bridge = AntivirusBridge();
    final res = bridge.scanFile(path);
    final infected = res.contains('infected') || res.contains('malware');
    return {'path': path, 'result': res, 'infected': infected};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'System Scan',
          style: text.titleLarge?.copyWith(color: text.bodyLarge?.color, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: theme.iconTheme.color),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _scanning
              ? _buildScanningView(theme, text)
              : _results.isEmpty
              ? _buildIdleView(theme, text)
              : _buildResultsView(theme, text),
        ),
      ),
    );
  }

  Widget _buildIdleView(ThemeData theme, TextTheme text) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 90),
        const SizedBox(height: 20),
        Text('Ready to Scan', style: text.titleLarge?.copyWith(color: text.bodyLarge?.color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('Tap below to scan your device', style: text.bodySmall?.copyWith(color: text.bodySmall?.color?.withOpacity(0.8))),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _startScan,
          child: const Text('Start Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _buildScanningView(ThemeData theme, TextTheme text) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * 0.1);
          final glowOpacity = 0.4 + (_pulseController.value * 0.3);
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(glowOpacity),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(Icons.shield, color: theme.colorScheme.primary, size: 100),
            ),
          );
        },
      ),
      const SizedBox(height: 35),
      Text('Scanning...', style: text.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      Text('$scanned files scanned', style: text.bodySmall?.copyWith(color: text.bodySmall?.color?.withOpacity(0.8))),
      const SizedBox(height: 6),
      Text('$infected threats found', style: text.bodySmall?.copyWith(color: Colors.redAccent)),
      const SizedBox(height: 25),
      const LinearProgressIndicator(minHeight: 5),
    ],
  );

  Widget _buildResultsView(ThemeData theme, TextTheme text) {
    final safe = infected == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: safe ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(safe ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: safe ? Colors.greenAccent : Colors.redAccent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  safe ? 'No threats found. Your device is secure.' : '$infected potential threats detected.',
                  style: text.bodyMedium?.copyWith(color: text.bodyMedium?.color, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final r = _results[i];
              final isThreat = r['infected'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isThreat ? Colors.redAccent.withOpacity(0.4) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(isThreat ? Icons.dangerous : Icons.insert_drive_file,
                        color: isThreat ? Colors.redAccent : theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r['path'].split('/').last,
                          style: text.bodyMedium?.copyWith(color: text.bodyMedium?.color, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startScan,
            child: const Text('Rescan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
