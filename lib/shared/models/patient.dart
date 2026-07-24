class Patient {
  final String id;
  final String firstName;
  final String lastName;
  final int age;
  final String gender;
  final String? phone;
  final String? email;
  final String? address;
  final String? bloodGroup;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? photoUrl;
  final String createdBy;
  final String createdAt;
  final String updatedAt;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.gender,
    this.phone,
    this.email,
    this.address,
    this.bloodGroup,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.photoUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'age': age,
        'gender': gender,
        'phone': phone,
        'email': email,
        'address': address,
        'blood_group': bloodGroup,
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
        'photo_url': photoUrl,
        'created_by': createdBy,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Patient.fromMap(Map<String, dynamic> map) => Patient(
        id: map['id'] as String,
        firstName: map['first_name'] as String,
        lastName: map['last_name'] as String,
        age: map['age'] as int? ?? 0,
        gender: map['gender'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        bloodGroup: map['blood_group'] as String?,
        emergencyContactName: map['emergency_contact_name'] as String?,
        emergencyContactPhone: map['emergency_contact_phone'] as String?,
        photoUrl: map['photo_url'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Patient copyWith({
    String? firstName,
    String? lastName,
    int? age,
    String? gender,
    String? phone,
    String? email,
    String? address,
    String? bloodGroup,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? photoUrl,
    String? updatedAt,
  }) =>
      Patient(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
        photoUrl: photoUrl ?? this.photoUrl,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      );
}
