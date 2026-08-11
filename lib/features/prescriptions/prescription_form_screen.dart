import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/app_storage.dart';
import '../../core/utils/platform_helper.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/models/prescription.dart';
import '../../shared/widgets/pending_items_list.dart';
import '../patients/patient_provider.dart';
import '../../shared/widgets/luxury_figures.dart';

class PrescriptionFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PrescriptionFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends ConsumerState<PrescriptionFormScreen> {
  final _medicineNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _frequencyCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _doctorNameCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _diagSearchCtrl = TextEditingController();
  final _drugSearchCtrl = TextEditingController();

  bool _isSaving = false;
  final List<PrescriptionItem> _addedItems = [];
  List<String> _filteredDiagnoses = [];
  List<Map<String, String>> _filteredDrugs = [];
  List<String> _previousDoctors = [];

  @override
  void initState() {
    super.initState();
    _filteredDiagnoses = List.from(AppConstants.commonDiagnoses);
    _filteredDrugs = List.from(AppConstants.prescriptionDrugs);
    _diagSearchCtrl.addListener(_filterDiagnoses);
    _drugSearchCtrl.addListener(_filterDrugs);
    _loadPreviousDoctor();
    _loadCustomDrugs();
  }

  Future<void> _loadPreviousDoctor() async {
    try {
      final saved = await AppStorage.read('last_doctor_name');
      if (saved != null && saved.isNotEmpty) {
        _doctorNameCtrl.text = saved;
      } else {
        final doctorName = (await AppStorage.read('doctor_name'))?.trim() ?? '';
        if (doctorName.isNotEmpty) {
          _doctorNameCtrl.text = doctorName;
        } else {
          final user = ref.read(currentUserProvider);
          final displayName = user?.displayName?.trim();
          if (displayName != null && displayName.isNotEmpty) {
            _doctorNameCtrl.text = displayName;
          }
        }
      }
      final all = await AppStorage.read('doctor_names');
      if (all != null && all.isNotEmpty) {
        _previousDoctors = all.split('|').where((n) => n.isNotEmpty).toList();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _saveDoctorName() async {
    final name = _doctorNameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await AppStorage.write('last_doctor_name', name);
      if (!_previousDoctors.contains(name)) {
        _previousDoctors.insert(0, name);
        if (_previousDoctors.length > 10) _previousDoctors = _previousDoctors.sublist(0, 10);
        await AppStorage.write('doctor_names', _previousDoctors.join('|'));
      }
    } catch (_) {}
  }

  void _loadCustomDrugs() {
    PlatformHelper.readCustomDrugs().then((content) {
      if (content != null && content.isNotEmpty) {
        final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
        AppConstants.customDrugs.clear();
        for (final line in lines) {
          final parts = line.trim().split('|');
          AppConstants.customDrugs.add({
            'drug': parts[0].trim(),
            'dosage': parts.length > 1 ? parts[1].trim() : '',
            'frequency': parts.length > 2 ? parts[2].trim() : '',
            'generic': parts.length > 3 ? parts[3].trim() : '',
          });
        }
        _filteredDrugs = [...AppConstants.customDrugs, ...AppConstants.prescriptionDrugs];
        if (mounted) setState(() {});
      }
    });
  }

  void _saveCustomDrug(String name, {String dosage = '', String frequency = ''}) {
    if (name.trim().isEmpty) return;
    final index = AppConstants.customDrugs.indexWhere(
        (m) => (m['drug'] ?? '').toLowerCase() == name.toLowerCase());
    if (index >= 0) {
      AppConstants.customDrugs[index] = {
        'drug': name,
        'dosage': dosage,
        'frequency': frequency,
        'generic': AppConstants.customDrugs[index]['generic'] ?? '',
      };
    } else {
      AppConstants.customDrugs.add({'drug': name, 'dosage': dosage, 'frequency': frequency, 'generic': ''});
    }
    final content = AppConstants.customDrugs
        .map((m) => '${m['drug']}|${m['dosage']}|${m['frequency']}|${m['generic']}')
        .join('\n');
    PlatformHelper.writeCustomDrugs(content);
    _rebuildFilteredDrugs();
  }

  @override
  void dispose() {
    _medicineNameCtrl.dispose();
    _dosageCtrl.dispose();
    _frequencyCtrl.dispose();
    _durationCtrl.dispose();
    _instructionsCtrl.dispose();
    _doctorNameCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    _diagSearchCtrl.removeListener(_filterDiagnoses);
    _drugSearchCtrl.removeListener(_filterDrugs);
    _diagSearchCtrl.dispose();
    _drugSearchCtrl.dispose();
    super.dispose();
  }

  void _filterDiagnoses() {
    final q = _diagSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredDiagnoses = q.isEmpty
          ? List.from(AppConstants.commonDiagnoses)
          : AppConstants.commonDiagnoses.where((d) => d.toLowerCase().contains(q)).toList();
    });
  }

  void _rebuildFilteredDrugs() {
    _filteredDrugs = [...AppConstants.customDrugs, ...AppConstants.prescriptionDrugs];
  }

