/// Type of vet certificate issued.
enum CertificateType {
  proposal,
  claimDeath,
  claimInjury;

  static CertificateType fromString(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return CertificateType.values.firstWhere(
      (t) => t.name.toLowerCase() == normalized,
      orElse: () => CertificateType.proposal,
    );
  }

  String get label {
    switch (this) {
      case CertificateType.proposal:
        return 'Proposal Certificate';
      case CertificateType.claimDeath:
        return 'Death Certificate';
      case CertificateType.claimInjury:
        return 'Injury Certificate';
    }
  }

  /// The form schema key used by the form engine.
  String get schemaKey {
    switch (this) {
      case CertificateType.proposal:
        return 'vet_cert_proposal';
      case CertificateType.claimDeath:
        return 'vet_cert_death';
      case CertificateType.claimInjury:
        return 'vet_cert_death';
    }
  }
}

/// Represents a vet-issued certificate for a proposal or claim.
class VetCertificateModel {
  final String id;

  /// The proposal_id or claim_id this certificate is associated with.
  final String relatedId;
  final CertificateType type;
  final Map<String, dynamic> formData;
  final String? vetSignatureUrl;
  final String vetId;
  final DateTime createdAt;

  const VetCertificateModel({
    required this.id,
    required this.relatedId,
    required this.type,
    this.formData = const {},
    this.vetSignatureUrl,
    required this.vetId,
    required this.createdAt,
  });

  String get typeLabel => type.label;

  factory VetCertificateModel.fromJson(Map<String, dynamic> json) {
    return VetCertificateModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      relatedId: json['relatedId']?.toString() ??
          json['related_id']?.toString() ??
          json['proposalId']?.toString() ??
          json['claimId']?.toString() ??
          '',
      type: CertificateType.fromString(
        json['type']?.toString() ?? 'proposal',
      ),
      formData: json['formData'] is Map<String, dynamic>
          ? json['formData'] as Map<String, dynamic>
          : json['form_data'] is Map<String, dynamic>
              ? json['form_data'] as Map<String, dynamic>
              : const {},
      vetSignatureUrl: json['vetSignatureUrl']?.toString() ??
          json['vet_signature_url']?.toString(),
      vetId: json['vetId']?.toString() ??
          json['vet_id']?.toString() ??
          '',
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relatedId': relatedId,
      'type': type.name,
      'formData': formData,
      if (vetSignatureUrl != null) 'vetSignatureUrl': vetSignatureUrl,
      'vetId': vetId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  VetCertificateModel copyWith({
    String? id,
    String? relatedId,
    CertificateType? type,
    Map<String, dynamic>? formData,
    String? vetSignatureUrl,
    String? vetId,
    DateTime? createdAt,
  }) {
    return VetCertificateModel(
      id: id ?? this.id,
      relatedId: relatedId ?? this.relatedId,
      type: type ?? this.type,
      formData: formData ?? this.formData,
      vetSignatureUrl: vetSignatureUrl ?? this.vetSignatureUrl,
      vetId: vetId ?? this.vetId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VetCertificateModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VetCertificateModel(id: $id, type: ${type.name}, related: $relatedId)';

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
