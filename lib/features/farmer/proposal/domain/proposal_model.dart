import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';

/// Status stages of an insurance proposal as it moves through the pipeline.
enum ProposalStatus {
  draft,
  submitted,
  vetReview,
  vetApproved,
  vetRejected,
  uiicSent,
  policyCreated;

  /// Creates a [ProposalStatus] from its JSON string representation.
  static ProposalStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return ProposalStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => ProposalStatus.draft,
    );
  }

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case ProposalStatus.draft:
        return 'Draft';
      case ProposalStatus.submitted:
        return 'Submitted';
      case ProposalStatus.vetReview:
        return 'Vet Review';
      case ProposalStatus.vetApproved:
        return 'Vet Approved';
      case ProposalStatus.vetRejected:
        return 'Vet Rejected';
      case ProposalStatus.uiicSent:
        return 'UIIC Sent';
      case ProposalStatus.policyCreated:
        return 'Policy Created';
    }
  }

  /// Color associated with this status for badges and indicators.
  Color get color {
    switch (this) {
      case ProposalStatus.draft:
        return Colors.grey;
      case ProposalStatus.submitted:
        return AppColors.info;
      case ProposalStatus.vetReview:
        return AppColors.warning;
      case ProposalStatus.vetApproved:
        return AppColors.success;
      case ProposalStatus.vetRejected:
        return AppColors.error;
      case ProposalStatus.uiicSent:
        return Colors.purple;
      case ProposalStatus.policyCreated:
        return Colors.teal;
    }
  }

  /// Icon associated with this status.
  IconData get icon {
    switch (this) {
      case ProposalStatus.draft:
        return Icons.edit_note;
      case ProposalStatus.submitted:
        return Icons.send;
      case ProposalStatus.vetReview:
        return Icons.medical_services;
      case ProposalStatus.vetApproved:
        return Icons.check_circle;
      case ProposalStatus.vetRejected:
        return Icons.cancel;
      case ProposalStatus.uiicSent:
        return Icons.business;
      case ProposalStatus.policyCreated:
        return Icons.verified;
    }
  }
}

/// Represents an insurance proposal for an animal.
/// Animal details included in proposal response for vet review.
class ProposalAnimalDetail {
  final String id;
  final String uniqueId;
  final String species;
  final String breed;
  final String sex;
  final String? sexCondition;
  final String color;
  final double? ageYears;
  final double? heightCm;
  final double? milkYieldLtr;
  final double? marketValue;
  final String? distinguishingMarks;
  final String? identificationTag;
  final int? healthScore;
  final String? healthRiskCategory;
  final List<String> muzzleImages;
  final List<String> bodyPhotos;

  const ProposalAnimalDetail({
    this.id = '',
    this.uniqueId = '',
    this.species = '',
    this.breed = '',
    this.sex = '',
    this.sexCondition,
    this.color = '',
    this.ageYears,
    this.heightCm,
    this.milkYieldLtr,
    this.marketValue,
    this.distinguishingMarks,
    this.identificationTag,
    this.healthScore,
    this.healthRiskCategory,
    this.muzzleImages = const [],
    this.bodyPhotos = const [],
  });

  factory ProposalAnimalDetail.fromJson(Map<String, dynamic> json) {
    return ProposalAnimalDetail(
      id: json['id']?.toString() ?? '',
      uniqueId: json['unique_id']?.toString() ?? '',
      species: json['species']?.toString() ?? '',
      breed: json['breed']?.toString() ?? '',
      sex: json['sex']?.toString() ?? '',
      sexCondition: json['sex_condition']?.toString(),
      color: json['color']?.toString() ?? '',
      ageYears: _parseDoubleStatic(json['age_years']),
      heightCm: _parseDoubleStatic(json['height_cm']),
      milkYieldLtr: _parseDoubleStatic(json['milk_yield_ltr']),
      marketValue: _parseDoubleStatic(json['market_value']),
      distinguishingMarks: json['distinguishing_marks']?.toString(),
      identificationTag: json['identification_tag']?.toString(),
      healthScore: json['health_score'] is int ? json['health_score'] as int : null,
      healthRiskCategory: json['health_risk_category']?.toString(),
      muzzleImages: _parseImageList(json['muzzle_images']),
      bodyPhotos: _parseImageList(json['body_photos']),
    );
  }

  /// Parses image list — handles both string paths and object maps with 'path' key.
  static List<String> _parseImageList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return (value as List<dynamic>).map((e) {
      if (e is String) return e;
      if (e is Map) return e['path']?.toString() ?? e['url']?.toString() ?? '';
      return e.toString();
    }).where((s) => s.isNotEmpty).toList();
  }

  static double? _parseDoubleStatic(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Farmer details included in proposal response for vet review.
class ProposalFarmerDetail {
  final String id;
  final String name;
  final String phone;
  final String? village;
  final String? district;
  final String? state;
  final String? aadhaarNumber;
  final String? fatherOrHusbandName;
  final String? occupation;

  const ProposalFarmerDetail({
    this.id = '',
    this.name = '',
    this.phone = '',
    this.village,
    this.district,
    this.state,
    this.aadhaarNumber,
    this.fatherOrHusbandName,
    this.occupation,
  });

  factory ProposalFarmerDetail.fromJson(Map<String, dynamic> json) {
    return ProposalFarmerDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      village: json['village']?.toString(),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      aadhaarNumber: json['aadhaar_number']?.toString(),
      fatherOrHusbandName: json['father_or_husband_name']?.toString(),
      occupation: json['occupation']?.toString(),
    );
  }
}

