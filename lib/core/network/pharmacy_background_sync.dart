import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../database/database_provider.dart';
import '../utils/app_storage.dart';
import '../../shared/models/prescription.dart';
import 'patient_client.dart';
import 'pharmacy_notifications.dart';

final _known = <String>{};
final _lastStatus = <String, String>{};
final _seededHosts = <String>{};

/// App-wide background sync for the pharmacy.
///
/// Runs while the app is open (any screen) and pulls prescriptions from all
/// configured doctor PCs, so the pharmacist never has to press Sync - new
/// prescriptions simply arrive. The pharmacy screen's own poll only adds the
/// arrival notification.
void startPharmacyBackgroundSync(ProviderContainer container) {
  Timer.periodic(const Duration(seconds: 3), (_) async {
    try {
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
      final existing = await db.getPharmacyQueue();
      final existingNames = {
        for (final r in existing) r['id']: (r['pharmacist_name'] as String?) ?? '',
      };
      var fetched = false;
      for (final doc in doctors) {
        final ip = doc['ip']!.trim();
        if (ip.isEmpty) continue;
        final port = int.tryParse(doc['port'] ?? '') ?? 9876;
        final (queue, _) = await PatientClient.fetchPharmacy(ip, port);
        if (queue.isEmpty) continue;
        fetched = true;
        final host = '$ip:$port';
        final docLabel = (doc['name'] ?? '').trim();
        for (final rx in queue) {
          final rxMap = (rx as Map).cast<String, dynamic>();
          final items = ((rxMap['items'] as List?) ?? const [])
              .map((i) => PrescriptionItem.fromMap((i as Map).cast<String, dynamic>()))
              .toList();
          final rawDoctor = (rxMap['doctor_name'] as String? ?? '').trim();
          final status = rxMap['status'] as String? ?? 'pending';
          final key = '$host|${rxMap['id']}';
          if (!_seededHosts.contains(host)) {
            // First contact with this doctor PC - learn its existing
            // prescriptions without alarming the pharmacist.
            _known.add(key);
            _lastStatus[key] = status;
          } else if (!_known.contains(key) && status == 'pending') {
            _known.add(key);
            _lastStatus[key] = status;
            notifyNewPharmacyRx(
              rxMap['id'] as String,
              rxMap['patient_name'] as String? ?? 'Patient',
              (rawDoctor.isEmpty || rawDoctor == 'Unknown') ? docLabel : rawDoctor,
            );
          } else if (_known.contains(key) &&
              _lastStatus[key] == 'dispensed' &&
              status == 'pending') {
            _lastStatus[key] = status;
            notifyNewPharmacyRx(
              rxMap['id'] as String,
              rxMap['patient_name'] as String? ?? 'Patient',
              (rawDoctor.isEmpty || rawDoctor == 'Unknown') ? docLabel : rawDoctor,
              resend: true,
            );
          } else {
            _lastStatus[key] = status;
          }
          await db.upsertPrescription(Prescription(
            id: rxMap['id'] as String,
            patientId: rxMap['patient_id'] as String,
            doctorName: (rawDoctor.isEmpty || rawDoctor == 'Unknown') && docLabel.isNotEmpty
                ? docLabel
                : rawDoctor,
            diagnosis: rxMap['diagnosis'] as String? ?? '',
            items: items,
            notes: rxMap['notes'] as String? ?? '',
            createdAt: rxMap['created_at'] as String,
            updatedAt: rxMap['updated_at'] as String,
            status: rxMap['status'] as String? ?? 'pending',
            dispensedBy: rxMap['dispensed_by'] as String?,
            dispensedAt: rxMap['dispensed_at'] as String?,
            pharmacistName:
                (rxMap['pharmacist_name'] as String?)?.isNotEmpty == true
                    ? rxMap['pharmacist_name'] as String
                    : existingNames[rxMap['id']],
            doctorHost: host,
            sentToPharmacy: true,
          ));
        }
        _seededHosts.add(host);
      }
      if (fetched) {
        container.invalidate(pharmacyQueueProvider);
      }
    } catch (_) {
      // Offline / missing doctor PC mid-tick - just try again next tick.
    }
  });
}