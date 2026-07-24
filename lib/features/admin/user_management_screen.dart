import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_provider.dart';
import '../../shared/widgets/app_drawer.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No users found', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final role = user['role'] as String? ?? '';
              final isActive = (user['is_active'] as int?) == 1;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(role).withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: _getRoleColor(role)),
                  ),
                  title: Text(user['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${user['email']}  |  ${role.toUpperCase()}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.successColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? AppTheme.successColor : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        error: (_, __) => const Center(child: Text('Error loading users')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.errorColor;
      case 'doctor':
        return AppTheme.primaryColor;
      case 'nurse':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _showAddUserDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String role = 'doctor';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                ],
                onChanged: (v) => role = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text,
                );
                await credential.user?.updateDisplayName(nameCtrl.text.trim());

                final db = DatabaseHelper();
                await db.insertUser({
                  'id': credential.user!.uid,
                  'email': emailCtrl.text.trim(),
                  'display_name': nameCtrl.text.trim(),
                  'role': role,
                  'phone': null,
                  'is_active': 1,
                  'created_at': DateTime.now().toIso8601String(),
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(allUsersProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User added')));
                }
              } on FirebaseAuthException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Error'), backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }
}
