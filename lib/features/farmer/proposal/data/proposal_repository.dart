import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/api_exception.dart';
import 'package:cattleshield/core/network/api_result.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import '../domain/proposal_model.dart';

/// Repository for managing insurance proposals via the REST API.
class ProposalRepository {
  final DioClient _dioClient;

  ProposalRepository({required DioClient dioClient}) : _dioClient = dioClient;

  /// Fetches all proposals, optionally filtered by [status].
  Future<ApiResult<List<ProposalModel>>> getProposals({
    ProposalStatus? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) {
        queryParams['status'] = status.name;
      }

      final result = await _dioClient.get(
        ApiEndpoints.proposals,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      return result.when(
        success: (response) {
          final data = response.data;
          final List<dynamic> items =
              data is List ? data : (data is Map ? data['data'] ?? [] : []);
          final proposals =
              items.map((json) => ProposalModel.fromJson(json as Map<String, dynamic>)).toList();
          // Sort by creation date descending.
          proposals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ApiResult.success(proposals);
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Fetches a single proposal by [id].
  Future<ApiResult<ProposalModel>> getProposalById(String id) async {
    try {
      final result = await _dioClient.get(ApiEndpoints.proposalById(id));

      return result.when(
        success: (response) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(ProposalModel.fromJson(data));
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Creates a new proposal for the given [animalId] with [formData].
  Future<ApiResult<ProposalModel>> createProposal(
    String animalId,
    Map<String, dynamic> formData,
  ) async {
    try {
      final result = await _dioClient.post(
        ApiEndpoints.proposals,
        data: {
          'animalId': animalId,
          'formData': formData,
        },
      );

      return result.when(
        success: (response) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(ProposalModel.fromJson(data));
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Updates an existing proposal's [formData].
  Future<ApiResult<ProposalModel>> updateProposal(
    String id,
    Map<String, dynamic> formData, {
    ProposalStatus? status,
  }) async {
    try {
      final body = <String, dynamic>{
        'formData': formData,
      };
      if (status != null) {
        body['status'] = status.name;
      }

      final result = await _dioClient.put(
        ApiEndpoints.proposalById(id),
        data: body,
      );

      return result.when(
        success: (response) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : (response.data['data'] as Map<String, dynamic>);
          return ApiResult.success(ProposalModel.fromJson(data));
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  /// Submits a draft proposal for vet review.
  Future<ApiResult<ProposalModel>> submitProposal(String id) async {
    return updateProposal(id, {}, status: ProposalStatus.submitted);
  }
}

/// Riverpod provider for [ProposalRepository].
final proposalRepositoryProvider = Provider<ProposalRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ProposalRepository(dioClient: dioClient);
});
