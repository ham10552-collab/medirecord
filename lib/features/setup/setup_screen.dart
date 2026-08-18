import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/fixed_ip_service.dart';
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
  String _detectedIp = '';
  String _fixedIp = '';
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  Future<void> _refreshInfo() async {
    final folder = await BackupManager.resolveFolder();
    final last = await AppStorage.read(BackupManager.lastKey) ?? '';
    final list = await BackupManager.listBackups();
    final detected = await FixedIpService.detectLocalIp();
    final fixed = await FixedIpService.getFixedIp();
    if (!mounted) return;
    setState(() {
      _folder = folder.path;
      _lastBackup = last;
      _backupCount = list.length;
      _detectedIp = detected;
      _fixedIp = fixed;
    });
  }

  Future<void> _saveFixedIp() async {
    if (_detectedIp.isEmpty) return;
    await FixedIpService.saveFixedIp(_detectedIp);
    await _refreshInfo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fixed IP saved - the pharmacy will always use this address'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _applyStaticIp() async {
    if (_fixedIp.isEmpty) return;
    final dns = await FixedIpService.detectDns();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyDeep,
        title: const Text('Apply static IP?', style: TextStyle(color: AppTheme.champagneLight)),
        content: Text(
          'This PC will be set to the fixed address $_fixedIp (mask 255.255.255.0, '
          'current gateway). An administrator window will open - accept it. '
          'The IP will never change, even after restarting the PC.\n\n'
          'DNS servers: ${dns.join(', ')} - internet will keep working.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply', style: TextStyle(color: AppTheme.champagne)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _applying = true);
    final result = await FixedIpService.applyStaticIp(_fixedIp);
    await _refreshInfo();
    if (!mounted) return;
    setState(() => _applying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result),
        backgroundColor: result.contains('successfully') ? Colors.green : AppTheme.errorColor,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _openFirewall() async {
    try {
      if (await _firewallRulePresent()) {
        await AppStorage.write('firewall_9876_opened', 'true');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Port 9876 is already open in Windows Firewall'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      final cmd = 'netsh advfirewall firewall add rule '
          'name="MediRecord LAN (9876)" dir=in action=allow '
          'protocol=TCP localport=9876 profile=private,domain';
      final encoded = base64Encode(_utf16Le(cmd));
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Start-Process powershell -Verb RunAs -ArgumentList '
              "'-NoProfile','-EncodedCommand','$encoded' -Wait",
        ],
      );
      if (!await _firewallRulePresent()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Firewall rule not created - accept the administrator window and try again'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      await AppStorage.write('firewall_9876_opened', 'true');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Port 9876 opened in Windows Firewall - the pharmacy and secretary can now reach this PC'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firewall: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  static Future<bool> _firewallRulePresent() async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "if (Get-NetFirewallRule -DisplayName 'MediRecord LAN (9876)' "
            "-ErrorAction SilentlyContinue) { 'True' } else { 'False' }",
      ]);
      return r.exitCode == 0 && (r.stdout as String).trim() == 'True';
    } catch (_) {
      return false;
    }
  }

  static List<int> _utf16Le(String s) {
    final bytes = <int>[];
    for (final unit in s.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return bytes;
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
        onBack: () {
          if (context.canPop()) {
            Navigator.pop(context);
          } else {
            context.go('/');
          }
        },
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
              _FixedIpCard(
                detectedIp: _detectedIp,
                fixedIp: _fixedIp,
                applying: _applying,
                onSave: _saveFixedIp,
                onApply: _applyStaticIp,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: _fixedIp));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fixed IP copied - give it to the pharmacy')),
                  );
                },
                onOpenFirewall: _openFirewall,
              ),
              const SizedBox(height: 14),
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

class _FixedIpCard extends StatelessWidget {
  final String detectedIp;
  final String fixedIp;
  final bool applying;
  final VoidCallback onSave;
  final VoidCallback onApply;
  final VoidCallback onCopy;
  final VoidCallback onOpenFirewall;

  const _FixedIpCard({
    required this.detectedIp,
    required this.fixedIp,
    required this.applying,
    required this.onSave,
    required this.onApply,
    required this.onCopy,
    required this.onOpenFirewall,
  });

  @override
  Widget build(BuildContext context) {
    final isFixed = fixedIp.isNotEmpty && fixedIp == detectedIp;
    return LuxHover(
      onTap: () {},
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
          border: Border.all(
            color: isFixed
                ? AppTheme.successColor.withValues(alpha: 0.6)
                : AppTheme.goldColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isFixed ? AppTheme.successColor : AppTheme.goldColor)
                        .withValues(alpha: 0.18),
                    border: Border.all(
                      color: (isFixed ? AppTheme.successColor : AppTheme.goldDeep)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    isFixed ? Icons.lock_outline : Icons.lan_outlined,
                    color: isFixed ? AppTheme.successColor : AppTheme.goldDeep,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Fixed IP',
                        style: TextStyle(
                          color: AppTheme.champagneLight,
                          fontSize: 15,
                          fontFamily: AppTheme.displayFont,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFixed
                            ? 'This PC is fixed at $fixedIp'
                            : detectedIp.isEmpty
                                ? 'No network detected'
                                : 'Current: $detectedIp',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy IP',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopy,
                  icon: Icon(Icons.copy, size: 16, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (fixedIp.isNotEmpty && fixedIp != detectedIp)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Saved fixed IP: $fixedIp',
                  style: const TextStyle(color: AppTheme.goldLight, fontSize: 11),
                ),
              ),
            Row(
              children: [
                if (!isFixed) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: detectedIp.isEmpty ? null : onSave,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save fixed IP'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.goldLight,
                        side: const BorderSide(color: AppTheme.goldColor),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: applying || fixedIp.isEmpty ? null : onApply,
                    icon: applying
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pin_outlined, size: 16),
                    label: Text(isFixed ? 'Apply on Windows' : 'Set as static IP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFixed ? AppTheme.successColor : AppTheme.goldDeep,
                      foregroundColor: AppTheme.navyDeep,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Fix the IP once so the pharmacy always finds this PC on the network. '
              'Give the pharmacy the saved IP - it will appear automatically.',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenFirewall,
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Open port 9876 (firewall)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.goldLight,
                      side: const BorderSide(color: AppTheme.goldColor),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
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