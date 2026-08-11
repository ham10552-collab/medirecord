import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';

/// OS-level notifications (Windows toasts) that appear even when the app is
/// minimized or on another screen, and clicking them restores the window.
class WindowsNotifier {
  WindowsNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
      const settings = InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: 'MediRecord Pro',
          appUserModelId: 'com.medirecord.pro',
          guid: 'b8c4f2a1-7d3e-4a6f-9c1b-2e5d8a4f6c30',
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) async {
          try {
            if (await windowManager.isMinimized()) await windowManager.restore();
            await windowManager.show();
            await windowManager.focus();
          } catch (_) {}
        },
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<void> show(String title, String body, {int id = 0}) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        windows: WindowsNotificationDetails(),
        linux: LinuxNotificationDetails(),
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }
}