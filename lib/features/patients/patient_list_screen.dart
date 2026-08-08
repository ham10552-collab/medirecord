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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
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
