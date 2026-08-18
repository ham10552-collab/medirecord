import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/widgets/luxury_figures.dart';

class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LuxNavyBackdrop(
        showBack: false,
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
                    onTap: () => _pickRole(context, ref, 'doctor'),
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
                    onPressed: () => _pickRole(context, ref, 'secretary'),
                    icon: const Icon(Icons.assignment_ind, size: 28),
                    label: const Text("I'm a Secretary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.goldColor, width: 1.6),
                      minimumSize: const Size(double.infinity, 62),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickRole(context, ref, 'pharmacist'),
                    icon: const Icon(Icons.local_pharmacy, size: 28),
                    label: const Text("I'm a Pharmacist", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      side: const BorderSide(color: AppTheme.secondaryColor, width: 1.6),
                      minimumSize: const Size(double.infinity, 62),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickRole(context, ref, 'lab'),
                    icon: const Icon(Icons.science, size: 28),
                    label: const Text("I'm a Lab Technician", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      side: const BorderSide(color: AppTheme.primaryLight, width: 1.6),
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

  void _pickRole(BuildContext context, WidgetRef ref, String role) async {
    await AppStorage.write('medirecord_role', role);
    // Force the router/drawer to see the NEW role before we navigate, so a
    // stale cached value can never route the doctor back to the pharmacy.
    ref.invalidate(deviceRoleProvider);
    await ref.read(deviceRoleProvider.future);
    if (!context.mounted) return;
    if (role == 'secretary') context.go('/secretary');
    else if (role == 'pharmacist') context.go('/pharmacy');
    else if (role == 'lab') context.go('/lab');
    else context.go('/');
  }
}