import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/widgets/luxury_figures.dart';

class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LuxNavyBackdrop(
        showBack: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LuxBrandHeader(
              title: 'MediRecord',
              tagline: 'CHOOSE YOUR ROLE',
            ),
            const SizedBox(height: 44),
            LuxuryCard(
              ornaments: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _pickRole(context, 'doctor'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MedicalCrossFigure(size: 15, gold: true),
                          SizedBox(width: 14),
                          Text(
                            "I'm a Doctor",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickRole(context, 'secretary'),
                    icon: const Icon(Icons.assignment_ind, size: 28),
                    label: const Text("I'm a Secretary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.goldColor, width: 1.6),
                      minimumSize: const Size(double.infinity, 62),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _pickRole(BuildContext context, String role) async {
    await AppStorage.write('medirecord_role', role);
    if (!context.mounted) return;
    if (role == 'secretary') context.push('/secretary');
    else context.push('/');
  }
}