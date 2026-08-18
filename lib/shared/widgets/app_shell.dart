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
import 'global_search.dart';

/// Fluent/Sehaty-style shell: on wide windows shows a fixed vertical
/// navigation pane on the left; on narrow windows just renders the child
/// (screens keep their hamburger drawer).
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  /// True when the fixed navigation pane is visible (wide window).
  static bool usesFixedNav(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<_ShellData>())?.fixedNav ??
      false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (!wide) {
          return _ShellData(fixedNav: false, child: child);
        }
        return _ShellData(
          fixedNav: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SideNavPane(),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0x33D4AF37)),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _ShellData extends InheritedWidget {
  final bool fixedNav;

  const _ShellData({required this.fixedNav, required super.child});

  @override
  bool updateShouldNotify(_ShellData oldWidget) =>
      oldWidget.fixedNav != fixedNav;
}

class _SideNavPane extends ConsumerWidget {
  const _SideNavPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final user = ref.watch(currentUserProvider);
    final savedName = ref.watch(doctorNameProvider).valueOrNull ?? '';
    final badgeCount = ref.watch(navBadgeCountProvider).valueOrNull ?? 0;
    final roleAsync = ref.watch(userRoleProvider);
    final deviceRole = ref.watch(deviceRoleProvider).valueOrNull;
    final server = ref.watch(patientServerProvider);
    final isPharmacist =
        deviceRole == 'pharmacist' || roleAsync.valueOrNull == 'pharmacist';
    final isSecretary =
        !isPharmacist &&
        (deviceRole == 'secretary' || roleAsync.valueOrNull == 'secretary');
    final isLab =
        !isPharmacist && !isSecretary &&
        (deviceRole == 'lab' || roleAsync.valueOrNull == 'lab');
    final isDoctorMachine = !isPharmacist && !isSecretary && !isLab;
    final secTab = ref.watch(secretaryTabProvider);
    final displayName = (user?.displayName?.trim() ?? '').isEmpty
        ? (isDoctorMachine ? savedName : '')
        : user!.displayName!.trim();

    Widget sectionHeader(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 20, 8),
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

