import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/license_provider.dart';
import '../../core/network/patient_server.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../core/utils/constants.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _livePatientCount = 0;
  final List<String> _notifications = [];
  int _lastPollCount = 0;
  Timer? _pollTimer;
  int _pollRunCount = 0;
  String _dbResult = '?';
  String _lastPollName = '';

  @override
  void initState() {
    super.initState();
    _refreshCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollDb());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    final count = await DatabaseHelper().getPatientCount();
    _lastPollCount = count;
    if (mounted) setState(() => _livePatientCount = count);
  }

  Future<void> _pollDb() async {
    _pollRunCount++;
    if (!mounted) return;
    final count = await DatabaseHelper().getPatientCount();
    if (!mounted) return;
    if (count > _lastPollCount) {
      final diff = count - _lastPollCount;
      _lastPollCount = count;
      _livePatientCount = count;
      final patients = await DatabaseHelper().getAllPatients();
      if (!mounted) return;
      final names = patients.sublist(patients.length - diff).map((p) => p.fullName).toList();
      _lastPollName = names.join(', ');
      for (final name in names) {
        if (!_notifications.contains(name)) {
          _notifications.add(name);
        }
      }
      setState(() {});
      for (final name in names) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('New patient received: $name'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ));
        } catch (_) {}
      }
    } else {
      _lastPollCount = count;
    }
    _dbResult = 'poll#$_pollRunCount count=$count last=$_lastPollCount live=$_livePatientCount n=${_notifications.length}';
    if (mounted) setState(() {});
  }

  Future<void> _startServer() async {
    final server = ref.read(patientServerProvider);
    if (server.state == ServerState.stopped) {
      await server.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final genderDist = ref.watch(genderDistributionProvider);
    final recentExams = ref.watch(recentExaminationsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final licenseStatus = ref.watch(licenseStatusProvider);
    final server = ref.watch(patientServerProvider);
    final count = _livePatientCount;
    final hasNew = _notifications.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('MediRecord #$_pollRunCount n=${_notifications.length}'),
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: themeMode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/patients'),
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: hasNew ? Colors.red : Colors.grey),
            onPressed: () {
              final names = List<String>.from(_notifications);
              _notifications.clear();
              setState(() {});
              context.push('/patients');
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            color: Colors.red,
            child: Text('CUSTOM: ${AppConstants.customDrugs.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          if (licenseStatus == LicenseStatus.trial) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: count >= 70 ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: count >= 70 ? Colors.orange : Colors.green),
              ),
              child: Row(
                children: [
                  Icon(count >= 70 ? Icons.warning_amber_rounded : Icons.free_breakfast,
                       color: count >= 70 ? Colors.orange : Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      count >= 70
                          ? 'Trial limit reached — Activate license to add patients'
                          : 'Free Trial — $count/70 patients used',
                      style: TextStyle(
                        fontSize: 13,
                        color: count >= 70 ? Colors.orange.shade800 : Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi, size: 20,
                           color: server.state == ServerState.running ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        server.state == ServerState.running ? 'Server Running' : 'Server Stopped',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: server.state == ServerState.running ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (server.state == ServerState.running) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.computer, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text('IP: ${server.ip}:${server.port}',
                             style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: '${server.ip}:${server.port}'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('IP copied to clipboard'), duration: Duration(seconds: 2)));
                          },
                          child: const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Total Patients: $count',
                         style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                  if (server.state == ServerState.error) ...[
                    const SizedBox(height: 8),
                    Text(server.error, style: const TextStyle(fontSize: 12, color: AppTheme.errorColor)),
                  ],
                  const SizedBox(height: 4),
                  Text('DEBUG: ${_dbResult}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  if (_lastPollName.isNotEmpty)
                    Text('FOUND: $_lastPollName', style: const TextStyle(fontSize: 9, color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard(Icons.people, 'Total Patients', '$count', Colors.blue, () => context.push('/patients'))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard(Icons.person, 'Male', '${genderDist.valueOrNull?['Male'] ?? 0}', Colors.blue, null)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard(Icons.person, 'Female', '${genderDist.valueOrNull?['Female'] ?? 0}', Colors.pink, null)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Examinations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  recentExams.when(
                    data: (exams) => exams.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No examinations yet', style: TextStyle(color: AppTheme.textSecondary)),
                          )
                        : Column(
                            children: exams.take(5).map((e) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.assignment, size: 20, color: AppTheme.primaryColor),
                              title: Text(e['patient_name'] ?? 'Unknown',
                                          style: const TextStyle(fontSize: 14)),
                              subtitle: Text(e['created_at']?.toString().substring(0, 10) ?? '',
                                              style: const TextStyle(fontSize: 12)),
                            )).toList(),
                          ),
                    error: (_, __) => const Text('Error loading', style: TextStyle(color: AppTheme.errorColor)),
                    loading: () => const CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color, VoidCallback? onTap) {
    final child = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: child);
    }
    return child;
  }
}

class _NotificationPage extends StatelessWidget {
  final List<String> patients;
  const _NotificationPage({required this.patients});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Patients Received')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: patients.length,
        itemBuilder: (_, i) => Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: Text(patients[i], style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
