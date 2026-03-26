import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/domain/user_model.dart';

/// Evaluates redirect logic for [GoRouter] based on the current [AuthState].
class AuthGuard {
  const AuthGuard._();

  /// Returns a redirect path, or `null` to allow navigation.
  static String? redirect(AuthState authState, String location) {
    final isAuthenticated = authState.isAuthenticated;
    final isLoading = authState.isLoading;
    final isInitial = authState.status == AuthStatus.initial;

    // Never redirect while on splash — splash handles its own navigation.
    if (location == '/splash') return null;

    // During initial/loading states, don't redirect (avoid loops).
    if (isInitial || isLoading) return null;

    final isAuthRoute = _isAuthRoute(location);

    // Unauthenticated users can only access auth routes.
    if (!isAuthenticated) {
      if (isAuthRoute) return null;
      return '/login';
    }

    // Authenticated users on login page → go to dashboard.
    // But allow OTP and registration routes (user might be mid-flow).
    if (location == '/login') {
      return _dashboardForRole(authState.user?.role);
    }

    // Role-based path guards.
    final role = authState.user?.role;
    if (role == UserRole.farmer && (location.startsWith('/vet') || location.startsWith('/admin'))) {
      return '/farmer';
    }
    if (role == UserRole.vet && (location.startsWith('/farmer') || location.startsWith('/admin'))) {
      return '/vet';
    }
    if (role == UserRole.admin && (location.startsWith('/farmer') || location.startsWith('/vet'))) {
      return '/admin';
    }
    // Agents can access farmer routes
    if (role == UserRole.agent && location.startsWith('/vet')) {
      return '/farmer';
    }

    return null;
  }

  static bool _isAuthRoute(String location) {
    return location == '/splash' ||
        location == '/login' ||
        location.startsWith('/login/') ||
        location.startsWith('/register/');
  }

  static String _dashboardForRole(UserRole? role) {
    switch (role) {
      case UserRole.vet:
        return '/vet';
      case UserRole.admin:
        return '/admin';
      case UserRole.agent:
      case UserRole.farmer:
      case null:
        return '/farmer';
    }
  }
}
