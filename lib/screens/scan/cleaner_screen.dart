import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:device_apps/device_apps.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'detail_screen.dart'; // reuses your existing file-list viewer
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

// ===== If your _fmtBytes(bytes) helper lives elsewhere, keep using that one. =====
String _fmtBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
}

// ===== MAIN SCREEN =====
class CleanerScreen extends StatefulWidget {
  const CleanerScreen({super.key});

  @override
  State<CleanerScreen> createState() => _CleanerScreenState();
}

class _CleanerScreenState extends State<CleanerScreen> {
  // UI state
  bool scanning = false;
  double progress = 0.0; // 0..1
  String status = 'Ready';

  // Results (files)
  List<File> dupFiles = [];        // flattened duplicates (all files that are part of duplicate groups)
  int dupReclaimBytes = 0;         // potential reclaimable bytes (sum of sizes except 1 per group)

  List<File> oldPhotos = [];
  int oldPhotosBytes = 0;

  List<File> oldVideos = [];
  int oldVideosBytes = 0;

  List<File> largeFiles = [];
  int largeFilesBytes = 0;

  // Results (apps)
  bool appsLoading = false;
  List<Application> unusedApps = [];


  // Start: isolate for files, then apps on UI isolate
  Future<void> _runCleaner() async {
    if (scanning) return;
    final hasUsagePerm = await UsageStats.checkUsagePermission() ?? false;
    if (!hasUsagePerm) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Grant Usage Access'),
          content: const Text(
            'To detect unused apps, this cleaner requires Usage Access permission. '
                'You’ll be redirected to system settings to enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (go == true) {
        await UsageStats.grantUsagePermission();
        return; // stop scanning, user will try again after granting
      }
    }
    setState(() {
      scanning = true;
      progress = 0.0;
      status = 'Starting…';

      // reset results
      dupFiles.clear();
      dupReclaimBytes = 0;
      oldPhotos.clear();
      oldPhotosBytes = 0;
      oldVideos.clear();
      oldVideosBytes = 0;
      largeFiles.clear();
      largeFilesBytes = 0;

      appsLoading = false;
      unusedApps.clear();
    });

    final rp = ReceivePort();
    Isolate? iso;

    try {
      // Spawn the worker isolate for the 4 file categories
      iso = await Isolate.spawn<_WorkerArgs>(
        _scanWorkerEntry,
        _WorkerArgs(
          port: rp.sendPort,
          rootPath: '/storage/emulated/0/',
          maxFiles: 12000,
          oldDays: 90,
          largeFileMinBytes: 20 * 1024 * 1024, // 20MB
          photoMinBytes: 5 * 1024 * 1024,      // 5MB
          videoMinBytes: 10 * 1024 * 1024,     // 10MB
        ),
        errorsAreFatal: true,
      );

      final completer = Completer<Map<String, dynamic>>();
      final sub = rp.listen((msg) {
        if (msg is Map) {
          final type = msg['type'];
          if (type == 'progress') {
            final double pct = (msg['percent'] as num?)?.toDouble() ?? 0.0;
            final int stage = msg['stage'] as int? ?? 0;
            final String label = msg['label'] as String? ?? 'Scanning…';

            // Map 4 stages across 0..1 (25% each)
            setState(() {
              final stageBase = (stage - 1).clamp(0, 3) * 0.25;
              progress = (stageBase + (pct * 0.25)).clamp(0.0, 0.99);
              status = label;
            });
          } else if (type == 'done') {
            if (!completer.isCompleted) {
              completer.complete((msg['result'] as Map).cast<String, dynamic>());
            }
          }
        }
      });

      final result = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => <String, dynamic>{
          'dupFiles': <String>[],
          'dupReclaimBytes': 0,
          'oldPhotos': <String>[],
          'oldPhotosBytes': 0,
          'oldVideos': <String>[],
          'oldVideosBytes': 0,
          'largeFiles': <String>[],
          'largeFilesBytes': 0,
        },
      );

      await sub.cancel();

      // Rehydrate File objects on UI isolate
      setState(() {
        dupFiles = (result['dupFiles'] as List).cast<String>().map((e) => File(e)).toList();
        dupReclaimBytes = (result['dupReclaimBytes'] as num).toInt();

        oldPhotos = (result['oldPhotos'] as List).cast<String>().map((e) => File(e)).toList();
        oldPhotosBytes = (result['oldPhotosBytes'] as num).toInt();

        oldVideos = (result['oldVideos'] as List).cast<String>().map((e) => File(e)).toList();
        oldVideosBytes = (result['oldVideosBytes'] as num).toInt();

        largeFiles = (result['largeFiles'] as List).cast<String>().map((e) => File(e)).toList();
        largeFilesBytes = (result['largeFilesBytes'] as num).toInt();

        // Mark file scanning complete visually
        progress = 1.0;
        status = 'Files scanned';
        scanning = false; // cards can activate now (for the 4 file categories)
      });

