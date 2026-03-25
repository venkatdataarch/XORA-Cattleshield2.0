import 'user_model.dart';

/// Possible authentication statuses for the app lifecycle.
enum AuthStatus {
  /// App has just started; auth status is unknown.
  initial,

  /// An auth operation (login, register, token check) is in progress.
  loading,

  /// User is authenticated and [AuthState.user] is available.
  authenticated,

  /// User is not authenticated (no token or token expired).
  unauthenticated,

  /// An error occurred during an auth operation.
  error,
}

/// Immutable state object representing the current authentication context.
class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.token,
    this.errorMessage,
  });

  /// Initial state when the app boots up.
  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        token = null,
        errorMessage = null;

  /// A loading state while an auth operation is underway.
  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        token = null,
        errorMessage = null;

  /// Successfully authenticated with the given [user] and [token].
  factory AuthState.authenticated({
    required AppUser user,
    required String token,
  }) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      token: token,
    );
  }

  /// Not authenticated (logged out or no stored credentials).
  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        token = null,
        errorMessage = null;

  /// An error occurred during authentication.
  factory AuthState.error(String message) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
    );
  }

  /// Returns a copy of this state with the given fields replaced.
  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Whether an auth operation is in progress.
  bool get isLoading => status == AuthStatus.loading;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          token == other.token &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, user, token, errorMessage);

  @override
  String toString() =>
      'AuthState(status: $status, user: ${user?.name}, hasToken: ${token != null})';
}
