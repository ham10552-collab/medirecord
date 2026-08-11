import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/license_provider.dart';
import '../../core/network/patient_server.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import 'luxury_figures.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final savedName = ref.watch(doctorNameProvider).valueOrNull ?? '';
    final roleAsync = ref.watch(userRoleProvider);
    final deviceRole = ref.watch(deviceRoleProvider).valueOrNull;
    final server = ref.watch(patientServerProvider);
    final isPharmacist = deviceRole == 'pharmacist' || roleAsync.valueOrNull == 'pharmacist';
    final isSecretary = !isPharmacist &&
        (deviceRole == 'secretary' || roleAsync.valueOrNull == 'secretary');
    final isDoctorMachine = !isPharmacist && !isSecretary;
    final displayName = (user?.displayName?.trim() ?? '').isEmpty
        ? (isDoctorMachine ? savedName : '')
        : user!.displayName!.trim();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MedicalCrossFigure(size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'MediRecord Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: AppTheme.displayFont,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        (displayName.isEmpty ? 'U' : displayName.substring(0, 1)).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? 'User' : displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                roleAsync.when(
                  data: (role) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      role?.toUpperCase() ?? '',
                      style: const TextStyle(
                        color: AppTheme.goldLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox(),
                  loading: () => const SizedBox(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'Version v24',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(isPharmacist
                ? Icons.local_pharmacy
                : isSecretary
                    ? Icons.supervisor_account
                    : Icons.dashboard,
                color: isPharmacist || isSecretary ? AppTheme.goldDeep : null),
            title: Text(isPharmacist ? 'Pharmacy' : isSecretary ? 'Secretary' : 'Dashboard'),
            onTap: () {
              context.pop();
              context.go('/');
            },
          ),
          if (!isPharmacist)
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Bookings'),
              onTap: () {
                context.pop();
                context.push('/bookings');
              },
            ),
          if (!isPharmacist && !isSecretary) ...[
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Patients'),
              onTap: () {
                context.pop();
                context.push('/patients');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_pharmacy_outlined),
              title: const Text('Pharmacy (my sent)'),
              onTap: () {
                context.pop();
                context.push('/pharmacy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Reports'),
              onTap: () {
                context.pop();
                context.push('/reports');
              },
            ),
          ],
          roleAsync.when(
            data: (role) {
              if (role == 'admin' && !isPharmacist && !isSecretary) {
                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('User Management'),
                  onTap: () {
                    context.pop();
                    context.push('/admin/users');
                  },
                );
              }
              return const SizedBox();
            },
            error: (_, __) => const SizedBox(),
            loading: () => const SizedBox(),
          ),
          if (ref.watch(licenseStatusProvider) == LicenseStatus.trial)
            ListTile(
              leading: const Icon(Icons.vpn_key, color: Colors.orange),
              title: const Text('Activate License', style: TextStyle(color: Colors.orange)),
              onTap: () {
                context.pop();
                context.push('/license');
              },
            ),
          // Server status (doctor mode only)
          if (!isSecretary && !isPharmacist)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi, size: 16, color: server.state == ServerState.running ? AppTheme.successColor : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      server.state == ServerState.running
                          ? 'Server: ${server.ip}:${server.port}'
                          : 'Server not running',
                      style: TextStyle(
                        fontSize: 12,
                        color: server.state == ServerState.running ? AppTheme.textPrimary : Colors.grey[600],
                        fontWeight: server.state == ServerState.running ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (server.state == ServerState.running)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: '${server.ip}:${server.port}'));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IP copied')));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy, size: 14, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Setup'),
            onTap: () {
              context.pop();
              context.push('/setup');
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support & Contact'),
            onTap: () {
              context.pop();
              context.push('/contact');
            },
          ),
          const SizedBox(height: 12),
          const Divider(),
          // One role per computer: once the license is active only the doctor
          // machine can switch roles (trial mode keeps switching for testing).
          if (ref.watch(licenseStatusProvider) == LicenseStatus.trial ||
              (!isSecretary && !isPharmacist))
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                // Logout = switch role only. The device license stays bound.
                await AppStorage.delete('medirecord_role');
                if (context.mounted) {
                  context.pop();
                  context.go('/role');
                }
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
