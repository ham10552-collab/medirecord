import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../shared/models/medical_history.dart';
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

  String _status = 'active';
  String _severity = 'moderate';
  DateTime? _diagnosisDate;
  bool _isSaving = false;
  List<Map<String, dynamic>> _filtered = [];

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
      _filtered = q.isEmpty
          ? List.from(AppConstants.commonConditions)
          : AppConstants.commonConditions.where((c) =>
              (c['condition'] as String).toLowerCase().contains(q)).toList();
    });
  }

  void _select(Map<String, dynamic> c) {
    _conditionCtrl.text = c['condition'] as String;
    setState(() {
      _severity = c['severity'] as String;
      _status = c['status'] as String;
      _searchCtrl.clear();
    });
  }

  void _addToLocal() {
    final condition = _conditionCtrl.text.trim();
    if (condition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter or select a condition first')));
      return;
    }
    setState(() {
      _addedItems.add({
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} condition(s) added')));
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
      appBar: AppBar(title: Text(_addedItems.isEmpty ? 'Add Medical Conditions' : 'Conditions (${_addedItems.length})')),
      body: Column(
        children: [
          if (_addedItems.isNotEmpty) ...[
            Container(
              width: double.infinity,
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
                  const SizedBox(width: 6),
                  Text('${_addedItems.length} condition(s) pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _addedItems.length,
                itemBuilder: (context, i) {
                  final item = _addedItems[i];
                  return Chip(
                    label: Text(item['condition_name'] as String, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeItem(i),
                    backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
                  );
                },
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Select', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search condition...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      itemCount: _filtered.length > 12 ? 12 : _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = _filtered[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_hospital, size: 18, color: AppTheme.primaryColor),
                          title: Text(c['condition'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text('${c['severity']} | ${c['status']}', style: const TextStyle(fontSize: 11)),
                          onTap: () => _select(c),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Or fill manually', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _conditionCtrl,
                    decoration: const InputDecoration(labelText: 'Condition / Disease', prefixIcon: Icon(Icons.local_hospital)),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _diagnosisDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                      if (picked != null) setState(() => _diagnosisDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Diagnosis Date', prefixIcon: Icon(Icons.calendar_today)),
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
