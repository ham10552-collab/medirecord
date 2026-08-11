import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_storage.dart';
import '../utils/windows_notifier.dart';
import 'queue_status.dart';

/// Incoming patient pushed by a secretary machine onto this doctor machine.
/// Filled by the doctor's server handler; drained by [drainIncomingPatientNotifications].
final ValueNotifier<List<String>> incomingPatientNotifier = ValueNotifier(const []);

void notifyIncomingPatient(String fullName) {
  final list = List<String>.from(incomingPatientNotifier.value);
  list.add(fullName);
  if (list.length > 10) list.removeAt(0);
  incomingPatientNotifier.value = list;
}

/// Pending "new prescription arrived" notifications for the pharmacy.
/// Filled by the background sync; drained by [drainPharmacyNotifications]
/// (SnackBar + beep).
final ValueNotifier<List<Map<String, String>>> pharmacyNewRxNotifier =
    ValueNotifier(const []);

void notifyNewPharmacyRx(String id, String patient, String doctor,
    {bool resend = false}) {
  final list = List<Map<String, String>>.from(pharmacyNewRxNotifier.value);
  list.add({'id': id, 'patient': patient, 'doctor': doctor, 'resend': '$resend'});
  if (list.length > 10) list.removeAt(0);
  pharmacyNewRxNotifier.value = list;
}

/// Persistent record of patients pushed by a secretary onto this (doctor)
/// machine. Stored in app storage so alerts are never lost - the bell reads
/// this even if a poll or popup was missed.
Future<List<Map<String, dynamic>>> readIncomingAlerts() async {
  try {
    final raw = await AppStorage.read('incoming_alerts') ?? '';
    if (raw.isEmpty) return [];
    return (json.decode(raw) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

Future<void> recordIncomingAlert(String id, String fullName) async {
  try {
    final alerts = await readIncomingAlerts();
    if (alerts.any((a) => a['id'] == id)) return;
    alerts.insert(0, {
      'id': id,
      'name': fullName,
      'at': DateTime.now().toIso8601String(),
      'read': false,
    });
    while (alerts.length > 100) alerts.removeLast();
    await AppStorage.write('incoming_alerts', json.encode(alerts));
  } catch (_) {}
}

Future<void> markIncomingAlertsRead() async {
  try {
    final alerts = await readIncomingAlerts();
    var changed = false;
    for (final a in alerts) {
      if (a['read'] != true) {
        a['read'] = true;
        changed = true;
      }
    }
    if (changed) await AppStorage.write('incoming_alerts', json.encode(alerts));
  } catch (_) {}
}

/// Status changes of sent patients (waiting → with doctor → done) that the
/// secretary machine should announce with a popup + beep + toast.
final ValueNotifier<List<Map<String, String>>> secretaryStatusNotifier =
    ValueNotifier(const []);

void notifySecretaryStatus(String id, String name, String status) {
  final list = List<Map<String, String>>.from(secretaryStatusNotifier.value);
  list.add({'id': id, 'name': name, 'status': status});
  if (list.length > 10) list.removeAt(0);
  secretaryStatusNotifier.value = list;
}

/// Shows arrivals as a SnackBar on whichever screen is open (any screen in
/// the app) and plays a short alert beep.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

bool _draining = false;
bool _drainingPatients = false;
bool _drainingSecretary = false;

void drainPharmacyNotifications() {
  if (_draining) return;
  _draining = true;
  try {
    final items = List<Map<String, String>>.from(pharmacyNewRxNotifier.value);
    if (items.isEmpty) return;
    pharmacyNewRxNotifier.value = const [];
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      pharmacyNewRxNotifier.value = [...items, ...pharmacyNewRxNotifier.value];
      return;
    }
    final fresh = items.where((i) => i['resend'] != 'true').length;
    final reSent = items.length - fresh;
    final String text;
    if (items.length == 1) {
      final it = items.first;
      text = '${it['resend'] == 'true' ? 'Re-sent' : 'New prescription'}: '
          '${it['patient']} — Dr ${it['doctor']}';
    } else {
      text = '${items.length} new prescriptions arrived'
          '${reSent > 0 ? ' ($reSent re-sent)' : ''}';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ));
    WindowsNotifier.show('New prescription', text, id: 1);
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  } finally {
    _draining = false;
  }
}

/// Shows secretary-sent patients as a SnackBar on any screen (doctor machine)
/// with an alert beep.
void drainIncomingPatientNotifications() {
  if (_drainingPatients) return;
  _drainingPatients = true;
  try {
    final names = List<String>.from(incomingPatientNotifier.value);
    if (names.isEmpty) return;
    incomingPatientNotifier.value = const [];
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      incomingPatientNotifier.value = [...names, ...incomingPatientNotifier.value];
      return;
    }
    final String text;
    if (names.length == 1) {
      text = 'New patient from secretary: ${names.first}';
    } else {
      text = '${names.length} new patients from secretary';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ));
    WindowsNotifier.show('New patient', text, id: 2);
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  } finally {
    _drainingPatients = false;
  }
}

/// Announces secretary-queue status changes (with the doctor / visit done).
void drainSecretaryStatusNotifications() {
  if (_drainingSecretary) return;
  _drainingSecretary = true;
  try {
    final items = List<Map<String, String>>.from(secretaryStatusNotifier.value);
    if (items.isEmpty) return;
    secretaryStatusNotifier.value = const [];
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      secretaryStatusNotifier.value = [...items, ...secretaryStatusNotifier.value];
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final status = it['status'];
      final String text;
      if (status == QueueStatus.statusDone) {
        text = '${it['name']} finished his visit';
      } else {
        text = '${it['name']} is now with the doctor';
      }
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ));
      if (i == 0) {
        WindowsNotifier.show('Waiting room', text, id: 3);
        try {
          SystemSound.play(SystemSoundType.alert);
        } catch (_) {}
      }
    }
  } finally {
    _drainingSecretary = false;
  }
}