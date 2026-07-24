class Examination {
  final String id;
  final String patientId;
  final String visitDate;
  final String doctorName;
  final String? chiefComplaint;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final double? temperature;
  final int? respiratoryRate;
  final int? oxygenSaturation;
  final double? height;
  final double? weight;
  final double? bmi;
  final String? generalAppearance;
  final String? headAndNeck;
  final String? chest;
  final String? abdomen;
  final String? cvs;
  final String? cns;
  final String? musculoskeletal;
  final String? skin;
  final String? diagnosis;
  final String? plan;
  final String? notes;
  final String createdBy;
  final String createdAt;

  Examination({
    required this.id,
    required this.patientId,
    required this.visitDate,
    required this.doctorName,
    this.chiefComplaint,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.temperature,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.height,
    this.weight,
    this.bmi,
    this.generalAppearance,
    this.headAndNeck,
    this.chest,
    this.abdomen,
    this.cvs,
    this.cns,
    this.musculoskeletal,
    this.skin,
    this.diagnosis,
    this.plan,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  String? get bp => bloodPressureSystolic != null && bloodPressureDiastolic != null
      ? '$bloodPressureSystolic/$bloodPressureDiastolic'
      : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'visit_date': visitDate,
        'doctor_name': doctorName,
        'chief_complaint': chiefComplaint,
        'blood_pressure_systolic': bloodPressureSystolic,
        'blood_pressure_diastolic': bloodPressureDiastolic,
        'heart_rate': heartRate,
        'temperature': temperature,
        'respiratory_rate': respiratoryRate,
        'oxygen_saturation': oxygenSaturation,
        'height': height,
        'weight': weight,
        'bmi': bmi,
        'general_appearance': generalAppearance,
        'head_and_neck': headAndNeck,
        'chest': chest,
        'abdomen': abdomen,
        'cvs': cvs,
        'cns': cns,
        'musculoskeletal': musculoskeletal,
        'skin': skin,
        'diagnosis': diagnosis,
        'plan': plan,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory Examination.fromMap(Map<String, dynamic> map) => Examination(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        visitDate: map['visit_date'] as String,
        doctorName: map['doctor_name'] as String,
        chiefComplaint: map['chief_complaint'] as String?,
        bloodPressureSystolic: map['blood_pressure_systolic'] as int?,
        bloodPressureDiastolic: map['blood_pressure_diastolic'] as int?,
        heartRate: map['heart_rate'] as int?,
        temperature: (map['temperature'] as num?)?.toDouble(),
        respiratoryRate: map['respiratory_rate'] as int?,
        oxygenSaturation: map['oxygen_saturation'] as int?,
        height: (map['height'] as num?)?.toDouble(),
        weight: (map['weight'] as num?)?.toDouble(),
        bmi: (map['bmi'] as num?)?.toDouble(),
        generalAppearance: map['general_appearance'] as String?,
        headAndNeck: map['head_and_neck'] as String?,
        chest: map['chest'] as String?,
        abdomen: map['abdomen'] as String?,
        cvs: map['cvs'] as String?,
        cns: map['cns'] as String?,
        musculoskeletal: map['musculoskeletal'] as String?,
        skin: map['skin'] as String?,
        diagnosis: map['diagnosis'] as String?,
        plan: map['plan'] as String?,
        notes: map['notes'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: map['created_at'] as String,
      );
}