class ProposalModel {
  final String id;
  final String animalId;
  final String farmerId;
  final Map<String, dynamic> formData;
  final String? formSchemaVersion;
  final ProposalStatus status;
  final String? rejectionReason;
  final String? uiicReference;
  final double? sumInsured;
  final double? premium;
  final String? animalName;
  final String? animalSpecies;
  final DateTime? submittedAt;
  final DateTime? vetReviewedAt;
  final DateTime? uiicSentAt;
  final DateTime createdAt;
  final ProposalAnimalDetail? animal;
  final ProposalFarmerDetail? farmer;

  const ProposalModel({
    required this.id,
    required this.animalId,
    required this.farmerId,
    this.formData = const {},
    this.formSchemaVersion,
    this.status = ProposalStatus.draft,
    this.rejectionReason,
    this.uiicReference,
    this.sumInsured,
    this.premium,
    this.animalName,
    this.animalSpecies,
    this.submittedAt,
    this.vetReviewedAt,
    this.uiicSentAt,
    required this.createdAt,
    this.animal,
    this.farmer,
  });

  /// Human-readable status label.
  String get statusLabel => status.label;

  /// Color for the status badge.
  Color get statusColor => status.color;

  /// Whether this proposal can be edited.
  bool get isEditable => status == ProposalStatus.draft;

  /// Whether this proposal can be submitted.
  bool get isSubmittable => status == ProposalStatus.draft;

  /// Whether a policy has been created from this proposal.
  bool get hasPolicyCreated => status == ProposalStatus.policyCreated;

  /// Deserialises a [ProposalModel] from a JSON map returned by the API.
  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    return ProposalModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      animalId: json['animalId']?.toString() ?? json['animal_id']?.toString() ?? '',
      farmerId: json['farmerId']?.toString() ?? json['farmer_id']?.toString() ?? '',
      formData: json['formData'] is Map<String, dynamic>
          ? json['formData'] as Map<String, dynamic>
          : json['form_data'] is Map<String, dynamic>
              ? json['form_data'] as Map<String, dynamic>
              : const {},
      formSchemaVersion: json['formSchemaVersion']?.toString() ??
          json['form_schema_version']?.toString(),
      status: ProposalStatus.fromString(
        json['status']?.toString() ?? 'draft',
      ),
      rejectionReason: json['rejectionReason']?.toString() ??
          json['rejection_reason']?.toString(),
      uiicReference: json['uiicReference']?.toString() ??
          json['uiic_reference']?.toString(),
      sumInsured: _parseDouble(json['sumInsured'] ?? json['sum_insured']),
      premium: _parseDouble(json['premium']),
      animalName: json['animalName']?.toString() ?? json['animal_name']?.toString(),
      animalSpecies: json['animalSpecies']?.toString() ?? json['animal_species']?.toString(),
      submittedAt: _parseDateTime(json['submittedAt'] ?? json['submitted_at']),
      vetReviewedAt: _parseDateTime(json['vetReviewedAt'] ?? json['vet_reviewed_at']),
      uiicSentAt: _parseDateTime(json['uiicSentAt'] ?? json['uiic_sent_at']),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      animal: json['animal'] is Map<String, dynamic>
          ? ProposalAnimalDetail.fromJson(json['animal'] as Map<String, dynamic>)
          : null,
      farmer: json['farmer'] is Map<String, dynamic>
          ? ProposalFarmerDetail.fromJson(json['farmer'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Serialises this [ProposalModel] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'animalId': animalId,
      'farmerId': farmerId,
      'formData': formData,
      if (formSchemaVersion != null) 'formSchemaVersion': formSchemaVersion,
      'status': status.name,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (uiicReference != null) 'uiicReference': uiicReference,
      if (sumInsured != null) 'sumInsured': sumInsured,
      if (premium != null) 'premium': premium,
      if (animalName != null) 'animalName': animalName,
      if (animalSpecies != null) 'animalSpecies': animalSpecies,
      if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
      if (vetReviewedAt != null) 'vetReviewedAt': vetReviewedAt!.toIso8601String(),
      if (uiicSentAt != null) 'uiicSentAt': uiicSentAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this model with the given fields replaced.
  ProposalModel copyWith({
    String? id,
    String? animalId,
    String? farmerId,
    Map<String, dynamic>? formData,
    String? formSchemaVersion,
    ProposalStatus? status,
    String? rejectionReason,
    String? uiicReference,
    double? sumInsured,
    double? premium,
    String? animalName,
    String? animalSpecies,
    DateTime? submittedAt,
    DateTime? vetReviewedAt,
    DateTime? uiicSentAt,
    DateTime? createdAt,
  }) {
    return ProposalModel(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      farmerId: farmerId ?? this.farmerId,
      formData: formData ?? this.formData,
      formSchemaVersion: formSchemaVersion ?? this.formSchemaVersion,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      uiicReference: uiicReference ?? this.uiicReference,
      sumInsured: sumInsured ?? this.sumInsured,
      premium: premium ?? this.premium,
      animalName: animalName ?? this.animalName,
      animalSpecies: animalSpecies ?? this.animalSpecies,
      submittedAt: submittedAt ?? this.submittedAt,
      vetReviewedAt: vetReviewedAt ?? this.vetReviewedAt,
      uiicSentAt: uiicSentAt ?? this.uiicSentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProposalModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProposalModel(id: $id, status: ${status.name}, animal: $animalId)';

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
