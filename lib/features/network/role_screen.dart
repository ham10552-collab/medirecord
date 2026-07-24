import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';

class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Role')),
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
              const Text('Choose your role', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () => _pickRole(context, 'doctor'),
                  icon: const Icon(Icons.local_hospital, size: 32),
                  label: const Text("I'm a Doctor", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: OutlinedButton.icon(
                  onPressed: () => _pickRole(context, 'secretary'),
                  icon: const Icon(Icons.assignment_ind, size: 32),
                  label: const Text("I'm a Secretary", style: TextStyle(fontSize: 18)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
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
