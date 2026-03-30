import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';

/// Status stages of an insurance claim.
enum ClaimStatus {
  submitted,
  vetReview,
  vetApproved,
  vetRejected,
  uiicProcessing,
  settled,
  repudiated;

  /// Creates a [ClaimStatus] from its JSON string representation.
  static ClaimStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return ClaimStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => ClaimStatus.submitted,
    );
  }

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case ClaimStatus.submitted:
        return 'Submitted';
      case ClaimStatus.vetReview:
        return 'Vet Review';
      case ClaimStatus.vetApproved:
        return 'Vet Approved';
      case ClaimStatus.vetRejected:
        return 'Vet Rejected';
      case ClaimStatus.uiicProcessing:
        return 'UIIC Processing';
      case ClaimStatus.settled:
        return 'Settled';
      case ClaimStatus.repudiated:
        return 'Repudiated';
    }
  }

  /// Color associated with this status for badges and indicators.
  Color get color {
    switch (this) {
      case ClaimStatus.submitted:
        return AppColors.info;
      case ClaimStatus.vetReview:
        return AppColors.warning;
      case ClaimStatus.vetApproved:
        return AppColors.success;
      case ClaimStatus.vetRejected:
        return AppColors.error;
      case ClaimStatus.uiicProcessing:
        return Colors.purple;
      case ClaimStatus.settled:
        return Colors.teal;
      case ClaimStatus.repudiated:
        return AppColors.error;
    }
  }

  /// Icon associated with this status.
  IconData get icon {
    switch (this) {
      case ClaimStatus.submitted:
        return Icons.send;
      case ClaimStatus.vetReview:
        return Icons.medical_services;
      case ClaimStatus.vetApproved:
        return Icons.check_circle;
      case ClaimStatus.vetRejected:
        return Icons.cancel;
      case ClaimStatus.uiicProcessing:
        return Icons.business;
      case ClaimStatus.settled:
        return Icons.paid;
      case ClaimStatus.repudiated:
        return Icons.block;
    }
  }
}

/// Type of insurance claim — death claims only.
enum ClaimType {
  death;

  /// Creates a [ClaimType] from its JSON string representation.
  static ClaimType fromString(String value) {
    return ClaimType.death; // Only death claims supported
  }

  /// Human-readable label for display.
  String get label => 'Death';

  /// Icon for the claim type.
  IconData get icon => Icons.dangerous;

  /// Color for the claim type badge.
  Color get color => AppColors.error;
}

/// Represents a piece of evidence media attached to a claim.
class EvidenceMedia {
  final String type; // photo, video, document
  final String url;
  final DateTime? capturedAt;
  final bool? aiProcessed;

  const EvidenceMedia({
    required this.type,
    required this.url,
    this.capturedAt,
    this.aiProcessed,
  });

  factory EvidenceMedia.fromJson(Map<String, dynamic> json) {
    return EvidenceMedia(
      type: json['type']?.toString() ?? 'photo',
      url: json['url']?.toString() ?? '',
      capturedAt: json['capturedAt'] != null
          ? DateTime.tryParse(json['capturedAt'].toString())
          : null,
      aiProcessed: json['aiProcessed'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
      if (aiProcessed != null) 'aiProcessed': aiProcessed,
    };
  }

  /// Whether this is a photo.
  bool get isPhoto => type == 'photo';

  /// Whether this is a video.
  bool get isVideo => type == 'video';

  /// Whether this is a document.
  bool get isDocument => type == 'document';

  /// Icon for the media type.
  IconData get typeIcon {
    switch (type) {
      case 'video':
        return Icons.videocam;
      case 'document':
        return Icons.description;
      default:
        return Icons.photo;
    }
  }
}

/// Represents an insurance claim for an animal.
class ClaimModel {
  final String id;
  final String policyId;
  final String animalId;
  final String claimNumber;
  final ClaimType type;
  final Map<String, dynamic> formData;
  final List<EvidenceMedia>? evidenceMedia;
  final double? aiMuzzleMatchScore;
  final String? aiMatchResult; // verified, suspicious, failed
  final ClaimStatus status;
  final double? settlementAmount;
  final DateTime? settledAt;
  final String? rejectionReason;
  final String? animalName;
  final String? policyNumber;
  final DateTime createdAt;

  const ClaimModel({
    required this.id,
    required this.policyId,
    required this.animalId,
    required this.claimNumber,
    this.type = ClaimType.death,
    this.formData = const {},
    this.evidenceMedia,
    this.aiMuzzleMatchScore,
    this.aiMatchResult,
    this.status = ClaimStatus.submitted,
    this.settlementAmount,
    this.settledAt,
    this.rejectionReason,
    this.animalName,
    this.policyNumber,
    required this.createdAt,
  });

