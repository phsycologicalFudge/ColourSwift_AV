import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../services/quarantine_service.dart';
import '../../services/exclusion_service.dart';

class QuarantineScreen extends StatefulWidget {
  const QuarantineScreen({super.key});
  @override
  State<QuarantineScreen> createState() => _QuarantineScreenState();
}

class _QuarantineScreenState extends State<QuarantineScreen> {
  List<Map<String, dynamic>> items = [];
  final Set<String> selected = {};
  bool loading = true;
  bool restoring = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => loading = true);
    final data = await QuarantineService.listAll();
    setState(() {
      items = data;
      selected.clear();
      loading = false;
    });
  }

  void _toggleAll() {
    setState(() {
      if (selected.length == items.length) {
        selected.clear();
      } else {
        selected
          ..clear()
          ..addAll(items.map((e) => e['id'] as String));
      }
    });
  }

  Future<void> _restore() async {
    if (selected.isEmpty) return;
    setState(() => restoring = true);
    try {
      await QuarantineService.restoreManyIsolated(selected);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored')));
      }
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  Future<void> _delete() async {
    if (selected.isEmpty) return;
    await QuarantineService.deleteMany(selected);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Quarantine'),
            actions: [
              IconButton(icon: const Icon(Icons.select_all_rounded), onPressed: _toggleAll),
              IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _reload),

            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? Center(child: Text('No quarantined files', style: text.bodyMedium?.copyWith(color: text.bodyMedium?.color?.withOpacity(0.7))))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = items[i];
              final id = m['id'] as String;
              final name = m['name'] as String;
              final orig = m['originalPath'] as String;
              final size = m['size'] as int;
              final dt = DateTime.parse(m['date']);
              final sel = selected.contains(id);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (sel) {
                      selected.remove(id);
                    } else {
                      selected.add(id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: sel,
                        onChanged: (_) {
                          setState(() {
                            if (sel) {
                              selected.remove(id);
                            } else {
                              selected.add(id);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(orig, style: text.bodySmall?.copyWith(color: text.bodySmall?.color?.withOpacity(0.7))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(_fmtSize(size), style: text.labelSmall),
                                const SizedBox(width: 12),
                                Text(DateFormat.yMMMd().add_jm().format(dt), style: text.labelSmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.orange),
                        onPressed: () async {
                          final bytes = File(orig).readAsBytesSync();
                          final sha = sha256.convert(bytes).toString();
                          final x = ExclusionService();
                          await x.load();
                          await x.addSha(sha);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to exclusions')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: items.isEmpty
              ? null
              : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: selected.isEmpty ? null : _restore,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: selected.isEmpty ? null : _delete,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (restoring)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  String _fmtSize(int b) {
    const k = 1024;
    if (b < k) return '${b} B';
    final kb = b / k;
    if (kb < k) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / k;
    if (mb < k) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / k;
    return '${gb.toStringAsFixed(1)} GB';
  }
}
