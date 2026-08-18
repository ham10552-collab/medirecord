import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_helper.dart';
import '../../shared/models/booking.dart';

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

final pharmacyQueueProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getPharmacyQueue();
});

final labQueueProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getLabQueue();
});

final myLabRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMyLabRequests();
});

/// Daily visits + prescriptions for the last 7 days (oldest first), used by
/// the dashboard activity chart. Missing days are filled with zeros.
final weeklyActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - 6);
  final stats = await db.getClinicStats(start, DateTime(now.year, now.month, now.day));
    final daily = <String, Map<String, dynamic>>{};
    for (final r in (stats['daily'] as List<dynamic>? ?? [])) {
      final m = r as Map<String, dynamic>;
      daily[m['date'] as String? ?? ''] = m;
    }
    final days = <Map<String, dynamic>>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      final key = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final row = daily[key] ?? {};
    days.add({
      'label': switch (d.weekday) {
        1 => 'M',
        2 => 'T',
        3 => 'W',
        4 => 'T',
        5 => 'F',
        6 => 'S',
        _ => 'S',
      },
      'fullLabel': switch (d.weekday) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        _ => 'Sun',
      },
      'visits': row['visits'] as int? ?? 0,
      'prescriptions': row['prescriptions'] as int? ?? 0,
    });
  }
  return days;
});

/// Next upcoming bookings (today onwards), nearest first.
final upcomingBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getUpcomingBookings(6);
});

/// Clinic departments reference list.
final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getDepartments();
});

/// Recent activity feed (admissions, exams, lab results, prescriptions...).
final activityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getRecentActivity(20);
});

/// KPI comparisons ("vs last week" / "vs yesterday").
final comparisonStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getComparisonStats();
});
