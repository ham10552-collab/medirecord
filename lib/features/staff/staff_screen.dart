import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_provider.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/luxury_figures.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctors & Staff'),
        actions: [
          IconButton(
            tooltip: 'User Management',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => context.push('/admin/users'),
          ),
        ],
      ),
      drawer: AppShell.usesFixedNav(context) ? null : const AppDrawer(),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.badge_outlined,
              title: 'No staff yet',
              message: 'Staff accounts appear here once they are created '
                  'in User Management.',
            );
          }
          final doctors = users.where((u) => u['role'] == 'doctor').length;
          final pharmacists = users.where((u) => u['role'] == 'pharmacist').length;
          final secretaries = users.where((u) => u['role'] == 'secretary').length;
          final lab = users.where((u) => u['role'] == 'lab').length;
          final admins = users.where((u) => u['role'] == 'admin').length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _roleCard(Icons.medical_services_outlined, 'Doctors', doctors,
                      AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  _roleCard(Icons.local_pharmacy_outlined, 'Pharmacists',
                      pharmacists, AppTheme.goldDeep),
                  const SizedBox(width: 10),
                  _roleCard(Icons.supervisor_account_outlined, 'Secretaries',
                      secretaries, AppTheme.secondaryColor),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _roleCard(Icons.science_outlined, 'Laboratory', lab,
                      AppTheme.primaryLight),
                  const SizedBox(width: 10),
                  _roleCard(Icons.admin_panel_settings_outlined, 'Admins',
                      admins, AppTheme.errorColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.goldColor.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.groups_outlined,
                              size: 18, color: AppTheme.textSecondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Total staff',
                                style: TextStyle(fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const LuxSectionTitle(
                  title: 'Staff Members', icon: Icons.badge_outlined),
              const SizedBox(height: 10),
              for (final u in users) _staffCard(u),
            ],
          );
        },
        error: (_, __) => const Center(
          child: Text('Error loading staff',
              style: TextStyle(color: AppTheme.errorColor)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _roleCard(IconData icon, String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text('$count',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> u) {
    final role = (u['role'] as String? ?? 'doctor').toUpperCase();
    final disabled = u['enabled'] == 0 || u['enabled'] == false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          child: Text(
            ((u['name'] as String? ?? 'S').isNotEmpty
                    ? (u['name'] as String).substring(0, 1)
                    : 'S')
                .toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        title: Text(u['name'] as String? ?? '',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        subtitle: Text(u['email'] as String? ?? '',
            style: const TextStyle(fontSize: 11.5)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (disabled
                        ? AppTheme.textSecondary
                        : AppTheme.successColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: disabled
                      ? AppTheme.textSecondary
                      : AppTheme.successColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (disabled ? AppTheme.errorColor : AppTheme.successColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                disabled ? 'Disabled' : 'Active',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color:
                      disabled ? AppTheme.errorColor : AppTheme.successColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}