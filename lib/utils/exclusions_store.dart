import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class ExclusionEntry {
  final String path;
  final DateTime addedAt;
  final DateTime? expiresAt;
  final bool permanent;
  ExclusionEntry({required this.path, required this.addedAt, this.expiresAt, this.permanent = false});
  Map<String, dynamic> toJson() => {
    'path': path,
    'addedAt': addedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'permanent': permanent,
  };
  static ExclusionEntry fromJson(Map<String, dynamic> j) => ExclusionEntry(
    path: j['path'],
    addedAt: DateTime.parse(j['addedAt']),
    expiresAt: j['expiresAt'] == null ? null : DateTime.parse(j['expiresAt']),
    permanent: j['permanent'] == true,
  );
}

class ExclusionsStore {
  ExclusionsStore._();
  static final ExclusionsStore instance = ExclusionsStore._();
  final _secure = const FlutterSecureStorage();
  final _algo = AesGcm.with256bits();
  List<ExclusionEntry> _items = [];
  String? _filePath;
  SecretKey? _key;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _filePath = '${dir.path}/exclusions.json';
    var k = await _secure.read(key: 'excl_key');
    if (k == null) {
      final r = Random.secure();
      final b = List<int>.generate(32, (_) => r.nextInt(256));
      k = base64Encode(b);
      await _secure.write(key: 'excl_key', value: k);
    }
    _key = SecretKey(base64Decode(k));
    await _load();
    await purgeExpired();
  }

  Future<void> _load() async {
    final f = File(_filePath!);
    if (!await f.exists()) {
      _items = [];
      return;
    }
    try {
      final raw = await f.readAsString();
      final j = jsonDecode(raw);
      final iv = base64Decode(j['iv']);
      final data = base64Decode(j['data']);
      final macBytes = base64Decode(j['mac']);
      final box = SecretBox(data, nonce: iv, mac: Mac(macBytes));
      final clear = await _algo.decrypt(box, secretKey: _key!);
      final list = jsonDecode(utf8.decode(clear));
      _items = List<Map<String, dynamic>>.from(list).map(ExclusionEntry.fromJson).toList();
    } catch (_) {
      _items = [];
      await _save();
    }
  }

  Future<void> _save() async {
    final f = File(_filePath!);
    final iv = _randBytes(12);
    final payload = utf8.encode(jsonEncode(_items.map((e) => e.toJson()).toList()));
    final box = await _algo.encrypt(payload, secretKey: _key!, nonce: iv);
    final j = {
      'iv': base64Encode(iv),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    await f.writeAsString(jsonEncode(j), flush: true);
  }

  List<int> _randBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  Future<void> purgeExpired() async {
    final now = DateTime.now();
    _items = _items.where((e) => e.permanent || (e.expiresAt != null && now.isBefore(e.expiresAt!))).toList();
    await _save();
  }

  bool isExcluded(String path) {
    final now = DateTime.now();
    for (final e in _items) {
      if (_eq(e.path, path)) {
        if (e.permanent) return true;
        if (e.expiresAt != null && now.isBefore(e.expiresAt!)) return true;
      }
    }
    return false;
  }

  Future<void> addTemporary(String path, Duration duration) async {
    await purgeExpired();
    _items.removeWhere((e) => _eq(e.path, path));
    _items.add(ExclusionEntry(path: path, addedAt: DateTime.now(), expiresAt: DateTime.now().add(duration), permanent: false));
    await _save();
  }

  Future<void> addPermanent(String path) async {
    await purgeExpired();
    _items.removeWhere((e) => _eq(e.path, path));
    _items.add(ExclusionEntry(path: path, addedAt: DateTime.now(), expiresAt: null, permanent: true));
    await _save();
  }

  Future<void> remove(String path) async {
    _items.removeWhere((e) => _eq(e.path, path));
    await _save();
  }

  List<ExclusionEntry> list() => List<ExclusionEntry>.from(_items);

  bool _eq(String a, String b) {
    final na = a.replaceAll('\\', '/').toLowerCase();
    final nb = b.replaceAll('\\', '/').toLowerCase();
    return na == nb;
  }
}
