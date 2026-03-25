import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/api_result.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import '../domain/vet_certificate_model.dart';

/// Repository for vet certificate CRUD operations.
class CertificateRepository {
  final DioClient _dio;

  CertificateRepository({required DioClient dio}) : _dio = dio;

  /// Fetches all certificates issued by the current vet.
  Future<ApiResult<List<VetCertificateModel>>> getCertificates() async {
    final result = await _dio.get(ApiEndpoints.vetCertificates);
    return result.when(
      success: (response) {
        final data = response.data;
        List<VetCertificateModel> certs = [];
        if (data is List) {
          certs = data
              .whereType<Map<String, dynamic>>()
              .map(VetCertificateModel.fromJson)
              .toList();
        } else if (data is Map<String, dynamic>) {
          final list = data['data'] as List<dynamic>? ?? [];
          certs = list
              .whereType<Map<String, dynamic>>()
              .map(VetCertificateModel.fromJson)
              .toList();
        }
        return ApiResult.success(certs);
      },
      failure: (e) => ApiResult.failure(e),
    );
  }

  /// Fetches a single certificate by [id].
  Future<ApiResult<VetCertificateModel>> getCertificateById(String id) async {
    final result = await _dio.get('${ApiEndpoints.vetCertificates}/$id');
    return result.when(
      success: (response) {
        final data = response.data as Map<String, dynamic>;
        return ApiResult.success(VetCertificateModel.fromJson(data));
      },
      failure: (e) => ApiResult.failure(e),
    );
  }

  /// Creates a new certificate.
  Future<ApiResult<VetCertificateModel>> createCertificate(
    CertificateType type,
    String entityId,
    Map<String, dynamic> formData,
  ) async {
    final result = await _dio.post(
      ApiEndpoints.vetCertificates,
      data: {
        'type': type.name,
        'relatedId': entityId,
        'formData': formData,
      },
    );
    return result.when(
      success: (response) {
        final data = response.data as Map<String, dynamic>;
        return ApiResult.success(VetCertificateModel.fromJson(data));
      },
      failure: (e) => ApiResult.failure(e),
    );
  }
}

/// Riverpod provider for [CertificateRepository].
final certificateRepositoryProvider = Provider<CertificateRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return CertificateRepository(dio: dio);
});
