import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_storage.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await AppStorage.read('theme_mode');
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.light;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    try {
      await AppStorage.write('theme_mode', newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await AppStorage.write('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}

enum AppDisplayDensity { compact, cozy, roomy }

final displayDensityProvider =
    StateNotifierProvider<DisplayDensityNotifier, AppDisplayDensity>((ref) {
  return DisplayDensityNotifier();
});

class DisplayDensityNotifier extends StateNotifier<AppDisplayDensity> {
  DisplayDensityNotifier() : super(AppDisplayDensity.cozy) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await AppStorage.read('display_density');
      state = switch (saved) {
        'compact' => AppDisplayDensity.compact,
        'roomy' => AppDisplayDensity.roomy,
        _ => AppDisplayDensity.cozy,
      };
    } catch (_) {
      state = AppDisplayDensity.cozy;
    }
  }

  Future<void> setDensity(AppDisplayDensity density) async {
    state = density;
    try {
      await AppStorage.write('display_density', switch (density) {
        AppDisplayDensity.compact => 'compact',
        AppDisplayDensity.roomy => 'roomy',
        AppDisplayDensity.cozy => 'cozy',
      });
    } catch (_) {}
  }
}
