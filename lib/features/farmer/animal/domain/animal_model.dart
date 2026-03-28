/// Species of animals supported by CattleShield 2.0.
enum AnimalSpecies {
  cow,
  buffalo,
  mule,
  horse,
  donkey;

  /// Creates an [AnimalSpecies] from its JSON string representation.
  static AnimalSpecies fromString(String value) {
    return AnimalSpecies.values.firstWhere(
      (s) => s.name == value.toLowerCase(),
      orElse: () => AnimalSpecies.cow,
    );
  }

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case AnimalSpecies.cow:
        return 'Cow';
      case AnimalSpecies.buffalo:
        return 'Buffalo';
      case AnimalSpecies.mule:
        return 'Mule';
      case AnimalSpecies.horse:
        return 'Horse';
      case AnimalSpecies.donkey:
        return 'Donkey';
    }
  }

  /// Whether this species is classified as cattle.
  bool get isCattle => this == cow || this == buffalo;

  /// Whether this species is classified as equine.
  bool get isEquine => this == mule || this == horse || this == donkey;
}

/// Biological sex of an animal.
enum AnimalSex {
  male,
  female;

  static AnimalSex fromString(String value) {
    return AnimalSex.values.firstWhere(
      (s) => s.name == value.toLowerCase(),
      orElse: () => AnimalSex.male,
    );
  }

  String get label => this == male ? 'Male' : 'Female';
}

/// Condition applicable to female cattle.
enum SexCondition {
  pregnant,
  calfAtFoot,
  freshlyCalved,
  heifer;

  static SexCondition fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return SexCondition.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => SexCondition.heifer,
    );
  }

  String get label {
    switch (this) {
      case SexCondition.pregnant:
        return 'Pregnant';
      case SexCondition.calfAtFoot:
        return 'Calf at Foot';
      case SexCondition.freshlyCalved:
        return 'Freshly Calved';
      case SexCondition.heifer:
        return 'Heifer';
    }
  }
}

/// Represents an animal registered in the CattleShield platform.
class AnimalModel {
  final String id;
  final String? uniqueId;
  final String userId;
  final AnimalSpecies species;
  final String? identificationTag;
  final String? speciesBreed;
  final AnimalSex? sex;
  final SexCondition? sexCondition;
  final String? color;
  final String? distinguishingMarks;
  final double? ageYears;
  final double? heightCm;
  final double? milkYieldLtr;
  final String? muzzleId;
  final List<String>? muzzleImages;
  final int? healthScore;
  final String? healthRiskCategory;
  final List<String>? bodyPhotos;
  final double? marketValue;
  final double? sumInsured;
  final DateTime? createdAt;

  const AnimalModel({
    required this.id,
    this.uniqueId,
    required this.userId,
    required this.species,
    this.identificationTag,
    this.speciesBreed,
    this.sex,
    this.sexCondition,
    this.color,
    this.distinguishingMarks,
    this.ageYears,
    this.heightCm,
    this.milkYieldLtr,
    this.muzzleId,
    this.muzzleImages,
    this.healthScore,
    this.healthRiskCategory,
    this.bodyPhotos,
    this.marketValue,
    this.sumInsured,
    this.createdAt,
  });

  /// A display-friendly name for the animal.
  ///
  /// Examples: "Gir Cow - HF-0042", "Mule - MU-0001"
  String get displayName {
    final breed = speciesBreed ?? species.label;
    final tag = identificationTag;
    if (tag != null && tag.isNotEmpty) {
      return '$breed - $tag';
    }
    return breed;
  }

  /// Label for the species (e.g. "Cow", "Mule").
  String get speciesLabel => species.label;

  /// Whether this animal is cattle (cow or buffalo).
  bool get isCattle => species.isCattle;

  /// Whether this animal is equine (mule, horse, donkey).
  bool get isMule => species.isEquine;

