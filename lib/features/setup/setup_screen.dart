import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../shared/widgets/luxury_figures.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final json = await DatabaseHelper().exportAllData();
      if (!context.mounted) return;

      final file = await getSaveLocation(
        suggestedName: 'medirecord_backup_${DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-')}.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON backup', extensions: ['json']),
        ],
      );
      if (file == null) return;

      await File(file.path).writeAsString(json);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved to ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON backup', extensions: ['json']),
      ],
    );
    if (file == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyDeep,
        title: const Text('Restore backup?', style: TextStyle(color: AppTheme.champagneLight)),
        content: const Text(
          'This will replace all current data with the backup contents.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: AppTheme.champagne)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final json = await File(file.path).readAsString();
      final data = await DatabaseHelper().importAllData(json);
      if (!context.mounted) return;
      final count = (data['patients'] as List?)?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup restored ($count patients)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxNavyBackdrop(
        showBack: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LuxBrandHeader(
              title: 'Setup & Backup',
              tagline: 'PROTECT YOUR DATA WITH ONE CLICK',
            ),
            const SizedBox(height: 28),
            _ActionCard(
              icon: Icons.file_download_outlined,
              title: 'Backup data to a file',
              subtitle: 'Choose where to save a full copy of all records',
              onTap: () => _exportBackup(context),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.file_upload_outlined,
              title: 'Restore from a backup',
              subtitle: 'Load a backup file and replace current data',
              onTap: () => _restoreBackup(context),
            ),
            const SizedBox(height: 28),
            const Text(
              'Backups are saved as JSON files you can store anywhere: USB, cloud, or another PC.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.goldLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LuxHover(
      onTap: onTap,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF101D45), Color(0xFF0B1430)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.goldGradient,
                boxShadow: [BoxShadow(color: AppTheme.goldDeep.withValues(alpha: 0.4), blurRadius: 10)],
              ),
              child: Icon(icon, color: AppTheme.navyDeep, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.champagneLight,
                      fontSize: 15,
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.goldColor),
          ],
        ),
      ),
    );
  }
}
