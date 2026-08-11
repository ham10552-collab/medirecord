import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../shared/widgets/patient_card.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../../shared/models/patient.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  String _searchQuery = '';
  List<Patient> _allPatients = [];
  List<Patient> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onSearchChanged(String value) {
    if (!mounted) return;
    final q = value.toLowerCase();
    setState(() {
      _searchQuery = value;
      _filtered = q.isEmpty
          ? List.from(_allPatients)
          : _allPatients.where((p) =>
              p.firstName.toLowerCase().contains(q) ||
              p.lastName.toLowerCase().contains(q) ||
              (p.phone?.toLowerCase().contains(q) ?? false)).toList();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final patients = await DatabaseHelper().getAllPatients();
      if (!mounted) return;
      setState(() {
        _allPatients = patients;
        _filtered = _searchQuery.isEmpty ? List.from(patients) : _filtered;
        _loading = false;
      });
      if (_searchQuery.isNotEmpty) _onSearchChanged(_searchQuery);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _showDuplicates() async {
    List<List<Map<String, dynamic>>> groups = [];
    try {
      groups = await DatabaseHelper().findDuplicatePatients();
    } catch (_) {}
    if (!mounted) return;
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicate patients found - all names are unique'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyDeep,
        title: Row(
          children: [
            const Icon(Icons.call_split, color: AppTheme.champagne),
            const SizedBox(width: 8),
            Text('${groups.length} duplicate group(s) found',
                style: const TextStyle(color: AppTheme.champagneLight)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final group in groups)
                _DuplicateGroupCard(
                  group: group,
                  onMerged: () {
                    Navigator.pop(context);
                    _load();
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.champagne)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_split_outlined),
            tooltip: 'Find duplicates',
            onPressed: _showDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Bookings',
            onPressed: () => context.push('/bookings'),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patients/add'),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: AppTheme.errorColor),
                        const SizedBox(height: 16),
                        Text('Database Error', style: const TextStyle(fontSize: 16, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const MedicalCrossFigure(size: 18),
                              const SizedBox(width: 10),
                              Text('Patient Records', style: AppTheme.displayStyle(size: 20, color: AppTheme.navy)),
                              const Spacer(),
                              const SparkleFigure(size: 13),
                              const SizedBox(width: 6),
                              const SparkleFigure(size: 9),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const GoldDivider(),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search by name or phone...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _onSearchChanged(''); })
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const MedicalCrossFigure(size: 28, gold: false),
                                  const SizedBox(height: 16),
                                  const SparkleFigure(size: 10),
                                  Text(
                                    _searchQuery.isEmpty ? 'No patients yet' : 'No patients match your search',
                                    style: AppTheme.displayStyle(size: 16, color: AppTheme.navy),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty ? 'Add your first patient to get started' : 'Try a different name or phone',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => context.push('/patients/add'),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Patient'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) => PatientCard(
                                  patient: _filtered[i],
                                  onTap: () => context.push('/patients/${_filtered[i].id}'),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _DuplicateGroupCard extends StatefulWidget {
  final List<Map<String, dynamic>> group;
  final VoidCallback onMerged;
  const _DuplicateGroupCard({required this.group, required this.onMerged});

  @override
  State<_DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<_DuplicateGroupCard> {
  String? _keepId;
  bool _busy = false;

  String _label(Map<String, dynamic> m) {
    final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
    final phone = (m['phone'] as String? ?? '').isNotEmpty ? '  ${m['phone']}' : '';
    final age = m['age'] != null ? '  ${m['age']} yrs' : '';
    return '$name$age$phone';
  }

  Future<void> _merge() async {
    if (_keepId == null) return;
    final removeIds = widget.group.map((m) => m['id'] as String).where((id) => id != _keepId).toList();
    if (removeIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyDeep,
        title: const Text('Merge patients?', style: TextStyle(color: AppTheme.champagneLight)),
        content: Text(
          'All history, examinations, medications, prescriptions and bookings '
          'of ${removeIds.length} patient(s) will move to the one you keep, then the '
          'duplicate(s) will be deleted permanently.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge', style: TextStyle(color: AppTheme.champagne)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final db = DatabaseHelper();
      for (final id in removeIds) {
        await db.mergePatients(_keepId!, id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patients merged'), backgroundColor: Colors.green),
      );
      widget.onMerged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merge failed: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101D45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in widget.group)
            RadioListTile<String>(
              dense: true,
              value: m['id'] as String,
              groupValue: _keepId ?? (widget.group.first['id'] as String),
              onChanged: _busy ? null : (v) => setState(() => _keepId = v),
              title: Text(_label(m), style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                m['id'] == _keepId || (_keepId == null && widget.group.first['id'] == m['id'])
                    ? 'KEEP this one'
                    : 'will be merged into the kept one',
                style: TextStyle(
                  color: m['id'] == _keepId || (_keepId == null && widget.group.first['id'] == m['id'])
                      ? Colors.greenAccent
                      : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton.icon(
                    onPressed: _merge,
                    icon: const Icon(Icons.join_full, size: 18),
                    label: const Text('Merge group'),
                  ),
          ),
        ],
      ),
    );
  }
}
