import 'dart:convert';
import 'package:localstorage/localstorage.dart';
import '../license/license_manager.dart';
import '../utils/constants.dart';
import '../../shared/models/patient.dart';
import '../../shared/models/medical_history.dart';
import '../../shared/models/examination.dart';
import '../../shared/models/investigation.dart';
import '../../shared/models/medication.dart';
import '../../shared/models/allergy.dart';
import '../../shared/models/prescription.dart';
import '../../shared/models/booking.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Map<String, dynamic> _data = {};
  bool _loaded = false;

  String get dbPath => '';

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await initLocalStorage();
    final raw = localStorage.getItem('medirecord_data');
    if (raw != null && raw.isNotEmpty) {
      _data = json.decode(raw) as Map<String, dynamic>;
    }
    _loaded = true;
  }

  Future<void> _save() async {
    localStorage.setItem('medirecord_data', json.encode(_data));
  }

  Future<String> exportAllData() async {
    await _ensureLoaded();
    return json.encode(_data);
  }

  Future<Map<String, dynamic>> importAllData(String rawJson) async {
    await _ensureLoaded();
    final parsed = json.decode(rawJson) as Map<String, dynamic>;
    _data = parsed;
    await _save();
    return parsed;
  }

  List<Map<String, dynamic>> _getList(String key) {
    _data.putIfAbsent(key, () => []);
    return List<Map<String, dynamic>>.from(_data[key] as List);
  }

  void _addToList(String key, Map<String, dynamic> item) {
    _data.putIfAbsent(key, () => []);
    (_data[key] as List).add(item);
  }

  void _updateInList(String key, String idField, String id, Map<String, dynamic> item) {
    final list = _data.putIfAbsent(key, () => []) as List;
    final idx = list.indexWhere((m) => (m as Map<String, dynamic>)[idField] == id);
    if (idx >= 0) list[idx] = item;
  }

  void _deleteFromList(String key, String idField, String id) {
    final list = _data.putIfAbsent(key, () => []) as List;
    list.removeWhere((m) => (m as Map<String, dynamic>)[idField] == id);
  }

  Future<int> insertPatient(Patient patient) async {
    await _ensureLoaded();

    // Trial cap enforced at the write choke point so no code path (UI form,
    // HTTP ingest, secretary local save) can bypass it.
    final licensed = await LicenseManager.isLicensedOnDevice();
    if (!licensed) {
      final count = (_data['patients'] as List?)?.length ?? 0;
      if (count >= AppConstants.maxTrialPatients) {
        return 0; // blocked by trial limit
      }
    }

    _addToList('patients', patient.toMap());
    await _save();
    return 1;
  }

  Future<int> updatePatient(Patient patient) async {
    await _ensureLoaded();
    _updateInList('patients', 'id', patient.id, patient.toMap());
    await _save();
    return 1;
  }

  Future<int> deletePatient(String id) async {
    await _ensureLoaded();
    _deleteFromList('patients', 'id', id);
    for (final key in ['medical_history', 'examinations', 'investigations', 'medications', 'surgeries', 'allergies']) {
      final list = _data[key] as List?;
      if (list != null) {
        list.removeWhere((m) => (m as Map<String, dynamic>)['patient_id'] == id);
      }
    }
    await _save();
    return 1;
  }

  Future<Patient?> getPatient(String id) async {
    await _ensureLoaded();
    final list = _getList('patients');
    final map = list.cast<Map<String, dynamic>>().where((m) => m['id'] == id).firstOrNull;
    return map != null ? Patient.fromMap(map) : null;
  }

  Future<List<Patient>> getAllPatients() async {
    await _ensureLoaded();
    final list = _getList('patients');
    final patients = list.cast<Map<String, dynamic>>().map((m) => Patient.fromMap(m)).toList();
    patients.sort((a, b) => '${a.lastName} ${a.firstName}'.compareTo('${b.lastName} ${b.firstName}'));
    return patients;
  }

  Future<List<Patient>> searchPatients(String query) async {
    await _ensureLoaded();
    final q = query.toLowerCase();
    final list = _getList('patients');
    return list.cast<Map<String, dynamic>>()
        .where((m) =>
            (m['first_name'] as String? ?? '').toLowerCase().contains(q) ||
            (m['last_name'] as String? ?? '').toLowerCase().contains(q) ||
            (m['phone'] as String? ?? '').toLowerCase().contains(q))
        .map((m) => Patient.fromMap(m))
        .toList();
  }

  Future<int> getPatientCount() async {
    await _ensureLoaded();
    return (_data['patients'] as List?)?.length ?? 0;
  }

  Future<Map<String, int>> getGenderDistribution() async {
    await _ensureLoaded();
    final list = _getList('patients');
    int male = 0, female = 0;
    for (final m in list) {
      final g = m['gender'] as String?;
      if (g == 'Male') male++;
      else if (g == 'Female') female++;
    }
    return {'male': male, 'female': female};
  }

  Future<int> insertMedicalHistory(MedicalHistory history) async {
    await _ensureLoaded();
    _addToList('medical_history', history.toMap());
    await _save();
    return 1;
  }

  Future<int> updateMedicalHistory(MedicalHistory history) async {
    await _ensureLoaded();
    _updateInList('medical_history', 'id', history.id, history.toMap());
    await _save();
    return 1;
  }

  Future<int> deleteMedicalHistory(String id) async {
    await _ensureLoaded();
    _deleteFromList('medical_history', 'id', id);
    await _save();
    return 1;
  }

  Future<List<MedicalHistory>> getPatientMedicalHistory(String patientId) async {
    await _ensureLoaded();
    final list = _getList('medical_history');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .map((m) => MedicalHistory.fromMap(m))
        .toList();
  }

  Future<int> insertSurgery(Map<String, dynamic> surgery) async {
    await _ensureLoaded();
    _addToList('surgeries', surgery);
    await _save();
    return 1;
  }

  Future<int> deleteSurgery(String id) async {
    await _ensureLoaded();
    _deleteFromList('surgeries', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Map<String, dynamic>>> getPatientSurgeries(String patientId) async {
    await _ensureLoaded();
    final list = _getList('surgeries');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .toList();
  }

  Future<int> insertExamination(Examination exam) async {
    await _ensureLoaded();
    _addToList('examinations', exam.toMap());
    await _save();
    return 1;
  }

  Future<int> updateExamination(Examination exam) async {
    await _ensureLoaded();
    _updateInList('examinations', 'id', exam.id, exam.toMap());
    await _save();
    return 1;
  }

  Future<int> deleteExamination(String id) async {
    await _ensureLoaded();
    _deleteFromList('examinations', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Examination>> getPatientExaminations(String patientId) async {
    await _ensureLoaded();
    final list = _getList('examinations');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .map((m) => Examination.fromMap(m))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getRecentExaminations(int limit) async {
    await _ensureLoaded();
    final list = _getList('examinations');
    list.sort((a, b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    final recent = list.take(limit).toList();
    final patients = _getList('patients');
    for (final exam in recent) {
      final patient = patients.cast<Map<String, dynamic>>().where((p) => p['id'] == exam['patient_id']).firstOrNull;
      if (patient != null) {
        exam['first_name'] = patient['first_name'];
        exam['last_name'] = patient['last_name'];
      }
    }
    return recent.cast<Map<String, dynamic>>();
  }

  Future<int> insertInvestigation(Investigation inv) async {
    await _ensureLoaded();
    _addToList('investigations', inv.toMap());
    await _save();
    return 1;
  }

  Future<int> updateInvestigation(Investigation inv) async {
    await _ensureLoaded();
    _updateInList('investigations', 'id', inv.id, inv.toMap());
    await _save();
    return 1;
  }

  Future<int> deleteInvestigation(String id) async {
    await _ensureLoaded();
    _deleteFromList('investigations', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Investigation>> getPatientInvestigations(String patientId) async {
    await _ensureLoaded();
    final list = _getList('investigations');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .map((m) => Investigation.fromMap(m))
        .toList();
  }

  Future<int> insertMedication(Medication med) async {
    await _ensureLoaded();
    _addToList('medications', med.toMap());
    await _save();
    return 1;
  }

  Future<int> updateMedication(Medication med) async {
    await _ensureLoaded();
    _updateInList('medications', 'id', med.id, med.toMap());
    await _save();
    return 1;
  }

  Future<int> deleteMedication(String id) async {
    await _ensureLoaded();
    _deleteFromList('medications', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Medication>> getPatientMedications(String patientId) async {
    await _ensureLoaded();
    final list = _getList('medications');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .map((m) => Medication.fromMap(m))
        .toList();
  }

  Future<int> insertAllergy(Allergy allergy) async {
    await _ensureLoaded();
    _addToList('allergies', allergy.toMap());
    await _save();
    return 1;
  }

  Future<int> updateAllergy(Allergy allergy) async {
    await _ensureLoaded();
    _updateInList('allergies', 'id', allergy.id, allergy.toMap());
    await _save();
    return 1;
  }

  Future<int> deleteAllergy(String id) async {
    await _ensureLoaded();
    _deleteFromList('allergies', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Allergy>> getPatientAllergies(String patientId) async {
    await _ensureLoaded();
    final list = _getList('allergies');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .map((m) => Allergy.fromMap(m))
        .toList();
  }

  Future<int> insertPrescription(Prescription prescription) async {
    await _ensureLoaded();
    _addToList('prescriptions', prescription.toMap());
    await _save();
    return 1;
  }

  Future<List<Prescription>> getPatientPrescriptions(String patientId) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    return list.cast<Map<String, dynamic>>()
        .where((m) => m['patient_id'] == patientId)
        .map((m) => Prescription.fromMap(m))
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<int> deletePrescription(String id) async {
    await _ensureLoaded();
    _deleteFromList('prescriptions', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    await _ensureLoaded();
    return _getList('users');
  }

  Future<int> getUserCount() async {
    await _ensureLoaded();
    return (_data['users'] as List?)?.length ?? 0;
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    await _ensureLoaded();
    _addToList('users', user);
    await _save();
    return 1;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    await _ensureLoaded();
    final list = _getList('users');
    return list.cast<Map<String, dynamic>>().where((u) => u['email'] == email || u['id'] == email).firstOrNull;
  }

  Future<int> insertBooking(Booking booking) async {
    await _ensureLoaded();
    _addToList('bookings', booking.toMap());
    await _save();
    return 1;
  }

  Future<int> updateBooking(Booking booking) async {
    await _ensureLoaded();
    _updateInList('bookings', 'id', booking.id, booking.toMap());
    await _save();
    return 1;
  }

  Future<int> deleteBooking(String id) async {
    await _ensureLoaded();
    _deleteFromList('bookings', 'id', id);
    await _save();
    return 1;
  }

  Future<List<Booking>> getAllBookings() async {
    await _ensureLoaded();
    final list = _getList('bookings');
    final bookings = list.cast<Map<String, dynamic>>().map((m) => Booking.fromMap(m)).toList();
    bookings.sort((a, b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'));
    return bookings;
  }

  Future<List<Booking>> getBookingsByDate(String date) async {
    await _ensureLoaded();
    final list = _getList('bookings');
    final bookings = list.cast<Map<String, dynamic>>()
        .where((m) => m['date'] == date)
        .map((m) => Booking.fromMap(m))
        .toList();
    bookings.sort((a, b) => a.time.compareTo(b.time));
    return bookings;
  }
}
