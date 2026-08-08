import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/license_provider.dart';
import '../../core/utils/app_storage.dart';
import '../../core/utils/constants.dart';
import '../../shared/widgets/luxury_figures.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LuxNavyBackdrop(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LuxBrandHeader(
              title: 'MediRecord',
              tagline: 'PATIENT MEDICAL RECORDS SYSTEM',
            ),
            const SizedBox(height: 44),
            LuxuryCard(
              ornaments: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      MedicalCrossFigure(size: 14, gold: false),
                      SizedBox(width: 10),
                      Text(
                        'Start your premium journey',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explore MediRecord free for ${AppConstants.maxTrialPatients} patients before you activate.',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  GoldButton(
                    onPressed: () => _startTrial(context, ref),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.workspace_premium, size: 19, color: AppTheme.navyDeep),
                        const SizedBox(width: 8),
                        Text(
                          'Start Free Trial (${AppConstants.maxTrialPatients} patients)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navyDeep,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: GoldDivider(),
                  ),
                  const Center(
                    child: Text(
                      'Already have a license?',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    onPressed: () => context.push('/license'),
                    outlined: true,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key, size: 18, color: AppTheme.goldDeep),
                        SizedBox(width: 8),
                        Text(
                          'Enter License Key',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.goldDeep,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
