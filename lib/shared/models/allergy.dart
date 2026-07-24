class Allergy {
  final String id;
  final String patientId;
  final String allergen;
  final String? reaction;
  final String severity;
  final String? onsetDate;
  final String? notes;
  final String createdBy;
  final String createdAt;

  Allergy({
    required this.id,
    required this.patientId,
    required this.allergen,
    this.reaction,
    this.severity = 'mild',
    this.onsetDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'allergen': allergen,
        'reaction': reaction,
        'severity': severity,
        'onset_date': onsetDate,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory Allergy.fromMap(Map<String, dynamic> map) => Allergy(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        allergen: map['allergen'] as String,
        reaction: map['reaction'] as String?,
        severity: map['severity'] as String? ?? 'mild',
        onsetDate: map['onset_date'] as String?,
        notes: map['notes'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: map['created_at'] as String,
      );
}
