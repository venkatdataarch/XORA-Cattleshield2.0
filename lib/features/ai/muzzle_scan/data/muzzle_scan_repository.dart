import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/api_result.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';

/// Repository for AI muzzle scan operations (register, identify, verify).
class MuzzleScanRepository {
  final DioClient _dio;

  MuzzleScanRepository({required DioClient dio}) : _dio = dio;

  /// Registers a new animal's muzzle pattern by uploading multi-angle images.
  ///
  /// Returns a map containing the generated unique ID (UCID/MUID) and
  /// confidence score.
  Future<ApiResult<Map<String, dynamic>>> registerWithMuzzle(
    AnimalSpecies species,
    FormData formData,
  ) async {
    final endpoint = species.isCattle
        ? ApiEndpoints.cattleRegister
        : ApiEndpoints.muleRegister;

    final result = await _dio.upload(endpoint, data: formData);
    return result.when(
      success: (response) {
        final data = response.data as Map<String, dynamic>;
        return ApiResult.success(data);
      },
      failure: (e) => ApiResult.failure(e),
    );
  }

  /// Identifies an animal by its muzzle pattern.
  ///
  /// Returns a map containing match results (ID, confidence, etc.).
  Future<ApiResult<Map<String, dynamic>>> identifyByMuzzle(
    AnimalSpecies species,
    FormData formData,
  ) async {
    final endpoint = species.isCattle
        ? ApiEndpoints.cattleIdentify
        : ApiEndpoints.muleIdentify;

    final result = await _dio.upload(endpoint, data: formData);
    return result.when(
      success: (response) {
        final data = response.data as Map<String, dynamic>;
        return ApiResult.success(data);
      },
      failure: (e) => ApiResult.failure(e),
    );
  }

  /// Verifies muzzle identity for a claim.
  ///
  /// Returns a map containing match percentage and verification status.
  Future<ApiResult<Map<String, dynamic>>> verifyMuzzle(
    String claimId,
    FormData formData,
  ) async {
    final result = await _dio.upload(
      ApiEndpoints.claimMuzzleVerify(claimId),
      data: formData,
    );
    return result.when(
      success: (response) {
        final data = response.data as Map<String, dynamic>;
        return ApiResult.success(data);
      },
      failure: (e) => ApiResult.failure(e),
    );
  }
}

/// Riverpod provider for [MuzzleScanRepository].
final muzzleScanRepositoryProvider = Provider<MuzzleScanRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return MuzzleScanRepository(dio: dio);
});
