import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cache_manager.dart';
import '../services/cloud_helper_service.dart';
import '../services/exclusion_service.dart';
import '../services/quarantine_service.dart';
import '../widgets/antivirus_bridge.dart';
import 'exclusions/exclusion_manager_screen.dart';

class LogBuffer {
  static final List<String> _messages = [];
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void add(String msg) {
    final now = DateTime.now();
    final time = "${now.hour}:${now.minute}:${now.second}";
    _messages.add('[$time] $msg');
    if (_messages.length > 300) _messages.removeAt(0);
    notifier.value++;
  }

  static List<String> get all => List.unmodifiable(_messages);

  static void clear() {
    _messages.clear();
    notifier.value++;
  }
}

enum ScanMode { none, smart, single, rapid }
enum ScanState { idle, scanning, result, empty }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class HashWorker {
  final ReceivePort _receive;
  final SendPort sendPort;

  HashWorker._(this._receive, this.sendPort);

  static Future<HashWorker> spawn() async {
    final receive = ReceivePort();
    await Isolate.spawn(_entry, receive.sendPort);
    final send = await receive.first as SendPort;
    return HashWorker._(receive, send);
  }

  static void _entry(SendPort root) {
    final port = ReceivePort();
    root.send(port.sendPort);

    port.listen((msg) {
      final send = msg[0] as SendPort;
      final path = msg[1] as String;

      try {
        final bytes = File(path).readAsBytesSync();
        final md5h = md5.convert(bytes).toString();
        final sha = sha256.convert(bytes).toString();
        send.send({'md5': md5h, 'sha': sha});
      } catch (_) {
        send.send({'md5': '', 'sha': ''});
      }
    });
  }

  Future<Map<String, String>> hash(String path) async {
    final port = ReceivePort();
    sendPort.send([port.sendPort, path]);
    return await port.first as Map<String, String>;
  }
}

class ScanWorker {
  final ReceivePort _receive;
  final SendPort sendPort;

  ScanWorker._(this._receive, this.sendPort);

  static Future<ScanWorker> spawn() async {
    final receive = ReceivePort();
    await Isolate.spawn(_entry, receive.sendPort);
    final send = await receive.first as SendPort;
    return ScanWorker._(receive, send);
  }

  static void _entry(SendPort root) {
    final port = ReceivePort();
    root.send(port.sendPort);

    port.listen((msg) {
      final send = msg[0] as SendPort;
      final path = msg[1] as String;

      try {
        final bridge = AntivirusBridge();
        final raw = bridge.scanFile(path);
        final decoded = jsonDecode(raw);
        final hits = decoded['hits'] as Map?;
        send.send(hits != null && hits.isNotEmpty);
      } catch (_) {
        send.send(false);
      }
    });
  }

  Future<bool> scan(String path) async {
    final port = ReceivePort();
    sendPort.send([port.sendPort, path]);
    return await port.first as bool;
  }
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool useCloudScan = false;
  late final CloudScanner cloudScanner;

  ScanMode mode = ScanMode.none;
  ScanState state = ScanState.idle;

  final ScrollController _logScroll = ScrollController();

  bool cancelled = false;
  int scanned = 0;
  int total = 0;
  String currentFile = '';
  String rustStatus = '';
  List<String> clean = [];
  List<String> infected = [];
  bool? singleResult;

  late AnimationController _pulse;

  String computeFileSha256(String path) {
    final bytes = File(path).readAsBytesSync();
    return sha256.convert(bytes).toString();
  }

  String computeFileMd5(String path) {
    final bytes = File(path).readAsBytesSync();
    return md5.convert(bytes).toString();
  }

  Future<Map<String, String>> _hashFile(String path) async {
    return await compute(_hashFileIsolate, path);
  }

