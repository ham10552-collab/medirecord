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
import '../../core/license/license_manager.dart';
import '../../core/utils/constants.dart';
import '../../core/network/patient_server.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../../shared/models/patient.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _livePatientCount = 0;
  final List<Patient> _notifications = [];
  final List<Patient> _readNotifications = [];
  int _lastPollCount = 0;
  Timer? _pollTimer;

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
    final count = await DatabaseHelper().getPatientCount();
    if (!mounted) return;
    if (count > _lastPollCount) {
      final diff = count - _lastPollCount;
      _lastPollCount = count;
      _livePatientCount = count;
      final patients = await DatabaseHelper().getAllPatients();
      if (!mounted) return;
      final newPatients = patients.sublist(patients.length - diff);
      for (final p in newPatients) {
        if (!_notifications.any((n) => n.id == p.id) && !_readNotifications.any((n) => n.id == p.id)) {
          _notifications.add(p);
        }
      }
      setState(() {});
      for (final p in newPatients) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('New patient received: ${p.fullName}'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        } catch (_) {}
      }
    } else {
      _lastPollCount = count;
    }
  }

  Future<void> _startServer() async {
    final server = ref.read(patientServerProvider);
    if (server.state == ServerState.stopped) {
      await server.start();
    }
  }

  void _openNotifications() {
    final pending = List<Patient>.from(_notifications);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _NotificationPanel(
        newPatients: pending,
        previousPatients: List<Patient>.from(_readNotifications),
        onOpenPatient: (patient) {
          Navigator.pop(sheetCtx);
          setState(() {
            _notifications.removeWhere((n) => n.id == patient.id);
            if (!_readNotifications.any((n) => n.id == patient.id)) {
              _readNotifications.add(patient);
            }
          });
          context.push('/patients/${patient.id}');
        },
        onClearAll: () {
          setState(() {
            _readNotifications.addAll(_notifications);
            _notifications.clear();
          });
        },
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final genderDist = ref.watch(genderDistributionProvider);
    final recentExams = ref.watch(recentExaminationsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final licenseStatus = ref.watch(licenseStatusProvider);
    final server = ref.watch(patientServerProvider);
    final count = _livePatientCount;
    final male = genderDist.valueOrNull?['Male'] ?? 0;
    final female = genderDist.valueOrNull?['Female'] ?? 0;
    final hasNew = _notifications.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediRecord'),
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: themeMode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Bookings',
            onPressed: () => context.push('/bookings'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/patients'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(
                    hasNew ? Icons.notifications_active : Icons.notifications_none,
                    color: hasNew ? AppTheme.goldColor : null,
                  ),
                  onPressed: () => _openNotifications(),
                ),
                if (hasNew)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        '${_notifications.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildHeroCard(server, count),
          if (licenseStatus == LicenseStatus.trial) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: count >= AppConstants.maxTrialPatients
                      ? const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)])
                      : const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(count >= AppConstants.maxTrialPatients ? Icons.warning_amber_rounded : Icons.workspace_premium,
                         color: count >= AppConstants.maxTrialPatients ? AppTheme.warningColor : AppTheme.successColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        count >= AppConstants.maxTrialPatients
                            ? 'Trial limit reached — Activate license to continue'
                            : 'Free Trial — $count/${AppConstants.maxTrialPatients} patients used',
                        style: TextStyle(
                          fontSize: 13,
                          color: count >= AppConstants.maxTrialPatients ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push('/license'),
                      child: Text(
                        'Upgrade',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: count >= AppConstants.maxTrialPatients ? AppTheme.warningColor : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const LuxSectionTitle(title: 'Quick Actions', icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _actionCard(Icons.person_add_alt_1, 'Add Patient', AppTheme.primaryColor, () => context.push('/patients'))),
                const SizedBox(width: 12),
                Expanded(child: _actionCard(Icons.calendar_month, 'Bookings', AppTheme.goldColor, () => context.push('/bookings'))),
                const SizedBox(width: 12),
                Expanded(child: _actionCard(Icons.receipt_long, 'Reports', AppTheme.secondaryColor, () => context.push('/reports'))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const LuxSectionTitle(title: 'Statistics', icon: Icons.stacked_line_chart_rounded),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.people_alt,
                    'Total Patients',
                    '$count',
                    AppTheme.primaryColor,
                    () => context.push('/patients'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.male, 'Male', '$male', AppTheme.primaryLight, null)),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.female, 'Female', '$female', AppTheme.goldColor, null)),
              ],
            ),
          ),
          if ((male > 0 || female > 0)) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _genderRatioCard(male, female, total: count),
            ),
          ],
          if (recentExams.valueOrNull?.isNotEmpty ?? false) ...[
            const SizedBox(height: 20),
            const LuxSectionTitle(title: 'Recent Examinations', icon: Icons.assignment_rounded),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRecentExams(recentExams),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard(PatientServer server, int count) {
    final online = server.state == ServerState.running;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navyDeep.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.goldColor.withValues(alpha: 0.20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -25,
            child: Icon(Icons.auto_awesome, size: 64, color: AppTheme.goldColor.withValues(alpha: 0.22)),
          ),
          Positioned(
            right: 30,
            top: -8,
            child: Icon(Icons.medical_services_outlined, size: 120, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            right: 52,
            bottom: -30,
            child: Icon(Icons.bubble_chart, size: 90, color: Colors.white.withValues(alpha: 0.04)),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Transform.flip(flipY: true, child: CornerOrnament(size: 30, color: Colors.white.withValues(alpha: 0.5))),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: CornerOrnament(size: 30, color: Colors.white.withValues(alpha: 0.5)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SparkleFigure(size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _greeting().toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.goldLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const SparkleFigure(size: 14),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const MedicalCrossFigure(size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'MediRecord Pro',
                        style: AppTheme.displayStyle(size: 24, color: Colors.white, gold: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete clinic management at your fingertips',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5, letterSpacing: 0.2),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 10, color: online ? const Color(0xFF69F0AE) : Colors.orangeAccent),
                          const SizedBox(width: 6),
                          Text(
                            online ? 'Online' : 'Offline',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (online)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: '${server.ip}:${server.port}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Clinic address copied'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.goldColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${server.ip}:${server.port}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy, size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.06)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const SparkleFigure(size: 15, color: AppTheme.goldLight),
                      const SizedBox(width: 10),
                      Text('$count patients recorded',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios, color: AppTheme.goldLight.withValues(alpha: 0.9), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color, VoidCallback? onTap) {
    final child = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.navy)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, letterSpacing: 0.2)),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: child);
    }
    return child;
  }

  Widget _genderRatioCard(int male, int female, {required int total}) {
    final malePct = total == 0 ? 0 : (male / total * 100).toStringAsFixed(0);
    final femalePct = total == 0 ? 0 : (female / total * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SparkleFigure(size: 13),
              const SizedBox(width: 8),
              Text('Gender Distribution', style: AppTheme.displayStyle(size: 15, color: AppTheme.navy)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.male, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Text('Male  $male', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(width: 20),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.female, size: 16, color: AppTheme.goldColor),
                const SizedBox(width: 4),
                Text('Female  $female', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: total == 0 ? 0.5 : male / total,
                    alignment: Alignment.centerLeft,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryLight, AppTheme.navy]),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: total == 0 ? 0.5 : female / total,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$malePct%', style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryColor, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$femalePct%', style: const TextStyle(fontSize: 11.5, color: AppTheme.goldDeep, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExams(AsyncValue recentExams) {
    return recentExams.when(
      data: (exams) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: exams.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No examinations yet', style: TextStyle(color: AppTheme.textSecondary)),
              )
            : Column(
                children: <Widget>[
                  ...exams.take(5).map<Widget>((e) {
                    final name = (e['patient_name'] ?? 'Unknown').toString();
                    final date = e['created_at']?.toString().substring(0, 10) ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(date, style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => context.push('/patients'),
                    );
                  }),
                ],
              ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Error loading', style: TextStyle(color: AppTheme.errorColor)),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  final List<Patient> newPatients;
  final List<Patient> previousPatients;
  final void Function(Patient) onOpenPatient;
  final VoidCallback onClearAll;

  const _NotificationPanel({
    required this.newPatients,
    required this.previousPatients,
    required this.onOpenPatient,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...newPatients, ...previousPatients];
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                const MedicalCrossFigure(size: 16),
                const SizedBox(width: 10),
                Text('Notifications', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
                const Spacer(),
                if (newPatients.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.done_all, color: AppTheme.textSecondary),
                    tooltip: 'Mark all read',
                    onPressed: onClearAll,
                  ),
              ],
            ),
          ),
          if (newPatients.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${newPatients.length} NEW PATIENT${newPatients.length == 1 ? '' : 'S'} FROM SECRETARY',
                style: const TextStyle(
                  color: AppTheme.navyDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          const SizedBox(height: 8),
          const GoldDivider(),
          Expanded(
            child: all.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 52, color: AppTheme.dividerColor),
                        SizedBox(height: 12),
                        Text('No notifications yet', style: TextStyle(color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('New patients sent by the secretary\nwill appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: all.length,
                    itemBuilder: (context, i) {
                      final p = all[i];
                      final isNew = i < newPatients.length;
                      return _notificationTile(context, p, isNew);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _notificationTile(BuildContext context, Patient p, bool isNew) {
    final initial = p.fullName.isNotEmpty ? p.fullName.substring(0, 1).toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: isNew ? AppTheme.goldColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew ? AppTheme.goldColor.withValues(alpha: 0.55) : AppTheme.dividerColor,
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: () => onOpenPatient(p),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: isNew ? AppTheme.goldGradient : AppTheme.heroGradient,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isNew ? AppTheme.goldColor : AppTheme.primaryColor).withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: isNew ? AppTheme.navyDeep : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                p.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (isNew) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                _infoChip(Icons.cake_outlined, '${p.age} yrs'),
                _infoChip(p.gender.toLowerCase() == 'female' ? Icons.female : Icons.male, p.gender),
                if (p.bloodGroup != null) _infoChip(Icons.bloodtype_outlined, p.bloodGroup!),
                if (p.phone != null) _infoChip(Icons.phone_outlined, p.phone!),
              ],
            ),
            if (p.address != null && p.address!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.primaryColor),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}