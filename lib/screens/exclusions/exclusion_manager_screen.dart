import 'dart:io';
import 'package:flutter/material.dart';
import 'package:colourswift_av/services/exclusion_service.dart';


class ExclusionManagerScreen extends StatefulWidget {
  ExclusionManagerScreen({super.key});
  @override
  State<ExclusionManagerScreen> createState() => _ExclusionManagerScreenState();
}

class _ExclusionManagerScreenState extends State<ExclusionManagerScreen> {
  List<String> folders = [];
  List<String> shas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final x = ExclusionService();
    await x.load();
    setState(() {
      folders = List.from(x.folders);
      shas = List.from(x.shas);
      loading = false;
    });
  }

  Future<void> _removeFolder(String f) async {
    final x = ExclusionService();
    await x.load();
    x.folders.remove(f);
    await x.save();
    await _load();
  }

  Future<void> _removeSha(String s) async {
    final x = ExclusionService();
    await x.load();
    x.shas.remove(s);
    await x.save();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exclusions'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Folders', style: text.titleMedium),
          const SizedBox(height: 10),
          if (folders.isEmpty)
            Text('None', style: text.bodySmall)
          else
            ...folders.map((f) {
              final name = f.split('/').last;
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _removeFolder(f),
                    ),
                  ],
                ),
              );
            }).toList(),
          const SizedBox(height: 20),
          Text('File Hashes', style: text.titleMedium),
          const SizedBox(height: 10),
          if (shas.isEmpty)
            Text('None', style: text.bodySmall)
          else
            ...shas.map((s) {
              final short = '${s.substring(0, 10)}...';
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(short),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _removeSha(s),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