  void _openExclusionPopup() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SizedBox(
          height: 240,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Exclude a Folder'),
                onTap: () async {
                  Navigator.pop(context);
                  final r = await FilePicker.platform.getDirectoryPath();
                  if (r != null) {
                    final x = ExclusionService();
                    await x.load();
                    await x.addFolder(r);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_copy),
                title: const Text('Exclude a File'),
                onTap: () async {
                  Navigator.pop(context);
                  final r = await FilePicker.platform.pickFiles();
                  if (r != null && r.files.isNotEmpty) {
                    final p = r.files.single.path!;
                    final bytes = File(p).readAsBytesSync();
                    final sha = sha256.convert(bytes).toString();
                    final x = ExclusionService();
                    await x.load();
                    await x.addSha(sha);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('See Exclusion List'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExclusionManagerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _safeScrollToEnd() {
    if (!_logScroll.hasClients) return;
    final position = _logScroll.position;
    if (!position.hasPixels) return;
    _logScroll.jumpTo(position.maxScrollExtent);
  }

  Future<void> _loadCloudToggle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useCloudScan = prefs.getBool('useCloudScan') ?? false;
    });
  }

  void _showCloudInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cloud Scan Info'),
          content: const Text(
            'When cloud-assisted scanning is enabled, only two cryptographic '
                'hashes are sent per file:\n\n'
                ' • MD5\n'
                ' • SHA-256\n\n'
                'No filenames, file contents, or personal data are uploaded.\n'
                'These hashes are compared against known threats '
                'in the ColourSwift database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    cloudScanner = CloudScanner(
      endpoint: 'https://efkou1u21ooih2hko.colourswift.com',
      apiKey: '23JVO3ojo23oO3O423rrTR',
    );

    _loadCloudToggle();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  double get progress => total == 0 ? 0 : scanned / total;

  Future<void> _startScan(ScanMode m) async {
    if (state == ScanState.scanning) return;

    setState(() {
      mode = m;
      state = ScanState.scanning;
      cancelled = false;
      scanned = 0;
      total = 0;
      currentFile = '';
      clean.clear();
      infected.clear();
      singleResult = null;
    });

    LogBuffer.clear();
    LogBuffer.add('[SCAN INIT] ${m.name} started...');

    switch (m) {
      case ScanMode.smart:
        await _runSmartScan();
        break;
      case ScanMode.rapid:
        await _runRapidScan();
        break;
      case ScanMode.single:
        await _runSingleScan();
        break;
      default:
        break;
    }
  }

  Future<void> _checkAndStart(ScanMode m) async {
    if (m == ScanMode.single) {
      await _startScan(m);
      return;
    }

    bool granted = false;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final sdk = info.version.sdkInt;

      if (sdk >= 30) {
        try {
          var status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            const platform = MethodChannel('colourswift/storage_permission');
            await platform.invokeMethod('openManageStorage');
            await Future.delayed(const Duration(seconds: 2));
            status = await Permission.manageExternalStorage.status;
          }
          granted = status.isGranted;
        } catch (e) {
          debugPrint('manageExternalStorage check failed: $e');
          await openAppSettings();
        }
      } else {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          granted = await Permission.storage.request().isGranted;
        } else {
          granted = true;
        }
      }
    } else {
      granted = true;
    }

