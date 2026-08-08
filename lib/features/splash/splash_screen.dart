import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/license_provider.dart';
import '../../core/license/license_manager.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/widgets/luxury_figures.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final licensed = await LicenseManager.isLicensedOnDevice();
      if (licensed) {
        ref.read(licenseStatusProvider.notifier).state = LicenseStatus.licensed;
        final role = await AppStorage.read('medirecord_role');
        if (mounted) {
          if (role == null) context.push('/role');
          else if (role == 'secretary') context.go('/secretary');
          else context.go('/');
        }
        return;
      }

      final trial = await AppStorage.read('medirecord_trial');
      if (trial == 'true') {
        ref.read(licenseStatusProvider.notifier).state = LicenseStatus.trial;
        final role = await AppStorage.read('medirecord_role');
        if (mounted) {
          if (role == null) context.push('/role');
          else if (role == 'secretary') context.go('/secretary');
          else context.go('/');
        }
        return;
      }

      if (mounted) context.go('/welcome');
    } catch (_) {
      if (mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxNavyBackdrop(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LuxBrandHeader(
              title: 'MediRecord',
              tagline: 'PATIENT MEDICAL RECORDS SYSTEM',
            ),
            const SizedBox(height: 60),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppTheme.goldColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Loading your clinic\u2026',
              style: TextStyle(
                color: AppTheme.champagneLight,
                fontSize: 12.5,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
