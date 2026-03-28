/// User roles supported by CattleShield 2.0.
enum UserRole {
  farmer,
  vet,
  agent,
  admin;

  /// Creates a [UserRole] from its JSON string representation.
  ///
  /// Returns `null` if the value does not match any known role, rather than
  /// silently defaulting to [farmer].
  static UserRole? tryFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final role in UserRole.values) {
      if (role.name == lower) return role;
    }
    return null;
  }

  /// Creates a [UserRole] from its JSON string representation.
  ///
  /// Throws [ArgumentError] if [value] does not match any known role.
  static UserRole fromString(String value) {
    final role = tryFromString(value);
    if (role == null) {
      throw ArgumentError('Unknown user role: "$value"');
    }
    return role;
  }
}

/// Represents an authenticated user of the CattleShield platform.
class AppUser {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String? email;
  final String? address;
  final String? village;
  final String? district;
  final String? state;
  final String? aadhaarNumber;
  final String? fatherOrHusbandName;
  final String? occupation;
  final String? qualification; // for vet
  final String? regNumber; // for vet
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.address,
    this.village,
    this.district,
    this.state,
    this.aadhaarNumber,
    this.fatherOrHusbandName,
    this.occupation,
    this.qualification,
    this.regNumber,
    this.createdAt,
  });

  /// Deserialises an [AppUser] from a JSON map returned by the API.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['mobile']?.toString() ?? '',
      role: UserRole.tryFromString(json['role']?.toString()) ?? UserRole.farmer,
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      village: json['village']?.toString(),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      aadhaarNumber: json['aadhaarNumber']?.toString() ??
          json['aadhaar_number']?.toString(),
      fatherOrHusbandName: json['fatherOrHusbandName']?.toString() ??
          json['father_or_husband_name']?.toString(),
      occupation: json['occupation']?.toString(),
      qualification: json['qualification']?.toString(),
      regNumber:
          json['regNumber']?.toString() ?? json['reg_number']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  /// Serialises this [AppUser] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role.name,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (village != null) 'village': village,
      if (district != null) 'district': district,
      if (state != null) 'state': state,
      if (aadhaarNumber != null) 'aadhaarNumber': aadhaarNumber,
      if (fatherOrHusbandName != null)
        'fatherOrHusbandName': fatherOrHusbandName,
      if (occupation != null) 'occupation': occupation,
      if (qualification != null) 'qualification': qualification,
      if (regNumber != null) 'regNumber': regNumber,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  /// Returns a copy of this user with the given fields replaced.
  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    String? email,
    String? address,
    String? village,
    String? district,
    String? state,
    String? aadhaarNumber,
    String? fatherOrHusbandName,
    String? occupation,
    String? qualification,
    String? regNumber,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      email: email ?? this.email,
      address: address ?? this.address,
      village: village ?? this.village,
      district: district ?? this.district,
      state: state ?? this.state,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      fatherOrHusbandName: fatherOrHusbandName ?? this.fatherOrHusbandName,
      occupation: occupation ?? this.occupation,
      qualification: qualification ?? this.qualification,
      regNumber: regNumber ?? this.regNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser(id: $id, name: $name, role: ${role.name})';
}
