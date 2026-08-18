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
    await logActivity(
      'patient',
      '${patient.fullName} registered',
      (patient.phone ?? '').trim().isEmpty
          ? 'New patient record'
          : 'Phone: ${(patient.phone ?? '').trim()}',
      patientId: patient.id,
    );
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
    for (final key in ['medical_history', 'examinations', 'investigations', 'medications', 'surgeries', 'allergies', 'prescriptions', 'bookings']) {
      final list = _data[key] as List?;
      if (list != null) {
        list.removeWhere((m) => (m as Map<String, dynamic>)['patient_id'] == id);
      }
    }
    await _save();
    return 1;
  }

  /// Groups patients that look like the same person. Matching is fuzzy so
  /// real duplicates are found even with messy input: the same full name
  /// (ignoring case, extra spaces and separators) or the same phone number.
  /// Each returned group is a list of patient records (name, phone, age, id).
  Future<List<List<Map<String, dynamic>>>> findDuplicatePatients() async {
    await _ensureLoaded();
    final list = _getList('patients');
    final groups = <String, List<Map<String, dynamic>>>{};

    String normName(String? value) {
      return (value ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll(RegExp(r'[.\-،,]'), '');
    }

    String normPhone(String? value) =>
        (value ?? '').replaceAll(RegExp(r'\D'), '');

    for (final m in list) {
      final name = normName('${m['first_name']} ${m['last_name']}');
      if (name.isNotEmpty) {
        groups.putIfAbsent('name|$name', () => []).add(m);
      }
    }
    for (final m in list) {
      final phone = normPhone(m['phone'] as String?);
      if (phone.length >= 7) {
        groups.putIfAbsent('phone|$phone', () => []).add(m);
      }
    }
    return groups.values.where((g) => g.length > 1).toList();
  }

  /// Moves every linked record (history, exams, investigations, medications,
  /// surgeries, allergies, prescriptions, bookings, alerts) plus the photo
  /// from [removeId] into [keepId], then deletes the duplicate patient.
  Future<int> mergePatients(String keepId, String removeId) async {
    await _ensureLoaded();
    // NOTE: use the live list, not _getList() - _getList returns a copy, so
    // removeAt would delete from the copy and the duplicate would survive.
    final patients = _data.putIfAbsent('patients', () => <dynamic>[]) as List;
    final keepIdx = patients.indexWhere((m) => (m as Map)['id'] == keepId);
    final removeIdx = patients.indexWhere((m) => (m as Map)['id'] == removeId);
    if (keepIdx < 0 || removeIdx < 0) return 0;

    for (final key in ['medical_history', 'examinations', 'investigations', 'medications', 'surgeries', 'allergies', 'prescriptions', 'bookings', 'incoming_alerts']) {
      final list = _data[key] as List?;
      if (list != null) {
        for (final m in list) {
          if ((m as Map<String, dynamic>)['patient_id'] == removeId) {
            m['patient_id'] = keepId;
          }
        }
      }
    }
    final keep = patients[keepIdx];
    final remove = patients[removeIdx];
    final keepPhoto = keep['photo_url'] as String?;
    final removePhoto = remove['photo_url'] as String?;
    if ((keepPhoto == null || keepPhoto.isEmpty) && removePhoto != null && removePhoto.isNotEmpty) {
      keep['photo_url'] = removePhoto;
    }
    if ((keep['phone'] as String? ?? '').isEmpty) keep['phone'] = remove['phone'];
    if ((keep['address'] as String? ?? '').isEmpty) keep['address'] = remove['address'];
    patients.removeAt(removeIdx);
    await _save();
    // Verify the delete really happened - any failure must be reported as an
    // error instead of silently reporting success.
    final stillThere = patients.any((m) => (m as Map)['id'] == removeId);
    return stillThere ? 0 : 1;
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
    await logActivity(
      'exam',
      'Examination: ${await _patientName(exam.patientId)}',
      (exam.diagnosis ?? '').trim().isEmpty
          ? 'Visit recorded'
          : 'Diagnosis: ${(exam.diagnosis ?? '').trim()}',
      patientId: exam.patientId,
    );
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

  /// Inserts a prescription, or replaces an existing one with the same id
  /// (used when syncing the pharmacy queue from the doctor's install).
  Future<int> upsertPrescription(Prescription prescription) async {
    await _ensureLoaded();
    final list = _data.putIfAbsent('prescriptions', () => <dynamic>[]) as List;
    final index = list.indexWhere((m) => (m as Map<String, dynamic>)['id'] == prescription.id);
    if (index >= 0) {
      list[index] = prescription.toMap();
    } else {
      list.add(prescription.toMap());
    }
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

  /// Re-sends an already sent prescription - the pharmacy receives it again
  /// as a fresh pending item (e.g. a refill).
  Future<int> resendPrescription(String id) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    final index = list.indexWhere((m) => m['id'] == id);
    if (index >= 0) {
      final item = list[index];
      item['sent_to_pharmacy'] = 1;
      item['status'] = 'pending';
      item.remove('dispensed_by');
      item.remove('dispensed_at');
      item['sent_at'] = DateTime.now().toIso8601String();
      await _save();
      return 1;
    }
    return 0;
  }

  /// Fills the doctor's name on a prescription when it is missing or generic.
  Future<int> attachDoctorName(String id, String name) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    final index = list.indexWhere((m) => m['id'] == id);
    if (index >= 0) {
      final item = list[index];
      final current = (item['doctor_name'] as String? ?? '').trim();
      if (current.isEmpty || current == 'Unknown') {
        item['doctor_name'] = name;
        await _save();
      }
      return 1;
    }
    return 0;
  }

  /// Doctor explicitly sends a prescription to the pharmacy.
  Future<int> markPrescriptionSent(String id) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    final index = list.indexWhere((m) => m['id'] == id);
    if (index >= 0) {
      final item = list[index];
      item['sent_to_pharmacy'] = 1;
      item['sent_at'] = DateTime.now().toIso8601String();
      await _save();
      final pid = item['patient_id'] as String? ?? '';
      await logActivity(
        'prescription',
        'Prescription sent to pharmacy',
        pid.isEmpty ? '' : await _patientName(pid),
        patientId: pid,
      );
      return 1;
    }
    return 0;
  }

  /// Attaches the pharmacist's name to a prescription (keeps the first one
  /// assigned, so the printer stamp stays the same pharmacist).
  Future<int> markPrescriptionPharmacist(String id, String name) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    final index = list.indexWhere((m) => m['id'] == id);
    if (index >= 0) {
      final item = list[index];
      if ((item['pharmacist_name'] as String? ?? '').isEmpty) {
        item['pharmacist_name'] = name;
        await _save();
        return 1;
      }
      return 1;
    }
    return 0;
  }

  /// Queue shown on the pharmacy screen / served to the pharmacist device.
  /// Only prescriptions the doctor explicitly sent appear, with the patient
  /// name so the pharmacist can identify and search for them.
  Future<List<Map<String, dynamic>>> getPharmacyQueue() async {
    await _ensureLoaded();
    final list = _getList('prescriptions')
        .where((m) => (m['sent_to_pharmacy'] ?? 1) == 1)
        .toList();
    list.sort((a, b) {
      final sa = (a['status'] as String?) ?? 'pending';
      final sb = (b['status'] as String?) ?? 'pending';
      if (sa == sb) {
        return ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? '');
      }
      return sa == 'pending' ? -1 : 1;
    });
    final patients = _getList('patients');
    for (final rx in list) {
      final patient = patients.cast<Map<String, dynamic>>()
          .where((p) => p['id'] == rx['patient_id'])
          .firstOrNull;
      if (patient != null) {
        rx['patient_name'] =
            '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim();
        rx['patient_phone'] = patient['phone'] ?? '';
      }
    }
    return list.cast<Map<String, dynamic>>();
  }

  /// Lab requests on this machine. When a doctor orders tests, they are
  /// stored here (sent_to_lab = 1) and served to the lab device; when the lab
  /// returns results they are updated in place and shown to the doctor.
  Future<List<Map<String, dynamic>>> getLabRequests() async {
    await _ensureLoaded();
    final list = _getList('lab_requests').toList();
    list.sort((a, b) =>
        ((b['requested_at'] as String?) ?? '').compareTo((a['requested_at'] as String?) ?? ''));
    final patients = _getList('patients');
    for (final r in list) {
      final patient = patients.cast<Map<String, dynamic>>()
          .where((p) => p['id'] == r['patient_id'])
          .firstOrNull;
      if (patient != null) {
        r['patient_name'] =
            '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim();
        r['patient_phone'] = patient['phone'] ?? '';
      }
    }
    return list.cast<Map<String, dynamic>>();
  }

  /// Requests the lab device pulls (only pending ones, like the pharmacy
  /// queue only shows unsent prescriptions).
  Future<List<Map<String, dynamic>>> getLabQueue() async {
    final all = await getLabRequests();
    return all
        .where((r) => (r['status'] as String? ?? 'requested') != 'completed')
        .toList();
  }

  /// Requests ordered locally (doctor view) - pending first then completed.
  Future<List<Map<String, dynamic>>> getMyLabRequests() async {
    final all = await getLabRequests();
    all.sort((a, b) {
      final sa = (a['status'] as String?) ?? 'requested';
      final sb = (b['status'] as String?) ?? 'requested';
      if (sa == sb) {
        return ((b['requested_at'] as String?) ?? '')
            .compareTo((a['requested_at'] as String?) ?? '');
      }
      return sa == 'requested' ? -1 : 1;
    });
    return all;
  }

  Future<int> upsertLabRequest(Map<String, dynamic> request) async {
    await _ensureLoaded();
    final list = _data.putIfAbsent('lab_requests', () => <dynamic>[]) as List;
    final index = list.indexWhere((m) => (m as Map<String, dynamic>)['id'] == request['id']);
    if (index >= 0) {
      list[index] = request;
    } else {
      list.add(request);
    }
    await _save();
    return 1;
  }

  /// Sets completed results for a lab request (used on both machines:
  /// the lab marks it complete locally, the doctor applies the return).
  Future<int> completeLabRequest(
    String id, {
    required Map<String, dynamic> request,
  }) async {
    await _ensureLoaded();
    final list = _data.putIfAbsent('lab_requests', () => <dynamic>[]) as List;
    final index = list.indexWhere((m) => (m as Map<String, dynamic>)['id'] == id);
    if (index >= 0) {
      list[index] = request;
    } else {
      list.add(request);
    }
    await _save();
    final pid = request['patient_id'] as String? ?? '';
    await logActivity(
      'lab_result',
      'Lab results ready',
      pid.isEmpty ? '' : 'For ${await _patientName(pid)}',
      patientId: pid,
    );
    return 1;
  }

  /// Once the doctor reads a completed lab result, copies every test with a
  /// value into the patient's Investigations record. Runs once per request
  /// (marked with `saved_to_record`) so it can never duplicate.
  Future<int> saveLabResultsToRecord(Map<String, dynamic> request) async {
    await _ensureLoaded();
    if ((request['saved_to_record'] as bool?) == true) return 0;
    final items = (request['items'] as List?) ?? const [];
    final pid = request['patient_id'] as String? ?? '';
    if (pid.isEmpty || items.isEmpty) return 0;

    String date10(String? s) {
      final v = s ?? '';
      return v.length >= 10 ? v.substring(0, 10) : v;
    }

    final baseId = '${request['id']}_ix';
    var saved = 0;
    for (var i = 0; i < items.length; i++) {
      final it = (items[i] as Map).cast<String, dynamic>();
      final value = (it['value'] as String? ?? '').trim();
      if (value.isEmpty) continue;
      final note = (it['note'] as String? ?? '').trim();
      final investigation = Investigation(
        id: '${baseId}_$i',
        patientId: pid,
        investigationDate: date10(
            request['completed_at'] as String? ?? DateTime.now().toIso8601String()),
        category: 'Laboratory',
        testName: it['test_name'] as String? ?? 'Test',
        result: value,
        normalRange: (it['normal_range'] as String? ?? '').isEmpty
            ? null
            : it['normal_range'] as String?,
        unit: (it['unit'] as String? ?? '').isEmpty ? null : it['unit'] as String?,
        isAbnormal: it['abnormal'] == true,
        labName: (request['lab_technician'] as String? ?? '').isEmpty
            ? null
            : request['lab_technician'] as String?,
        notes: note.isEmpty ? null : note,
        orderedBy: request['ordered_by'] as String?,
        createdBy: 'lab',
        createdAt: DateTime.now().toIso8601String(),
      );
      await insertInvestigation(investigation);
      saved++;
    }
    if (saved > 0) {
      request['saved_to_record'] = true;
      await upsertLabRequest(request);
    }
    return saved;
  }

  Future<int> updatePrescriptionStatus(
    String id, {
    required String status,
    String? dispensedBy,
    String? dispensedAt,
  }) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    final index = list.indexWhere((m) => m['id'] == id);
    if (index >= 0) {
      final item = list[index];
      item['status'] = status;
      if (dispensedBy != null) item['dispensed_by'] = dispensedBy;
      if (dispensedAt != null) item['dispensed_at'] = dispensedAt;
      item['updated_at'] = DateTime.now().toIso8601String();
      await _save();
      if (status == 'dispensed') {
        final pid = item['patient_id'] as String? ?? '';
        await logActivity(
          'dispensed',
          'Prescription dispensed',
          pid.isEmpty ? '' : 'By ${dispensedBy ?? 'Pharmacist'} for ${await _patientName(pid)}',
          patientId: pid,
        );
      }
      return 1;
    }
    return 0;
  }

  Future<int> deletePrescriptionItem(String id, int itemIndex) async {
    await _ensureLoaded();
    final list = _getList('prescriptions');
    final index = list.indexWhere((m) => m['id'] == id);
    if (index >= 0) {
      final items = (list[index]['items'] as List).toList();
      if (itemIndex >= 0 && itemIndex < items.length) {
        items.removeAt(itemIndex);
        list[index]['items'] = items;
      }
      await _save();
      return 1;
    }
    return 0;
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

  Future<int> updateUser(String id, Map<String, dynamic> fields) async {
    await _ensureLoaded();
    final list = _getList('users');
    final idx = list.indexWhere((u) => u['id'] == id);
    if (idx < 0) return 0;
    list[idx].addAll(fields);
    await _save();
    return 1;
  }

  Future<int> deleteUser(String id) async {
    await _ensureLoaded();
    _deleteFromList('users', 'id', id);
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
    await logActivity(
      'booking',
      'Appointment booked: ${booking.patientName}',
      '${booking.date} at ${booking.time}',
      patientId: booking.patientId,
    );
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

  /// Bookings from today onwards (today included), nearest first.
  Future<List<Booking>> getUpcomingBookings(int limit) async {
    await _ensureLoaded();
    final today = DateTime.now();
    final todayKey = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final list = _getList('bookings');
    final bookings = list.cast<Map<String, dynamic>>()
        .where((m) {
          final d = (m['date'] as String? ?? '').trim();
          return d.isNotEmpty &&
              d.compareTo(todayKey) >= 0 &&
              (m['status'] as String? ?? '') != 'cancelled';
        })
        .map((m) => Booking.fromMap(m))
        .toList();
    bookings.sort((a, b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'));
    return bookings.take(limit).toList();
  }

  // ---- Pharmacy inventory ----

  Future<List<Map<String, dynamic>>> getInventory() async {
    await _ensureLoaded();
    final items = _getList('pharmacy_inventory').cast<Map<String, dynamic>>().toList();
    items.sort((a, b) =>
        (a['medicine_name'] as String? ?? '').compareTo(b['medicine_name'] as String? ?? ''));
    return items;
  }

  Future<int> upsertInventoryItem(Map<String, dynamic> item) async {
    await _ensureLoaded();
    final list = _getList('pharmacy_inventory');
    final idx = list.indexWhere((m) => m['id'] == item['id']);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    await _save();
    return 1;
  }

  Future<int> deleteInventoryItem(String id) async {
    await _ensureLoaded();
    _deleteFromList('pharmacy_inventory', 'id', id);
    await _save();
    return 1;
  }

  /// Adds [delta] to every stock entry whose medicine name matches
  /// [medicineName] (case-insensitive). Returns how many entries matched.
  Future<int> adjustInventory(String medicineName, int delta) async {
    await _ensureLoaded();
    final name = medicineName.trim().toLowerCase();
    if (name.isEmpty) return 0;
    final list = _getList('pharmacy_inventory');
    int matched = 0;
    for (final m in list) {
      if ((m['medicine_name'] as String? ?? '').trim().toLowerCase() == name) {
        m['quantity'] = ((m['quantity'] as num?)?.toInt() ?? 0) + delta;
        matched++;
      }
    }
    await _save();
    return matched;
  }

  Future<int> getLowStockCount(int threshold) async {
    await _ensureLoaded();
    final list = _getList('pharmacy_inventory');
    return list.where((m) => ((m['quantity'] as num?)?.toInt() ?? 0) <= threshold).length;
  }

  /// Clinic statistics between [start] and [end] (inclusive).
  /// Counts new patients, visits (examinations), unique visiting patients,
  /// prescriptions (sent + dispensed), investigations, abnormal results and
  /// the most common diagnoses, with a per-day breakdown.
  Future<Map<String, dynamic>> getClinicStats(DateTime start, DateTime end) async {
    await _ensureLoaded();
    String dayKey(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final from = dayKey(start);
    final to = dayKey(end);
    final daily = <String, Map<String, dynamic>>{};
    void bump(String date, String field) {
      daily.putIfAbsent(date, () => {
        'date': date,
        'new_patients': 0,
        'visits': 0,
        'unique_patients': <String>{},
        'prescriptions': 0,
        'dispensed': 0,
        'investigations': 0,
      });
      if (field == 'unique_patients') return;
      daily[date]![field] = (daily[date]![field] as int) + 1;
    }

    final patients = _getList('patients');
    final newPatients = <Map<String, dynamic>>[];
    for (final p in patients) {
      final created = (p['created_at'] as String? ?? '').split('T').first;
      if (created.compareTo(from) >= 0 && created.compareTo(to) <= 0) {
        newPatients.add(p);
        if (created.compareTo(from) >= 0) bump(created, 'new_patients');
      }
    }

    final exams = _getList('examinations');
    final diagnoses = <String, int>{};
    int examinationsCount = 0;
    final visitingIds = <String>{};
    for (final e in exams) {
      final date = (e['visit_date'] as String? ?? '').split('T').first;
      if (date.compareTo(from) >= 0 && date.compareTo(to) <= 0) {
        examinationsCount++;
        visitingIds.add(e['patient_id'] as String? ?? '');
        bump(date, 'visits');
        final diag = (e['diagnosis'] as String? ?? '').trim();
        if (diag.isNotEmpty) diagnoses[diag] = (diagnoses[diag] ?? 0) + 1;
      }
    }

    final rxs = _getList('prescriptions');
    int prescriptionsCount = 0, dispensedCount = 0;
    for (final rx in rxs) {
      final date = (rx['created_at'] as String? ?? '').split('T').first;
      if (date.compareTo(from) >= 0 && date.compareTo(to) <= 0) {
        prescriptionsCount++;
        if (rx['status'] == 'dispensed') dispensedCount++;
        bump(date, 'prescriptions');
        if (rx['status'] == 'dispensed') bump(date, 'dispensed');
      }
    }

    final invs = _getList('investigations');
    int invCount = 0, abnormalCount = 0;
    for (final i in invs) {
      final date = (i['investigation_date'] as String? ?? '').split('T').first;
      if (date.compareTo(from) >= 0 && date.compareTo(to) <= 0) {
        invCount++;
        if (i['is_abnormal'] == true) abnormalCount++;
        bump(date, 'investigations');
      }
    }

    final sortedDiagnoses = diagnoses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dailyList = daily.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    int male = 0, female = 0;
    for (final p in newPatients) {
      if (p['gender'] == 'Male') male++;
      else if (p['gender'] == 'Female') female++;
    }

    return {
      'from': from,
      'to': to,
      'new_patients': newPatients.length,
      'new_male': male,
      'new_female': female,
      'examinations': examinationsCount,
      'unique_visits': visitingIds.length,
      'prescriptions': prescriptionsCount,
      'dispensed': dispensedCount,
      'investigations': invCount,
      'abnormal': abnormalCount,
      'top_diagnoses': sortedDiagnoses.take(8).map((e) => {'diagnosis': e.key, 'count': e.value}).toList(),
      'daily': dailyList.map((d) {
        final m = Map<String, dynamic>.from(d);
        m['unique_patients'] = (d['unique_patients'] as Set).length;
        return m;
      }).toList(),
    };
  }

  // ---------------- Activity log (Clinova-style Recent Activity) ----------------

  Future<void> logActivity(String type, String title, String detail,
      {String? patientId}) async {
    await _ensureLoaded();
    final list = _getList('activity_log');
    list.insert(0, {
      'type': type,
      'title': title,
      'detail': detail,
      'patient_id': patientId ?? '',
      'at': DateTime.now().toIso8601String(),
    });
    while (list.length > 200) list.removeLast();
    await _save();
  }

  Future<List<Map<String, dynamic>>> getRecentActivity(int limit) async {
    await _ensureLoaded();
    return _getList('activity_log').take(limit).toList();
  }

  Future<String> _patientName(String id) async {
    try {
      final p = await getPatient(id);
      return p?.fullName ?? '';
    } catch (_) {
      return '';
    }
  }

  // ---------------- Departments ----------------

  Future<int> insertDepartment(Map<String, dynamic> dept) async {
    await _ensureLoaded();
    _addToList('departments', dept);
    await _save();
    return 1;
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    await _ensureLoaded();
    return _getList('departments').cast<Map<String, dynamic>>().toList();
  }

  Future<int> deleteDepartment(String id) async {
    await _ensureLoaded();
    _deleteFromList('departments', 'id', id);
    await _save();
    return 1;
  }

  // ---------------- KPI comparisons (Clinova-style "vs last week") ----------------

  Future<Map<String, dynamic>> getComparisonStats() async {
    await _ensureLoaded();
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    String key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final todayKey = key(today0);
    final yesterdayKey = key(today0.subtract(const Duration(days: 1)));
    final weekStart = today0.subtract(const Duration(days: 6));
    final prevWeekStart = today0.subtract(const Duration(days: 13));
    final prevWeekEnd = weekStart.subtract(const Duration(days: 1));
    final thisWeek = await getClinicStats(weekStart, today0);
    final lastWeek = await getClinicStats(prevWeekStart, prevWeekEnd);

    int examsToday = 0, examsYesterday = 0;
    for (final e in _getList('examinations')) {
      final d = (e['visit_date'] as String? ?? '').split('T').first;
      if (d == todayKey) examsToday++;
      else if (d == yesterdayKey) examsYesterday++;
    }
    int bookingsToday = 0, bookingsYesterday = 0;
    for (final b in _getList('bookings')) {
      final d = (b['date'] as String? ?? '').trim();
      if (d == todayKey) bookingsToday++;
      else if (d == yesterdayKey) bookingsYesterday++;
    }

    double delta(int cur, int prev) =>
        prev <= 0 ? 0 : ((cur - prev) / prev) * 100;

    return {
      'patients_total': _getList('patients').length,
      'new_patients_delta': delta(
          thisWeek['new_patients'] as int? ?? 0,
          lastWeek['new_patients'] as int? ?? 0),
      'exams_today': examsToday,
      'exams_today_delta': delta(examsToday, examsYesterday),
      'prescriptions_delta': delta(
          thisWeek['prescriptions'] as int? ?? 0,
          lastWeek['prescriptions'] as int? ?? 0),
      'dispensed_delta': delta(
          thisWeek['dispensed'] as int? ?? 0,
          lastWeek['dispensed'] as int? ?? 0),
      'bookings_today': bookingsToday,
      'bookings_today_delta': delta(bookingsToday, bookingsYesterday),
    };
  }
}