      setState(() {
        appsLoading = true;
        status = 'Finding unused apps…';
      });

      final apps = await _scanUnusedApps();

      setState(() {
        unusedApps = apps;
        appsLoading = false;
        status = 'Complete';
      });
    } catch (e) {
      setState(() {
        scanning = false;
        appsLoading = false;
        status = 'Scan error';
      });
      debugPrint('Cleaner: scan error $e');
    } finally {
      rp.close();
      iso?.kill(priority: Isolate.immediate);
    }
  }

  Future<bool> ensureStoragePermission(BuildContext context) async {
    bool granted = false;

    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

      if (sdk >= 30) {
        // Android 11+ → MANAGE_EXTERNAL_STORAGE
        final status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          try {
            const channel = MethodChannel('colourswift/permissions');
            await channel.invokeMethod('openManageAllFilesSettings');
          } catch (_) {
            // Fallback if device lacks the activity (rare)
            await openAppSettings();
          }
        }
        granted = await Permission.manageExternalStorage.request().isGranted;
      } else {
        // Android 10 and below → regular storage permission
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          granted = result.isGranted;
        } else {
          granted = true;
        }
      }
    } else {
      granted = true;
    }

    return granted;
  }


  // Unused apps (UI isolate)
  Future<List<Application>> _scanUnusedApps() async {
    try {
      final has = await UsageStats.checkUsagePermission() ?? false;
      if (!has) {
        // Don’t interrupt flow — just return empty; user can grant later in info dialog
        return [];
      }
      final stats = await UsageStats.queryUsageStats(
        DateTime.now().subtract(const Duration(days: 30)),
        DateTime.now(),
      );
      if (stats.isEmpty) return [];

      final usedPkgs = stats.map((e) => e.packageName).toSet();
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
      );
      return apps.where((a) => !usedPkgs.contains(a.packageName)).toList();
    } catch (_) {
      return [];
    }
  }

  // Navigation helpers
  void _openFiles(String title, List<File> files) {
    if (files.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CleanerDetailScreen(title: title, files: files)),
    );
  }

  void _openUnusedApps() {
    if (unusedApps.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UnusedAppsScreen(apps: unusedApps),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = text.bodySmall?.color?.withOpacity(0.7);

    final filesScanning = scanning;
    final appsBusy = appsLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Cleaner Pro')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header + button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ready to Scan',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                FilledButton.icon(
                  onPressed: filesScanning || appsBusy
                      ? null
                      : () async {
                    final ok = await ensureStoragePermission(context);
                    if (ok) {
                      await _runCleaner();
                    }
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(filesScanning || appsBusy ? 'Scanning…' : 'Scan'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (filesScanning || appsBusy) ? progress : 1.0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                (filesScanning || appsBusy) ? status : 'Ready',
                style: TextStyle(color: muted),
              ),
            ),
            const SizedBox(height: 16),

            // Cards
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _card(
                    title: 'Duplicates',
                    enabled: !filesScanning,
                    subtitle: dupFiles.isEmpty
                        ? 'No duplicates found'
                        : '${dupFiles.length} items • reclaim ${_fmtBytes(dupReclaimBytes)}',
                    trailing:
                    dupReclaimBytes > 0 ? Text(_fmtBytes(dupReclaimBytes)) : null,
                    onTap: () => _openFiles('Duplicates', dupFiles),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Old Photos',
                    enabled: !filesScanning,
                    subtitle: oldPhotos.isEmpty
                        ? 'No photos older than 90 days'
                        : '${oldPhotos.length} items • ${_fmtBytes(oldPhotosBytes)}',
                    trailing: oldPhotosBytes > 0
                        ? Text(_fmtBytes(oldPhotosBytes))
                        : null,
                    onTap: () => _openFiles('Old Photos', oldPhotos),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Old Videos',
                    enabled: !filesScanning,
                    subtitle: oldVideos.isEmpty
                        ? 'No videos older than 90 days'
                        : '${oldVideos.length} items • ${_fmtBytes(oldVideosBytes)}',
                    trailing: oldVideosBytes > 0
                        ? Text(_fmtBytes(oldVideosBytes))
                        : null,
                    onTap: () => _openFiles('Old Videos', oldVideos),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Large Files',
                    enabled: !filesScanning,
                    subtitle: largeFiles.isEmpty
                        ? 'No files ≥ 5 MB'
                        : '${largeFiles.length} items • ${_fmtBytes(largeFilesBytes)}',
                    trailing: largeFilesBytes > 0
                        ? Text(_fmtBytes(largeFilesBytes))
                        : null,
                    onTap: () => _openFiles('Large Files', largeFiles),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Unused Apps',
                    enabled: !(filesScanning || appsBusy),
                    subtitle: appsBusy
                        ? 'Scanning apps…'
                        : (unusedApps.isEmpty
                        ? 'No unused apps (last 30 days)'
                        : '${unusedApps.length} apps'),
                    trailing: unusedApps.isNotEmpty
                        ? Text('${unusedApps.length}')
                        : null,
                    onTap: _openUnusedApps,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required bool enabled,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    IconData innerIcon;
    switch (title) {
      case 'Duplicates':
        innerIcon = Icons.copy_rounded;
        break;
      case 'Old Photos':
        innerIcon = Icons.photo_rounded;
        break;
      case 'Old Videos':
        innerIcon = Icons.play_arrow_rounded;
        break;
      case 'Large Files':
        innerIcon = Icons.description_rounded;
        break;
      case 'Unused Apps':
        innerIcon = Icons.apps_rounded;
        break;
      default:
        innerIcon = Icons.insert_drive_file_rounded;
    }

    final folderColor =
    enabled ? theme.colorScheme.primary : theme.disabledColor;

    return InkWell(
      onTap: enabled && onTap != null ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.folder_rounded,
                    size: 40,
                    color: folderColor.withOpacity(enabled ? 0.9 : 0.5)),
                Icon(innerIcon,
                    size: 18,
                    color: Colors.white.withOpacity(enabled ? 0.95 : 0.4)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? text.titleMedium?.color
                          : theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: enabled
                          ? text.bodySmall?.color
                          : theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              DefaultTextStyle(
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? text.bodyLarge?.color
                      : theme.disabledColor,
                ) ??
                    const TextStyle(),
                child: trailing,
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: enabled ? theme.iconTheme.color : theme.disabledColor),
          ],
        ),
      ),
    );
  }
}

