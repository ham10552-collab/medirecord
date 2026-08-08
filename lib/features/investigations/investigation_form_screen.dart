import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/models/investigation.dart';
import '../../shared/widgets/pending_items_list.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../patients/patient_provider.dart';

class InvestigationFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const InvestigationFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<InvestigationFormScreen> createState() => _InvestigationFormScreenState();
}

class _InvestigationFormScreenState extends ConsumerState<InvestigationFormScreen> {
  final _testNameCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();
  final _normalRangeCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _labNameCtrl = TextEditingController();
  final _orderedByCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _category = 'Blood';
  bool _isAbnormal = false;
  DateTime _testDate = DateTime.now();
  bool _isSaving = false;
  List<Map<String, dynamic>> _filteredTests = [];
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  final List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _filteredTests = List.from(AppConstants.commonInvestigations);
    _searchCtrl.addListener(_filterTests);
    _testNameCtrl.addListener(_autofillTestInfo);
  }

  void _autofillTestInfo() {
    final q = _testNameCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return;
    Map<String, dynamic>? match;
    for (final t in AppConstants.commonInvestigations) {
      final name = (t['test'] as String).toLowerCase();
      final nr = ((t['normalRange'] as String?) ?? '').trim();
      if (name == q || name.startsWith(q) || q.contains(name)) {
        if (nr.isNotEmpty) {
          match = t;
          break;
        }
      }
    }
    if (match == null) return;
    final matched = match;
    setState(() {
      if (_normalRangeCtrl.text.trim().isEmpty) {
        _normalRangeCtrl.text = matched['normalRange'] as String;
      }
      if (_unitCtrl.text.trim().isEmpty && ((matched['unit'] as String?) ?? '').trim().isNotEmpty) {
        _unitCtrl.text = matched['unit'] as String;
      }
    });
  }

  void _filterTests() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredTests = q.isEmpty
          ? List.from(AppConstants.commonInvestigations)
          : AppConstants.commonInvestigations.where((t) =>
              (t['test'] as String).toLowerCase().contains(q) ||
              (t['category'] as String).toLowerCase().contains(q)).toList();
    });
  }

  void _selectInvestigation(Map<String, dynamic> inv) {
    _testNameCtrl.text = inv['test'] as String;
    _unitCtrl.text = inv['unit'] as String;
    _normalRangeCtrl.text = inv['normalRange'] as String;
    setState(() {
      _category = inv['category'] as String;
      _searchCtrl.clear();
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedImage = picked;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  void _addToLocal() {
    final testName = _testNameCtrl.text.trim();
    if (testName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter or select a test name first')));
      return;
    }
    setState(() {
      _addedItems.add({
        'test_name': testName,
        'category': _category,
        'investigation_date': _testDate.toIso8601String().split('T')[0],
        'result': _resultCtrl.text.trim().isEmpty ? null : _resultCtrl.text.trim(),
        'normal_range': _normalRangeCtrl.text.trim().isEmpty ? null : _normalRangeCtrl.text.trim(),
        'unit': _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        'is_abnormal': _isAbnormal,
        'lab_name': _labNameCtrl.text.trim().isEmpty ? null : _labNameCtrl.text.trim(),
        'ordered_by': _orderedByCtrl.text.trim().isEmpty ? null : _orderedByCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'file_path': _pickedImage?.path,
        'picked_image': _pickedImage,
      });
      _testNameCtrl.clear();
      _resultCtrl.clear();
      _normalRangeCtrl.clear();
      _unitCtrl.clear();
      _labNameCtrl.clear();
      _orderedByCtrl.clear();
      _notesCtrl.clear();
      _testDate = DateTime.now();
      _isAbnormal = false;
      _category = 'Blood';
      _searchCtrl.clear();
      _pickedImage = null;
    });
  }

  void _removeItem(int index) {
    setState(() => _addedItems.removeAt(index));
  }

  Future<String?> _saveImage(XFile image, String id) async {
    try {
      final bytes = await image.readAsBytes();
      final ext = p.extension(image.name).replaceAll('.', '');
      return await PlatformHelper.saveImageBytes(bytes, id, ext.isEmpty ? 'jpg' : ext);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAll() async {
    if (_testNameCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final uid = (() { try { return FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) { return 'offline'; } })();
      final now = DateTime.now().toIso8601String();

      for (final item in _addedItems) {
        final id = const Uuid().v4();
        String? savedPath;
        final picked = item['picked_image'] as XFile?;
        if (picked != null) {
          savedPath = await _saveImage(picked, id);
        }
        await db.insertInvestigation(Investigation(
          id: id,
          patientId: widget.patientId,
          investigationDate: item['investigation_date'] as String,
          category: item['category'] as String,
          testName: item['test_name'] as String,
          result: item['result'] as String?,
          normalRange: item['normal_range'] as String?,
          unit: item['unit'] as String?,
          isAbnormal: item['is_abnormal'] as bool,
          labName: item['lab_name'] as String?,
          notes: item['notes'] as String?,
          orderedBy: item['ordered_by'] as String?,
          filePath: savedPath,
          createdBy: uid,
          createdAt: now,
        ));
      }

      if (mounted) {
        ref.invalidate(patientInvestigationsProvider(widget.patientId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} investigation(s) saved')));
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
    _searchCtrl.removeListener(_filterTests);
    _searchCtrl.dispose();
    _testNameCtrl.dispose();
    _resultCtrl.dispose();
    _normalRangeCtrl.dispose();
    _unitCtrl.dispose();
    _labNameCtrl.dispose();
    _orderedByCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Widget _buildImagePreview() {
    if (_pickedImageBytes == null) return const SizedBox();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _pickedImageBytes!,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              color: Colors.grey[200],
              child: const Center(child: Text('Preview not available', style: TextStyle(color: AppTheme.textSecondary))),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.close, size: 14, color: Colors.white),
              onPressed: () => setState(() {
                _pickedImage = null;
                _pickedImageBytes = null;
              }),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MedicalCrossFigure(size: 16),
            const SizedBox(width: 10),
            Text(_addedItems.isEmpty ? 'New Investigations' : 'Investigations (${_addedItems.length})'),
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
                    Text('Laboratory & Imaging', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
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
                  Text('${_addedItems.length} test(s) pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
              iconBuilder: (_) => Icons.science,
              labelBuilder: (i) => _addedItems[i]['test_name'] as String,
              subtitleBuilder: (i) {
                final result = _addedItems[i]['result'] as String?;
                return result != null && result.isNotEmpty ? 'Result: $result' : null;
              },
              onRemove: _removeItem,
            ),
            const Divider(height: 1),
            const Divider(height: 1),
          ],
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      hintText: 'Search test...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      itemCount: _filteredTests.length > 12 ? 12 : _filteredTests.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = _filteredTests[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.science, size: 18, color: AppTheme.primaryColor),
                          title: Text(t['test'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text('${t['category']}${t['unit'].toString().isNotEmpty ? ' | ${t['unit']}' : ''}', style: const TextStyle(fontSize: 11)),
                          onTap: () => _selectInvestigation(t),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Or fill details', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                    items: AppConstants.investigationCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _testDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                      if (picked != null) setState(() => _testDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Test Date', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text('${_testDate.year}-${_testDate.month.toString().padLeft(2, '0')}-${_testDate.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _testNameCtrl,
                    decoration: const InputDecoration(labelText: 'Test Name', prefixIcon: Icon(Icons.science)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _resultCtrl, decoration: const InputDecoration(labelText: 'Result'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Unit'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _normalRangeCtrl, decoration: const InputDecoration(labelText: 'Normal Range')),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Mark as Abnormal'),
                    value: _isAbnormal,
                    activeThumbColor: AppTheme.errorColor,
                    onChanged: (v) => setState(() => _isAbnormal = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _labNameCtrl, decoration: const InputDecoration(labelText: 'Lab / Facility')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _orderedByCtrl, decoration: const InputDecoration(labelText: 'Ordered By')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
                  const SizedBox(height: 16),
                  const Text('Attach Image', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildImagePreview(),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image, size: 18),
                    label: Text(_pickedImage != null ? 'Change Image' : 'Attach X-ray / CT / Photo'),
                    onPressed: _pickImage,
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
