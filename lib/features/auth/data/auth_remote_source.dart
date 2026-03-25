import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

/// Remote data source for authentication endpoints.
///
/// Communicates with the CattleShield API for login, registration,
/// OTP verification, and fetching the current user profile.
class AuthRemoteSource {
  final DioClient _client;

  AuthRemoteSource({required DioClient client}) : _client = client;

  /// Authenticates an agent/vet using [agentId] and [password].
  ///
  /// Returns the raw JSON response containing `token` and `user` keys.
  Future<Map<String, dynamic>> login(String agentId, String password) async {
    final result = await _client.post(
      ApiEndpoints.login,
      data: {
        'agentId': agentId,
        'password': password,
      },
    );

    return result.when(
      success: (Response response) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw const ApiException(message: 'Invalid response format.');
      },
      failure: (error) => throw error,
    );
  }

  /// Registers a new user (farmer or vet) with the provided [data].
  ///
  /// Returns the raw JSON response containing `token` and `user` keys.
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final result = await _client.post(
      ApiEndpoints.register,
      data: data,
    );

    return result.when(
      success: (Response response) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) return responseData;
        throw const ApiException(message: 'Invalid response format.');
      },
      failure: (error) => throw error,
    );
  }

  /// Sends or verifies an OTP for the given [phone] and [otp].
  ///
  /// Returns the raw JSON response containing `token` and `user` keys.
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final result = await _client.post(
      ApiEndpoints.verifyOtp,
      data: {
        'phone': phone,
        'otp': otp,
      },
    );

    return result.when(
      success: (Response response) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw const ApiException(message: 'Invalid response format.');
      },
      failure: (error) => throw error,
    );
  }

  /// Fetches the profile of the currently authenticated user.
  ///
  /// Requires a valid JWT token set via the interceptor.
  Future<Map<String, dynamic>> getCurrentUser() async {
    final result = await _client.get(ApiEndpoints.currentUser);

    return result.when(
      success: (Response response) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          // API may return { "user": {...} } or the user map directly.
          return (data['user'] as Map<String, dynamic>?) ?? data;
        }
        throw const ApiException(message: 'Invalid response format.');
      },
      failure: (error) => throw error,
    );
  }
}

/// Riverpod provider for [AuthRemoteSource].
final authRemoteSourceProvider = Provider<AuthRemoteSource>((ref) {
  final client = ref.watch(dioClientProvider);
  return AuthRemoteSource(client: client);
});
