import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';

/// Status of an insurance policy, typically computed from dates.
enum PolicyStatus {
  active,
  expiringSoon,
  expired,
  lapsed,
  cancelled;

  /// Creates a [PolicyStatus] from its JSON string representation.
  static PolicyStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return PolicyStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => PolicyStatus.active,
    );
  }

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case PolicyStatus.active:
        return 'Active';
      case PolicyStatus.expiringSoon:
        return 'Expiring Soon';
      case PolicyStatus.expired:
        return 'Expired';
      case PolicyStatus.lapsed:
        return 'Lapsed';
      case PolicyStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Color associated with this status for badges and indicators.
  Color get color {
    switch (this) {
      case PolicyStatus.active:
        return AppColors.success;
      case PolicyStatus.expiringSoon:
        return AppColors.warning;
      case PolicyStatus.expired:
        return Colors.grey;
      case PolicyStatus.lapsed:
        return AppColors.error;
      case PolicyStatus.cancelled:
        return AppColors.error;
    }
  }

  /// Icon for this status.
  IconData get icon {
    switch (this) {
      case PolicyStatus.active:
        return Icons.check_circle;
      case PolicyStatus.expiringSoon:
        return Icons.schedule;
      case PolicyStatus.expired:
        return Icons.event_busy;
      case PolicyStatus.lapsed:
        return Icons.cancel;
      case PolicyStatus.cancelled:
        return Icons.block;
    }
  }
}

/// Represents an insurance policy for an animal.
class PolicyModel {
  final String id;
  final String proposalId;
  final String animalId;
  final String policyNumber;
  final String? insuredName;
  final double sumInsured;
  final double premium;
  final DateTime startDate;
  final DateTime endDate;
  final PolicyStatus? _explicitStatus;
  final String? animalName;
  final String? animalSpecies;
  final Map<String, dynamic>? detailsJson;
  final DateTime createdAt;

  const PolicyModel({
    required this.id,
    required this.proposalId,
    required this.animalId,
    required this.policyNumber,
    this.insuredName,
    required this.sumInsured,
    required this.premium,
    required this.startDate,
    required this.endDate,
    PolicyStatus? status,
    this.animalName,
    this.animalSpecies,
    this.detailsJson,
    required this.createdAt,
  }) : _explicitStatus = status;

  /// Computes the policy status based on dates.
  ///
  /// If an explicit status was provided (e.g. lapsed, cancelled), that takes
  /// precedence. Otherwise, status is derived from the current date relative
  /// to start and end dates.
  PolicyStatus get status {
    if (_explicitStatus == PolicyStatus.lapsed ||
        _explicitStatus == PolicyStatus.cancelled) {
      return _explicitStatus!;
    }
    return computeStatus(startDate, endDate);
  }

  /// Computes the policy status from dates.
  static PolicyStatus computeStatus(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (now.isBefore(start)) return PolicyStatus.active;
    if (now.isAfter(end)) return PolicyStatus.expired;

    final daysRemaining = end.difference(now).inDays;
    if (daysRemaining <= 30) return PolicyStatus.expiringSoon;

    return PolicyStatus.active;
  }

  /// Human-readable status label.
  String get statusLabel => status.label;

  /// Color for the status badge.
  Color get statusColor => status.color;

  /// Number of days remaining until policy expiry.
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays;
  }

  /// Whether this policy is currently active.
  bool get isActive => status == PolicyStatus.active;

  /// Whether this policy is expiring soon (within 30 days).
  bool get isExpiringSoon => status == PolicyStatus.expiringSoon;

  /// Whether this policy has expired.
  bool get isExpired => status == PolicyStatus.expired;

  /// Whether a claim can be filed against this policy.
  bool get isClaimable => isActive || isExpiringSoon;

  /// Deserialises a [PolicyModel] from a JSON map returned by the API.
  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      proposalId: json['proposalId']?.toString() ??
          json['proposal_id']?.toString() ??
          '',
      animalId: json['animalId']?.toString() ??
          json['animal_id']?.toString() ??
          '',
      policyNumber: json['policyNumber']?.toString() ??
          json['policy_number']?.toString() ??
          '',
      insuredName: json['insuredName']?.toString() ??
          json['insured_name']?.toString(),
      sumInsured: _parseDouble(json['sumInsured'] ?? json['sum_insured']) ?? 0,
      premium: _parseDouble(json['premium']) ?? 0,
      startDate:
          _parseDateTime(json['startDate'] ?? json['start_date']) ?? DateTime.now(),
      endDate: _parseDateTime(json['endDate'] ?? json['end_date']) ??
          DateTime.now().add(const Duration(days: 365)),
      status: json['status'] != null
          ? PolicyStatus.fromString(json['status'].toString())
          : null,
      animalName: json['animalName']?.toString() ??
          json['animal_name']?.toString(),
      animalSpecies: json['animalSpecies']?.toString() ??
          json['animal_species']?.toString(),
      detailsJson: json['detailsJson'] is Map<String, dynamic>
          ? json['detailsJson'] as Map<String, dynamic>
          : json['details_json'] is Map<String, dynamic>
              ? json['details_json'] as Map<String, dynamic>
              : null,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  /// Serialises this [PolicyModel] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proposalId': proposalId,
      'animalId': animalId,
      'policyNumber': policyNumber,
      if (insuredName != null) 'insuredName': insuredName,
      'sumInsured': sumInsured,
      'premium': premium,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.name,
      if (animalName != null) 'animalName': animalName,
      if (animalSpecies != null) 'animalSpecies': animalSpecies,
      if (detailsJson != null) 'detailsJson': detailsJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this model with the given fields replaced.
  PolicyModel copyWith({
    String? id,
    String? proposalId,
    String? animalId,
    String? policyNumber,
    String? insuredName,
    double? sumInsured,
    double? premium,
    DateTime? startDate,
    DateTime? endDate,
    PolicyStatus? status,
    String? animalName,
    String? animalSpecies,
    Map<String, dynamic>? detailsJson,
    DateTime? createdAt,
  }) {
    return PolicyModel(
      id: id ?? this.id,
      proposalId: proposalId ?? this.proposalId,
      animalId: animalId ?? this.animalId,
      policyNumber: policyNumber ?? this.policyNumber,
      insuredName: insuredName ?? this.insuredName,
      sumInsured: sumInsured ?? this.sumInsured,
      premium: premium ?? this.premium,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? _explicitStatus,
      animalName: animalName ?? this.animalName,
      animalSpecies: animalSpecies ?? this.animalSpecies,
      detailsJson: detailsJson ?? this.detailsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolicyModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PolicyModel(id: $id, policyNumber: $policyNumber, status: ${status.name})';

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
