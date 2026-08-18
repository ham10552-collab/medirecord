import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/license_provider.dart';
import '../../core/network/patient_server.dart';
import '../../core/network/nav_badges.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../features/network/secretary_tab.dart';
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
    final badgeCount = ref.watch(navBadgeCountProvider).valueOrNull ?? 0;
    final isPharmacist = deviceRole == 'pharmacist' || roleAsync.valueOrNull == 'pharmacist';
    final isSecretary = !isPharmacist &&
        (deviceRole == 'secretary' || roleAsync.valueOrNull == 'secretary');
    final isLab = !isPharmacist &&
        !isSecretary &&
        (deviceRole == 'lab' || roleAsync.valueOrNull == 'lab');
    final isDoctorMachine = !isPharmacist && !isSecretary && !isLab;
    final displayName = (user?.displayName?.trim() ?? '').isEmpty
        ? (isDoctorMachine ? savedName : '')
        : user!.displayName!.trim();

    Widget tile(IconData icon, String title, VoidCallback onTap,
        {Color? iconColor, Widget? trailing, bool danger = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(icon, color: danger ? AppTheme.errorColor : iconColor ?? AppTheme.navy, size: 22),
          trailing: trailing,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: danger ? AppTheme.errorColor : AppTheme.textPrimary,
            ),
          ),
          onTap: onTap,
        ),
      );
    }

    Widget sectionHeader(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 20, 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    void go(String path) {
      context.pop();
      context.push(path);
    }

    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(16))),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    MedicalCrossFigure(size: 22),
                    SizedBox(width: 12),
                    Text(
                      'MediRecord Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        (displayName.isEmpty ? 'U' : displayName.substring(0, 1)).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty ? 'User' : displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    roleAsync.when(
                      data: (role) => role == null
                          ? const SizedBox()
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                      error: (_, __) => const SizedBox(),
                      loading: () => const SizedBox(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        'v25',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          sectionHeader('MAIN'),
          tile(
            isPharmacist
                ? Icons.local_pharmacy_outlined
                : isSecretary
                    ? Icons.groups_outlined
                    : isLab
                        ? Icons.science_outlined
                        : Icons.dashboard_outlined,
            isPharmacist
                ? 'Pharmacy'
                : isSecretary
                    ? 'Waiting Room'
                    : isLab
                        ? 'Laboratory'
                        : 'Dashboard',
            () => isSecretary
                ? () {
                    ref.read(secretaryTabProvider.notifier).state = SecretaryTab.queue;
                    context.pop();
                    context.go('/secretary');
                  }()
                : go(isPharmacist
                    ? '/pharmacy'
                    : isLab
                        ? '/lab'
                        : '/'),
            trailing: isPharmacist || isSecretary || isLab
                ? _NavBadge(count: badgeCount)
                : null,
          ),
          if (isSecretary) ...[
            tile(Icons.people_outline, 'Patients', () {
              ref.read(secretaryTabProvider.notifier).state = SecretaryTab.patients;
              context.pop();
              context.go('/secretary');
            }),
            tile(Icons.calendar_month_outlined, 'Bookings', () => go('/bookings')),
          ],
          if (!isPharmacist && !isSecretary && !isLab) ...[
            tile(Icons.calendar_month_outlined, 'Bookings', () => go('/bookings')),
            tile(Icons.people_outline, 'Patients', () => go('/patients')),
            tile(Icons.description_outlined, 'Reports', () => go('/reports')),
            tile(
              Icons.biotech_outlined,
              'Lab Orders',
              () => go('/lab-orders'),
              trailing: _NavBadge(count: badgeCount),
            ),
          ],
          roleAsync.when(
            data: (role) {
              if (role == 'admin' && !isPharmacist && !isSecretary) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionHeader('ADMIN'),
                    tile(Icons.badge_outlined, 'Doctors & Staff', () => go('/staff')),
                    tile(Icons.account_balance_outlined, 'Departments', () => go('/departments')),
                    tile(Icons.admin_panel_settings_outlined, 'User Management', () => go('/admin/users')),
                  ],
                );
              }
              return const SizedBox();
            },
            error: (_, __) => const SizedBox(),
            loading: () => const SizedBox(),
          ),
          sectionHeader('SYSTEM'),
          if (ref.watch(licenseStatusProvider) == LicenseStatus.trial)
            tile(
              Icons.vpn_key_outlined,
              'Activate License',
              () => go('/license'),
              iconColor: Colors.orange,
            ),
          tile(Icons.tune, 'Setup', () => go('/setup')),
          tile(Icons.headset_mic_outlined, 'Support & Contact', () => go('/contact')),
          if (isDoctorMachine)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi, size: 15, color: server.state == ServerState.running ? AppTheme.successColor : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        server.state == ServerState.running
                            ? '${server.ip}:${server.port}'
                            : 'Server not running',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: server.state == ServerState.running ? AppTheme.textPrimary : Colors.grey[600],
                          fontWeight: FontWeight.w600,
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
          const SizedBox(height: 10),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),
          if (ref.watch(licenseStatusProvider) == LicenseStatus.trial ||
              isDoctorMachine ||
              isLab)
            tile(
              Icons.logout,
              'Logout',
              () async {
                await AppStorage.delete('medirecord_role');
                ref.invalidate(deviceRoleProvider);
                await ref.read(deviceRoleProvider.future);
                if (context.mounted) {
                  context.pop();
                  context.go('/role');
                }
              },
              danger: true,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  final int count;
  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}