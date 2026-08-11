import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/app_storage.dart';
import '../../core/utils/backup_manager.dart';
import '../../shared/widgets/luxury_figures.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _folder = '';
  String _lastBackup = '';
  int _backupCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  Future<void> _refreshInfo() async {
    final folder = await BackupManager.resolveFolder();
    final last = await AppStorage.read(BackupManager.lastKey) ?? '';
    final list = await BackupManager.listBackups();
    if (!mounted) return;
    setState(() {
      _folder = folder.path;
      _lastBackup = last;
      _backupCount = list.length;
    });
  }

  Future<void> _chooseFolder() async {
    final dir = await getDirectoryPath(
      confirmButtonText: 'Use This Folder',
      initialDirectory: _folder,
    );
    if (dir == null) return;
    await AppStorage.write(BackupManager.folderKey, dir);
    await BackupManager.runDailyBackup();
    await _refreshInfo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Automatic daily backups will be saved in:\n$dir'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _backupNow() async {
    final path = await BackupManager.createBackup();
    await _refreshInfo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null ? 'Backup saved:\n$path' : 'Backup failed - try again'),
        backgroundColor: path != null ? Colors.green : AppTheme.errorColor,
      ),
    );
  }

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              const LuxBrandHeader(
                title: 'Setup & Backup',
                tagline: 'AUTOMATIC DAILY BACKUPS - NO MORE LOSING DATA',
              ),
              const SizedBox(height: 24),
              _ActionCard(
                icon: Icons.folder_outlined,
                title: 'Automatic backup folder',
                subtitle: _folder.isEmpty
                    ? 'Choose where daily backups are saved'
                    : 'Folder:\n${_lastBackup.isNotEmpty ? 'Last backup: $_lastBackup' : ''}',
                trailing: Text(
                  _folder.isEmpty ? 'Tap to choose' : '$_backupCount backup(s)',
                  style: const TextStyle(color: AppTheme.goldLight, fontSize: 10),
                ),
                onTap: _chooseFolder,
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.cloud_upload_outlined,
                title: 'Back up now',
                subtitle: 'One backup of everything - records, prescriptions, images',
                trailing: Text(
                  _lastBackup.isEmpty ? 'Not backed up yet' : 'Daily at app start',
                  style: const TextStyle(color: AppTheme.goldLight, fontSize: 10),
                ),
                onTap: _backupNow,
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.file_download_outlined,
                title: 'Backup data to a chosen file',
                subtitle: 'Save a full copy anywhere: USB, cloud, another PC',
                onTap: () => _exportBackup(context),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.file_upload_outlined,
                title: 'Restore from a backup',
                subtitle: 'Load a backup file and replace current data',
                onTap: () => _restoreBackup(context),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'A backup is created automatically once per day (the last 21 are kept). Backups are JSON files you can store anywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.goldLight, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LuxHover(
      onTap: onTap,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(16),
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
            const SizedBox(width: 14),
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
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 4),
                    trailing!,
                  ],
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