    if (granted) {
      await _startScan(m);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required to scan files.')),
        );
      }
    }
  }

  String _ext(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  bool _isImage(String ext) {
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic'].contains(ext);
  }


  void logCloud(String msg) {
    LogBuffer.add('[CLOUD] $msg');
  }

  Future<void> _runSmartScan() async {
    final folders = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Documents',
    ];
    final files = <String>[];

    for (final path in folders) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final e in dir.list(recursive: true, followLinks: false)) {
            if (e is File) {
              final x = ExclusionService();
              await x.load();
              if (x.skipFolder(e.path)) continue;
              final ext = _ext(e.path);
              if (!_isImage(ext)) files.add(e.path);
            }
          }
        }
      } catch (e) {
        LogBuffer.add('[ERROR] Skipped restricted: $path ($e)');
      }
    }

    LogBuffer.add('[SCAN READY] ${files.length} files found.');
    files.sort((a, b) {
      try {
        return File(a).lengthSync().compareTo(File(b).lengthSync());
      } catch (_) {
        return 0;
      }
    });

    await _scanFiles(files);
  }

  Future<void> _runRapidScan() async {
    final dir = Directory('/storage/emulated/0/Download');
    final List<String> allPaths = [];

    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              final x = ExclusionService();
              await x.load();
              if (x.skipFolder(entity.path)) continue;
              final ext = _ext(entity.path);
              final size = await entity.length();
              if (_isAllowedFile(ext, size)) allPaths.add(entity.path);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      LogBuffer.add('[ERROR] Directory access failed: $e');
    }

    setState(() => total = allPaths.length);
    LogBuffer.add('[ENGINE] Files enumerated: $total');

    if (total == 0) {
      LogBuffer.add('[ENGINE] No readable files found.');
      if (mounted) setState(() => state = ScanState.empty);
      return;
    }

    await _scanFiles(allPaths);
  }

  Future<void> _runSingleScan() async {
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.isEmpty) {
      setState(() => state = ScanState.idle);
      return;
    }

    final file = res.files.single;
    setState(() => currentFile = file.name);
    LogBuffer.add('[SCAN INIT] Single-file → ${file.path}');
    await Future.delayed(const Duration(milliseconds: 60));

    bool infectedFlag = false;

    final md5h = computeFileMd5(file.path!);
    final sha = computeFileSha256(file.path!);

    if (useCloudScan) {
      logCloud('Sending MD5=$md5h and SHA256=$sha to cloud');
      final hits = await cloudScanner.checkBatch([md5h, sha]);

      if (hits.isNotEmpty) {
        logCloud('Cloud detected this file');
        infectedFlag = true;
      } else {
        logCloud('Cloud returned safe, switching to offline engine');
        infectedFlag = await compute(_scanFileIsolate, file.path!);
      }
    } else {
      infectedFlag = await compute(_scanFileIsolate, file.path!);
    }

    if (infectedFlag) {
      await QuarantineService.quarantineFile(file.path!);
      LogBuffer.add('[THREAT] Malicious file quarantined');
    } else {
      LogBuffer.add('[CLEAN] File safe');
    }

    LogBuffer.add('[SUMMARY] Single-file scan complete');
    await CacheManager.clearAll();

    if (!mounted || cancelled) return;
    setState(() {
      singleResult = infectedFlag;
      state = ScanState.result;
    });
  }

  Future<void> _scanFiles(List<String> files) async {
    total = files.length;
    if (total == 0) {
      LogBuffer.add('[ENGINE] No readable files found.');
      if (mounted) setState(() => state = ScanState.empty);
      return;
    }

    final scanWorker = await ScanWorker.spawn();
    HashWorker? hashWorker;

    final fileHashes = <String, Map<String, String>>{};
    final cloudDetected = <String>{};

    final useCloud = useCloudScan;

    if (useCloud) {
      hashWorker = await HashWorker.spawn();
      LogBuffer.add('[STAGE 1] Computing file hashes...');

      for (int i = 0; i < files.length; i++) {
        if (!mounted || cancelled) return;

        final path = files[i];
        final ex = ExclusionService();
        await ex.load();
        if (ex.skipFolder(path)) continue;
        final name = path.split('/').last;
        final sha = sha256.convert(File(path).readAsBytesSync()).toString();
        if (ex.skipSha(sha)) continue;

        setState(() {
          currentFile = name;
          scanned = i + 1;
        });

        final hashes = await hashWorker.hash(path);
        fileHashes[path] = hashes;
        LogBuffer.add('[HASH] $name');
        _safeScrollToEnd();
      }

      LogBuffer.add('[STAGE 2] Sending batch hash list to cloud...');

      final hashList = <String>[];
      for (final entry in fileHashes.values) {
        final m = entry['md5'] ?? '';
        final s = entry['sha'] ?? '';
        if (m.isNotEmpty) hashList.add(m);
        if (s.isNotEmpty) hashList.add(s);
      }

      final cloudResp = await cloudScanner.checkBatch(hashList);
      for (final match in cloudResp) {
        cloudDetected.add(match);
      }

      LogBuffer.add('[CLOUD] Cloud flagged ${cloudDetected.length} hash matches.');
    }

    LogBuffer.add('[STAGE ${useCloud ? '3' : '1'}] Local scanning files...');

    scanned = 0;
    clean.clear();
    infected.clear();

    for (int i = 0; i < files.length; i++) {
      if (!mounted || cancelled) return;

      final path = files[i];
      final name = path.split('/').last;

      setState(() {
        currentFile = name;
        scanned = i + 1;
      });

      bool infectedFlag = false;

      if (useCloud) {
        final hashes = fileHashes[path];
        if (hashes != null) {
          final md5h = hashes['md5'] ?? '';
          final sha = hashes['sha'] ?? '';
          if (cloudDetected.contains(md5h) || cloudDetected.contains(sha)) {
            infectedFlag = true;
            LogBuffer.add('[CLOUD HIT] $name');
          }
        }
      }

      if (!infectedFlag) {
        infectedFlag = await scanWorker.scan(path);
      }

      if (infectedFlag) {
        infected.add(path);
        try {
          await QuarantineService.quarantineFile(path);
          LogBuffer.add('[THREAT] Quarantined $name');
        } catch (_) {}
      } else {
        clean.add(path);
        LogBuffer.add('[CLEAN] $name');
      }

      _safeScrollToEnd();
    }

    LogBuffer.add('[SUMMARY] ${infected.length} suspicious • ${clean.length} clean');

    if (!mounted || cancelled) return;

    await CacheManager.clearAll();
    setState(() => state = ScanState.result);
  }

  static bool _isAllowedFile(String ext, int size) {
    const allowed = ['apk', 'zip', 'pdf', 'txt', 'md', 'pdf', 'exe'];
    const skip = ['mp3', 'rar', 'mp4', 'm4a', 'mov', 'jpg', 'jpeg', 'png', '7z'];
    return allowed.contains(ext) && !skip.contains(ext) && size < 100 * 1024 * 1024;
  }

  void _cancelScan() {
    cancelled = true;
    LogBuffer.add('[USER] Scan cancelled');
    setState(() {
      state = ScanState.idle;
      String rustStatus = '';
      currentFile = '';
      scanned = 0;
      total = 0;
    });
  }

  void _reset() {
    setState(() {
      mode = ScanMode.none;
      state = ScanState.idle;
      clean.clear();
      infected.clear();
      scanned = 0;
      total = 0;
      currentFile = '';
      cancelled = false;
    });
  }

  Widget _buildEmpty(ThemeData theme, TextTheme text) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder_off_rounded, size: 70, color: Colors.grey),
        const SizedBox(height: 20),
        Text(
          'No files found to scan',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Try adding files to your Downloads folder.',
          style: text.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 25),
        ElevatedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Return'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Full Device Scan',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _openExclusionPopup,
        child: const Icon(Icons.rule_folder_rounded),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (state) {
            ScanState.idle => _buildIdle(theme, text),
            ScanState.scanning => _buildScanning(theme, text),
            ScanState.result => _buildResult(theme, text),
            ScanState.empty => _buildEmpty(theme, text),
          },
        ),
      ),
    );
  }

  Widget _logBox() {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ValueListenableBuilder(
        valueListenable: LogBuffer.notifier,
        builder: (context, _, __) {
          return ListView.builder(
            itemCount: LogBuffer.all.length,
            itemBuilder: (context, i) {
              return Text(
                LogBuffer.all[i],
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.2,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIdle(ThemeData theme, TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 10),
      Center(
        child: Text(
          'Engine Ready • VX-Titanium-005',
          style: text.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ),
      const SizedBox(height: 40),
      _scanButton(
        color: Colors.greenAccent,
        icon: Icons.shield_rounded,
        title: 'Smart Scan',
        desc: 'Scans your device for threats.',
        onTap: () => _checkAndStart(ScanMode.smart),
      ),
      _scanButton(
        color: Colors.blueAccent,
        icon: Icons.insert_drive_file_rounded,
        title: 'Single File Scan',
        desc: 'Pick and scan a file securely.',
        onTap: () => _checkAndStart(ScanMode.single),
      ),
      _scanButton(
        color: Colors.amberAccent,
        icon: Icons.bolt_rounded,
        title: 'Rapid Scan',
        desc: 'Scans downloads for small files quickly.',
        onTap: () => _checkAndStart(ScanMode.rapid),
      ),
      Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Use cloud-assisted Scan'),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showCloudInfo,
                child: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                value: useCloudScan,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('useCloudScan', v);
                  setState(() => useCloudScan = v);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Widget _buildScanning(ThemeData theme, TextTheme text) {
    final color = switch (mode) {
      ScanMode.smart => Colors.greenAccent,
      ScanMode.single => Colors.blueAccent,
      ScanMode.rapid => Colors.amberAccent,
      _ => theme.colorScheme.primary,
    };

    final icon = switch (mode) {
      ScanMode.smart => Icons.shield_rounded,
      ScanMode.single => Icons.insert_drive_file_rounded,
      ScanMode.rapid => Icons.bolt_rounded,
      _ => Icons.shield_rounded,
    };

    final percent = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Center(child: _glowIcon(icon, color)),
        const SizedBox(height: 25),
        Text(
          'Scanning... $percent%',
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Scanning:',
              style: text.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              currentFile,
              style: text.bodyMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (mode != ScanMode.single)
          LinearProgressIndicator(
            value: progress,
            color: color,
            backgroundColor: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
          ),
        const SizedBox(height: 20),
        _logBox(),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _cancelScan,
          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
          label: const Text(
            'Cancel Scan',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

      ],
    );
  }

  Widget _buildResult(ThemeData theme, TextTheme text) {
    final color = switch (mode) {
      ScanMode.smart => Colors.greenAccent,
      ScanMode.single => Colors.blueAccent,
      ScanMode.rapid => Colors.amberAccent,
      _ => theme.colorScheme.primary,
    };


    if (mode == ScanMode.single && singleResult != null) {
      final safe = !singleResult!;
      final resColor = safe ? Colors.greenAccent : Colors.redAccent;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _glowIcon(
              safe ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
              resColor,
            ),
            const SizedBox(height: 20),
            Text(
              safe ? 'File is Clean' : 'Threats Detected',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: resColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentFile,
              style: text.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _returnButtons(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _glowIcon(Icons.verified_user_rounded, color),
          const SizedBox(height: 25),
          Text(
            'Scan Complete',
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Clean: ${clean.length}',
                style: text.bodyMedium?.copyWith(color: Colors.greenAccent),
              ),
              const SizedBox(width: 15),
              Text(
                'Suspicious: ${infected.length}',
                style: text.bodyMedium?.copyWith(color: Colors.orangeAccent),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _fileColumn('Clean Files', Colors.greenAccent, clean),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fileColumn(
                  'Potentially Dangerous',
                  Colors.orangeAccent,
                  infected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _returnButtons(),
        ],
      ),
    );
  }

  Widget _fileColumn(String title, Color color, List<String> files) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            width: double.infinity,
            child: Center(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, i) {
                final name = files[i].split('/').last;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: color,
                    size: 18,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanButton({
    required Color color,
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: text.bodySmall?.copyWith(
                        color: text.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _returnButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Return to Main'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildIdle(Theme.of(context), Theme.of(context).textTheme),
      ],
    );
  }

  Widget _glowIcon(IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.4 + (_pulse.value * 0.5);
        final scale = 1.0 + (_pulse.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(glow),
                  blurRadius: 45,
                  spreadRadius: 10,
                ),
              ],
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, size: 55, color: color),
          ),
        );
      },
    );
  }
}

Map<String, String> _hashFileIsolate(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    return {
      'md5': md5.convert(bytes).toString(),
      'sha': sha256.convert(bytes).toString(),
    };
  } catch (_) {
    return {'md5': '', 'sha': ''};
  }
}

bool _scanFileIsolate(String path) {
  try {
    final bridge = AntivirusBridge();
    final raw = bridge.scanFile(path);
    final decoded = jsonDecode(raw);
    final hits = decoded['hits'] as Map?;
    return hits != null && hits.isNotEmpty;
  } catch (_) {
    return false;
  }
}
