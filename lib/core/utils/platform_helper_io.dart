import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';

class PlatformHelper {
  static Future<String> savePdf(Uint8List bytes, String fileName) async {
    final db = DatabaseHelper();
    final dir = Directory(p.join(db.dbPath, 'reports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final filePath = p.join(dir.path, fileName);
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  static Future<void> openFile(String path) async {
    if (!File(path).existsSync()) return;
    try {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } catch (_) {
      try {
        await Process.run('powershell', ['-Command', 'Start-Process', '-FilePath', path]);
      } catch (_) {}
    }
  }

  static Future<String> saveImageBytes(Uint8List bytes, String id, String ext) async {
    final db = DatabaseHelper();
    final imagesDir = Directory(p.join(db.dbPath, 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    final destPath = p.join(imagesDir.path, '$id.$ext');
    await File(destPath).writeAsBytes(bytes);
    return destPath;
  }

  static Uint8List? loadImageBytes(String identifier) {
    try {
      return File(identifier).readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readCustomDrugs() async {
    final db = DatabaseHelper();
    final filePath = p.join(db.dbPath, 'custom_drugs_v2.txt');
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  static Future<void> writeCustomDrugs(String content) async {
    final db = DatabaseHelper();
    final filePath = p.join(db.dbPath, 'custom_drugs_v2.txt');
    await File(filePath).writeAsString(content);
  }

  static Future<void> downloadBytes(Uint8List bytes, String fileName) async {
    final db = DatabaseHelper();
    final dir = Directory(p.join(db.dbPath, 'downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final filePath = p.join(dir.path, fileName);
    await File(filePath).writeAsBytes(bytes);
  }
}