    Widget navItem({
      required String path,
      required IconData icon,
      required String title,
      Color? iconColor,
      bool danger = false,
      VoidCallback? onTapOverride,
      bool Function()? isSelected,
      int? badge,
    }) {
      final selected =
          isSelected?.call() ?? (location == path || (path != '/' && location.startsWith(path)));
      final vd = Theme.of(context).visualDensity;
      final padV = vd == VisualDensity.compact
          ? 6.0
          : (vd == VisualDensity.comfortable ? 18.0 : 11.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Material(
          color: selected
              ? AppTheme.goldColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
            onTap: () {
              if (onTapOverride != null) return onTapOverride();
              if (location == path) return;
              context.go(path);
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: selected ? AppTheme.goldDeep : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              padding: EdgeInsets.fromLTRB(10, padV, 10, padV),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: danger
                        ? AppTheme.errorColor
                        : selected
                              ? AppTheme.goldDeep
                              : iconColor ?? AppTheme.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: danger
                            ? AppTheme.errorColor
                            : selected
                                  ? AppTheme.navy
                                  : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if ((badge ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (selected)
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.goldDeep,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showGlobalSearch(context),
      },
      child: Container(
        width: 256,
        color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    MedicalCrossFigure(size: 22),
                    SizedBox(width: 12),
                    Text(
                      'MediRecord Pro',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
                      radius: 20,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        (displayName.isEmpty ? 'U' : displayName.substring(0, 1))
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty ? 'User' : displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    roleAsync.when(
                      data: (role) => role == null
                          ? const SizedBox()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                      error: (_, __) => const SizedBox(),
                      loading: () => const SizedBox(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        'v25',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: InkWell(
              onTap: () => showGlobalSearch(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.white54, size: 17),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search anything…   (Ctrl+K)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_command_key,
                        color: Colors.white38, size: 14),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isPharmacist) ...[
                    sectionHeader('MAIN'),
                    navItem(
                      path: '/pharmacy',
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Pharmacy',
                    ),
                  ] else if (isSecretary) ...[
                    sectionHeader('MAIN'),
                    navItem(
                      path: '/secretary',
                      icon: Icons.groups_outlined,
                      title: 'Waiting Room',
                      badge: badgeCount,
                      isSelected: () => secTab == SecretaryTab.queue,
                      onTapOverride: () {
                        ref.read(secretaryTabProvider.notifier).state = SecretaryTab.queue;
                        context.go('/secretary');
                      },
                    ),
                    sectionHeader('RECORDS'),
                    navItem(
                      path: '/secretary',
                      icon: Icons.people_outline,
                      title: 'Patients',
                      isSelected: () => secTab == SecretaryTab.patients,
                      onTapOverride: () {
                        ref.read(secretaryTabProvider.notifier).state = SecretaryTab.patients;
                        context.go('/secretary');
                      },
                    ),
                    navItem(
                      path: '/bookings',
                      icon: Icons.calendar_month_outlined,
                      title: 'Bookings',
                    ),
                  ] else if (isLab) ...[
                    sectionHeader('MAIN'),
                    navItem(
                      path: '/lab',
                      icon: Icons.science_outlined,
                      title: 'Laboratory',
                      badge: badgeCount,
                    ),
                  ] else ...[
                    sectionHeader('MAIN'),
                    navItem(
                      path: '/',
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard',
                    ),
                  ],
                  if (isDoctorMachine) ...[
                    sectionHeader('RECORDS'),
                    navItem(
                      path: '/bookings',
                      icon: Icons.calendar_month_outlined,
                      title: 'Bookings',
                    ),
                    navItem(
                      path: '/patients',
                      icon: Icons.people_outline,
                      title: 'Patients',
                    ),
                    navItem(
                      path: '/reports',
                      icon: Icons.description_outlined,
                      title: 'Reports',
                    ),
                    navItem(
                      path: '/lab-orders',
                      icon: Icons.biotech_outlined,
                      title: 'Lab Orders',
                      badge: badgeCount,
                    ),
                  ],
                  if (roleAsync.valueOrNull == 'admin' &&
                      !isPharmacist &&
                      !isSecretary) ...[
                    sectionHeader('ADMIN'),
                    navItem(
                      path: '/staff',
                      icon: Icons.badge_outlined,
                      title: 'Doctors & Staff',
                    ),
                    navItem(
                      path: '/departments',
                      icon: Icons.account_balance_outlined,
                      title: 'Departments',
                    ),
                    navItem(
                      path: '/admin/users',
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'User Management',
                    ),
                  ],
                  sectionHeader('SYSTEM'),
                  if (ref.watch(licenseStatusProvider) == LicenseStatus.trial)
                    navItem(
                      path: '/license',
                      icon: Icons.vpn_key_outlined,
                      title: 'Activate License',
                      iconColor: Colors.orange,
                    ),
                  navItem(
                    path: '/setup',
                    icon: Icons.tune,
                    title: 'Setup',
                  ),
                  navItem(
                    path: '/contact',
                    icon: Icons.headset_mic_outlined,
                    title: 'Support & Contact',
                  ),
                  if (isDoctorMachine)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi,
                              size: 15,
                              color: server.state == ServerState.running
                                  ? AppTheme.successColor
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                server.state == ServerState.running
                                    ? '${server.ip}:${server.port}'
                                    : 'Server not running',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color:
                                      server.state == ServerState.running
                                      ? AppTheme.textPrimary
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (server.state == ServerState.running)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: '${server.ip}:${server.port}',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('IP copied'),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.copy,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
            child: navItem(
              path: '/role',
              icon: Icons.logout,
              title: 'Logout',
              danger: true,
              onTapOverride: () async {
                await AppStorage.delete('medirecord_role');
                ref.invalidate(deviceRoleProvider);
                await ref.read(deviceRoleProvider.future);
                if (context.mounted) {
                  context.go('/role');
                }
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}