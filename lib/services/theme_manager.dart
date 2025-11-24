import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeManager extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _keyTheme = 'appTheme';

  late Box _box;
  String _themeName = 'black';
  ThemeData _themeData = _buildBlackTheme();

  String get themeName => _themeName;

  ThemeData get themeData => _themeData;

  ThemeMode get themeMode {
    switch (_themeName) {
      case 'white':
      case 'emerald':
        return ThemeMode.light;
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _themeName = _box.get(_keyTheme, defaultValue: 'black') as String;
    _themeData = _resolveTheme(_themeName);
  }

  static ThemeData _resolveTheme(String name) {
    switch (name) {
      case 'white':
        return _buildWhiteTheme();
      case 'grey':
        return _buildGreyTheme();
      case 'emerald':
        return _buildEmeraldTheme();
      default:
        return _buildBlackTheme();
    }
  }

  Future<void> setTheme(String name) async {
    _themeName = name;
    _themeData = _resolveTheme(name);
    await _box.put(_keyTheme, name);
    notifyListeners();
  }

  // THEMES

  static ThemeData _buildBlackTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueAccent,
        secondary: Colors.tealAccent,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      cardColor: const Color(0xFF1A1A1A),
    );
  }


  static ThemeData _buildWhiteTheme() {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.blueAccent,
        secondary: Colors.blueAccent,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
    );
  }

  static ThemeData _buildGreyTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF2B2B2B),
      cardColor: const Color(0xFF3A3A3A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9E9E9E),
        secondary: Color(0xFFBDBDBD),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2B2B2B)),
      textTheme: ThemeData
          .dark()
          .textTheme
          .apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white70,
      ),
    );
  }

  static ThemeData _buildEmeraldTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F7F5),
      // softer white
      cardColor: const Color(0xFFE7EFEB),
      // pale mint surface
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF009E73),
        secondary: Color(0xFF00A982),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F7F5),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      textTheme: ThemeData
          .light()
          .textTheme
          .apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
    );
  }
}
