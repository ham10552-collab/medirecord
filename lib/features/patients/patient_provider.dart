import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_provider.dart';
import '../../shared/models/patient.dart';

final patientSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredPatientsProvider = FutureProvider<List<Patient>>((ref) async {
  final db = ref.watch(databaseProvider);
  final query = ref.watch(patientSearchQueryProvider);
  if (query.isEmpty) return db.getAllPatients();
  return db.searchPatients(query);
});

final patientByIdProvider = FutureProvider.family<Patient?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.getPatient(id);
});

final patientMedicalHistoryProvider = FutureProvider.family<List, String>((ref, patientId) async {
  final db = ref.watch(databaseProvider);
  return db.getPatientMedicalHistory(patientId);
});

final patientExaminationsProvider = FutureProvider.family<List, String>((ref, patientId) async {
  final db = ref.watch(databaseProvider);
  return db.getPatientExaminations(patientId);
});

final patientInvestigationsProvider = FutureProvider.family<List, String>((ref, patientId) async {
  final db = ref.watch(databaseProvider);
  return db.getPatientInvestigations(patientId);
});

final patientMedicationsProvider = FutureProvider.family<List, String>((ref, patientId) async {
  final db = ref.watch(databaseProvider);
  return db.getPatientMedications(patientId);
});

final patientPrescriptionsProvider = FutureProvider.family<List, String>((ref, patientId) async {
  final db = ref.watch(databaseProvider);
  return db.getPatientPrescriptions(patientId);
});
