import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _secure.read(key: key);
    }
  }

  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secure.delete(key: key);
    }
  }

  static Future<bool> containsKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(key);
    } else {
      return await _secure.containsKey(key: key);
    }
  }

  static Future<List<String>> readList(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key) ?? [];
    } else {
      final raw = await _secure.read(key: key);
      if (raw == null || raw.isEmpty) return [];
      return raw.split('\n').where((s) => s.isNotEmpty).toList();
    }
  }

  static Future<void> writeList(String key, List<String> list) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, list);
    } else {
      await _secure.write(key: key, value: list.join('\n'));
    }
  }
}
