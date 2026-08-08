class Booking {
  final String id;
  final String patientId;
  final String patientName;
  final String date;
  final String time;
  final String? reason;
  final String status;
  final String? notes;
  final String? phone;
  final String createdAt;

  Booking({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.time,
    this.reason,
    required this.status,
    this.notes,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'patient_name': patientName,
        'date': date,
        'time': time,
        'reason': reason,
        'status': status,
        'notes': notes,
        'phone': phone,
        'created_at': createdAt,
      };

  factory Booking.fromMap(Map<String, dynamic> map) => Booking(
        id: map['id'] as String,
        patientId: map['patient_id'] as String? ?? '',
        patientName: map['patient_name'] as String? ?? '',
        date: map['date'] as String,
        time: map['time'] as String? ?? map['time'] as String,
        reason: map['reason'] as String?,
        status: map['status'] as String? ?? 'pending',
        notes: map['notes'] as String?,
        phone: map['phone'] as String?,
        createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Booking copyWith({String? status, String? notes}) => Booking(
        id: id,
        patientId: patientId,
        patientName: patientName,
        date: date,
        time: time,
        reason: reason,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        phone: phone,
        createdAt: createdAt,
      );
}
