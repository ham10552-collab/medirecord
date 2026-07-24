class Medication {
  final String id;
  final String patientId;
  final String drugName;
  final String? genericName;
  final String dosage;
  final String form;
  final String route;
  final String frequency;
  final String? duration;
  final String startDate;
  final String? endDate;
  final String prescribedBy;
  final String? reason;
  final String? sideEffects;
  final bool isActive;
  final int? refillCount;
  final String? notes;
  final String createdBy;
  final String createdAt;

  Medication({
    required this.id,
    required this.patientId,
    required this.drugName,
    this.genericName,
    required this.dosage,
    required this.form,
    required this.route,
    required this.frequency,
    this.duration,
    required this.startDate,
    this.endDate,
    required this.prescribedBy,
    this.reason,
    this.sideEffects,
    this.isActive = true,
    this.refillCount,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'drug_name': drugName,
        'generic_name': genericName,
        'dosage': dosage,
        'form': form,
        'route': route,
        'frequency': frequency,
        'duration': duration,
        'start_date': startDate,
        'end_date': endDate,
        'prescribed_by': prescribedBy,
        'reason': reason,
        'side_effects': sideEffects,
        'is_active': isActive ? 1 : 0,
        'refill_count': refillCount,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory Medication.fromMap(Map<String, dynamic> map) => Medication(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        drugName: map['drug_name'] as String,
        genericName: map['generic_name'] as String?,
        dosage: map['dosage'] as String,
        form: map['form'] as String,
        route: map['route'] as String,
        frequency: map['frequency'] as String,
        duration: map['duration'] as String?,
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String?,
        prescribedBy: map['prescribed_by'] as String,
        reason: map['reason'] as String?,
        sideEffects: map['side_effects'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        refillCount: map['refill_count'] as int?,
        notes: map['notes'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: map['created_at'] as String,
      );
}
