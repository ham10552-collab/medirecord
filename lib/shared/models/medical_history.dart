class MedicalHistory {
  final String id;
  final String patientId;
  final String historyType;
  final String conditionName;
  final String? diagnosisDate;
  final String status;
  final String? severity;
  final String? notes;
  final String createdBy;
  final String createdAt;

  MedicalHistory({
    required this.id,
    required this.patientId,
    this.historyType = 'medical',
    required this.conditionName,
    this.diagnosisDate,
    this.status = 'active',
    this.severity,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'history_type': historyType,
        'condition_name': conditionName,
        'diagnosis_date': diagnosisDate,
        'status': status,
        'severity': severity,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory MedicalHistory.fromMap(Map<String, dynamic> map) => MedicalHistory(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        historyType: map['history_type'] as String? ?? 'medical',
        conditionName: map['condition_name'] as String,
        diagnosisDate: map['diagnosis_date'] as String?,
        status: map['status'] as String? ?? 'active',
        severity: map['severity'] as String?,
        notes: map['notes'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: map['created_at'] as String,
      );
}