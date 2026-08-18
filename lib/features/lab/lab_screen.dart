import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_provider.dart';
import '../../core/network/patient_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../prescriptions/prescription_printer.dart';
import 'lab_result_form.dart';

/// The Lab Technician's overall screen: incoming requests, completed results
/// with search + per-patient comparison, and a small overview dashboard.
class LabScreen extends ConsumerStatefulWidget {
  const LabScreen({super.key});

  @override
  ConsumerState<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends ConsumerState<LabScreen> {
  String _tab = 'inbox';
  String _query = '';
  String _dateFilter = '';
  bool _todayOnly = false;
  List<Map<String, String>> _doctors = [];
  final Map<String, bool> _doctorOnline = {};
  bool _checkingDoctors = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final rawList = await AppStorage.readList('doctor_pcs');
    if (rawList.isNotEmpty) {
      final parsed = rawList.map((e) {
        try {
          return (json.decode(e) as Map).cast<String, String>();
        } catch (_) {
          return <String, String>{};
        }
      }).where((m) => (m['ip'] ?? '').trim().isNotEmpty).toList();
      if (mounted) setState(() => _doctors = parsed);
    }
  }

  Future<void> _poll() async {
    ref.invalidate(labQueueProvider);
    ref.invalidate(myLabRequestsProvider);
    await _checkDoctors();
  }

  Future<void> _saveDoctors(List<Map<String, String>> doctors) async {
    await AppStorage.writeList('doctor_pcs',
        doctors.map((d) => json.encode(d)).toList());
  }

