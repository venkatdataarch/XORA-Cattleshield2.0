import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';
import 'api_interceptor.dart';
import 'api_result.dart';

/// Central HTTP client for the CattleShield 2.0 app.
///
/// Wraps [Dio] with sensible defaults, token-based auth, structured error
/// handling and multipart upload support.
class DioClient {
  late final Dio _dio;

  DioClient({
    required SecureStorageService storageService,
    void Function()? onUnauthorized,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 120),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      ApiInterceptor(
        storageService: storageService,
        onUnauthorized: onUnauthorized,
      ),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) {}, // silenced in favour of ApiInterceptor logs
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sends a GET request to [path] and returns the response wrapped in an
  /// [ApiResult].
  Future<ApiResult<Response>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _execute(
      () => _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Sends a POST request.
  Future<ApiResult<Response>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _execute(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Sends a PUT request.
  Future<ApiResult<Response>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _execute(
      () => _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Sends a PATCH request.
  Future<ApiResult<Response>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _execute(
      () => _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Sends a DELETE request.
  Future<ApiResult<Response>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _execute(
      () => _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Uploads multipart [FormData] to [path] with an extended send timeout.
  ///
  /// Use [onSendProgress] to drive a progress indicator.
  Future<ApiResult<Response>> upload(
    String path, {
    required FormData data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return _execute(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: const Duration(seconds: 120),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Executes a Dio call, catches exceptions and wraps the result.
  Future<ApiResult<Response>> _execute(
    Future<Response> Function() request,
  ) async {
    try {
      final response = await request();
      return ApiResult.success(response);
    } on DioException catch (e) {
      return ApiResult.failure(_mapDioException(e));
    } on SocketException {
      return const ApiResult.failure(NetworkException());
    } catch (e) {
      return ApiResult.failure(
        ApiException(message: e.toString()),
      );
    }
  }

  /// Maps a [DioException] to the appropriate [ApiException] subtype.
  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();

      case DioExceptionType.connectionError:
        return const NetworkException();

      case DioExceptionType.badResponse:
        return _mapStatusCode(
          e.response?.statusCode,
          e.response?.data,
        );

      case DioExceptionType.cancel:
        return const ApiException(message: 'Request was cancelled.');

      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'SSL certificate verification failed.',
        );

      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const NetworkException();
        }
        return ApiException(
          message: e.message ?? 'An unexpected error occurred.',
        );
    }
  }

  /// Converts an HTTP status code to a typed [ApiException].
  ApiException _mapStatusCode(int? statusCode, dynamic data) {
    switch (statusCode) {
      case 400:
      case 422:
        return ValidationException(
          message: _extractMessage(data) ?? 'Validation failed.',
          statusCode: statusCode,
          data: data,
          fieldErrors: _extractFieldErrors(data),
        );

      case 401:
        return UnauthorizedException(
          message: _extractMessage(data) ?? 'Unauthorized.',
          data: data,
        );

      case 403:
        return ApiException(
          message: _extractMessage(data) ?? 'Access denied.',
          statusCode: 403,
          data: data,
        );

      case 404:
        return NotFoundException(
          message: _extractMessage(data) ?? 'Resource not found.',
          data: data,
        );

      case 409:
        return ApiException(
          message: _extractMessage(data) ?? 'Conflict.',
          statusCode: 409,
          data: data,
        );

      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: _extractMessage(data) ?? 'Server error.',
            statusCode: statusCode,
            data: data,
          );
        }
        return ApiException(
          message: _extractMessage(data) ?? 'Something went wrong.',
          statusCode: statusCode,
          data: data,
        );
    }
  }

  /// Tries to pull a human-readable message from the response body.
  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ??
          data['error'] as String? ??
          data['title'] as String?;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  /// Extracts a map of field-level errors from a validation response.
  ///
  /// Supports common shapes:
  /// ```json
  /// { "errors": { "field": ["msg"] } }
  /// { "errors": [ { "field": "name", "message": "..." } ] }
  /// ```
  Map<String, List<String>> _extractFieldErrors(dynamic data) {
    if (data is! Map<String, dynamic>) return {};

    final errors = data['errors'];

    // Shape: { "errors": { "field": ["msg1", "msg2"] } }
    if (errors is Map<String, dynamic>) {
      return errors.map((key, value) {
        if (value is List) {
          return MapEntry(key, value.map((e) => e.toString()).toList());
        }
        return MapEntry(key, [value.toString()]);
      });
    }

    // Shape: { "errors": [ { "field": "name", "message": "..." } ] }
    if (errors is List) {
      final Map<String, List<String>> fieldMap = {};
      for (final item in errors) {
        if (item is Map<String, dynamic>) {
          final field = item['field']?.toString() ?? 'general';
          final msg = item['message']?.toString() ?? 'Invalid value';
          fieldMap.putIfAbsent(field, () => []).add(msg);
        }
      }
      return fieldMap;
    }

    return {};
  }
}

/// Riverpod provider for [DioClient].
///
/// Depends on [secureStorageProvider] to supply the token storage.
final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return DioClient(storageService: storage);
});
