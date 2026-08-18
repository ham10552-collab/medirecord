/// A lab test order placed by a doctor for a patient.
///
/// Status flow is simple: `requested` (new, waiting at the lab) →
/// `completed` (results ready and returned to the doctor).
class LabRequest {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String doctorName;
  final String? doctorHost; // ip:port of the requesting doctor
  final String orderedBy;
  final String requestedAt;
  String status;
  String? completedAt;
  String? labTechnician;
  final List<Map<String, dynamic>> items; // name + note + result fields

  LabRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    required this.doctorName,
    this.doctorHost,
    required this.orderedBy,
    required this.requestedAt,
    this.status = 'requested',
    this.completedAt,
    this.labTechnician,
    required this.items,
  });

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'patient_name': patientName,
        'patient_phone': patientPhone,
        'doctor_name': doctorName,
        'doctor_host': doctorHost,
        'ordered_by': orderedBy,
        'requested_at': requestedAt,
        'status': status,
        'completed_at': completedAt,
        'lab_technician': labTechnician,
        'items': items,
      };

  factory LabRequest.fromMap(Map<String, dynamic> map) => LabRequest(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        patientName: map['patient_name'] as String? ?? '',
        patientPhone: map['patient_phone'] as String?,
        doctorName: map['doctor_name'] as String? ?? '',
        doctorHost: map['doctor_host'] as String?,
        orderedBy: map['ordered_by'] as String? ?? '',
        requestedAt: map['requested_at'] as String? ?? '',
        status: map['status'] as String? ?? 'requested',
        completedAt: map['completed_at'] as String?,
        labTechnician: map['lab_technician'] as String?,
        items: ((map['items'] as List?) ?? const [])
            .map((i) => (i as Map).cast<String, dynamic>())
            .toList(),
      );
}

/// Normal range + unit autofilled from the catalog when the doctor/lab
/// picks a known test; both stay editable for custom tests.
const String kLabRequested = 'requested';
const String kLabCompleted = 'completed';