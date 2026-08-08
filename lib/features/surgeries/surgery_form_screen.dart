import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../patients/patient_provider.dart';
import '../../shared/widgets/pending_items_list.dart';
import '../../shared/widgets/luxury_figures.dart';

class SurgeryFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const SurgeryFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<SurgeryFormScreen> createState() => _SurgeryFormScreenState();
}

class _SurgeryFormScreenState extends ConsumerState<SurgeryFormScreen> {
  final _nameCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _surgeonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DateTime? _surgeryDate;
  bool _isSaving = false;
  List<Map<String, dynamic>> _filtered = [];

  final List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(AppConstants.commonSurgeries);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(AppConstants.commonSurgeries)
          : AppConstants.commonSurgeries.where((s) =>
              (s['surgery'] as String).toLowerCase().contains(q) ||
              (s['category'] as String).toLowerCase().contains(q)).toList();
    });
  }

  void _select(Map<String, dynamic> s) {
    _nameCtrl.text = s['surgery'] as String;
    setState(() => _searchCtrl.clear());
  }

  void _addToLocal() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter or select a surgery name first')));
      return;
    }
    setState(() {
      _addedItems.add({
        'surgery_name': name,
        'surgery_date': _surgeryDate?.toIso8601String().split('T')[0],
        'hospital': _hospitalCtrl.text.trim().isEmpty ? null : _hospitalCtrl.text.trim(),
        'surgeon': _surgeonCtrl.text.trim().isEmpty ? null : _surgeonCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      _nameCtrl.clear();
      _hospitalCtrl.clear();
      _surgeonCtrl.clear();
      _notesCtrl.clear();
      _surgeryDate = null;
      _searchCtrl.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _addedItems.removeAt(index));
  }

  Future<void> _saveAll() async {
    if (_nameCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final uid = (() { try { return FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) { return 'offline'; } })();
      final now = DateTime.now().toIso8601String();

      for (final item in _addedItems) {
        await db.insertSurgery({
          'id': const Uuid().v4(),
          'patient_id': widget.patientId,
          'surgery_name': item['surgery_name'] as String,
          'surgery_date': item['surgery_date'] as String?,
          'hospital': item['hospital'] as String?,
          'surgeon': item['surgeon'] as String?,
          'notes': item['notes'] as String?,
          'created_by': uid,
          'created_at': now,
        });
      }

      if (mounted) {
        ref.invalidate(patientSurgeriesProvider(widget.patientId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} surgery/surgeries added')));
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
    _nameCtrl.dispose();
    _hospitalCtrl.dispose();
    _surgeonCtrl.dispose();
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
            Text(_addedItems.isEmpty ? 'Add Surgeries' : 'Surgeries (${_addedItems.length})'),
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
                    Text('Surgery History', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
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
                  Text('${_addedItems.length} surgery/surgeries pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
              iconBuilder: (_) => Icons.local_hospital,
              labelBuilder: (i) => _addedItems[i]['surgery_name'] as String,
              subtitleBuilder: (i) => _addedItems[i]['surgery_date'] != null ? '${_addedItems[i]['surgery_date']}' : null,
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
                  const Text('Quick Select', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search surgery...',
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
                        final s = _filtered[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_hospital, size: 18, color: AppTheme.primaryColor),
                          title: Text(s['surgery'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text(s['category'] as String, style: const TextStyle(fontSize: 11)),
                          onTap: () => _select(s),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Or fill manually', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Surgery Name', prefixIcon: Icon(Icons.local_hospital)),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _surgeryDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                      if (picked != null) setState(() => _surgeryDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Surgery Date', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(_surgeryDate != null
                          ? '${_surgeryDate!.year}-${_surgeryDate!.month.toString().padLeft(2, '0')}-${_surgeryDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hospitalCtrl,
                    decoration: const InputDecoration(labelText: 'Hospital', prefixIcon: Icon(Icons.local_hospital_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _surgeonCtrl,
                    decoration: const InputDecoration(labelText: 'Surgeon', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes), alignLabelWithHint: true),
                    maxLines: 4,
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
