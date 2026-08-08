import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'shared/widgets/luxury_figures.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) => const _LuxErrorScreen();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(const ProviderScope(child: MediRecordApp()));
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