  /// Adds/edits the doctor PCs the lab pulls requests from (shared with the
  /// pharmacy's list on this machine - one clinic-wide network setup).
  Future<void> _manageDoctors() async {
    final working = _doctors
        .map((d) => {
              'name': d['name'] ?? '',
              'ip': d['ip'] ?? '',
              'port': d['port'] ?? '9876',
            })
        .toList();
    final ctrls = <List<TextEditingController>>[
      for (final d in working)
        [
          TextEditingController(text: d['name']),
          TextEditingController(text: d['ip']),
          TextEditingController(text: d['port']),
        ],
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Doctor PCs to Sync'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add every doctor computer in the clinic. The lab syncs '
                    'lab requests from all of them.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < ctrls.length; i++) ...[
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _doctorOnline.containsKey(working[i]['ip'])
                                ? (_doctorOnline[working[i]['ip']]!
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor)
                                : Colors.grey,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: ctrls[i][0],
                            decoration: const InputDecoration(
                                labelText: 'Name',
                                hintText: 'Dr. Ahmed',
                                isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: ctrls[i][1],
                            decoration: const InputDecoration(
                                labelText: 'IP',
                                hintText: '192.168.1.10',
                                prefixIcon: Icon(Icons.lan, size: 16),
                                isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: ctrls[i][2],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Port',
                                prefixIcon: Icon(Icons.numbers, size: 16),
                                isDense: true),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () {
                            setDlg(() {
                              ctrls.removeAt(i);
                              working.removeAt(i);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  TextButton.icon(
                    onPressed: () {
                      setDlg(() {
                        ctrls.add([
                          TextEditingController(
                              text: 'Doctor ${ctrls.length + 1}'),
                          TextEditingController(),
                          TextEditingController(text: '9876'),
                        ]);
                        working.add({
                          'name': 'Doctor ${working.length + 1}',
                          'ip': '',
                          'port': '9876'
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add doctor'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final list = <Map<String, String>>[];
                final seenIps = <String>{};
                for (var i = 0; i < ctrls.length; i++) {
                  final ip = ctrls[i][1].text.trim();
                  if (ip.isEmpty || seenIps.contains(ip)) continue;
                  seenIps.add(ip);
                  list.add({
                    'name': ctrls[i][0].text.trim().isEmpty
                        ? 'Doctor PC ${i + 1}'
                        : ctrls[i][0].text.trim(),
                    'ip': ip,
                    'port': ctrls[i][2].text.trim().isEmpty
                        ? '9876'
                        : ctrls[i][2].text.trim(),
                  });
                }
                await _saveDoctors(list);
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _loadSettings();
      await _poll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Doctor PCs saved - syncing from ${_doctors.length}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkDoctors() async {
    if (_doctors.isEmpty || _checkingDoctors) return;
    _checkingDoctors = true;
    try {
      final results = await Future.wait(_doctors.map((d) async {
        final ip = (d['ip'] ?? '').trim();
        if (ip.isEmpty) return false;
        final port = int.tryParse(d['port'] ?? '') ?? 9876;
        try {
          return await PatientClient.fetchQueueStatus(ip, port) != null;
        } catch (_) {
          return false;
        }
      }));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _doctors.length && i < results.length; i++) {
          _doctorOnline[(_doctors[i]['ip'] ?? '')] = results[i];
        }
      });
    } finally {
      _checkingDoctors = false;
    }
  }

  List<Map<String, dynamic>> _completed(List<Map<String, dynamic>> all) =>
      all.where((r) => (r['status'] as String?) == 'completed').toList();

  List<Map<String, dynamic>> _filterCompleted(List<Map<String, dynamic>> all) {
    final q = _query.trim().toLowerCase();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return all.where((r) {
      final completedAt = (r['completed_at'] as String? ?? '');
      if (_todayOnly && !completedAt.startsWith(today)) return false;
      if (_dateFilter.isNotEmpty && !completedAt.startsWith(_dateFilter)) {
        return false;
      }
      if (q.isEmpty) return true;
      final patient = (r['patient_name'] as String? ?? '').toLowerCase();
      final doctor = (r['doctor_name'] as String? ?? '').toLowerCase();
      final id = (r['id'] as String? ?? '').toLowerCase();
      return patient.contains(q) || 'dr. $doctor'.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(labQueueProvider);
    final mineAsync = ref.watch(myLabRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratory'),
        actions: [
          IconButton(
            tooltip: 'Add/manage doctor PCs',
            icon: const Icon(Icons.lan),
            onPressed: _manageDoctors,
          ),
          IconButton(
            tooltip: 'Refresh now',
            icon: const Icon(Icons.sync),
            onPressed: () => _poll(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search patient, doctor or request...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),
        ),
      ),
      drawer: AppShell.usesFixedNav(context) ? null : const AppDrawer(),
      body: Column(
        children: [
          _labHero(),
          _doctorsStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'inbox',
                  label: Text('Inbox'),
                  icon: Icon(Icons.inbox, size: 16),
                ),
                ButtonSegment(
                  value: 'completed',
                  label: Text('Results'),
                  icon: Icon(Icons.assignment_turned_in, size: 16),
                ),
                ButtonSegment(
                  value: 'stats',
                  label: Text('Overview'),
                  icon: Icon(Icons.insights, size: 16),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          Expanded(
            child: queueAsync.when(
              data: (queue) {
                if (_tab == 'inbox') return _buildInbox(queue);
                final mine = mineAsync.valueOrNull ?? [];
                if (_tab == 'completed') return _buildResults(mine);
                return _buildStats(mine);
              },
              error: (_, __) => const Center(child: Text('Error loading lab requests')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navyDeep.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.goldColor.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const MedicalCrossFigure(size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SparkleFigure(size: 12),
                    const SizedBox(width: 6),
                    const Text(
                      'LABORATORY',
                      style: TextStyle(
                        color: AppTheme.goldLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const SparkleFigure(size: 12),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'MediRecord Pro',
                  style: AppTheme.displayStyle(size: 22, color: Colors.white, gold: true),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Lab test requests and results - in one place',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.biotech, size: 42, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _doctorsStrip() {
    if (_doctors.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.goldColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppTheme.goldDeep),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No doctor PC configured - add a doctor in Setup to receive lab requests.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navy),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/setup'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Setup'),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connected doctors',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _doctors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _doctors[i];
                final ip = (d['ip'] ?? '').trim();
                final online = _doctorOnline[ip] == true;
                final checking = !_doctorOnline.containsKey(ip);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (online ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (online ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: checking
                              ? Colors.grey
                              : (online ? AppTheme.successColor : AppTheme.errorColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${d['name'] ?? 'Doctor'} $ip',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInbox(List<Map<String, dynamic>> queue) {
    if (queue.isEmpty) {
      return const EmptyState(
        icon: Icons.science_outlined,
        title: 'No lab requests yet',
        message: 'Requests sent by the doctors will appear here automatically.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: queue.length,
      itemBuilder: (context, i) {
        final r = queue[i];
        final items = (r['items'] as List?) ?? const [];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.14),
              child: const Icon(Icons.biotech, color: AppTheme.primaryColor, size: 20),
            ),
            title: Text(r['patient_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. ${r['doctor_name'] ?? '-'} • ${(r['requested_at'] as String? ?? '').substring(0, 10)}',
                    style: const TextStyle(fontSize: 12)),
                Text('${items.length} test(s)', style: const TextStyle(fontSize: 12, color: AppTheme.goldDeep)),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LabResultForm(request: r)),
              );
              ref.invalidate(myLabRequestsProvider);
              ref.invalidate(labQueueProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildResults(List<Map<String, dynamic>> mine) {
    final completed = _filterCompleted(_completed(mine));
    if (completed.isEmpty) {
      final q = _query.trim();
      return EmptyState(
        icon: q.isEmpty ? Icons.assignment_turned_in_outlined : Icons.search_off_outlined,
        title: q.isEmpty ? 'No completed results yet' : 'No matches for "$q"',
        message: q.isEmpty
            ? 'Results you finalize will be stored here.'
            : 'Try a different patient name.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: completed.length,
      itemBuilder: (context, i) {
        final r = completed[i];
        final items = (r['items'] as List?) ?? const [];
        final abnormal = items.any((it) => (it as Map<String, dynamic>)['abnormal'] == true);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  (abnormal ? AppTheme.errorColor : AppTheme.successColor).withValues(alpha: 0.14),
              child: Icon(
                abnormal ? Icons.warning_amber : Icons.check_circle,
                color: abnormal ? AppTheme.errorColor : AppTheme.successColor,
                size: 20,
              ),
            ),
            title: Text(r['patient_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${r['doctor_name'] ?? '-'} • completed ${(r['completed_at'] as String? ?? '').substring(0, 10)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${items.length} test(s)${abnormal ? ' • has abnormal value(s)' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: abnormal ? AppTheme.errorColor : AppTheme.goldDeep,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.visibility_outlined, size: 18),
            onTap: () => _openResult(r),
          ),
        );
      },
    );
  }

  void _openResult(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MedicalCrossFigure(size: 18),
                    const SizedBox(width: 10),
                    Text('Lab Result', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Print result',
                      icon: const Icon(Icons.print, color: AppTheme.goldDeep),
                      onPressed: () => _printResult(r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const GoldDivider(),
                const SizedBox(height: 10),
                Text('Patient: ${r['patient_name'] ?? 'Unknown'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Doctor: Dr. ${r['doctor_name'] ?? '-'}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('Requested: ${(r['requested_at'] as String? ?? '').substring(0, 10)}  •  Completed: ${(r['completed_at'] as String? ?? '').substring(0, 10)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if ((r['lab_technician'] as String? ?? '').isNotEmpty)
                  Text('By: ${r['lab_technician']}', style: const TextStyle(fontSize: 12, color: AppTheme.goldDeep)),
                const SizedBox(height: 12),
                const Text('Results', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    itemCount: (r['items'] as List?)?.length ?? 0,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = (r['items'] as List)[i] as Map<String, dynamic>;
                      final abnormal = it['abnormal'] == true;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${it['test_name']}${(it['note'] as String? ?? '').trim().isNotEmpty ? ' (${it['note']})' : ''}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Normal: ${it['normal_range'] ?? '-'} ${it['unit'] ?? ''}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (it['value'] as String? ?? '').trim().isEmpty
                                  ? '-'
                                  : '${it['value']} ${it['unit'] ?? ''}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: abnormal ? AppTheme.errorColor : AppTheme.goldDeep,
                              ),
                            ),
                            if (abnormal)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.warning_amber, size: 15, color: AppTheme.errorColor),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(List<Map<String, dynamic>> mine) {
    final completed = _completed(mine);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final completedToday = completed
        .where((r) => ((r['completed_at'] as String?) ?? '').startsWith(today))
        .length;
    final pending = mine.length - completed.length;

    final testCounts = <String, int>{};
    var totalTests = 0;
    for (final r in completed) {
      for (final it in (r['items'] as List? ?? [])) {
        final name = ((it as Map<String, dynamic>)['test_name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        totalTests++;
        testCounts[name] = (testCounts[name] ?? 0) + 1;
      }
    }
    final topTests = testCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFive = topTests.take(5).toList();

    final doctorCounts = <String, int>{};
    for (final r in mine) {
      final d = (r['doctor_name'] as String? ?? 'Doctor').trim();
      doctorCounts[d] = (doctorCounts[d] ?? 0) + 1;
    }
    final topDoctors = doctorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _statBox('Pending', pending.toString(), AppTheme.goldDeep, Icons.inbox),
            const SizedBox(width: 8),
            _statBox('Completed', completed.length.toString(), AppTheme.successColor, Icons.assignment_turned_in),
            const SizedBox(width: 8),
            _statBox('Completed today', completedToday.toString(), AppTheme.primaryColor, Icons.today),
            const SizedBox(width: 8),
            _statBox('Tests done', totalTests.toString(), AppTheme.navy, Icons.biotech),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Most requested tests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (topFive.isEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Icon(Icons.biotech_outlined, size: 44, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
                const SizedBox(height: 10),
                const Text('No data yet - requests will be counted here', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ] else
          Card(
            child: Column(
              children: [
                for (final e in topFive)
                  ListTile(
                    dense: true,
                    title: Text(e.key, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('${e.value}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const Text('Doctors', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (topDoctors.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.medical_services_outlined, size: 44, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
                const SizedBox(height: 10),
                const Text('No data yet - doctors will appear once requests arrive', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final e in topDoctors)
                  ListTile(
                    dense: true,
                    title: Text('Dr. ${e.key}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    trailing: Text('${e.value} request(s)', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printResult(Map<String, dynamic> r) async {
    try {
      final path = await generateLabResultPdf(r);
      if (!mounted) return;
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print cancelled'), backgroundColor: AppTheme.errorColor),
        );
        return;
      }
      await printPrescriptionDirect(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate the lab report: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}