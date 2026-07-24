import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/models/medication.dart';
import '../patients/patient_provider.dart';

class MedicationFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const MedicationFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  final _drugNameCtrl = TextEditingController();
  final _genericNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _frequencyCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _prescribedByCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _sideEffectsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _refillCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _form = 'Tablet';
  String _route = 'Oral';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _filteredMeds = [];


  final List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _filteredMeds = List.from(AppConstants.commonMedications);
    _searchCtrl.addListener(_filterMeds);
    _loadCustomDrugs();
  }

  void _loadCustomDrugs() {
    PlatformHelper.readCustomDrugs().then((content) {
      if (content != null && content.isNotEmpty) {
        final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
        AppConstants.customDrugs.clear();
        for (final name in lines) {
          AppConstants.customDrugs.add({'drug': name.trim(), 'dosage': '', 'frequency': ''});
        }
        _rebuildFilteredMeds();
      }
    });
  }

  void _saveCustomMed(String name) {
    if (name.trim().isEmpty) return;
    if (AppConstants.customDrugs.any((m) => (m['drug'] ?? '').toLowerCase() == name.toLowerCase())) return;
    AppConstants.customDrugs.add({'drug': name, 'dosage': '', 'frequency': ''});
    final content = AppConstants.customDrugs.map((m) => m['drug']).join('\n');
    PlatformHelper.writeCustomDrugs(content);
    _rebuildFilteredMeds();
  }

  List<Map<String, dynamic>> _mergedMeds() {
    final custom = AppConstants.customDrugs.map((c) => <String, dynamic>{
      'drug': c['drug'], 'dosage': c['dosage'], 'frequency': c['frequency'], 'generic': '', 'form': '', 'route': ''
    }).toList();
    return [...custom, ...AppConstants.commonMedications];
  }

  void _rebuildFilteredMeds() {
    _filteredMeds = _mergedMeds();
    if (mounted) setState(() {});
  }

  void _filterMeds() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredMeds = q.isEmpty
          ? _mergedMeds()
          : _mergedMeds().where((m) =>
              (m['drug'] as String).toLowerCase().contains(q) ||
              (m['generic'] as String).toLowerCase().contains(q)).toList();
    });
  }

  void _selectMedication(Map<String, dynamic> med) {
    _drugNameCtrl.text = med['drug'] as String;
    _genericNameCtrl.text = med['generic'] as String;
    _dosageCtrl.text = med['dosage'] as String;
    _frequencyCtrl.text = med['frequency'] as String;
    setState(() {
      _form = med['form'] as String;
      _route = med['route'] as String;
      _searchCtrl.clear();
    });
  }

  void _addToLocal() {
    final drugName = _drugNameCtrl.text.trim();
    if (drugName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter or select a drug name first')));
      return;
    }
    _saveCustomMed(drugName);
    setState(() {
      _addedItems.add({
        'drug_name': drugName,
        'generic_name': _genericNameCtrl.text.trim().isEmpty ? null : _genericNameCtrl.text.trim(),
        'dosage': _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
        'frequency': _frequencyCtrl.text.trim().isEmpty ? null : _frequencyCtrl.text.trim(),
        'form': _form,
        'route': _route,
        'start_date': _startDate.toIso8601String().split('T')[0],
        'end_date': _endDate?.toIso8601String().split('T')[0],
        'is_active': _isActive,
        'prescribed_by': _prescribedByCtrl.text.trim().isEmpty ? null : _prescribedByCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        'side_effects': _sideEffectsCtrl.text.trim().isEmpty ? null : _sideEffectsCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'refill_info': _refillCtrl.text.trim().isEmpty ? null : _refillCtrl.text.trim(),
      });
      _drugNameCtrl.clear();
      _genericNameCtrl.clear();
      _dosageCtrl.clear();
      _frequencyCtrl.clear();
      _prescribedByCtrl.clear();
      _reasonCtrl.clear();
      _sideEffectsCtrl.clear();
      _notesCtrl.clear();
      _refillCtrl.clear();
      _startDate = DateTime.now();
      _endDate = null;
      _isActive = true;
      _form = 'Tablet';
      _route = 'Oral';
      _searchCtrl.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _addedItems.removeAt(index));
  }

  Future<void> _saveAll() async {
    if (_drugNameCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final uid = (() { try { return FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) { return 'offline'; } })();
      final now = DateTime.now().toIso8601String();

      for (final item in _addedItems) {
        await db.insertMedication(Medication(
          id: const Uuid().v4(),
          patientId: widget.patientId,
          drugName: item['drug_name'] as String,
          genericName: item['generic_name'] as String?,
          dosage: item['dosage'] as String? ?? '',
          frequency: item['frequency'] as String? ?? '',
          form: item['form'] as String,
          route: item['route'] as String,
          startDate: item['start_date'] as String,
          endDate: item['end_date'] as String?,
          isActive: item['is_active'] as bool,
          prescribedBy: item['prescribed_by'] as String? ?? '',
          reason: item['reason'] as String?,
          sideEffects: item['side_effects'] as String?,
          notes: item['notes'] as String?,
          refillCount: int.tryParse(item['refill_info'] as String? ?? ''),
          createdBy: uid,
          createdAt: now,
        ));
      }

      if (mounted) {
        ref.invalidate(patientMedicationsProvider(widget.patientId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} medication(s) saved')));
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
    _searchCtrl.removeListener(_filterMeds);
    _searchCtrl.dispose();
    _drugNameCtrl.dispose();
    _genericNameCtrl.dispose();
    _dosageCtrl.dispose();
    _frequencyCtrl.dispose();
    _durationCtrl.dispose();
    _prescribedByCtrl.dispose();
    _reasonCtrl.dispose();
    _sideEffectsCtrl.dispose();
    _notesCtrl.dispose();
    _refillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_addedItems.isEmpty ? 'New Medication' : 'Medications (${_addedItems.length})')),
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
                  Text('${_addedItems.length} medication(s) pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _addedItems.length,
                itemBuilder: (context, i) {
                  final item = _addedItems[i];
                  return Chip(
                    avatar: Icon(Icons.medication, size: 14, color: AppTheme.primaryColor),
                    label: Text(item['drug_name'] as String, style: const TextStyle(fontSize: 11)),
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
                      hintText: 'Search medication...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      itemCount: _filteredMeds.length > 12 ? 12 : _filteredMeds.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = _filteredMeds[i];
                        final isCustom = AppConstants.customDrugs.any((c) => c['drug'] == m['drug']);
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.medication, size: 18, color: isCustom ? Colors.orange : AppTheme.primaryColor),
                          title: Text(m['drug'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isCustom ? Colors.deepOrange : null)),
                          subtitle: Text(isCustom ? 'Custom entry' : '${m['form']} | ${m['dosage']}', style: const TextStyle(fontSize: 11)),
                          trailing: isCustom ? const Icon(Icons.star, size: 14, color: Colors.orange) : null,
                          onTap: () => _selectMedication(m),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Or fill details', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _form,
                          decoration: const InputDecoration(labelText: 'Form', prefixIcon: Icon(Icons.medication)),
                          items: AppConstants.medicationForms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (v) => setState(() => _form = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _route,
                          decoration: const InputDecoration(labelText: 'Route', prefixIcon: Icon(Icons.arrow_forward)),
                          items: AppConstants.medicationRoutes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (v) => setState(() => _route = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _drugNameCtrl,
                    decoration: const InputDecoration(labelText: 'Drug Name', prefixIcon: Icon(Icons.medication)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _genericNameCtrl, decoration: const InputDecoration(labelText: 'Generic Name')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _frequencyCtrl, decoration: const InputDecoration(labelText: 'Frequency'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (picked != null) setState(() => _startDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today)),
                            child: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (picked != null) setState(() => _endDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'End Date', prefixIcon: Icon(Icons.date_range)),
                            child: Text(_endDate != null ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}' : 'Not set'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Currently Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppTheme.successColor,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _prescribedByCtrl, decoration: const InputDecoration(labelText: 'Prescribed By')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Medication'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _sideEffectsCtrl, decoration: const InputDecoration(labelText: 'Side Effects'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
                  const SizedBox(height: 12),
                  TextFormField(controller: _refillCtrl, decoration: const InputDecoration(labelText: 'Refill Information')),
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
