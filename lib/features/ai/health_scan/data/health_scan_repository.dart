import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/api_result.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';

/// The result of an AI health scan analysis.
class HealthResult {
  final int chiScore; // Cattle Health Index (0-100)
  final String healthStatus; // Excellent, Good, Fair, Poor
  final double bodyConditionScore; // 1-5 scale
  final List<String> observations;
  final List<String> recommendations;
  final List<String> riskFactors;

  const HealthResult({
    required this.chiScore,
    required this.healthStatus,
    required this.bodyConditionScore,
    this.observations = const [],
    this.recommendations = const [],
    this.riskFactors = const [],
  });

  factory HealthResult.fromJson(Map<String, dynamic> json) {
    return HealthResult(
      chiScore: json['chiScore'] as int? ??
          json['chi_score'] as int? ??
          json['score'] as int? ??
          0,
      healthStatus:
          json['healthStatus']?.toString() ??
          json['health_status']?.toString() ??
          json['status']?.toString() ??
          'Unknown',
      bodyConditionScore: _parseDouble(
            json['bodyConditionScore'] ??
                json['body_condition_score'] ??
                json['bcs'],
          ) ??
          3.0,
      observations: _parseStringList(
          json['observations'] ?? json['findings'] ?? []),
      recommendations:
          _parseStringList(json['recommendations'] ?? json['advice'] ?? []),
      riskFactors:
          _parseStringList(json['riskFactors'] ?? json['risk_factors'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'chiScore': chiScore,
        'healthStatus': healthStatus,
        'bodyConditionScore': bodyConditionScore,
        'observations': observations,
        'recommendations': recommendations,
        'riskFactors': riskFactors,
      };

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

/// Repository for AI health scan operations.
class HealthScanRepository {
  final DioClient _dio;

  HealthScanRepository({required DioClient dio}) : _dio = dio;

  /// Submits health scan images for AI analysis.
  Future<ApiResult<HealthResult>> submitHealthScan(
    String animalId,
    AnimalSpecies species,
    FormData formData,
  ) async {
    final endpoint = species.isCattle
        ? ApiEndpoints.cattleHealthScan(animalId)
        : ApiEndpoints.muleHealthScan(animalId);

    final result = await _dio.upload(endpoint, data: formData);
    return result.when(
      success: (response) {
        final data = response.data as Map<String, dynamic>;
        return ApiResult.success(HealthResult.fromJson(data));
      },
      failure: (e) => ApiResult.failure(e),
    );
  }

  /// Fetches health scan history for an animal.
  Future<ApiResult<List<HealthResult>>> getHealthHistory(
    String animalId,
    AnimalSpecies species,
  ) async {
    final endpoint = species.isCattle
        ? ApiEndpoints.cattleHealthHistory(animalId)
        : ApiEndpoints.muleHealthHistory(animalId);

    final result = await _dio.get(endpoint);
    return result.when(
      success: (response) {
        final data = response.data;
        List<HealthResult> results = [];
        if (data is List) {
          results = data
              .whereType<Map<String, dynamic>>()
              .map(HealthResult.fromJson)
              .toList();
        } else if (data is Map<String, dynamic>) {
          final list = data['data'] as List<dynamic>? ?? [];
          results = list
              .whereType<Map<String, dynamic>>()
              .map(HealthResult.fromJson)
              .toList();
        }
        return ApiResult.success(results);
      },
      failure: (e) => ApiResult.failure(e),
    );
  }
}

/// Riverpod provider for [HealthScanRepository].
final healthScanRepositoryProvider = Provider<HealthScanRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return HealthScanRepository(dio: dio);
});
