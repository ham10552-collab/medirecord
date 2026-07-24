import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_provider.dart';
import '../../core/utils/constants.dart';
import '../../shared/models/examination.dart';
import '../patients/patient_provider.dart';

class ExaminationFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const ExaminationFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<ExaminationFormScreen> createState() => _ExaminationFormScreenState();
}

class _ExaminationFormScreenState extends ConsumerState<ExaminationFormScreen> {
  final _doctorCtrl = TextEditingController();
  final _complaintCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _generalCtrl = TextEditingController();
  final _headNeckCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _abdomenCtrl = TextEditingController();
  final _cvsCtrl = TextEditingController();
  final _cnsCtrl = TextEditingController();
  final _musculoCtrl = TextEditingController();
  final _skinCtrl = TextEditingController();
  final _bpSystolicCtrl = TextEditingController();
  final _bpDiastolicCtrl = TextEditingController();
  final _heartRateCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _rrCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DateTime _visitDate = DateTime.now();
  bool _isSaving = false;
  List<Map<String, dynamic>> _filtered = [];

  final List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(AppConstants.commonExaminations);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(AppConstants.commonExaminations)
          : AppConstants.commonExaminations.where((e) =>
              (e['type'] as String).toLowerCase().contains(q) ||
              (e['complaint'] as String).toLowerCase().contains(q)).toList();
    });
  }

  void _select(Map<String, dynamic> exam) {
    _complaintCtrl.text = exam['complaint'] as String;
    _diagnosisCtrl.text = exam['diagnosis'] as String;
    _planCtrl.text = exam['plan'] as String;
    setState(() => _searchCtrl.clear());
  }

  double? _calculateBmi() {
    final w = double.tryParse(_weightCtrl.text);
    final h = double.tryParse(_heightCtrl.text);
    if (w != null && h != null && h > 0) {
      return double.parse((w / ((h / 100) * (h / 100))).toStringAsFixed(1));
    }
    return null;
  }

  void _addToLocal() {
    if (_doctorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor name is required')));
      return;
    }
    setState(() {
      _addedItems.add({
        'visit_date': _visitDate.toIso8601String().split('T')[0],
        'doctor_name': _doctorCtrl.text.trim(),
        'chief_complaint': _complaintCtrl.text.trim().isEmpty ? null : _complaintCtrl.text.trim(),
        'blood_pressure_systolic': int.tryParse(_bpSystolicCtrl.text),
        'blood_pressure_diastolic': int.tryParse(_bpDiastolicCtrl.text),
        'heart_rate': int.tryParse(_heartRateCtrl.text),
        'temperature': double.tryParse(_tempCtrl.text),
        'respiratory_rate': int.tryParse(_rrCtrl.text),
        'oxygen_saturation': int.tryParse(_spo2Ctrl.text),
        'height': double.tryParse(_heightCtrl.text),
        'weight': double.tryParse(_weightCtrl.text),
        'bmi': _calculateBmi(),
        'general_appearance': _generalCtrl.text.trim().isEmpty ? null : _generalCtrl.text.trim(),
        'head_and_neck': _headNeckCtrl.text.trim().isEmpty ? null : _headNeckCtrl.text.trim(),
        'chest': _chestCtrl.text.trim().isEmpty ? null : _chestCtrl.text.trim(),
        'abdomen': _abdomenCtrl.text.trim().isEmpty ? null : _abdomenCtrl.text.trim(),
        'cvs': _cvsCtrl.text.trim().isEmpty ? null : _cvsCtrl.text.trim(),
        'cns': _cnsCtrl.text.trim().isEmpty ? null : _cnsCtrl.text.trim(),
        'musculoskeletal': _musculoCtrl.text.trim().isEmpty ? null : _musculoCtrl.text.trim(),
        'skin': _skinCtrl.text.trim().isEmpty ? null : _skinCtrl.text.trim(),
        'diagnosis': _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
        'plan': _planCtrl.text.trim().isEmpty ? null : _planCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      _doctorCtrl.clear();
      _complaintCtrl.clear();
      _diagnosisCtrl.clear();
      _planCtrl.clear();
      _notesCtrl.clear();
      _generalCtrl.clear();
      _headNeckCtrl.clear();
      _chestCtrl.clear();
      _abdomenCtrl.clear();
      _cvsCtrl.clear();
      _cnsCtrl.clear();
      _musculoCtrl.clear();
      _skinCtrl.clear();
      _bpSystolicCtrl.clear();
      _bpDiastolicCtrl.clear();
      _heartRateCtrl.clear();
      _tempCtrl.clear();
      _rrCtrl.clear();
      _spo2Ctrl.clear();
      _heightCtrl.clear();
      _weightCtrl.clear();
      _visitDate = DateTime.now();
      _searchCtrl.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _addedItems.removeAt(index));
  }

  Future<void> _saveAll() async {
    if (_doctorCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final uid = (() { try { return FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) { return 'offline'; } })();
      final now = DateTime.now().toIso8601String();

      for (final item in _addedItems) {
        await db.insertExamination(Examination(
          id: const Uuid().v4(),
          patientId: widget.patientId,
          visitDate: item['visit_date'] as String,
          doctorName: item['doctor_name'] as String,
          chiefComplaint: item['chief_complaint'] as String?,
          bloodPressureSystolic: item['blood_pressure_systolic'] as int?,
          bloodPressureDiastolic: item['blood_pressure_diastolic'] as int?,
          heartRate: item['heart_rate'] as int?,
          temperature: (item['temperature'] as num?)?.toDouble(),
          respiratoryRate: item['respiratory_rate'] as int?,
          oxygenSaturation: item['oxygen_saturation'] as int?,
          height: (item['height'] as num?)?.toDouble(),
          weight: (item['weight'] as num?)?.toDouble(),
          bmi: (item['bmi'] as num?)?.toDouble(),
          generalAppearance: item['general_appearance'] as String?,
          headAndNeck: item['head_and_neck'] as String?,
          chest: item['chest'] as String?,
          abdomen: item['abdomen'] as String?,
          cvs: item['cvs'] as String?,
          cns: item['cns'] as String?,
          musculoskeletal: item['musculoskeletal'] as String?,
          skin: item['skin'] as String?,
          diagnosis: item['diagnosis'] as String?,
          plan: item['plan'] as String?,
          notes: item['notes'] as String?,
          createdBy: uid,
          createdAt: now,
        ));
      }

      if (mounted) {
        ref.invalidate(patientExaminationsProvider(widget.patientId));
        ref.invalidate(recentExaminationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} examination(s) saved')));
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
    _doctorCtrl.dispose();
    _complaintCtrl.dispose();
    _diagnosisCtrl.dispose();
    _planCtrl.dispose();
    _notesCtrl.dispose();
    _generalCtrl.dispose();
    _headNeckCtrl.dispose();
    _chestCtrl.dispose();
    _abdomenCtrl.dispose();
    _cvsCtrl.dispose();
    _cnsCtrl.dispose();
    _musculoCtrl.dispose();
    _skinCtrl.dispose();
    _bpSystolicCtrl.dispose();
    _bpDiastolicCtrl.dispose();
    _heartRateCtrl.dispose();
    _tempCtrl.dispose();
    _rrCtrl.dispose();
    _spo2Ctrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_addedItems.isEmpty ? 'New Examinations' : 'Exams (${_addedItems.length})')),
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
                  Text('${_addedItems.length} exam(s) pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                    avatar: Icon(Icons.medical_services, size: 14, color: AppTheme.primaryColor),
                    label: Text('${item['doctor_name']}  ${item['visit_date']}', style: const TextStyle(fontSize: 11)),
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
                  const Text('Quick Select Template', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search template...',
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
                        final e = _filtered[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.medical_services, size: 18, color: AppTheme.primaryColor),
                          title: Text(e['type'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text(e['complaint'] as String, style: const TextStyle(fontSize: 11)),
                          onTap: () => _select(e),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Or fill manually', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _doctorCtrl,
                    decoration: const InputDecoration(labelText: 'Doctor Name', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _visitDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                      if (picked != null) setState(() => _visitDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Visit Date', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text('${_visitDate.year}-${_visitDate.month.toString().padLeft(2, '0')}-${_visitDate.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _complaintCtrl,
                    decoration: const InputDecoration(labelText: 'Chief Complaint', prefixIcon: Icon(Icons.chat)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  const Text('Vital Signs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _bpSystolicCtrl, decoration: const InputDecoration(labelText: 'BP Systolic', hintText: '120'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _bpDiastolicCtrl, decoration: const InputDecoration(labelText: 'BP Diastolic', hintText: '80'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _heartRateCtrl, decoration: const InputDecoration(labelText: 'Heart Rate', hintText: '72 bpm'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _tempCtrl, decoration: const InputDecoration(labelText: 'Temperature', hintText: '36.5 °C'), keyboardType: TextInputType.numberWithOptions(decimal: true))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _rrCtrl, decoration: const InputDecoration(labelText: 'Resp. Rate', hintText: '16 /min'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _spo2Ctrl, decoration: const InputDecoration(labelText: 'SpO2', hintText: '98 %'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _heightCtrl, decoration: const InputDecoration(labelText: 'Height', hintText: '170 cm'), keyboardType: TextInputType.numberWithOptions(decimal: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _weightCtrl, decoration: const InputDecoration(labelText: 'Weight', hintText: '70 kg'), keyboardType: TextInputType.numberWithOptions(decimal: true))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Physical Examination', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _generalCtrl, decoration: const InputDecoration(labelText: 'General Appearance'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _headNeckCtrl, decoration: const InputDecoration(labelText: 'Head & Neck'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _chestCtrl, decoration: const InputDecoration(labelText: 'Chest'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _abdomenCtrl, decoration: const InputDecoration(labelText: 'Abdomen'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _cvsCtrl, decoration: const InputDecoration(labelText: 'CVS'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _cnsCtrl, decoration: const InputDecoration(labelText: 'CNS'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _musculoCtrl, decoration: const InputDecoration(labelText: 'Musculoskeletal'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _skinCtrl, decoration: const InputDecoration(labelText: 'Skin'), maxLines: 2),
                  const SizedBox(height: 20),
                  const Text('Assessment & Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _diagnosisCtrl, decoration: const InputDecoration(labelText: 'Diagnosis'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _planCtrl, decoration: const InputDecoration(labelText: 'Plan'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Additional Notes'), maxLines: 3),
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
