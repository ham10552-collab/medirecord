import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../core/utils/lab_tests.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/luxury_figures.dart';

/// Doctor-side screen: every lab request this doctor ordered, with a button
/// to order new tests for any patient and the incoming results visible
/// per request (compare with previous results included).
class LabOrdersScreen extends ConsumerStatefulWidget {
  const LabOrdersScreen({super.key});

  @override
  ConsumerState<LabOrdersScreen> createState() => _LabOrdersScreenState();
}

class _LabOrdersScreenState extends ConsumerState<LabOrdersScreen> {
  String _query = '';
  bool _showCompletedOnly = false;
  String? _pendingHighlight;
  bool _highlightHandled = false;

  @override
  void initState() {
    super.initState();
    final qp = GoRouterState.of(context).uri.queryParameters['highlight'];
    if (qp != null && qp.trim().isNotEmpty) _pendingHighlight = qp.trim();
  }

  void _maybeOpenHighlight(List<Map<String, dynamic>> all) {
    if (_highlightHandled || _pendingHighlight == null) return;
    for (final r in all) {
      if (r['id'] == _pendingHighlight &&
          (r['status'] as String?) == 'completed') {
        _highlightHandled = true;
        _pendingHighlight = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openResult(r);
        });
        return;
      }
    }
  }

  Future<void> _orderTests() async {
    final db = DatabaseHelper();
    final patients = await db.getAllPatients();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => PatientPickerDialog(
        patients: patients
            .map((p) => {
                  'id': p.id,
                  'fullName': p.fullName,
                  'phone': p.phone ?? '',
                })
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;

    final doctorName = (await AppStorage.read('doctor_name'))?.trim() ?? '';
    final tests = await _selectTests();
    if (tests.isEmpty) return;
    if (!mounted) return;

    final request = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'patient_id': selected['id'],
      'patient_name': selected['fullName'],
      'patient_phone': selected['phone'],
      'doctor_name': doctorName,
      'doctor_host': null,
      'ordered_by': doctorName,
      'requested_at': DateTime.now().toIso8601String(),
      'status': 'requested',
      'items': tests,
    };
    await db.upsertLabRequest(request);
    ref.invalidate(myLabRequestsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Lab request sent${doctorName.isEmpty ? '' : ' by Dr. $doctorName'} - the lab will pull it automatically'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 4),
        ),
    );
  }
}

