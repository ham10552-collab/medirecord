import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../shared/models/medical_history.dart';
import '../../shared/widgets/pending_items_list.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../patients/patient_provider.dart';

class HistoryFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const HistoryFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<HistoryFormScreen> createState() => _HistoryFormScreenState();
}

class _HistoryFormScreenState extends ConsumerState<HistoryFormScreen> {
  final _conditionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _historyType = 'Medical';
  String _status = 'active';
  String _severity = 'moderate';
  DateTime? _diagnosisDate;
  bool _isSaving = false;
  List<Map<String, dynamic>> _filtered = [];
  List<String> _filteredAllergens = [];

  final List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(AppConstants.commonConditions);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      if (_historyType == 'Surgical') {
        _filtered = q.isEmpty
            ? List.from(AppConstants.commonSurgeries)
            : AppConstants.commonSurgeries.where((c) =>
                (c['surgery'] as String).toLowerCase().contains(q) ||
                (c['category'] as String).toLowerCase().contains(q)).toList();
      } else if (_historyType == 'Allergy') {
        _filteredAllergens = q.isEmpty
            ? List.from(AppConstants.commonAllergens)
            : AppConstants.commonAllergens.where((a) => a.toLowerCase().contains(q)).toList();
      } else if (_historyType == 'Medical') {
        _filtered = q.isEmpty
            ? List.from(AppConstants.commonConditions)
            : AppConstants.commonConditions.where((c) =>
                (c['condition'] as String).toLowerCase().contains(q)).toList();
      }
    });
  }

  void _changeType(String type) {
    setState(() {
      _historyType = type;
      _searchCtrl.clear();
      _conditionCtrl.clear();
      _notesCtrl.clear();
      _diagnosisDate = null;
      _status = 'active';
      _severity = 'moderate';
    });
    _filter();
  }

  void _select(Map<String, dynamic> c) {
    _conditionCtrl.text = c['condition'] as String;
    setState(() {
      _severity = c['severity'] as String;
      _status = c['status'] as String;
      _searchCtrl.clear();
    });
  }

  void _selectSurgery(Map<String, dynamic> s) {
    _conditionCtrl.text = s['surgery'] as String;
    setState(() {
      _searchCtrl.clear();
      _status = 'active';
      _severity = 'moderate';
    });
  }

  void _selectAllergen(String allergen) {
    _conditionCtrl.text = allergen;
    setState(() {
      _status = 'active';
      _severity = 'moderate';
      _searchCtrl.clear();
    });
  }

  void _addToLocal() {
    final condition = _conditionCtrl.text.trim();
    if (condition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter or select an item first')));
      return;
    }
    setState(() {
      _addedItems.add({
        'history_type': _historyType.toLowerCase(),
        'condition_name': condition,
        'diagnosis_date': _diagnosisDate?.toIso8601String().split('T')[0],
        'status': _status,
        'severity': _severity,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      _conditionCtrl.clear();
      _notesCtrl.clear();
      _diagnosisDate = null;
      _status = 'active';
      _severity = 'moderate';
      _searchCtrl.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _addedItems.removeAt(index));
  }

  Future<void> _saveAll() async {
    if (_conditionCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final uid = (() { try { return FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) { return 'offline'; } })();
      final now = DateTime.now().toIso8601String();

      for (final item in _addedItems) {
        await db.insertMedicalHistory(MedicalHistory(
          id: const Uuid().v4(),
          patientId: widget.patientId,
          historyType: item['history_type'] as String,
          conditionName: item['condition_name'] as String,
          diagnosisDate: item['diagnosis_date'] as String?,
          status: item['status'] as String,
          severity: item['severity'] as String?,
          notes: item['notes'] as String?,
          createdBy: uid,
          createdAt: now,
        ));
      }

      if (mounted) {
        ref.invalidate(patientMedicalHistoryProvider(widget.patientId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} item(s) added')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _entryLabel => switch (_historyType) {
        'Surgical' => 'Surgery / Procedure',
        'Allergy' => 'Allergen / Reaction',
        'Other' => 'Other history item',
        _ => 'Condition / Disease',
      };

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    _conditionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MedicalCrossFigure(size: 16),
            const SizedBox(width: 10),
            Text(_addedItems.isEmpty ? 'Add History' : 'History (${_addedItems.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SparkleFigure(size: 12),
                    const SizedBox(width: 8),
                    Text('History', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
                    const Spacer(),
                    const SparkleFigure(size: 9),
                  ],
                ),
                const SizedBox(height: 8),
                const GoldDivider(),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: AppConstants.historyTypes
                      .map((t) => ButtonSegment(value: t, label: Text(t)))
                      .toList(),
                  selected: {_historyType},
                  onSelectionChanged: (s) => _changeType(s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          if (_addedItems.isNotEmpty) ...[
            Container(
              width: double.infinity,
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
                  const SizedBox(width: 6),
                  Text('${_addedItems.length} item(s) pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(_addedItems.clear),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ],
              ),
            ),
            PendingItemsList(
              itemCount: _addedItems.length,
              iconBuilder: (i) {
                final type = _addedItems[i]['history_type'] as String;
                return type == 'surgical'
                    ? Icons.content_cut
                    : type == 'allergy'
                        ? Icons.warning
                        : Icons.local_hospital;
              },
              iconColorBuilder: (i) {
                final type = _addedItems[i]['history_type'] as String;
                return type == 'surgical'
                    ? AppTheme.primaryColor
                    : type == 'allergy'
                        ? AppTheme.errorColor
                        : AppTheme.goldDeep;
              },
              labelBuilder: (i) => _addedItems[i]['condition_name'] as String,
              subtitleBuilder: (i) {
                final type = _addedItems[i]['history_type'] as String;
                return switch (type) {
                  'surgical' => 'Surgical',
                  'allergy' => 'Allergy',
                  'other' => 'Other',
                  'medical' => 'Medical',
                  _ => type,
                };
              },
              onRemove: _removeItem,
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_historyType != 'Other') ...[
                    const Row(
                      children: [
                        SparkleFigure(size: 11),
                        SizedBox(width: 8),
                        Text('Quick Select', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: AppTheme.displayFont)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 120,
                      child: _historyType == 'Allergy'
                          ? ListView.separated(
                              itemCount: _filteredAllergens.length > 12 ? 12 : _filteredAllergens.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final a = _filteredAllergens[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.warning_amber, size: 18, color: AppTheme.errorColor),
                                  title: Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  onTap: () => _selectAllergen(a),
                                );
                              },
                            )
                          : ListView.separated(
                              itemCount: _filtered.length > 12 ? 12 : _filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = _filtered[i];
                                final isSurgical = _historyType == 'Surgical';
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isSurgical ? Icons.content_cut : Icons.local_hospital,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  title: Text(
                                    isSurgical ? (c['surgery'] as String) : (c['condition'] as String),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    isSurgical ? (c['category'] as String) : '${c['severity']} | ${c['status']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => isSurgical ? _selectSurgery(c) : _select(c),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 24),
                  ],
                  Text(
                    _historyType == 'Other'
                        ? 'Enter any other important history detail'
                        : 'Or fill manually',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _conditionCtrl,
                    decoration: InputDecoration(
                      labelText: _entryLabel,
                      prefixIcon: Icon(_historyType == 'Allergy' ? Icons.warning : _historyType == 'Surgical' ? Icons.content_cut : Icons.local_hospital),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _diagnosisDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                      if (picked != null) setState(() => _diagnosisDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Diagnosis / Event Date', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(_diagnosisDate != null
                          ? '${_diagnosisDate!.year}-${_diagnosisDate!.month.toString().padLeft(2, '0')}-${_diagnosisDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.circle), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                          ],
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _severity,
                          decoration: const InputDecoration(labelText: 'Severity', prefixIcon: Icon(Icons.warning), isDense: true),
                          items: AppConstants.severityLevels.map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                          onChanged: (v) => setState(() => _severity = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes), alignLabelWithHint: true),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Another'),
                          onPressed: _isSaving ? null : _addToLocal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 18),
                          label: Text(_addedItems.isEmpty ? 'Save' : 'Save ${_addedItems.length}'),
                          onPressed: _isSaving ? null : _saveAll,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}