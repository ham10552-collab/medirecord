class Investigation {
  final String id;
  final String patientId;
  final String investigationDate;
  final String category;
  final String testName;
  final String? result;
  final String? normalRange;
  final String? unit;
  final bool isAbnormal;
  final String? labName;
  final String? notes;
  final String? filePath;
  final String? orderedBy;
  final String createdBy;
  final String createdAt;

  Investigation({
    required this.id,
    required this.patientId,
    required this.investigationDate,
    required this.category,
    required this.testName,
    this.result,
    this.normalRange,
    this.unit,
    this.isAbnormal = false,
    this.labName,
    this.notes,
    this.filePath,
    this.orderedBy,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'investigation_date': investigationDate,
        'category': category,
        'test_name': testName,
        'result': result,
        'normal_range': normalRange,
        'unit': unit,
        'is_abnormal': isAbnormal ? 1 : 0,
        'lab_name': labName,
        'notes': notes,
        'file_path': filePath,
        'ordered_by': orderedBy,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory Investigation.fromMap(Map<String, dynamic> map) => Investigation(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        investigationDate: map['investigation_date'] as String,
        category: map['category'] as String,
        testName: map['test_name'] as String,
        result: map['result'] as String?,
        normalRange: map['normal_range'] as String?,
        unit: map['unit'] as String?,
        isAbnormal: (map['is_abnormal'] as int?) == 1,
        labName: map['lab_name'] as String?,
        notes: map['notes'] as String?,
        filePath: map['file_path'] as String?,
        orderedBy: map['ordered_by'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: map['created_at'] as String,
      );
}
