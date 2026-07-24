class PrescriptionItem {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;

  PrescriptionItem({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions = '',
  });

  Map<String, dynamic> toMap() => {
        'medicine_name': medicineName,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
      };

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) => PrescriptionItem(
        medicineName: map['medicine_name'] as String,
        dosage: map['dosage'] as String,
        frequency: map['frequency'] as String,
        duration: map['duration'] as String,
        instructions: map['instructions'] as String? ?? '',
      );
}

class Prescription {
  final String id;
  final String patientId;
  final String doctorName;
  final String diagnosis;
  final List<PrescriptionItem> items;
  final String notes;
  final String createdAt;
  final String updatedAt;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorName,
    this.diagnosis = '',
    required this.items,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'doctor_name': doctorName,
        'diagnosis': diagnosis,
        'items': items.map((i) => i.toMap()).toList(),
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Prescription.fromMap(Map<String, dynamic> map) => Prescription(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        doctorName: map['doctor_name'] as String,
        diagnosis: map['diagnosis'] as String? ?? '',
        items: (map['items'] as List?)
                ?.map((i) => PrescriptionItem.fromMap(i as Map<String, dynamic>))
                .toList() ??
            [],
        notes: map['notes'] as String? ?? '',
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );
}
