import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_helper.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final allPatientsProvider = FutureProvider((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllPatients();
});

final patientCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getPatientCount();
});

final genderDistributionProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getGenderDistribution();
});

final recentExaminationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getRecentExaminations(10);
});

final allUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllUsers();
});
