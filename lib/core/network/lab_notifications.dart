import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/windows_notifier.dart';
import 'pharmacy_notifications.dart' show recordIncomingAlert, scaffoldMessengerKey;

/// App-wide navigator key used to open screens from background notifications
/// (lab results arriving while the doctor is on any screen).
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Lab requests that arrived on the LAB machine (new order from a doctor).
final ValueNotifier<List<Map<String, String>>> labNewRequestNotifier =
    ValueNotifier(const []);

void notifyNewLabRequest(String id, String patient, String doctor,
    {bool resend = false}) {
  final list = List<Map<String, String>>.from(labNewRequestNotifier.value);
  list.add({'id': id, 'patient': patient, 'doctor': doctor, 'resend': '$resend'});
  if (list.length > 10) list.removeAt(0);
  labNewRequestNotifier.value = list;
}

/// Completed lab results that arrived on the DOCTOR machine.
final ValueNotifier<List<Map<String, String>>> labResultNotifier =
    ValueNotifier(const []);

void notifyLabResult(Map<String, dynamic> request) {
  final list = List<Map<String, String>>.from(labResultNotifier.value);
  list.add({
    'id': request['id'] as String? ?? '',
    'patient': request['patient_name'] as String? ?? 'Patient',
    'doctor': request['doctor_name'] as String? ?? '',
  });
  if (list.length > 10) list.removeAt(0);
  labResultNotifier.value = list;
}

// Uses the app-wide [scaffoldMessengerKey] (bound in app.dart) so lab
// notifications appear as SnackBars on whichever screen is open.

bool _drainingLabNew = false;
bool _drainingLabResult = false;

void drainLabNewRequestNotifications() {
  if (_drainingLabNew) return;
  _drainingLabNew = true;
  try {
    final items = List<Map<String, String>>.from(labNewRequestNotifier.value);
    if (items.isEmpty) return;
    labNewRequestNotifier.value = const [];
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      labNewRequestNotifier.value = [...items, ...labNewRequestNotifier.value];
      return;
    }
    final String text;
    if (items.length == 1) {
      final it = items.first;
      text = 'New lab request: ${it['patient']} — Dr ${it['doctor']}';
    } else {
      text = '${items.length} new lab requests arrived';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ));
    WindowsNotifier.show('New lab request', text, id: 5);
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  } finally {
    _drainingLabNew = false;
  }
}

void drainLabResultNotifications() {
  if (_drainingLabResult) return;
  _drainingLabResult = true;
  try {
    final items = List<Map<String, String>>.from(labResultNotifier.value);
    if (items.isEmpty) return;
    labResultNotifier.value = const [];
    for (final it in items) {
      recordIncomingAlert(
        'lab_${it['id']}',
        '${it['patient']} — Lab results ready',
        type: 'labresult',
      );
    }
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      labResultNotifier.value = [...items, ...labResultNotifier.value];
      return;
    }
    final String text;
    if (items.length == 1) {
      final it = items.first;
      text = 'Lab results ready: ${it['patient']}';
    } else {
      text = '${items.length} lab results arrived';
    }
    void openResults() {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;
      final firstId = items.first['id'] ?? '';
      GoRouter.of(nav.context).push(
        '/lab-orders?highlight=${Uri.encodeComponent(firstId)}',
      );
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View result',
          textColor: AppTheme.goldLight,
          onPressed: openResults,
        ),
      ));
    WindowsNotifier.show('Lab results received', text, id: 6);
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  } finally {
    _drainingLabResult = false;
  }
}