  /// Human-readable status label.
  String get statusLabel => status.label;

  /// Color for the status badge.
  Color get statusColor => status.color;

  /// Whether the claim has been settled.
  bool get isSettled => status == ClaimStatus.settled;

  /// Whether the AI match result is verified.
  bool get isAiVerified => aiMatchResult == 'verified';

  /// Whether the AI match result is suspicious.
  bool get isAiSuspicious => aiMatchResult == 'suspicious';

  /// Deserialises a [ClaimModel] from a JSON map returned by the API.
  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    return ClaimModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      policyId: json['policyId']?.toString() ?? json['policy_id']?.toString() ?? '',
      animalId: json['animalId']?.toString() ?? json['animal_id']?.toString() ?? '',
      claimNumber: json['claimNumber']?.toString() ??
          json['claim_number']?.toString() ??
          '',
      type: ClaimType.fromString(json['type']?.toString() ?? 'death'),
      formData: json['formData'] is Map<String, dynamic>
          ? json['formData'] as Map<String, dynamic>
          : json['form_data'] is Map<String, dynamic>
              ? json['form_data'] as Map<String, dynamic>
              : const {},
      evidenceMedia: _parseEvidenceMedia(
        json['evidenceMedia'] ?? json['evidence_media'],
      ),
      aiMuzzleMatchScore:
          _parseDouble(json['aiMuzzleMatchScore'] ?? json['ai_muzzle_match_score']),
      aiMatchResult: json['aiMatchResult']?.toString() ??
          json['ai_match_result']?.toString(),
      status: ClaimStatus.fromString(json['status']?.toString() ?? 'submitted'),
      settlementAmount:
          _parseDouble(json['settlementAmount'] ?? json['settlement_amount']),
      settledAt: _parseDateTime(json['settledAt'] ?? json['settled_at']),
      rejectionReason: json['rejectionReason']?.toString() ??
          json['rejection_reason']?.toString(),
      animalName: json['animalName']?.toString() ?? json['animal_name']?.toString(),
      policyNumber: json['policyNumber']?.toString() ?? json['policy_number']?.toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  /// Serialises this [ClaimModel] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'policyId': policyId,
      'animalId': animalId,
      'claimNumber': claimNumber,
      'type': type.name,
      'formData': formData,
      if (evidenceMedia != null)
        'evidenceMedia': evidenceMedia!.map((e) => e.toJson()).toList(),
      if (aiMuzzleMatchScore != null) 'aiMuzzleMatchScore': aiMuzzleMatchScore,
      if (aiMatchResult != null) 'aiMatchResult': aiMatchResult,
      'status': status.name,
      if (settlementAmount != null) 'settlementAmount': settlementAmount,
      if (settledAt != null) 'settledAt': settledAt!.toIso8601String(),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (animalName != null) 'animalName': animalName,
      if (policyNumber != null) 'policyNumber': policyNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this model with the given fields replaced.
  ClaimModel copyWith({
    String? id,
    String? policyId,
    String? animalId,
    String? claimNumber,
    ClaimType? type,
    Map<String, dynamic>? formData,
    List<EvidenceMedia>? evidenceMedia,
    double? aiMuzzleMatchScore,
    String? aiMatchResult,
    ClaimStatus? status,
    double? settlementAmount,
    DateTime? settledAt,
    String? rejectionReason,
    String? animalName,
    String? policyNumber,
    DateTime? createdAt,
  }) {
    return ClaimModel(
      id: id ?? this.id,
      policyId: policyId ?? this.policyId,
      animalId: animalId ?? this.animalId,
      claimNumber: claimNumber ?? this.claimNumber,
      type: type ?? this.type,
      formData: formData ?? this.formData,
      evidenceMedia: evidenceMedia ?? this.evidenceMedia,
      aiMuzzleMatchScore: aiMuzzleMatchScore ?? this.aiMuzzleMatchScore,
      aiMatchResult: aiMatchResult ?? this.aiMatchResult,
      status: status ?? this.status,
      settlementAmount: settlementAmount ?? this.settlementAmount,
      settledAt: settledAt ?? this.settledAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      animalName: animalName ?? this.animalName,
      policyNumber: policyNumber ?? this.policyNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ClaimModel(id: $id, claimNumber: $claimNumber, status: ${status.name})';

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

  static List<EvidenceMedia>? _parseEvidenceMedia(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .map((json) => EvidenceMedia.fromJson(json))
          .toList();
    }
    return null;
  }
}
