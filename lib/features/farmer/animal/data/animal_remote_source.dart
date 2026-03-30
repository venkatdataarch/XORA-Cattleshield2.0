import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';

/// Remote data source for animal-related API endpoints.
///
/// Handles both cattle and mule (equine) endpoints, which use separate
/// legacy API paths on the CattleShield backend.
class AnimalRemoteSource {
  final DioClient _client;

  AnimalRemoteSource({required DioClient client}) : _client = client;

  // ---------------------------------------------------------------------------
  // Cattle endpoints
  // ---------------------------------------------------------------------------

  /// Registers a new cattle animal with multipart form data.
  ///
  /// Uses an extended 120-second timeout for muzzle image upload.
  Future<Map<String, dynamic>> registerCattle(FormData data) async {
    final result = await _client.upload(
      ApiEndpoints.cattleRegister,
      data: data,
    );

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Identifies an existing cattle animal by muzzle scan.
  Future<Map<String, dynamic>> identifyCattle(FormData data) async {
    final result = await _client.upload(
      ApiEndpoints.cattleIdentify,
      data: data,
    );

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Fetches all cattle for the authenticated user.
  Future<List<Map<String, dynamic>>> getAllCattle() async {
    final result = await _client.get(ApiEndpoints.cattleAll);

    return result.when(
      success: (Response response) => _extractList(response),
      failure: (error) => throw error,
    );
  }

  /// Fetches a single cattle record by its database ID.
  Future<Map<String, dynamic>> getCattleById(String id) async {
    final result = await _client.get(ApiEndpoints.cattleById(id));

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Fetches a single cattle record by its UCID.
  Future<Map<String, dynamic>> getCattleByUcid(String ucid) async {
    final result = await _client.get(ApiEndpoints.cattleByUcid(ucid));

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Submits a health scan for a cattle animal.
  Future<Map<String, dynamic>> submitCattleHealthScan(
    String id,
    FormData data,
  ) async {
    final result = await _client.upload(
      ApiEndpoints.cattleHealthScan(id),
      data: data,
    );

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  // ---------------------------------------------------------------------------
  // Mule / Equine endpoints
  // ---------------------------------------------------------------------------

  /// Registers a new mule or equine animal with multipart form data.
  ///
  /// Uses a shorter 35-second timeout compared to cattle.
  Future<Map<String, dynamic>> registerMule(FormData data) async {
    final result = await _client.upload(
      ApiEndpoints.muleRegister,
      data: data,
    );

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Identifies an existing mule/equine animal by muzzle scan.
  Future<Map<String, dynamic>> identifyMule(FormData data) async {
    final result = await _client.upload(
      ApiEndpoints.muleIdentify,
      data: data,
    );

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Fetches all mule/equine records for the authenticated user.
  Future<List<Map<String, dynamic>>> getAllMule() async {
    final result = await _client.get(ApiEndpoints.muleAll);

    return result.when(
      success: (Response response) => _extractList(response),
      failure: (error) => throw error,
    );
  }

  /// Fetches a single mule record by its database ID.
  Future<Map<String, dynamic>> getMuleById(String id) async {
    final result = await _client.get(ApiEndpoints.muleById(id));

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Fetches a single mule record by its MUID.
  Future<Map<String, dynamic>> getMuleByMuid(String muid) async {
    final result = await _client.get(ApiEndpoints.muleByMuid(muid));

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  /// Submits a health scan for a mule/equine animal.
  Future<Map<String, dynamic>> submitMuleHealthScan(
    String id,
    FormData data,
  ) async {
    final result = await _client.upload(
      ApiEndpoints.muleHealthScan(id),
      data: data,
    );

    return result.when(
      success: (Response response) => _extractMap(response),
      failure: (error) => throw error,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Extracts a JSON map from the response, handling both wrapped and
  /// unwrapped response formats.
  Map<String, dynamic> _extractMap(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      // API may wrap the result under a "data" or "animal" key.
      return (data['data'] as Map<String, dynamic>?) ??
          (data['animal'] as Map<String, dynamic>?) ??
          (data['cattle'] as Map<String, dynamic>?) ??
          (data['mule'] as Map<String, dynamic>?) ??
          data;
    }
    throw const ApiException(message: 'Invalid response format.');
  }

  /// Extracts a JSON list from the response.
  List<Map<String, dynamic>> _extractList(Response response) {
    final data = response.data;

    // Direct list response
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }

    // Wrapped under a key
    if (data is Map<String, dynamic>) {
      final list = data['data'] ??
          data['animals'] ??
          data['cattle'] ??
          data['mules'] ??
          data['records'];
      if (list is List) {
        return list.cast<Map<String, dynamic>>();
      }
    }

    throw const ApiException(message: 'Invalid response format.');
  }
}

/// Riverpod provider for [AnimalRemoteSource].
final animalRemoteSourceProvider = Provider<AnimalRemoteSource>((ref) {
  final client = ref.watch(dioClientProvider);
  return AnimalRemoteSource(client: client);
});
