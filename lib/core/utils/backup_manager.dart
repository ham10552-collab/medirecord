import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import 'app_storage.dart';

/// Automatic daily backup of the whole database (+ saved images) into a
/// folder the user can choose. Runs at app start when no backup exists for
/// today; keeps the most recent [maxBackups] files.
class BackupManager {
  BackupManager._();

  static const String folderKey = 'backup_folder';
  static const String lastKey = 'last_backup_date';
  static const int maxBackups = 21;

  static Future<Directory> defaultFolder() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'MediRecord_Backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory?> configuredFolder() async {
    final saved = await AppStorage.read(folderKey);
    if (saved == null || saved.trim().isEmpty) return null;
    try {
      final dir = Directory(saved.trim());
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> resolveFolder() async =>
      (await configuredFolder()) ?? await defaultFolder();

  /// Called at app start: backs up once per day, in the background.
  static Future<void> runDailyBackup() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final last = await AppStorage.read(lastKey) ?? '';
      if (last == today) return;
      await createBackup();
      await AppStorage.write(lastKey, today);
    } catch (_) {}
  }

  static Future<String?> createBackup() async {
    try {
      final dir = await resolveFolder();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final json = await DatabaseHelper().exportAllData();
      final file = File(p.join(dir.path, 'medirecord_backup_$stamp.json'));
      await file.writeAsString(json);

      // Include saved images (if any) so the backup is complete.
      try {
        final images = Directory(p.join('.', 'images'));
        if (await images.exists()) {
          final dest = Directory(p.join(dir.path, 'images'));
          if (!await dest.exists()) await dest.create(recursive: true);
          await for (final f in images.list()) {
            if (f is File) {
              try {
                await f.copy(p.join(dest.path, p.basename(f.path)));
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      await _pruneOld(dir);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _pruneOld(Directory dir) async {
    try {
      final files = await dir
          .list()
          .where((f) =>
              f is File && p.extension(f.path) == '.json')
          .cast<File>()
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      for (final f in files.skip(maxBackups)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<List<File>> listBackups() async {
    try {
      final dir = await resolveFolder();
      final files = await dir
          .list()
          .where((f) => f is File && p.extension(f.path) == '.json')
          .cast<File>()
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (_) {
      return [];
    }
  }
}