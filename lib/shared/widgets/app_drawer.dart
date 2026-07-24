import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/license_provider.dart';
import '../../core/network/patient_server.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final roleAsync = ref.watch(userRoleProvider);
    final server = ref.watch(patientServerProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                roleAsync.when(
                  data: (role) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role?.toUpperCase() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  error: (_, __) => const SizedBox(),
                  loading: () => const SizedBox(),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              context.pop();
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Patients'),
            onTap: () {
              context.pop();
              context.go('/patients');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Reports'),
            onTap: () {
              context.pop();
              context.go('/reports');
            },
          ),
          roleAsync.when(
            data: (role) {
              if (role == 'admin') {
                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('User Management'),
                  onTap: () {
                    context.pop();
                    context.go('/admin/users');
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
          // Server status (doctor mode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.wifi, size: 16, color: server.state == ServerState.running ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    server.state == ServerState.running
                        ? 'Server: ${server.ip}:${server.port}'
                        : 'Server not running',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          ListTile(
            leading: const Icon(Icons.arrow_back, color: Colors.grey),
            title: const Text('Back to Setup', style: TextStyle(color: Colors.grey)),
            onTap: () {
              context.pop();
              context.go('/welcome');
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AppStorage.delete('medirecord_licensed');
              await AppStorage.delete('medirecord_trial');
              await AppStorage.delete('medirecord_role');
              if (context.mounted) {
                context.pop();
                context.go('/splash');
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
