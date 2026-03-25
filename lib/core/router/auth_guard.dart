import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/domain/user_model.dart';

/// Evaluates redirect logic for [GoRouter] based on the current [AuthState].
///
/// Returns the path to redirect to, or `null` if no redirect is needed.
class AuthGuard {
  const AuthGuard._();

  /// Determines whether the user should be redirected based on auth state
  /// and the requested [location].
  ///
  /// Returns a redirect path, or `null` to allow navigation.
  static String? redirect(AuthState authState, String location) {
    final isAuthenticated = authState.isAuthenticated;
    final isLoading = authState.isLoading;
    final isInitial = authState.status == AuthStatus.initial;

    // While auth status is being determined, stay on splash.
    if (isInitial || isLoading) {
      if (location == '/splash') return null;
      return '/splash';
    }

    // Unauthenticated users can only access auth routes.
    final isAuthRoute = _isAuthRoute(location);
    if (!isAuthenticated) {
      if (isAuthRoute) return null;
      return '/login';
    }

    // Authenticated users trying to access auth routes -> redirect to dashboard.
    if (isAuthRoute && location != '/splash') {
      return _dashboardForRole(authState.user?.role);
    }

    // Role-based path guards.
    final role = authState.user?.role;

    // Farmers cannot access vet routes.
    if (role == UserRole.farmer && location.startsWith('/vet')) {
      return '/farmer';
    }

    // Vets cannot access farmer routes.
    if (role == UserRole.vet && location.startsWith('/farmer')) {
      return '/vet';
    }

    // Scan routes are accessible to all authenticated users.
    // No redirect needed.

    return null;
  }

  /// Returns `true` if [location] is an authentication-related route.
  static bool _isAuthRoute(String location) {
    return location == '/splash' ||
        location == '/login' ||
        location.startsWith('/login/') ||
        location.startsWith('/register/');
  }

  /// Returns the dashboard path for the given [role].
  static String _dashboardForRole(UserRole? role) {
    switch (role) {
      case UserRole.vet:
        return '/vet';
      case UserRole.agent:
      case UserRole.admin:
        return '/farmer'; // agents/admins share the farmer dashboard for now
      case UserRole.farmer:
      case null:
        return '/farmer';
    }
  }
}
