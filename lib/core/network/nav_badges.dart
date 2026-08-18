import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/queue_status.dart';

/// Live count badge for the side navigation (Fluent-style live counters).
/// Polls every few seconds according to the device role:
///  - pharmacist: number of pending prescriptions
///  - secretary:  number of patients waiting in the queue
///  - lab:        number of incoming lab requests
///  - doctor:     number of lab orders awaiting results
final navBadgeCountProvider = StreamProvider<int>((ref) async* {
  ref.watch(deviceRoleProvider);
  while (true) {
    var count = 0;
    try {
      final role = ref.read(deviceRoleProvider).valueOrNull;
      final db = DatabaseHelper();
      if (role == 'pharmacist') {
        final queue = await db.getPharmacyQueue();
        count = queue.where((r) => (r['status'] as String?) == 'pending').length;
      } else if (role == 'secretary') {
        count = (await QueueStatus.readSecretaryQueue()).length;
      } else if (role == 'lab') {
        count = (await db.getLabQueue()).length;
      } else {
        final mine = await db.getMyLabRequests();
        count = mine.where((r) => (r['status'] as String?) != 'completed').length;
      }
    } catch (_) {}
    yield count;
    await Future.delayed(const Duration(seconds: 10));
  }
});