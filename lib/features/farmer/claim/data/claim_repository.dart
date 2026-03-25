import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/api_exception.dart';
import 'package:cattleshield/core/network/api_result.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import '../domain/claim_model.dart';

/// Repository for managing insurance claims via the REST API.
class ClaimRepository {
  final DioClient _dioClient;

  ClaimRepository({required DioClient dioClient}) : _dioClient = dioClient;

  /// Fetches all claims, optionally filtered by [status].
  Future<ApiResult<List<ClaimModel>>> getClaims({
    ClaimStatus? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) {
        queryParams['status'] = status.name;
      }

      final result = await _dioClient.get(
        ApiEndpoints.claims,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return result.when(
        success: (response) {
          final data = response.data;
          final List<dynamic> items =
              data is List ? data : (data is Map ? data['data'] ?? [] : []);
          final claims = items
              .map((json) => ClaimModel.fromJson(json as Map<String, dynamic>))
              .toList();
          // Sort by creation date descending.
          claims.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ApiResult.success(claims);
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Fetches a single claim by [id].
  Future<ApiResult<ClaimModel>> getClaimById(String id) async {
    try {
      final result = await _dioClient.get(ApiEndpoints.claimById(id));

      return result.when(
        success: (response) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(ClaimModel.fromJson(data));
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Creates a new claim for the given [policyId].
  Future<ApiResult<ClaimModel>> createClaim(
    String policyId,
    ClaimType type,
    Map<String, dynamic> formData,
  ) async {
    try {
      final result = await _dioClient.post(
        ApiEndpoints.claims,
        data: {
          'policyId': policyId,
          'type': type.name,
          'formData': formData,
        },
      );

      return result.when(
        success: (response) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(ClaimModel.fromJson(data));
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Uploads evidence media for a claim.
  Future<ApiResult<void>> uploadEvidence(
    String claimId,
    FormData data,
  ) async {
    try {
      final result = await _dioClient.upload(
        '${ApiEndpoints.claimById(claimId)}/evidence',
        data: data,
      );

      return result.when(
        success: (_) => const ApiResult.success(null),
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Verifies muzzle match for a claim.
  Future<ApiResult<Map<String, dynamic>>> verifyMuzzle(
    String claimId,
    FormData data,
  ) async {
    try {
      final result = await _dioClient.upload(
        ApiEndpoints.claimMuzzleVerify(claimId),
        data: data,
      );

      return result.when(
        success: (response) {
          final responseData = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};
          return ApiResult.success(responseData);
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }
}

/// Riverpod provider for [ClaimRepository].
final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ClaimRepository(dioClient: dioClient);
});
