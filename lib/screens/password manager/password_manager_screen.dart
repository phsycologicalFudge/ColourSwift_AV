import 'dart:convert';
import 'dart:typed_data';

import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/meta_password_service.dart';
import '../../widgets/antivirus_bridge.dart';

class PasswordTestScreen extends StatefulWidget {
  const PasswordTestScreen({super.key});

  @override
  State<PasswordTestScreen> createState() => _PasswordManagerScreenState();
}

class _PasswordManagerScreenState extends State<PasswordTestScreen> {
  final _bridge = AntivirusBridge();
  final _secure = const FlutterSecureStorage();

  String? _metaPassword;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  static const _prefsKey = 'vault_entries';

  @override
  void initState() {
    super.initState();
    _loadVault();
    _loadMetaFromKeystore();
  }

  Future<void> _loadVault() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? [];
    final parsed = <Map<String, dynamic>>[];

    for (final item in rawList) {
      try {
        final map = jsonDecode(item);
        if (map is Map<String, dynamic>) {
          parsed.add(map);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _entries = parsed;
      _loading = false;
    });
  }

  Future<void> _saveVault() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _entries.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_prefsKey, raw);
  }

  Future<void> _loadMetaFromKeystore() async {
    final stored = await MetaPasswordService.getMeta();
    if (!mounted) return;
    setState(() {
      _metaPassword = stored;
    });
  }

  Future<String?> _ensureMetaPassword() async {
    if (_metaPassword != null && _metaPassword!.isNotEmpty) {
      return _metaPassword;
    }

    final stored = await MetaPasswordService.getMeta();
    if (stored != null && stored.isNotEmpty) {
      _metaPassword = stored;
      return _metaPassword;
    }

    String temp = '';
    bool remember = true;
    bool obscure = true;

    final meta = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Meta Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your meta password. It never leaves this device. All vault passwords rely on it.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: obscure,
                    onChanged: (v) => temp = v,
                    decoration: InputDecoration(
                      labelText: 'Meta password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: remember,
                        onChanged: (v) =>
                            setState(() => remember = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Remember for this device (stored securely)',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Changing this later changes all generated passwords. Using the same meta password restores them.',
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (temp.isEmpty) return;
                    Navigator.pop(context, temp);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (meta == null || meta.isEmpty) {
      return null;
    }

    _metaPassword = meta;

    if (remember) {
      await MetaPasswordService.setMeta(meta);
    }

    return _metaPassword;
  }

  Future<void> _onAddPressed() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('Pick from installed apps'),
              onTap: () {
                Navigator.pop(context);
                _pickInstalledApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('Add website or custom label'),
              onTap: () {
                Navigator.pop(context);
                _showManualAddDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickInstalledApp() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(child: CircularProgressIndicator()),
      );

      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
      );

      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      final selected = await showDialog<ApplicationWithIcon?>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          List<ApplicationWithIcon> filtered = apps
              .whereType<ApplicationWithIcon>()
              .toList()
            ..sort((a, b) =>
                a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

          return StatefulBuilder(
            builder: (context, setState) {
              void filter(String q) {
                final query = q.toLowerCase().trim();
                setState(() {
                  if (query.isEmpty) {
                    filtered = apps.whereType<ApplicationWithIcon>().toList()
                      ..sort((a, b) => a.appName
                          .toLowerCase()
                          .compareTo(b.appName.toLowerCase()));
                  } else {
                    filtered = apps
                        .whereType<ApplicationWithIcon>()
                        .where((a) =>
                    a.appName.toLowerCase().contains(query) ||
                        a.packageName.toLowerCase().contains(query))
                        .toList()
                      ..sort((a, b) => a.appName
                          .toLowerCase()
                          .compareTo(b.appName.toLowerCase()));
                  }
                });
              }

              return AlertDialog(
                title: const Text('Select an app'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        onChanged: filter,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search apps',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.maxFinite,
                        height: 360,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: MemoryImage(app.icon),
                              ),
                              title: Text(app.appName),
                              subtitle: Text(
                                app.packageName,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => Navigator.pop(context, app),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selected == null || !mounted) return;

      await _showVersionLengthDialog(
        label: selected.appName,
        package: selected.packageName,
        iconBytes: selected.icon,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load apps: $e')),
      );
    }
  }

  Future<void> _showManualAddDialog() async {
    final labelCtrl = TextEditingController();
    final lengthCtrl = TextEditingController(text: '24');
    final versionCtrl = TextEditingController(text: '1');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name or URL',
                    hintText: 'e.g. nextcloud, steam, example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: versionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Version',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lengthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Length',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                final version = int.tryParse(versionCtrl.text) ?? 1;
                final length = int.tryParse(lengthCtrl.text) ?? 24;
                Navigator.pop(context, {
                  'label': label,
                  'package': null,
                  'version': version,
                  'length': length,
                  'icon': null,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      _upsertEntry(
        label: result['label'],
        package: result['package'],
        iconB64: result['icon'],
        version: result['version'],
        length: result['length'],
      );
    }
  }

  Future<void> _showVersionLengthDialog({
    required String label,
    required String package,
    required Uint8List iconBytes,
  }) async {
    final lengthCtrl = TextEditingController(text: '24');
    final versionCtrl = TextEditingController(text: '1');

    final res = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundImage: MemoryImage(iconBytes)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        package,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: versionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Version',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lengthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Length',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final version = int.tryParse(versionCtrl.text) ?? 1;
                final length = int.tryParse(lengthCtrl.text) ?? 24;
                Navigator.pop(context, {
                  'version': version,
                  'length': length,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (res != null) {
      final iconB64 = base64Encode(iconBytes);
      _upsertEntry(
        label: label,
        package: package,
        iconB64: iconB64,
        version: res['version'],
        length: res['length'],
      );
    }
  }

  void _upsertEntry({
    required String label,
    String? package,
    String? iconB64,
    required int version,
    required int length,
  }) {
    final normLabel = label.trim();
    if (normLabel.isEmpty) return;

    final existingIndex = _entries.indexWhere(
          (e) => (e['label'] as String).toLowerCase() == normLabel.toLowerCase(),
    );

    if (existingIndex == -1) {
      final entry = <String, dynamic>{
        'label': normLabel,
        'package': package,
        'icon': iconB64,
        'versions': [
          {'version': version, 'length': length},
        ],
        'selectedVersion': version,
      };
      setState(() => _entries.add(entry));
    } else {
      final entry = Map<String, dynamic>.from(_entries[existingIndex]);
      if (package != null) entry['package'] = package;
      if (iconB64 != null) entry['icon'] = iconB64;

      final versions = (entry['versions'] as List)
          .map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v))
          .toList();

      final existingVerIndex =
      versions.indexWhere((v) => v['version'] == version);

      if (existingVerIndex == -1) {
        versions.add({'version': version, 'length': length});
      } else {
        versions[existingVerIndex]['length'] = length;
      }

      versions.sort(
            (a, b) => (a['version'] as int).compareTo(b['version'] as int),
      );
      entry['versions'] = versions;
      entry['selectedVersion'] = version;

      setState(() => _entries[existingIndex] = entry);
    }

    _saveVault();
  }

  Future<void> _deleteEntry(int index) async {
    final entry = _entries[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove entry'),
        content: Text('Remove "${entry['label']}" from your vault?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _entries.removeAt(index);
    });
    _saveVault();
  }

  Future<void> _copyPasswordForEntry(Map<String, dynamic> entry) async {
    final meta = await _ensureMetaPassword();
    if (meta == null || meta.isEmpty) return;

    final label = entry['label'] as String;
    final versions = (entry['versions'] as List)
        .map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v))
        .toList();

    if (versions.isEmpty) return;

    final selectedVersion = entry['selectedVersion'] as int? ??
        (versions.isNotEmpty ? versions.last['version'] as int : 1);

    final versionItem = versions.firstWhere(
          (v) => v['version'] == selectedVersion,
      orElse: () => versions.last,
    );

    final int v = versionItem['version'] as int;
    final int length = versionItem['length'] as int;

    try {
      final pw = _bridge.generatePassword(meta, label, v, length);
      await Clipboard.setData(ClipboardData(text: pw));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password copied for $label (v$v, $length chars)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate password: $e')),
      );
    }
  }

  Widget _buildIcon(Map<String, dynamic> entry) {
    final iconB64 = entry['icon'] as String?;
    final label = entry['label'] as String? ?? '';
    final isWeb = label.contains('.') || label.startsWith('http');

    if (iconB64 != null) {
      try {
        final bytes = base64Decode(iconB64);
        return CircleAvatar(
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    final letter = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return CircleAvatar(
      backgroundColor: isWeb ? Colors.blueAccent : Colors.grey.shade800,
      child: Text(
        isWeb ? '🌐' : letter,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildVersionDropdown(Map<String, dynamic> entry, int index) {
    final versions = (entry['versions'] as List)
        .map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v))
        .toList();
    if (versions.length <= 1) {
      final v = versions.first['version'];
      return Text(
        'v$v',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context)
              .textTheme
              .bodySmall
              ?.color
              ?.withOpacity(0.7),
        ),
      );
    }

    final selected =
        entry['selectedVersion'] as int? ?? versions.last['version'] as int;

    return DropdownButton<int>(
      value: selected,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(10),
      style: const TextStyle(fontSize: 12),
      onChanged: (val) {
        if (val == null) return;
        final updated = Map<String, dynamic>.from(entry);
        updated['selectedVersion'] = val;
        setState(() {
          _entries[index] = updated;
        });
        _saveVault();
      },
      items: versions
          .map(
            (v) => DropdownMenuItem<int>(
          value: v['version'] as int,
          child: Text('v${v['version']}'),
        ),
      )
          .toList(),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How MetaPass works'),
        content: const Text(
          'Passwords are never stored.\n\n'
              'Each entry derives a password from:\n'
              '• Your meta password\n'
              '• The label(name)\n'
              '• The version and length\n\n'
              'Reinstalling the app with the same meta password and labels regenerates the same passwords.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MetaPass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfo,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? _buildEmptyState(theme, text, isDark)
          : Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: _entries.length + 1, // +1 for footer
          itemBuilder: (context, index) {
            // Footer section
            if (index == _entries.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'powered by ColourSwift AV',
                    style: text.bodySmall?.copyWith(
                      fontSize: 11,
                      color: text.bodySmall?.color?.withOpacity(0.4),
                    ),
                  ),
                ),
              );
            }

            // Normal list items
            final entry = _entries[index];
            final label = entry['label'] as String;
            final versions = (entry['versions'] as List)
                .map<Map<String, dynamic>>(
                    (v) => Map<String, dynamic>.from(v))
                .toList();
            versions.sort((a, b) =>
                (a['version'] as int).compareTo(b['version'] as int));
            final selected = entry['selectedVersion'] as int? ??
                versions.last['version'] as int;
            final length = (versions.firstWhere(
                  (v) => v['version'] == selected,
              orElse: () => versions.last,
            )['length']) as int? ??
                24;

            return GestureDetector(
              onTap: () => _copyPasswordForEntry(entry),
              onLongPress: () => _deleteEntry(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.cardColor
                      : theme.colorScheme.surfaceVariant.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIcon(entry),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: text.bodyLarge?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildVersionDropdown(entry, index),
                              const SizedBox(width: 8),
                              Text(
                                '$length chars',
                                style: text.bodySmall?.copyWith(
                                  color: text.bodySmall?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to copy. Long-press to remove.',
                            style: text.bodySmall?.copyWith(
                              fontSize: 10,
                              color: text.bodySmall?.color
                                  ?.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => _copyPasswordForEntry(entry),
                      tooltip: 'Copy password',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      ThemeData theme,
      TextTheme text,
      bool isDark,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key_rounded,
              size: 56,
              color: theme.colorScheme.primary
                  .withOpacity(0.9),
            ),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an app or website.\nPasswords are generated on-device from your secret meta password.',
              style: text.bodySmall?.copyWith(
                color: text.bodySmall?.color
                    ?.withOpacity(0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _onAddPressed,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                  'Add first entry'),
            ),
          ],
        ),
      ),
    );
  }
}
