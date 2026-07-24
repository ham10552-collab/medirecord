import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/license_provider.dart';
import '../../core/utils/app_storage.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medical_services, size: 72, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text('MediRecord', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Patient Medical Records System', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _startTrial(context, ref),
                  icon: const Icon(Icons.free_breakfast),
                  label: const Text('Start Free Trial (70 patients)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('- or -', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              const Text('Already have a license?', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.push('/license'),
                  child: const Text('Enter License Key'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startTrial(BuildContext context, WidgetRef ref) {
    AppStorage.write('medirecord_trial', 'true');
    ref.read(licenseStatusProvider.notifier).state = LicenseStatus.trial;
    context.push('/role');
  }
}