  void _filterDrugs() {
    final q = _drugSearchCtrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredDrugs = [...AppConstants.customDrugs, ...AppConstants.prescriptionDrugs];
      } else {
        _filteredDrugs = [...AppConstants.customDrugs, ...AppConstants.prescriptionDrugs]
            .where((m) => (m['drug'] ?? '').toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _selectDiagnosis(String d) {
    _diagnosisCtrl.text = d;
    _diagSearchCtrl.clear();
  }

  void _selectDrug(Map<String, String> drug) {
    _medicineNameCtrl.text = drug['drug'] ?? '';
    _dosageCtrl.text = drug['dosage'] ?? '';
    _frequencyCtrl.text = drug['frequency'] ?? '';
    _drugSearchCtrl.clear();
  }

  void _addToLocal() {
    final name = _medicineNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a medicine name first')));
      return;
    }
    _saveCustomDrug(name,
        dosage: _dosageCtrl.text.trim(),
        frequency: _frequencyCtrl.text.trim());
    setState(() {
      _addedItems.add(PrescriptionItem(
        medicineName: name,
        dosage: _dosageCtrl.text.trim().isEmpty ? '' : _dosageCtrl.text.trim(),
        frequency: _frequencyCtrl.text.trim().isEmpty ? '' : _frequencyCtrl.text.trim(),
        duration: _durationCtrl.text.trim().isEmpty ? '' : _durationCtrl.text.trim(),
        instructions: _instructionsCtrl.text.trim().isEmpty ? '' : _instructionsCtrl.text.trim(),
      ));
      _medicineNameCtrl.clear();
      _dosageCtrl.clear();
      _frequencyCtrl.clear();
      _durationCtrl.clear();
      _instructionsCtrl.clear();
      _drugSearchCtrl.clear();
    });
  }

  void _removeItem(int i) {
    setState(() => _addedItems.removeAt(i));
  }

  Future<void> _saveAll() async {
    if (_medicineNameCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    final loginName = ref.read(currentUserProvider)?.displayName?.trim() ?? '';
    final doctorName = _doctorNameCtrl.text.trim().isEmpty
        ? (loginName.isEmpty ? 'Unknown' : loginName)
        : _doctorNameCtrl.text.trim();

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      await _saveDoctorName();
      await db.insertPrescription(Prescription(
        id: id,
        patientId: widget.patientId,
        doctorName: doctorName,
        diagnosis: _diagnosisCtrl.text.trim().isEmpty ? '' : _diagnosisCtrl.text.trim(),
        items: _addedItems,
        notes: _notesCtrl.text.trim().isEmpty ? '' : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      ));

      if (mounted) {
        ref.invalidate(patientPrescriptionsProvider(widget.patientId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prescription saved with ${_addedItems.length} item(s)')));
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MedicalCrossFigure(size: 16),
            const SizedBox(width: 10),
            Text('New Prescription [C:${AppConstants.customDrugs.length}]'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SparkleFigure(size: 12),
                    const SizedBox(width: 8),
                    Text('Doctor\u2019s Prescription', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
                    const Spacer(),
                    const SparkleFigure(size: 9),
                  ],
                ),
                const SizedBox(height: 8),
                const GoldDivider(),
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
              iconBuilder: (_) => Icons.medication,
              labelBuilder: (i) => _addedItems[i].medicineName,
              subtitleBuilder: (i) {
                final item = _addedItems[i];
                return [
                  item.dosage,
                  item.frequency,
                  item.duration,
                ].where((s) => s.trim().isNotEmpty).join(' | ');
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
                  // Doctor & Diagnosis
                  Row(
                    children: [
                      Expanded(
                        child: Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return _previousDoctors;
                            return _previousDoctors.where((d) => d.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          initialValue: TextEditingValue(text: _doctorNameCtrl.text),
                          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                            _doctorNameCtrl.text = controller.text;
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(labelText: 'Doctor Name', prefixIcon: Icon(Icons.person)),
                              onChanged: (v) => _doctorNameCtrl.text = v,
                            );
                          },
                          onSelected: (v) => _doctorNameCtrl.text = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Quick Select Diagnosis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _diagSearchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search diagnosis...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filteredDiagnoses.length > 10 ? 10 : _filteredDiagnoses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        return ActionChip(
                          label: Text(_filteredDiagnoses[i], style: const TextStyle(fontSize: 12)),
                          onPressed: () => _selectDiagnosis(_filteredDiagnoses[i]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: _diagnosisCtrl, decoration: const InputDecoration(labelText: 'Diagnosis', prefixIcon: Icon(Icons.local_hospital)), maxLines: 2),
                  const Divider(height: 24),
                  // Drugs
                  Text('Quick Select Medicine (Custom: ${AppConstants.customDrugs.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (AppConstants.customDrugs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${AppConstants.customDrugs.first['drug']}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                    ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _drugSearchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search medicine...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      itemCount: _filteredDrugs.length > 8 ? 8 : _filteredDrugs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = _filteredDrugs[i];
                        final isCustom = AppConstants.customDrugs.any((c) => c['drug'] == m['drug']);
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.medication, size: 18, color: isCustom ? Colors.orange : AppTheme.primaryColor),
                          title: Text(m['drug'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isCustom ? Colors.deepOrange : null)),
                          subtitle: Text(isCustom ? 'Custom entry' : '${m['dosage']} | ${m['frequency']}', style: const TextStyle(fontSize: 11)),
                          trailing: isCustom ? const Icon(Icons.star, size: 14, color: Colors.orange) : null,
                          onTap: () => _selectDrug(m),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _medicineNameCtrl, decoration: const InputDecoration(labelText: 'Medicine Name', prefixIcon: Icon(Icons.medication)))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _frequencyCtrl, decoration: const InputDecoration(labelText: 'Frequency'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _durationCtrl, decoration: const InputDecoration(labelText: 'Duration'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _instructionsCtrl, decoration: const InputDecoration(labelText: 'Instructions'), maxLines: 2),
                  const SizedBox(height: 12),
                  TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
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
