import 'dart:convert';
import '../utils/app_storage.dart';

/// Doctor- and secretary-side queues for patients sent from the secretary
/// machine to the doctor machine.
///
/// Doctor machine: AppStorage key 'queue_status' =
///   { patientId: {'status': 'waiting'|'with_doctor'|'done', 'at': ISO8601} }
/// Secretary machine: AppStorage key 'secretary_queue' =
///   [ {'id', 'name', 'sentAt'} ]  (in send order, newest last)
class QueueStatus {
  QueueStatus._();

  static const statusWaiting = 'waiting';
  static const statusWithDoctor = 'with_doctor';
  static const statusDone = 'done';

  // ---------------- Doctor side (status owner) ----------------

  static Future<Map<String, Map<String, String>>> readDoctorQueue() async {
    try {
      final raw = await AppStorage.read('queue_status') ?? '';
      if (raw.isEmpty) return {};
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
            k,
            ((v as Map).cast<String, dynamic>()).cast<String, String>(),
          ));
    } catch (_) {
      return {};
    }
  }

  static Future<void> setStatus(String patientId, String status) async {
    try {
      final map = await readDoctorQueue();
      map[patientId] = {
        'status': status,
        'at': DateTime.now().toIso8601String(),
      };
      await AppStorage.write('queue_status', json.encode(map));
    } catch (_) {}
  }

  /// Response payload for GET /api/queue/status with the patient's name
  /// joined in so the secretary never has to look it up.
  static Future<Map<String, dynamic>> buildStatusResponse(
      Map<String, String> namesById) async {
    try {
      final map = await readDoctorQueue();
      final out = <String, dynamic>{};
      map.forEach((id, entry) {
        out[id] = {
          'name': namesById[id] ?? '',
          'status': entry['status'] ?? statusWaiting,
          'at': entry['at'] ?? '',
        };
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  // ---------------- Secretary side (watcher) ----------------

  static Future<List<Map<String, dynamic>>> readSecretaryQueue() async {
    try {
      final raw = await AppStorage.read('secretary_queue') ?? '';
      if (raw.isEmpty) return [];
      return (json.decode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addSecretaryEntry(String patientId, String name) async {
    try {
      final list = await readSecretaryQueue();
      if (list.any((e) => e['id'] == patientId)) return;
      list.add({
        'id': patientId,
        'name': name,
        'sentAt': DateTime.now().toIso8601String(),
      });
      while (list.length > 120) list.removeAt(0);
      await AppStorage.write('secretary_queue', json.encode(list));
    } catch (_) {}
  }

  static Future<void> removeSecretaryEntry(String patientId) async {
    try {
      final list = await readSecretaryQueue();
      list.removeWhere((e) => e['id'] == patientId);
      await AppStorage.write('secretary_queue', json.encode(list));
    } catch (_) {}
  }

  static Future<void> clearSecretaryQueue() async {
    try {
      await AppStorage.write('secretary_queue', json.encode(const []));
    } catch (_) {}
  }
}