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
import '../../core/utils/constants.dart';
import '../../core/network/patient_server.dart';
import '../../core/network/pharmacy_notifications.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/global_search.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../../shared/widgets/skeleton.dart';

/// Dashboard shown for the doctor role.

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _livePatientCount = 0;
  final Set<String> _seenPatientIds = {};
  final List<Map<String, dynamic>> _alerts = [];
  bool _notificationsSeeded = false;
  Timer? _pollTimer;
  bool _doctorNameChecked = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
      _ensureDoctorName();
      _loadAlerts();
      incomingPatientNotifier.addListener(_onIncomingEvent);
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollDb());
    });
  }

  /// Asks the doctor for his name ONCE. The name is stored on this PC and is
  /// used on every prescription he creates or sends - he never types it again.
  Future<void> _ensureDoctorName() async {
    String? saved;
    try {
      saved = await AppStorage.read('doctor_name');
    } catch (_) {}
    if (saved != null && saved.trim().isNotEmpty || _doctorNameChecked) return;
    _doctorNameChecked = true;
    final ctrl = TextEditingController(
      text: ref.read(currentUserProvider)?.displayName?.trim() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Doctor Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your name as it should appear on prescriptions',
            hintText: 'e.g. Dr. Ahmed',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (name != null && name.isNotEmpty) {
      await AppStorage.write('doctor_name', name);
      ref.invalidate(doctorNameProvider);
      ref.read(patientServerProvider).setDoctorIdentity(name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Doctor name saved: $name - used on all prescriptions'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    final count = await DatabaseHelper().getPatientCount();
    if (mounted) setState(() => _livePatientCount = count);
  }

  Future<void> _loadAlerts() async {
    final alerts = await readIncomingAlerts();
    if (mounted) setState(() {
      _alerts
        ..clear()
        ..addAll(alerts);
    });
  }

  void _onIncomingEvent() {
    if (incomingPatientNotifier.value.isNotEmpty) {
      _loadAlerts();
    }
  }

  Future<void> _pollDb() async {
    final patients = await DatabaseHelper().getAllPatients();
    if (!mounted) return;
    _livePatientCount = patients.length;
    if (!_notificationsSeeded) {
      _notificationsSeeded = true;
      _seenPatientIds.addAll(patients.map((p) => p.id));
      return;
    }
    final fresh = patients
        .where((p) =>
            !_seenPatientIds.contains(p.id) &&
            !_alerts.any((a) => a['id'] == p.id))
        .toList();
    setState(() {
      _seenPatientIds.addAll(patients.map((p) => p.id));
    });
    for (final p in fresh) {
      await recordIncomingAlert(p.id, p.fullName);
    }
    if (fresh.isNotEmpty) {
      await _loadAlerts();
      try {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('New patient received: ${fresh.first.fullName}'
              '${fresh.length > 1 ? ' (+${fresh.length - 1} more)' : ''}'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      } catch (_) {}
    }
  }

  Future<void> _startServer() async {
    final server = ref.read(patientServerProvider);
    var name = (await AppStorage.read('doctor_name'))?.trim() ?? '';
    if (name.isEmpty) {
      name = ref.read(currentUserProvider)?.displayName?.trim() ?? '';
    }
    if (name.isEmpty) {
      name = (await AppStorage.read('last_doctor_name'))?.trim() ?? '';
    }
    if (name.isNotEmpty) {
      server.setDoctorIdentity(name);
    }
    if (server.state == ServerState.stopped) {
      await server.start();
    }
  }

  Future<void> _openNotifications() async {
    final snapshot = List<Map<String, dynamic>>.from(_alerts);
    final hadUnread = snapshot.any((a) => a['read'] != true);
    await markIncomingAlertsRead();
    if (hadUnread) _loadAlerts();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _IncomingPanel(
        alerts: snapshot,
        onOpenPatient: (id) {
          Navigator.pop(sheetCtx);
          if (id.startsWith('lab_')) {
            context.push(
              '/lab-orders?highlight=${Uri.encodeComponent(id.substring(4))}',
            );
          } else {
            context.push('/patients/$id');
          }
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
    final weeklyActivity = ref.watch(weeklyActivityProvider);
    final comparisonStats = ref.watch(comparisonStatsProvider);
    final activity = ref.watch(activityProvider);
    final themeMode = ref.watch(themeModeProvider);
    final licenseStatus = ref.watch(licenseStatusProvider);
    final server = ref.watch(patientServerProvider);
    final count = _livePatientCount;
    final male = genderDist.valueOrNull?['Male'] ?? 0;
    final female = genderDist.valueOrNull?['Female'] ?? 0;
    final unreadAlerts = _alerts.where((a) => a['read'] != true).length;
    final hasNew = unreadAlerts > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediRecord'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.goldColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.5)),
              ),
              child: const Text('v25',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.goldDeep)),
            ),
          ),
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: themeMode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          PopupMenuButton<AppDisplayDensity>(
            tooltip: 'Display density',
            icon: const Icon(Icons.density_medium),
            onSelected: (d) => ref.read(displayDensityProvider.notifier).setDensity(d),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AppDisplayDensity.compact,
                child: Text('Compact'),
              ),
              PopupMenuItem(
                value: AppDisplayDensity.cozy,
                child: Text('Cozy'),
              ),
              PopupMenuItem(
                value: AppDisplayDensity.roomy,
                child: Text('Roomy'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Bookings',
            onPressed: () => context.push('/bookings'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Global search',
            onPressed: () => showGlobalSearch(context),
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
                  tooltip: hasNew ? 'Notifications (new)' : 'Notifications',
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
                        '$unreadAlerts',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: AppShell.usesFixedNav(context) ? null : const AppDrawer(),
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
                            ? 'Trial limit reached â€” Activate license to continue'
                            : 'Free Trial â€” $count/${AppConstants.maxTrialPatients} patients used',
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
                Expanded(child: _actionCard(Icons.person_add_alt_1, 'Add Patient', AppTheme.primaryColor, () => context.push('/patients/add'))),
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
                    delta: '+${comparisonStats.valueOrNull?['new_patients_delta'] ?? 0} new',
                    deltaUp: (comparisonStats.valueOrNull?['new_patients_delta'] ?? 0) >= 0,
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
          const SizedBox(height: 20),
          const LuxSectionTitle(title: 'Clinic Overview', icon: Icons.dashboard_customize_outlined),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _weeklyChartCard(weeklyActivity),
          ),
          const SizedBox(height: 20),
          const LuxSectionTitle(title: 'Recent Activity', icon: Icons.history_rounded),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _activityPanel(activity),
          ),
          if ((recentExams.valueOrNull ?? []).isEmpty) ...[
            const SizedBox(height: 20),
            const LuxSectionTitle(title: 'Recent Examinations', icon: Icons.assignment_rounded),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmptyState(
                icon: Icons.medical_services_outlined,
                title: 'No examinations yet',
                message: 'Recent examinations will appear here once you record your first one.',
                actionLabel: 'Start an Examination',
                onAction: () => context.push('/patients'),
              ),
            ),
          ] else ...[
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
                      style: const TextStyle(
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
    final vd = Theme.of(context).visualDensity;
    final padV = vd == VisualDensity.compact
        ? 10.0
        : (vd == VisualDensity.comfortable ? 26.0 : 18.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: padV, horizontal: 8),
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

  Widget _statCard(IconData icon, String label, String value, Color color, VoidCallback? onTap,
      {String? delta, bool deltaUp = true}) {
    final vd = Theme.of(context).visualDensity;
    final pad = vd == VisualDensity.compact
        ? 8.0
        : (vd == VisualDensity.comfortable ? 20.0 : 14.0);
    final child = Container(
      padding: EdgeInsets.all(pad),
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
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.navy)),
          if (delta != null) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 13,
                  color: deltaUp ? AppTheme.successColor : AppTheme.warningColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '$delta vs last week',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: deltaUp ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _activityPanel(AsyncValue<List<Map<String, dynamic>>> activity) {
    final items = activity.valueOrNull ?? const [];
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 36, color: AppTheme.textSecondary),
            SizedBox(height: 8),
            Text(
              'No activity yet',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 2),
            Text(
              'Actions like adding patients, exams and prescriptions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 52, endIndent: 12, color: AppTheme.goldLight),
            _activityRow(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _activityRow(Map<String, dynamic> item) {
    final type = (item['type'] as String? ?? '');
    final (icon, color) = switch (type) {
      'patient' => (Icons.person_add_alt_1, AppTheme.primaryColor),
      'examination' => (Icons.assignment_rounded, AppTheme.secondaryColor),
      'booking' => (Icons.event_available, AppTheme.goldDeep),
      'prescription' => (Icons.medication_outlined, const Color(0xFF2E7D32)),
      'lab' => (Icons.science_outlined, const Color(0xFF6A1B9A)),
      'department' => (Icons.business_outlined, const Color(0xFF37474F)),
      _ => (Icons.history, AppTheme.textSecondary),
    };
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
      title: Text(
        item['title'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy),
      ),
      subtitle: Text(
        item['detail'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Text(
        _relativeTime(item['at'] as String? ?? ''),
        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
      ),
    );
  }

  String _relativeTime(String iso) {
    try {
      final then = DateTime.parse(iso);
      final diff = DateTime.now().difference(then);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${then.day}/${then.month}';
    } catch (_) {
      return '';
    }
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

  Widget _weeklyChartCard(AsyncValue<List<Map<String, dynamic>>> weekly) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: weekly.when(
        data: (days) {
          final hasData = days.any((d) => (d['visits'] as int? ?? 0) > 0 || (d['prescriptions'] as int? ?? 0) > 0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SparkleFigure(size: 13),
                  const SizedBox(width: 8),
                  Text('Last 7 Days', style: AppTheme.displayStyle(size: 15, color: AppTheme.navy)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _legendDot(AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  const Text('Visits', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(width: 14),
                  _legendDot(AppTheme.goldDeep),
                  const SizedBox(width: 6),
                  const Text('Prescriptions', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Center(
                    child: Text('No activity this week yet',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  ),
                )
              else
                SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: CustomPaint(painter: _WeeklyBarsPainter(days)),
                ),
            ],
          );
        },
        error: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Center(
            child: Text('Error loading activity', style: TextStyle(color: AppTheme.errorColor, fontSize: 12.5)),
          ),
        ),
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 140),
            SizedBox(height: 10),
            SkeletonBox(width: 200, height: 11),
            SizedBox(height: 16),
            SkeletonBox(height: 120, radius: 8),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
      loading: () => const SkeletonPulse(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 180),
              SizedBox(height: 10),
              SkeletonBox(width: 260, height: 11),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 11),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingPanel extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final void Function(String id) onOpenPatient;

  const _IncomingPanel({required this.alerts, required this.onOpenPatient});

  @override
  Widget build(BuildContext context) {
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
                Text('Incoming Patients', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
                const Spacer(),
                if (alerts.isNotEmpty)
                  Text('${alerts.length} total',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const GoldDivider(),
          Expanded(
            child: alerts.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No new patients yet',
                    message: 'Patients sent by the secretary will appear here in real time.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: alerts.length,
                    itemBuilder: (context, i) {
                      final a = alerts[i];
                      final rawName = ((a['name'] ?? a['patient_name']) as String? ?? '').trim();
                      final name = rawName.isEmpty ? 'Patient' : rawName;
                      final at = a['at'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        decoration: BoxDecoration(
                          color: a['read'] != true
                              ? AppTheme.goldColor.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: a['read'] != true
                                ? AppTheme.goldColor.withValues(alpha: 0.55)
                                : AppTheme.dividerColor,
                            width: 1.2,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: AppTheme.goldDeep,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              if (a['type'] == 'followup') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Follow up',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      )),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                at.length >= 16 ? 'Sent ${at.substring(0, 10)} at ${at.substring(11, 16)}' : 'Sent just now',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                          onTap: () => onOpenPatient(a['id'] as String? ?? ''),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Simple 7-day grouped bar chart (visits + prescriptions) drawn without
/// external chart packages.
class _WeeklyBarsPainter extends CustomPainter {
  final List<Map<String, dynamic>> days;

  _WeeklyBarsPainter(this.days);

  @override
  void paint(Canvas canvas, Size size) {
    const visitsColor = AppTheme.primaryColor;
    const rxColor = AppTheme.goldDeep;
    const labelColor = AppTheme.textSecondary;
    final paint = Paint()..isAntiAlias = true;

    var maxVal = 1;
    for (final d in days) {
      final v = d['visits'] as int? ?? 0;
      final p = d['prescriptions'] as int? ?? 0;
      if (v > maxVal) maxVal = v;
      if (p > maxVal) maxVal = p;
    }

    const bottomPad = 22.0;
    const topPad = 16.0;
    final chartHeight = size.height - bottomPad - topPad;
    final slot = size.width / days.length;
    final barWidth = slot * 0.16;
    final gap = slot * 0.05;

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final visits = d['visits'] as int? ?? 0;
      final prescriptions = d['prescriptions'] as int? ?? 0;
      final centerX = slot * i + slot / 2;
      final visitsH = visits <= 0 ? 0.0 : chartHeight * (visits / maxVal).toDouble();
      final rxH = prescriptions <= 0 ? 0.0 : chartHeight * (prescriptions / maxVal).toDouble();

      final rxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth - gap / 2, topPad + chartHeight - rxH, barWidth, rxH),
        const Radius.circular(4),
      );
      final visitsRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + gap / 2, topPad + chartHeight - visitsH, barWidth, visitsH),
        const Radius.circular(4),
      );

      if (prescriptions > 0) paint.color = rxColor;
      canvas.drawRRect(rxRect, paint);
      if (visits > 0) paint.color = visitsColor;
      canvas.drawRRect(visitsRect, paint);

      if (visits > 0) {
        _drawCount(canvas, '${visits + prescriptions}', Offset(centerX, topPad + chartHeight - (visitsH > rxH ? visitsH : rxH) - 10), paint, labelColor);
      } else if (prescriptions > 0) {
        _drawCount(canvas, '$prescriptions', Offset(centerX, topPad + chartHeight - rxH - 10), paint, labelColor);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: (d['fullLabel'] as String? ?? ''),
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - tp.width / 2, topPad + chartHeight + 5));
    }
  }

  void _drawCount(Canvas canvas, String text, Offset at, Paint paint, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_WeeklyBarsPainter oldDelegate) => oldDelegate.days != days;
}
