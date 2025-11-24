import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MetaPasswordService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'meta_password';

  static Future<String?> getMeta() {
    return _storage.read(key: _key);
  }

  static Future<void> setMeta(String value) {
    return _storage.write(key: _key, value: value);
  }

  static Future<void> clearMeta() {
    return _storage.delete(key: _key);
  }
}