/// Safe date-shortening helper: returns "YYYY-MM-DD" whenever possible,
/// otherwise the raw value or an empty string (never throws on short text).
String _date10(Object? value) {
  final s = value as String? ?? '';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

  Future<List<Map<String, dynamic>>> _selectTests() async {
    final selected = <Map<String, dynamic>>[];
    final added = <String>{};
    final searchCtrl = TextEditingController();
    final customNameCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Select tests to order'),
          content: SizedBox(
            width: 480,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type test name (first letters)...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (_) => setDlg(() {}),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: labTestCatalog.length,
                    itemBuilder: (_, i) {
                      final t = labTestCatalog[i];
                      final q = searchCtrl.text.trim().toLowerCase();
                      if (q.isNotEmpty &&
                          !t.name.toLowerCase().contains(q) &&
                          !t.nameAr.contains(q)) {
                        return const SizedBox.shrink();
                      }
                      final key = t.name.toLowerCase();
                      final isChecked = added.contains(key);
                      return CheckboxListTile(
                        dense: true,
                        title: Text('${t.name} (${t.nameAr})',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('Normal: ${t.normalRange} ${t.unit}',
                            style: const TextStyle(fontSize: 11)),
                        value: isChecked,
                        onChanged: (v) {
                          setDlg(() {
                            if (v == true) {
                              added.add(key);
                              selected.add({
                                'test_name': t.name,
                                'note': '',
                                'value': '',
                                'normal_range': t.normalRange,
                                'unit': t.unit,
                                'abnormal': false,
                              });
                            } else {
                              added.remove(key);
                              selected.removeWhere((s) =>
                                  (s['test_name'] as String).toLowerCase() == key);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Custom test name (optional)',
                          isDense: true,
                          prefixIcon: Icon(Icons.add, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Add custom test',
                      icon: const Icon(Icons.add_circle, color: AppTheme.goldDeep),
                      onPressed: () {
                        final name = customNameCtrl.text.trim();
                        if (name.isEmpty) return;
                        setDlg(() {
                          selected.add({
                            'test_name': name,
                            'note': '',
                            'value': '',
                            'normal_range': '',
                            'unit': '',
                            'abnormal': false,
                          });
                          customNameCtrl.clear();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx),
              child: Text('Send ${selected.length} test(s)'),
            ),
          ],
        ),
      ),
    );
    return selected;
  }

  void _openResult(Map<String, dynamic> r) {
    if ((r['saved_to_record'] as bool?) != true) {
      _saveToRecord(r);
    }
    final items = ((r['items'] as List?) ?? const [])
        .map((i) => (i as Map).cast<String, dynamic>())
        .toList();
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
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const GoldDivider(),
                const SizedBox(height: 10),
                Text('Patient: ${r['patient_name'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Requested: ${_date10(r['requested_at'])}  •  Completed: ${_date10(r['completed_at'])}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if ((r['lab_technician'] as String? ?? '').isNotEmpty)
                  Text('By: ${r['lab_technician']}', style: const TextStyle(fontSize: 12, color: AppTheme.goldDeep)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final abnormal = it['abnormal'] == true;
                      final value = (it['value'] as String? ?? '').trim();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${it['test_name']}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Normal: ${it['normal_range'] ?? '-'} ${it['unit'] ?? ''}${(it['note'] as String? ?? '').trim().isEmpty ? '' : '  •  ${it['note']}'}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value.isEmpty ? '-' : '$value ${it['unit'] ?? ''}',
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

  /// First time the doctor opens a completed result: copies every value into
  /// the patient's Investigations (ix) record automatically.
  Future<void> _saveToRecord(Map<String, dynamic> r) async {
    final saved = await DatabaseHelper().saveLabResultsToRecord(r);
    if (!mounted || saved <= 0) return;
    ref.invalidate(myLabRequestsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$saved result(s) saved to the patient record (Investigations)'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mineAsync = ref.watch(myLabRequestsProvider);

    return Scaffold(
      drawer: AppShell.usesFixedNav(context) ? null : const AppDrawer(),
      appBar: AppBar(
        title: const Text('Lab Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search patient...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Results only'),
                  selected: _showCompletedOnly,
                  onSelected: (v) => setState(() => _showCompletedOnly = v),
                ),
              ],
            ),
          ),
        ),
      ),
      body: mineAsync.when(
        data: (all) {
          _maybeOpenHighlight(all);
          final q = _query.trim().toLowerCase();
          final items = all.where((r) {
            if (_showCompletedOnly && (r['status'] as String?) != 'completed') return false;
            if (q.isEmpty) return true;
            final patient = (r['patient_name'] as String? ?? '').toLowerCase();
            return patient.contains(q);
          }).toList();
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.biotech_outlined,
              title: q.isEmpty
                  ? (_showCompletedOnly ? 'No completed orders' : 'No lab requests yet')
                  : 'No matches for "$q"',
              message: q.isEmpty
                  ? 'Order tests for a patient with the + button.'
                  : 'Try a different patient name.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              final isComplete = (r['status'] as String?) == 'completed';
              final itemsCount = (r['items'] as List?)?.length ?? 0;
              final abnormal = ((r['items'] as List?) ?? const [])
                  .any((it) => (it as Map<String, dynamic>)['abnormal'] == true);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (isComplete ? (abnormal ? AppTheme.errorColor : AppTheme.successColor) : AppTheme.goldColor)
                            .withValues(alpha: 0.14),
                    child: Icon(
                      isComplete
                          ? (abnormal ? Icons.warning_amber : Icons.check_circle)
                          : Icons.schedule,
                      color: isComplete
                          ? (abnormal ? AppTheme.errorColor : AppTheme.successColor)
                          : AppTheme.goldDeep,
                      size: 20,
                    ),
                  ),
                  title: Text(r['patient_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_date10(r['requested_at'])} • $itemsCount test(s)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        isComplete ? 'Results received${abnormal ? ' - check abnormal values' : ''}' : 'Waiting for the lab',
                        style: TextStyle(
                          fontSize: 12,
                          color: isComplete
                              ? (abnormal ? AppTheme.errorColor : AppTheme.successColor)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  trailing: isComplete
                      ? IconButton(
                          tooltip: 'View result',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _openResult(r),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: isComplete ? () => _openResult(r) : null,
                ),
              );
            },
          );
        },
        error: (_, __) => const Center(child: Text('Error loading lab requests')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _orderTests,
        icon: const Icon(Icons.add),
        label: const Text('Order Tests'),
      ),
    );
  }
}

/// Simple patient picker for the lab order flow.
class PatientPickerDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> patients;

  const PatientPickerDialog({super.key, required this.patients});

  @override
  ConsumerState<PatientPickerDialog> createState() => _PatientPickerDialogState();
}

class _PatientPickerDialogState extends ConsumerState<PatientPickerDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final items = widget.patients.where((p) {
      final name = (p['fullName'] as String? ?? '').toLowerCase();
      return name.contains(q) || (p['phone'] as String? ?? '').contains(q);
    }).toList();
    return AlertDialog(
      title: const Text('Select patient'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                labelText: 'Search patient...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No patients found',
                      message: 'Search by a different name or phone number.',
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final p = items[i];
                        final name = (p['fullName'] as String? ?? 'Patient')
                            .trim();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
                          subtitle: Text(p['phone'] as String? ?? ''),
                          onTap: () => Navigator.pop(context, {
                            'id': p['id'],
                            'fullName': name,
                            'phone': p['phone'] ?? '',
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}