import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/license_provider.dart';
import '../../core/utils/app_storage.dart';

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
      final licensed = await AppStorage.read('medirecord_licensed');
      if (licensed == 'true') {
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 72, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text('MediRecord', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