// ===== WORKER (Isolate) =====

class _WorkerArgs {
  final SendPort port;
  final String rootPath;
  final int maxFiles;
  final int oldDays;
  final int largeFileMinBytes;
  final int photoMinBytes;
  final int videoMinBytes;

  _WorkerArgs({
    required this.port,
    required this.rootPath,
    required this.maxFiles,
    required this.oldDays,
    required this.largeFileMinBytes,
    required this.photoMinBytes,
    required this.videoMinBytes,
  });
}

void _scanWorkerEntry(_WorkerArgs args) async {
  final send = args.port;
  final now = DateTime.now();

  // Buckets (paths-only)
  final dupGroups = <String, List<String>>{}; // key -> list of paths (duplicates)
  int dupReclaimBytes = 0;

  final oldPhotos = <String>[];
  int oldPhotosBytes = 0;

  final oldVideos = <String>[];
  int oldVideosBytes = 0;

  final largeFiles = <String>[];
  int largeFilesBytes = 0;

  // Helper: quick size
  int _size(File f) {
    try { return f.lengthSync(); } catch (_) { return 0; }
  }

  // Helper: walk directories with cap, skipping /Android and trash folders
  Future<void> _walk(
      Directory dir, {
        required void Function(File f) onFile,
        required int cap,
        required void Function(int processed, int totalGuess)? onProgress,
      }) async {
    int processed = 0;
    const totalGuess = 4000; // fuzzy for progress maths
    final q = <Directory>[];

    const trashMarkers = [
      '/.trash',
      '/.trash-',
      '/.recyclebin',
      '/.recycle_bin',
      '/.recycle/',
      '/.thumbnails',
      '/.temp/',
      '/.cache/',
      '/trash/',
      '/recycle/',
      '/recycler/',
      '/.deleted/',
      '/.GalleryTrash/',
      '/Android/data/com.android.gallery3d/files/.trash/',
    ];

    if (await dir.exists()) q.add(dir);

    while (q.isNotEmpty) {
      final d = q.removeLast();
      try {
        await for (final e in d.list(followLinks: false)) {
          if (processed >= cap) break;

          if (e is Directory) {
            // skip restricted and trash dirs
            final lower = e.path.toLowerCase();
            if (lower.contains('/android/')) continue;
            if (trashMarkers.any((t) => lower.contains(t))) continue;
            q.add(e);
          } else if (e is File) {
            final path = e.path.toLowerCase();
            if (trashMarkers.any((t) => path.contains(t))) continue;

            onFile(e);
            processed++;
            if (processed % 150 == 0 && onProgress != null) {
              onProgress(processed, totalGuess);
            }
          }
        }
      } catch (_) {
        // unreadable—skip
      }
      if (processed >= cap) break;
    }
    if (onProgress != null) onProgress(processed, totalGuess);
  }

  Future<void> _stage(
      int stageNum,
      String labelStart,
      Future<void> Function() body,
      ) async {
    send.send({'type': 'progress', 'stage': stageNum, 'percent': 0.02, 'label': labelStart});
    await body();
    send.send({'type': 'progress', 'stage': stageNum, 'percent': 1.0, 'label': '$labelStart Done'});
  }

  // Stage 1: Duplicates (size + first 32 KB fingerprint)
  await _stage(1, 'Scanning duplicates…', () async {
    final root = Directory(args.rootPath);

    Future<String?> _fingerprint(File f) async {
      try {
        final raf = f.openSync(mode: FileMode.read);
        final len = raf.lengthSync();
        final toRead = len < 32768 ? len : 32768;
        final bytes = raf.readSync(toRead);
        raf.closeSync();
        // Lightweight fingerprint: size + first chunk hash
        final h = bytes.fold<int>(0, (a, b) => (a * 131 + b) & 0x7fffffff);
        return '${len}_$h';
      } catch (_) {
        return null;
      }
    }

    await _walk(
      root,
      onFile: (f) {
        final ext = p.extension(f.path).toLowerCase();
        // target common media/docs to keep it fast
        const ok = {
          '.jpg', '.jpeg', '.png', '.gif',
          '.mp4', '.mov', '.mkv',
          '.mp3', '.wav', '.flac',
          '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.zip', '.7z', '.rar',
        };
        if (!ok.contains(ext)) return;
      },
      cap: args.maxFiles,
      onProgress: (processed, total) async {
        // Use processed to pseudo-progress; real grouping happens after
        send.send({'type': 'progress', 'stage': 1, 'percent': (processed / total).clamp(0.05, 0.98), 'label': 'Scanning duplicates…'});
      },
    );

    // Second pass: actual grouping (iterate root again but do minimal I/O)
    int processed = 0;
    await _walk(
      Directory(args.rootPath),
      onFile: (f) async {
        final ext = p.extension(f.path).toLowerCase();
        const ok = {
          '.jpg', '.jpeg', '.png', '.gif',
          '.mp4', '.mov', '.mkv',
          '.mp3', '.wav', '.flac',
          '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.zip', '.7z', '.rar',
        };
        if (!ok.contains(ext)) return;

        final fp = await _fingerprint(f);
        if (fp == null) return;
        (dupGroups[fp] ??= <String>[]).add(f.path);

        processed++;
        if (processed % 200 == 0) {
          send.send({'type': 'progress', 'stage': 1, 'percent': 0.6, 'label': 'Grouping duplicates…'});
        }
      },
      cap: args.maxFiles,
      onProgress: null,
    );

    // Compute reclaimable bytes & flatten list
    final dupFiles = <String>[];
    dupReclaimBytes = 0;
    dupGroups.forEach((_, paths) {
      if (paths.length >= 2) {
        final pairs = <MapEntry<int, String>>[];
        for (final pth in paths) {
          pairs.add(MapEntry(_size(File(pth)), pth));
        }

        // Sort by size ascending
        pairs.sort((a, b) => a.key.compareTo(b.key));

        // Keep the last (largest), mark others as duplicates
        for (var i = 0; i < pairs.length - 1; i++) {
          dupFiles.add(pairs[i].value);
        }

        if (pairs.isNotEmpty) {
          final total = pairs.fold<int>(0, (a, b) => a + b.key);
          final keep = pairs.last.key;
          dupReclaimBytes += (total - keep);
        }
      }
    });

    // Stash dup files into the sendable result store — we’ll attach in final payload
    _stageStore['dupFiles'] = dupFiles;
    _stageStore['dupReclaimBytes'] = dupReclaimBytes;
  });

  // Stage 2: Old Photos
  await _stage(2, 'Scanning old photos…', () async {
    final root = Directory(args.rootPath);
    final photosExt = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'};

    await _walk(
      root,
      onFile: (f) {
        final ext = p.extension(f.path).toLowerCase();
        if (!photosExt.contains(ext)) return;

        try {
          final st = f.statSync();
          final ageDays = now.difference(st.modified).inDays;
          if (ageDays >= args.oldDays && st.size >= args.photoMinBytes) {
            oldPhotos.add(f.path);
            oldPhotosBytes += st.size;
          }
        } catch (_) {}
      },
      cap: args.maxFiles,
      onProgress: (processed, total) {
        send.send({
          'type': 'progress',
          'stage': 2,
          'percent': (processed / total).clamp(0.05, 0.98),
          'label': 'Old photos: ${oldPhotos.length} • ${_fmtBytes(oldPhotosBytes)}',
        });
      },
    );
  });

  // Stage 3: Old Videos
  await _stage(3, 'Scanning old videos…', () async {
    final root = Directory(args.rootPath);
    final videoExt = {'.mp4', '.mov', '.mkv', '.avi', '.webm'};

    await _walk(
      root,
      onFile: (f) {
        final ext = p.extension(f.path).toLowerCase();
        if (!videoExt.contains(ext)) return;

        try {
          final st = f.statSync();
          final ageDays = now.difference(st.modified).inDays;
          if (ageDays >= args.oldDays && st.size >= args.videoMinBytes) {
            oldVideos.add(f.path);
            oldVideosBytes += st.size;
          }
        } catch (_) {}
      },
      cap: args.maxFiles,
      onProgress: (processed, total) {
        send.send({
          'type': 'progress',
          'stage': 3,
          'percent': (processed / total).clamp(0.05, 0.98),
          'label': 'Old videos: ${oldVideos.length} • ${_fmtBytes(oldVideosBytes)}',
        });
      },
    );
  });

  // Stage 4: Large Files (≥ 5 MB, excluding photos/videos)
  await _stage(4, 'Scanning large files…', () async {
    final root = Directory(args.rootPath);
    final photosExt = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'};
    final videoExt = {'.mp4', '.mov', '.mkv', '.avi', '.webm'};

    await _walk(
      root,
      onFile: (f) {
        try {
          final st = f.statSync();
          if (st.size >= args.largeFileMinBytes) {
            final ext = p.extension(f.path).toLowerCase();
            if (!photosExt.contains(ext) && !videoExt.contains(ext)) {
              largeFiles.add(f.path);
              largeFilesBytes += st.size;
            }
          }
        } catch (_) {}
      },
      cap: args.maxFiles,
      onProgress: (processed, total) {
        send.send({
          'type': 'progress',
          'stage': 4,
          'percent': (processed / total).clamp(0.05, 0.98),
          'label': 'Large files: ${largeFiles.length} • ${_fmtBytes(largeFilesBytes)}',
        });
      },
    );
  });

  // Final payload
  send.send({
    'type': 'done',
    'result': {
      'dupFiles': (_stageStore['dupFiles'] as List<String>? ?? const <String>[]),
      'dupReclaimBytes': _stageStore['dupReclaimBytes'] ?? 0,
      'oldPhotos': oldPhotos,
      'oldPhotosBytes': oldPhotosBytes,
      'oldVideos': oldVideos,
      'oldVideosBytes': oldVideosBytes,
      'largeFiles': largeFiles,
      'largeFilesBytes': largeFilesBytes,
    }
  });
}

// Stage store for duplicates between closures in the worker
final Map<String, Object> _stageStore = {};

// ===== Minimal Unused Apps viewer (keeps you independent of other files) =====
class UnusedAppsScreen extends StatelessWidget {
  final List<Application> apps;
  const UnusedAppsScreen({super.key, required this.apps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unused Apps')),
      body: apps.isEmpty
          ? const Center(child: Text('No unused apps in last 30 days'))
          : ListView.separated(
        itemCount: apps.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final a = apps[i];
          return ListTile(
            leading: const Icon(Icons.apps_rounded),
            title: Text(a.appName),
            subtitle: Text(a.packageName, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () {
                try { DeviceApps.openApp(a.packageName); } catch (_) {}
              },
            ),
            onLongPress: () {
              try { DeviceApps.uninstallApp(a.packageName); } catch (_) {}
            },
          );
        },
      ),
    );
  }
}
