import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';

/// Dio [Interceptor] that attaches the Bearer token to every outgoing request,
/// logs request/response metadata, and handles 401 (unauthorized) responses.
class ApiInterceptor extends Interceptor {
  final SecureStorageService _storageService;

  /// Optional callback invoked when a 401 response is received.
  /// Use this to trigger navigation to the login screen or reset auth state.
  final void Function()? onUnauthorized;

  ApiInterceptor({
    required SecureStorageService storageService,
    this.onUnauthorized,
  }) : _storageService = storageService;

  // ---------------------------------------------------------------------------
  // Request
  // ---------------------------------------------------------------------------

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Attach Bearer token if available.
    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    developer.log(
      '→ ${options.method} ${options.uri}',
      name: 'ApiInterceptor',
    );

    handler.next(options);
  }

  // ---------------------------------------------------------------------------
  // Response
  // ---------------------------------------------------------------------------

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
      name: 'ApiInterceptor',
    );

    handler.next(response);
  }

  // ---------------------------------------------------------------------------
  // Error
  // ---------------------------------------------------------------------------

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    developer.log(
      '✗ ${err.requestOptions.method} ${err.requestOptions.uri} '
      '-> $statusCode ${err.message}',
      name: 'ApiInterceptor',
      level: 900, // WARNING
    );

    if (statusCode == 401) {
      // Clear stored credentials so stale tokens are not re-sent.
      await _storageService.deleteToken();
      await _storageService.deleteRefreshToken();

      // Notify listeners (e.g. auth state notifier) about the forced logout.
      onUnauthorized?.call();
    }

    handler.next(err);
  }
}
