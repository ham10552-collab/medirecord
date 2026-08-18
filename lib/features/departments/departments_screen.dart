import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_provider.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  static const _icons = [
    Icons.medical_services_outlined,
    Icons.child_care_outlined,
    Icons.heart_broken_outlined,
    Icons.psychology_outlined,
    Icons.healing_outlined,
    Icons.visibility_outlined,
  ];

  Future<void> _addDepartment(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Department'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Department name',
                  hintText: 'e.g. Cardiology',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    await DatabaseHelper().insertDepartment({
      'id': const Uuid().v4(),
      'name': name,
      'description': descCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    ref.invalidate(departmentsProvider);
  }

  Future<void> _deleteDepartment(BuildContext context, WidgetRef ref,
      Map<String, dynamic> dept) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text(
            '${dept['name']} will be removed from the departments list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper().deleteDepartment(dept['id'] as String);
    ref.invalidate(departmentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        actions: [
          IconButton(
            tooltip: 'New Department',
            icon: const Icon(Icons.add),
            onPressed: () => _addDepartment(context, ref),
          ),
        ],
      ),
      drawer: AppShell.usesFixedNav(context) ? null : const AppDrawer(),
      body: deptsAsync.when(
        data: (depts) {
          if (depts.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No departments yet',
              message: 'Add the clinic departments so staff know which '
                  'service each area provides.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: depts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final dept = depts[i];
              final icon = _icons[i % _icons.length];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.goldColor.withValues(alpha: 0.35)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: AppTheme.primaryColor),
                  ),
                  title: Text(dept['name'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    (dept['description'] as String? ?? '').isEmpty
                        ? 'No description'
                        : dept['description'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.errorColor),
                    onPressed: () => _deleteDepartment(context, ref, dept),
                  ),
                ),
              );
            },
          );
        },
        error: (_, __) => const Center(
          child: Text('Error loading departments',
              style: TextStyle(color: AppTheme.errorColor)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}