  /// Deserialises an [AnimalModel] from a JSON map returned by the API.
  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    return AnimalModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      uniqueId: json['uniqueId']?.toString() ??
          json['ucid']?.toString() ??
          json['muid']?.toString(),
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      species: AnimalSpecies.fromString(
        json['species']?.toString() ?? json['type']?.toString() ?? 'cow',
      ),
      identificationTag: json['identificationTag']?.toString() ??
          json['identification_tag']?.toString() ??
          json['tagNumber']?.toString(),
      speciesBreed: json['speciesBreed']?.toString() ??
          json['species_breed']?.toString() ??
          json['breed']?.toString(),
      sex: json['sex'] != null
          ? AnimalSex.fromString(json['sex'].toString())
          : null,
      sexCondition: json['sexCondition'] != null
          ? SexCondition.fromString(json['sexCondition'].toString())
          : null,
      color: json['color']?.toString(),
      distinguishingMarks: json['distinguishingMarks']?.toString() ??
          json['distinguishing_marks']?.toString(),
      ageYears: _parseDouble(json['ageYears'] ?? json['age_years'] ?? json['age']),
      heightCm: _parseDouble(json['heightCm'] ?? json['height_cm'] ?? json['height']),
      milkYieldLtr:
          _parseDouble(json['milkYieldLtr'] ?? json['milk_yield_ltr'] ?? json['milkYield']),
      muzzleId: json['muzzleId']?.toString() ?? json['muzzle_id']?.toString(),
      muzzleImages: _parseStringList(json['muzzleImages'] ?? json['muzzle_images']),
      healthScore: _parseInt(json['healthScore'] ?? json['health_score']),
      healthRiskCategory: json['healthRiskCategory']?.toString() ??
          json['health_risk_category']?.toString(),
      bodyPhotos: _parseStringList(json['bodyPhotos'] ?? json['body_photos']),
      marketValue: _parseDouble(json['marketValue'] ?? json['market_value']),
      sumInsured: _parseDouble(json['sumInsured'] ?? json['sum_insured']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  /// Serialises this [AnimalModel] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (uniqueId != null) 'uniqueId': uniqueId,
      'userId': userId,
      'species': species.name,
      if (identificationTag != null) 'identificationTag': identificationTag,
      if (speciesBreed != null) 'speciesBreed': speciesBreed,
      if (sex != null) 'sex': sex!.name,
      if (sexCondition != null) 'sexCondition': sexCondition!.name,
      if (color != null) 'color': color,
      if (distinguishingMarks != null) 'distinguishingMarks': distinguishingMarks,
      if (ageYears != null) 'ageYears': ageYears,
      if (heightCm != null) 'heightCm': heightCm,
      if (milkYieldLtr != null) 'milkYieldLtr': milkYieldLtr,
      if (muzzleId != null) 'muzzleId': muzzleId,
      if (muzzleImages != null) 'muzzleImages': muzzleImages,
      if (healthScore != null) 'healthScore': healthScore,
      if (healthRiskCategory != null) 'healthRiskCategory': healthRiskCategory,
      if (bodyPhotos != null) 'bodyPhotos': bodyPhotos,
      if (marketValue != null) 'marketValue': marketValue,
      if (sumInsured != null) 'sumInsured': sumInsured,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  /// Returns a copy of this model with the given fields replaced.
  AnimalModel copyWith({
    String? id,
    String? uniqueId,
    String? userId,
    AnimalSpecies? species,
    String? identificationTag,
    String? speciesBreed,
    AnimalSex? sex,
    SexCondition? sexCondition,
    String? color,
    String? distinguishingMarks,
    double? ageYears,
    double? heightCm,
    double? milkYieldLtr,
    String? muzzleId,
    List<String>? muzzleImages,
    int? healthScore,
    String? healthRiskCategory,
    List<String>? bodyPhotos,
    double? marketValue,
    double? sumInsured,
    DateTime? createdAt,
  }) {
    return AnimalModel(
      id: id ?? this.id,
      uniqueId: uniqueId ?? this.uniqueId,
      userId: userId ?? this.userId,
      species: species ?? this.species,
      identificationTag: identificationTag ?? this.identificationTag,
      speciesBreed: speciesBreed ?? this.speciesBreed,
      sex: sex ?? this.sex,
      sexCondition: sexCondition ?? this.sexCondition,
      color: color ?? this.color,
      distinguishingMarks: distinguishingMarks ?? this.distinguishingMarks,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      milkYieldLtr: milkYieldLtr ?? this.milkYieldLtr,
      muzzleId: muzzleId ?? this.muzzleId,
      muzzleImages: muzzleImages ?? this.muzzleImages,
      healthScore: healthScore ?? this.healthScore,
      healthRiskCategory: healthRiskCategory ?? this.healthRiskCategory,
      bodyPhotos: bodyPhotos ?? this.bodyPhotos,
      marketValue: marketValue ?? this.marketValue,
      sumInsured: sumInsured ?? this.sumInsured,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimalModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AnimalModel(id: $id, species: ${species.name}, tag: $identificationTag)';

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }
}
