/// Exception hierarchy for API error handling in CattleShield 2.0.
///
/// All API errors are represented as subtypes of [ApiException],
/// enabling exhaustive pattern matching in error handlers.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when the device has no internet connectivity.
class NetworkException extends ApiException {
  const NetworkException({
    super.message = 'No internet connection. Please check your network.',
    super.statusCode,
    super.data,
  });

  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown when a request exceeds the configured timeout duration.
class TimeoutException extends ApiException {
  const TimeoutException({
    super.message = 'Request timed out. Please try again.',
    super.statusCode,
    super.data,
  });

  @override
  String toString() => 'TimeoutException: $message';
}

/// Thrown on HTTP 401 responses, indicating invalid or expired credentials.
class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = 'Session expired. Please log in again.',
    super.statusCode = 401,
    super.data,
  });

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Thrown on HTTP 5xx responses, indicating a server-side failure.
class ServerException extends ApiException {
  const ServerException({
    super.message = 'Server error. Please try again later.',
    super.statusCode,
    super.data,
  });

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown on HTTP 400 or 422 responses that include field-level validation errors.
class ValidationException extends ApiException {
  /// Map of field names to their validation error messages.
  final Map<String, List<String>> fieldErrors;

  const ValidationException({
    super.message = 'Validation failed. Please check your input.',
    super.statusCode,
    super.data,
    this.fieldErrors = const {},
  });

  /// Returns a flat list of all validation error messages.
  List<String> get allErrors =>
      fieldErrors.values.expand((errors) => errors).toList();

  /// Returns the first error for a given [field], or null if none.
  String? errorForField(String field) {
    final errors = fieldErrors[field];
    return (errors != null && errors.isNotEmpty) ? errors.first : null;
  }

  @override
  String toString() => 'ValidationException($statusCode): $message | $fieldErrors';
}

/// Thrown on HTTP 404 responses when the requested resource does not exist.
class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = 'Resource not found.',
    super.statusCode = 404,
    super.data,
  });

  @override
  String toString() => 'NotFoundException: $message';
}
