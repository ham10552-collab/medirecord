import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../database/database_provider.dart';
import '../utils/app_storage.dart';
import 'patient_client.dart';
import 'lab_notifications.dart';

final _knownLab = <String>{};

/// App-wide background sync for the LAB device.
///
/// Same mechanics as the pharmacy sync: pulls pending lab requests from every
/// configured doctor PC every 3 seconds and stores them locally, so new
/// orders simply arrive without pressing anything.
void startLabBackgroundSync(ProviderContainer container) {
  Timer.periodic(const Duration(seconds: 3), (_) async {
    try {
      // Only the LAB device pulls lab requests from the doctors. On a doctor,
      // pharmacy or secretary machine this sync must not run - otherwise the
      // requests from every doctor in the shared doctor_pcs list end up
      // duplicated into that machine's local database.
      final role = (await AppStorage.read('medirecord_role'))?.trim() ?? '';
      if (role != 'lab') return;

      final rawList = await AppStorage.readList('doctor_pcs');
      if (rawList.isEmpty) return;
      final doctors = rawList
          .map((e) {
            try {
              return (json.decode(e) as Map).cast<String, String>();
            } catch (_) {
              return <String, String>{};
            }
          })
          .where((m) => (m['ip'] ?? '').trim().isNotEmpty)
          .toList();
      if (doctors.isEmpty) return;

      final db = DatabaseHelper();
      var fetched = false;
      for (final doc in doctors) {
        final ip = doc['ip']!.trim();
        if (ip.isEmpty) continue;
        final port = int.tryParse(doc['port'] ?? '') ?? 9876;
        final (queue, _) = await PatientClient.fetchLabTests(ip, port);
        if (queue.isEmpty) continue;
        fetched = true;
        final host = '$ip:$port';
        final docLabel = (doc['name'] ?? '').trim();
        for (final r in queue) {
          final rMap = (r as Map).cast<String, dynamic>();
          final key = '$host|${rMap['id']}';
          final patient = rMap['patient_name'] as String? ?? 'Patient';
          final doctor =
              (rMap['doctor_name'] as String? ?? '').trim().isEmpty
                  ? docLabel
                  : (rMap['doctor_name'] as String? ?? '');
          if (_knownLab.add(key)) {
            notifyNewLabRequest(rMap['id'] as String, patient, doctor);
          }
          await db.upsertLabRequest(rMap);
        }
      }
      if (fetched) {
        container.invalidate(labQueueProvider);
      }
    } catch (_) {
      // Offline / missing doctor PC mid-tick - just try again next tick.
    }
  });
}