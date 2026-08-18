import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/network/lab_background_sync.dart';
import 'core/network/lab_notifications.dart';
import 'core/network/pharmacy_background_sync.dart';
import 'core/network/pharmacy_notifications.dart';
import 'core/database/database_provider.dart';
import 'core/utils/windows_notifier.dart';
import 'core/utils/backup_manager.dart';
import 'shared/widgets/luxury_figures.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) => const _LuxErrorScreen();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowsControlsInit();
    unawaited(WindowsNotifier.init());
  }
  if (!kIsWeb) {
    unawaited(BackupManager.runDailyBackup());
  }

  final container = ProviderContainer();
  if (!kIsWeb) {
    startPharmacyBackgroundSync(container);
    pharmacyNewRxNotifier.addListener(drainPharmacyNotifications);
    startLabBackgroundSync(container);
    labNewRequestNotifier.addListener(drainLabNewRequestNotifications);
    labResultNotifier.addListener(drainLabResultNotifications);
    secretaryStatusNotifier.addListener(drainSecretaryStatusNotifications);
    incomingPatientNotifier.addListener(() {
      if (incomingPatientNotifier.value.isNotEmpty) {
        container.invalidate(allPatientsProvider);
        container.invalidate(patientCountProvider);
      }
      drainIncomingPatientNotifications();
    });
  }
  runApp(UncontrolledProviderScope(
    container: container,
    child: const MediRecordApp(),
  ));
}

Future<void> windowsControlsInit() async {
  try {
    await windowManager.ensureInitialized();
  } catch (_) {}
}

class _LuxErrorScreen extends StatelessWidget {
  const _LuxErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxNavyBackdrop(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            MedicalCrossFigure(size: 28),
            SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: AppTheme.champagneLight,
                fontSize: 22,
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Restart MediRecord to continue. Your data is safe.',
              style: TextStyle(color: AppTheme.goldLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
