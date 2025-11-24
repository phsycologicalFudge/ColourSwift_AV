import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/exclusions_store.dart';

class QuarantineService {
  static final _storage = const FlutterSecureStorage();
  static final _algo = AesGcm.with256bits();
  static SecretKey? _key;
  static Directory? _qDir;
  static Box? _box;

  static Future<void> init() async {
    if (!Hive.isBoxOpen('quarantine')) {
      await Hive.initFlutter();
      _box = await Hive.openBox('quarantine');
    } else {
      _box = Hive.box('quarantine');
    }
    _key ??= await _loadOrCreateKey();
    _qDir ??= await _ensureQuarantineDir();
    await ExclusionsStore.instance.init();
  }

  static Future<SecretKey> _loadOrCreateKey() async {
    final k = await _storage.read(key: 'qs_aes256_key');
    if (k != null) {
      return SecretKey(base64Decode(k));
    }
    final sk = await _algo.newSecretKey();
    final raw = await sk.extractBytes();
    await _storage.write(key: 'qs_aes256_key', value: base64Encode(raw));
    return SecretKey(raw);
  }

  static Future<List<int>> getRawKey() async {
    await init();
    return await _key!.extractBytes();
  }

  static Future<Directory> _ensureQuarantineDir() async {
    Directory? base = await getExternalStorageDirectory();
    base ??= await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'quarantine'));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  static String _id() {
    final r = Random.secure();
    final a = r.nextInt(1 << 32);
    final b = r.nextInt(1 << 32);
    final c = DateTime.now().millisecondsSinceEpoch;
    return '${c.toRadixString(16)}_${a.toRadixString(16)}_${b.toRadixString(16)}';
  }

  static Future<Map<String, dynamic>> quarantineFile(String srcPath) async {
    await init();
    final f = File(srcPath);
    if (!await f.exists()) {
      throw Exception('Source not found');
    }
    final data = await f.readAsBytes();
    final nonce = _algo.newNonce();
    final box = await _algo.encrypt(data, secretKey: _key!, nonce: nonce);
    final out = BytesBuilder();
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    final id = _id();
    final qName = '$id.vqsafe';
    final qPath = p.join(_qDir!.path, qName);
    await File(qPath).writeAsBytes(out.toBytes(), flush: true);
    final meta = {
      'id': id,
      'qPath': qPath,
      'name': p.basename(srcPath),
      'originalPath': srcPath,
      'size': data.length,
      'date': DateTime.now().toIso8601String(),
    };
    try {
      await f.delete();
      if (await f.exists()) {
        await f.delete(recursive: true);
        if (await f.exists()) {
          meta['deleteFailed'] = true;
        }
      }
    } catch (_) {
      meta['deleteFailed'] = true;
    }
    await _box!.put(id, meta);
    return meta;
  }

  static Future<void> restore(String id) async {
    await init();
    final meta = Map<String, dynamic>.from(_box!.get(id));
    final qFile = File(meta['qPath']);
    if (!await qFile.exists()) {
      throw Exception('Quarantine file missing');
    }
    final all = await qFile.readAsBytes();
    if (all.length < 12 + 16) {
      throw Exception('Corrupt package');
    }
    final nonce = all.sublist(0, 12);
    final mac = Mac(all.sublist(all.length - 16));
    final cipher = all.sublist(12, all.length - 16);
    final plain = await _algo.decrypt(SecretBox(cipher, nonce: nonce, mac: mac), secretKey: _key!);
    final orig = meta['originalPath'] as String;
    final parent = Directory(p.dirname(orig));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    var outPath = orig;
    if (await File(outPath).exists()) {
      final dir = p.dirname(orig);
      final base = p.basenameWithoutExtension(orig);
      final ext = p.extension(orig);
      outPath = p.join(dir, '${base}_restored$ext');
    }
    await File(outPath).writeAsBytes(plain, flush: true);
    await qFile.delete();
    await _box!.delete(id);
    await ExclusionsStore.instance.addTemporary(outPath, const Duration(hours: 24));
  }

  static Future<void> deleteForever(String id) async {
    await init();
    final meta = Map<String, dynamic>.from(_box!.get(id));
    final qFile = File(meta['qPath']);
    if (await qFile.exists()) {
      await qFile.delete();
    }
    await _box!.delete(id);
  }

  static Future<List<Map<String, dynamic>>> listAll() async {
    await init();
    final keys = _box!.keys.toList();
    final out = <Map<String, dynamic>>[];
    for (final k in keys) {
      final v = Map<String, dynamic>.from(_box!.get(k));
      out.add(v);
    }
    out.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    return out;
  }

  static Future<void> restoreMany(Iterable<String> ids) async {
    for (final id in ids) {
      await restore(id);
    }
  }

  static Future<void> deleteMany(Iterable<String> ids) async {
    for (final id in ids) {
      await deleteForever(id);
    }
  }

  static Future<int> totalSize() async {
    await init();
    final list = await listAll();
    return list.fold<int>(0, (s, e) => s + (e['size'] as int));
  }

  static Future<void> purgeOlderThan(Duration age) async {
    await init();
    final now = DateTime.now();
    final list = await listAll();
    for (final m in list) {
      final t = DateTime.parse(m['date']);
      if (now.difference(t) > age) {
        await deleteForever(m['id']);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _metasForIds(Iterable<String> ids) async {
    await init();
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final v = _box!.get(id);
      if (v != null) out.add(Map<String, dynamic>.from(v));
    }
    return out;
  }

  static Future<List<String>> restoreManyIsolated(Iterable<String> ids) async {
    await init();
    final metas = await _metasForIds(ids);
    final keyBytes = await getRawKey();
    final result = await compute(_restoreWorker, {'metas': metas, 'key': keyBytes});
    for (final r in result) {
      final id = r['id'] as String;
      final outPath = r['outPath'] as String;
      await _box!.delete(id);
      await ExclusionsStore.instance.addTemporary(outPath, const Duration(hours: 24));
    }
    return result.map<String>((e) => e['outPath'] as String).toList();
  }
}

Future<List<Map<String, dynamic>>> _restoreWorker(Map args) async {
  final algo = AesGcm.with256bits();
  final metas = List<Map<String, dynamic>>.from(args['metas']);
  final key = SecretKey(List<int>.from(args['key']));
  final out = <Map<String, dynamic>>[];
  for (final m in metas) {
    final qPath = m['qPath'] as String;
    final orig = m['originalPath'] as String;
    final qFile = File(qPath);
    if (!await qFile.exists()) continue;
    final all = await qFile.readAsBytes();
    if (all.length < 12 + 16) continue;
    final nonce = all.sublist(0, 12);
    final mac = Mac(all.sublist(all.length - 16));
    final cipher = all.sublist(12, all.length - 16);
    final plain = await algo.decrypt(SecretBox(cipher, nonce: nonce, mac: mac), secretKey: key);
    final parent = Directory(p.dirname(orig));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    var outPath = orig;
    if (await File(outPath).exists()) {
      final dir = p.dirname(orig);
      final base = p.basenameWithoutExtension(orig);
      final ext = p.extension(orig);
      outPath = p.join(dir, '${base}_restored$ext');
    }
    await File(outPath).writeAsBytes(plain, flush: true);
    await qFile.delete();
    out.add({'id': m['id'], 'outPath': outPath});
  }
  return out;
}
