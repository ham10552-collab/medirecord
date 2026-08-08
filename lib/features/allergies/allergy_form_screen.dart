import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../shared/models/allergy.dart';
import '../patients/patient_provider.dart';
import '../../shared/widgets/pending_items_list.dart';
import '../../shared/widgets/luxury_figures.dart';

class AllergyFormScreen extends ConsumerStatefulWidget {
  final String patientId;

  const AllergyFormScreen({super.key, required this.patientId});

  @override
  ConsumerState<AllergyFormScreen> createState() => _AllergyFormScreenState();
}

class _AllergyFormScreenState extends ConsumerState<AllergyFormScreen> {
  final _allergenCtrl = TextEditingController();
  final _reactionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _severity = 'mild';
  DateTime? _onsetDate;
  bool _isSaving = false;

  final List<String> _commonAllergens = [
    'Penicillin', 'Amoxicillin', 'Cephalexin', 'Sulfa drugs', 'Aspirin',
    'Ibuprofen', 'Codeine', 'Morphine', 'NSAIDs', 'Contrast dye',
    'Latex', 'Iodine', 'Bandage adhesive', 'Suture material',
    'Peanuts', 'Tree nuts', 'Shellfish', 'Eggs', 'Milk', 'Soy',
    'Wheat', 'Fish', 'Sesame', 'Pollen', 'Dust mites',
    'Pet dander', 'Mold', 'Bee stings', 'Wasp stings', 'Cockroach',
    'Nickel', 'Fragrance', 'Corticosteroids', 'Local anesthetics',
    'ACE Inhibitors', 'Sulfonamides', 'Quinolones', 'Tetracyclines',
    'Vancomycin', 'Gentamicin', 'Clindamycin', 'Erythromycin',
    'Allopurinol', 'Carbamazepine', 'Lamotrigine', 'Phenytoin',
    'Aspirin', 'Celecoxib', 'Paracetamol', 'Tramadol', 'Morphine',
    'Bee pollen', 'Honey', 'Propofol', 'Ketamine', 'Halothane',
    'Sunscreen', 'Cosmetics', 'Shampoo', 'Soap', 'Detergent',
    'Fabric softener', 'Wool', 'Nylon', 'Copper', 'Gold', 'Cobalt',
    'Mango', 'Banana', 'Avocado', 'Kiwi', 'Strawberry', 'Tomato',
    'Corn', 'Rice', 'Potato', 'Garlic', 'Onion', 'Chocolate',
    'Coffee', 'Tea', 'Cinnamon', 'Pepper', 'Food coloring',
    'MSG (Monosodium Glutamate)', 'Sulfites', 'Yeast', 'Gluten',
    'Cockroach', 'Mosquito', 'Fire ant', 'Tick', 'Cat dander',
    'Dog dander', 'Horse dander', 'Rat urine', 'Feathers',
  ];
  List<String> _filteredAllergens = [];

  final List<Map<String, dynamic>> _addedItems = [];

  @override
  void initState() {
    super.initState();
    _filteredAllergens = List.from(_commonAllergens);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredAllergens = q.isEmpty
          ? List.from(_commonAllergens)
          : _commonAllergens.where((a) => a.toLowerCase().contains(q)).toList();
    });
  }

  void _select(String allergen) {
    _allergenCtrl.text = allergen;
    setState(() => _searchCtrl.clear());
  }

  void _addToLocal() {
    final allergen = _allergenCtrl.text.trim();
    if (allergen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter or select an allergen first')));
      return;
    }
    setState(() {
      _addedItems.add({
        'allergen': allergen,
        'severity': _severity,
        'reaction': _reactionCtrl.text.trim().isEmpty ? null : _reactionCtrl.text.trim(),
        'onset_date': _onsetDate?.toIso8601String().split('T')[0],
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      _allergenCtrl.clear();
      _reactionCtrl.clear();
      _notesCtrl.clear();
      _onsetDate = null;
      _severity = 'mild';
      _searchCtrl.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _addedItems.removeAt(index));
  }

  Future<void> _saveAll() async {
    if (_allergenCtrl.text.trim().isNotEmpty) _addToLocal();
    if (_addedItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper();
      final uid = (() { try { return FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) { return 'offline'; } })();
      final now = DateTime.now().toIso8601String();

      for (final item in _addedItems) {
        await db.insertAllergy(Allergy(
          id: const Uuid().v4(),
          patientId: widget.patientId,
          allergen: item['allergen'] as String,
          reaction: item['reaction'] as String?,
          severity: item['severity'] as String,
          onsetDate: item['onset_date'] as String?,
          notes: item['notes'] as String?,
          createdBy: uid,
          createdAt: now,
        ));
      }

      if (mounted) {
        ref.invalidate(patientAllergiesProvider(widget.patientId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_addedItems.length} allergy/allergies added')));
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
    _allergenCtrl.dispose();
    _reactionCtrl.dispose();
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
            Text(_addedItems.isEmpty ? 'Add Allergies' : 'Allergies (${_addedItems.length})'),
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
                    Text('Allergy Profile', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
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
                  Text('${_addedItems.length} allergy/allergies pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
              iconBuilder: (_) => Icons.warning_amber,
              iconColorBuilder: (i) {
                final severity = _addedItems[i]['severity'] as String?;
                if (severity == 'severe') return AppTheme.errorColor;
                if (severity == 'moderate') return Colors.orange;
                return AppTheme.successColor;
              },
              labelBuilder: (i) => _addedItems[i]['allergen'] as String,
              subtitleBuilder: (i) {
                final reaction = _addedItems[i]['reaction'] as String?;
                return reaction != null && reaction.isNotEmpty ? 'Reaction: $reaction' : null;
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
                  const Text('Quick Select', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search allergen...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      itemCount: _filteredAllergens.length > 12 ? 12 : _filteredAllergens.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final a = _filteredAllergens[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning_amber, size: 18, color: AppTheme.errorColor),
                          title: Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          onTap: () => _select(a),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Or fill manually', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _allergenCtrl,
                    decoration: const InputDecoration(labelText: 'Allergen', prefixIcon: Icon(Icons.warning_amber)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _severity,
                    decoration: const InputDecoration(labelText: 'Severity', prefixIcon: Icon(Icons.warning)),
                    items: const [
                      DropdownMenuItem(value: 'mild', child: Text('Mild')),
                      DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                      DropdownMenuItem(value: 'severe', child: Text('Severe')),
                    ],
                    onChanged: (v) => setState(() => _severity = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reactionCtrl,
                    decoration: const InputDecoration(labelText: 'Reaction', prefixIcon: Icon(Icons.info_outline)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _onsetDate ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                      if (picked != null) setState(() => _onsetDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Onset Date', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(_onsetDate != null
                          ? '${_onsetDate!.year}-${_onsetDate!.month.toString().padLeft(2, '0')}-${_onsetDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date'),
                    ),
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
