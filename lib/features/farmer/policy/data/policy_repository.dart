import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/api_exception.dart';
import 'package:cattleshield/core/network/api_result.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import '../domain/policy_model.dart';

/// Repository for managing insurance policies via the REST API.
class PolicyRepository {
  final DioClient _dioClient;

  PolicyRepository({required DioClient dioClient}) : _dioClient = dioClient;

  /// Fetches all policies, optionally filtered by [status].
  Future<ApiResult<List<PolicyModel>>> getPolicies({
    PolicyStatus? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) {
        queryParams['status'] = status.name;
      }

      final result = await _dioClient.get(
        ApiEndpoints.policies,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return result.when(
        success: (response) {
          final data = response.data;
          final List<dynamic> items =
              data is List ? data : (data is Map ? data['data'] ?? [] : []);
          final policies = items
              .map((json) => PolicyModel.fromJson(json as Map<String, dynamic>))
              .toList();
          // Sort by creation date descending.
          policies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ApiResult.success(policies);
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Fetches a single policy by [id].
  Future<ApiResult<PolicyModel>> getPolicyById(String id) async {
    try {
      final result = await _dioClient.get(ApiEndpoints.policyById(id));

      return result.when(
        success: (response) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(PolicyModel.fromJson(data));
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Creates a new policy (typically from an approved proposal).
  Future<ApiResult<PolicyModel>> createPolicy(
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _dioClient.post(
        ApiEndpoints.policies,
        data: data,
      );

      return result.when(
        success: (response) {
          final responseData = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(PolicyModel.fromJson(responseData));
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

/// Riverpod provider for [PolicyRepository].
final policyRepositoryProvider = Provider<PolicyRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PolicyRepository(dioClient: dioClient);
});
