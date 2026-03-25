import 'api_exception.dart';

/// A sealed union representing the outcome of an API call.
///
/// Use [when] or [maybeWhen] for exhaustive / partial pattern matching:
/// ```dart
/// final result = await dioClient.get('/endpoint');
/// result.when(
///   success: (data) => print(data),
///   failure: (error) => print(error.message),
/// );
/// ```
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.failure(ApiException error) = ApiFailure<T>;

  /// Exhaustive pattern match -- both branches are required.
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  });

  /// Partial pattern match with a required [orElse] fallback.
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(ApiException error)? failure,
    required R Function() orElse,
  });

  /// Returns `true` when this result is [ApiSuccess].
  bool get isSuccess => this is ApiSuccess<T>;

  /// Returns `true` when this result is [ApiFailure].
  bool get isFailure => this is ApiFailure<T>;

  /// Returns the success data or `null`.
  T? get dataOrNull => switch (this) {
        ApiSuccess<T>(data: final d) => d,
        ApiFailure<T>() => null,
      };

  /// Returns the error or `null`.
  ApiException? get errorOrNull => switch (this) {
        ApiSuccess<T>() => null,
        ApiFailure<T>(error: final e) => e,
      };
}

/// Successful API result containing [data].
final class ApiSuccess<T> extends ApiResult<T> {
  final T data;

  const ApiSuccess(this.data);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) =>
      success(data);

  @override
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(ApiException error)? failure,
    required R Function() orElse,
  }) =>
      success != null ? success(data) : orElse();

  @override
  String toString() => 'ApiSuccess($data)';
}

/// Failed API result containing an [error].
final class ApiFailure<T> extends ApiResult<T> {
  final ApiException error;

  const ApiFailure(this.error);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) =>
      failure(error);

  @override
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(ApiException error)? failure,
    required R Function() orElse,
  }) =>
      failure != null ? failure(error) : orElse();

  @override
  String toString() => 'ApiFailure($error)';
}
