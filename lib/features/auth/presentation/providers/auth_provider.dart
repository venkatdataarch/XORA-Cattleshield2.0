import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart';

/// Manages the global authentication state via [StateNotifier].
///
/// All auth-related UI actions (login, register, logout) should go through
/// this notifier so that the rest of the app reacts to state changes.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState.initial());

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Checks persisted credentials on app start and updates state accordingly.
  Future<void> checkAuth() async {
    state = const AuthState.loading();
    final authState = await _repository.checkAuthStatus();
    state = authState;
  }

  /// Authenticates a vet or agent with [agentId] and [password].
  Future<void> login(String agentId, String password) async {
    state = const AuthState.loading();

    final result = await _repository.login(agentId, password);

    state = result.when(
      success: (user) => AuthState.authenticated(
        user: user,
        token: '', // token is stored in secure storage
      ),
      failure: (error) => AuthState.error(error.message),
    );
  }

  /// Sends an OTP to the farmer's [phone] number.
  ///
  /// Does NOT change auth state to avoid triggering router redirects.
  /// The actual auth state change happens in verifyOtp().
  Future<bool> loginWithOtp(String phone) async {
    final result = await _repository.loginWithOtp(phone);

    return result.when(
      success: (_) => true,
      failure: (error) {
        state = AuthState.error(error.message);
        return false;
      },
    );
  }

  /// Verifies the OTP sent to [phone].
  ///
  /// On success, navigates to registration if the user has no name,
  /// otherwise marks as authenticated.
  Future<bool> verifyOtp(String phone, String otp) async {
    state = const AuthState.loading();

    final result = await _repository.verifyOtp(phone, otp);

    return result.when(
      success: (user) {
        if (user.name.isEmpty) {
          // User needs to complete registration.
          state = AuthState.authenticated(
            user: user,
            token: 'pending_registration',
          );
        } else {
          state = AuthState.authenticated(user: user, token: '');
        }
        return true;
      },
      failure: (error) {
        state = AuthState.error(error.message);
        return false;
      },
    );
  }

  /// Registers a new farmer with the provided [data].
  Future<bool> registerFarmer(Map<String, dynamic> data) async {
    state = const AuthState.loading();

    final result = await _repository.registerFarmer(data);

    return result.when(
      success: (user) {
        state = AuthState.authenticated(user: user, token: '');
        return true;
      },
      failure: (error) {
        state = AuthState.error(error.message);
        return false;
      },
    );
  }

  /// Registers a new field agent.
  Future<bool> registerAgent({
    required String name,
    required String phone,
    String? email,
    required String agentId,
    required String password,
    required String address,
    required String village,
    required String district,
    required String state,
    String? aadhaarNumber,
  }) async {
    this.state = const AuthState.loading();

    final data = {
      'name': name,
      'phone': phone,
      'email': email,
      'role': 'agent',
      'address': address,
      'village': village,
      'district': district,
      'state': state,
      'aadhaar_number': aadhaarNumber,
      'agent_id': agentId,
      'password': password,
    };

    final result = await _repository.registerFarmer(data);

    return result.when(
      success: (user) {
        this.state = const AuthState.unauthenticated();
        return true;
      },
      failure: (error) {
        this.state = AuthState.error(error.message);
        return false;
      },
    );
  }

  /// Signs out the current user and clears all stored credentials.
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.unauthenticated();
  }

  /// Refreshes the current user profile from the API.
  Future<void> refreshUser() async {
    final result = await _repository.getCurrentUser();

    result.when(
      success: (user) {
        if (state.isAuthenticated) {
          state = state.copyWith(user: user);
        }
      },
      failure: (_) {
        // Silently ignore refresh failures.
      },
    );
  }

  /// Clears any error message and returns to the unauthenticated state.
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }
}

/// Global auth state provider.
///
/// Usage:
/// ```dart
/// final authState = ref.watch(authProvider);
/// final authNotifier = ref.read(authProvider.notifier);
/// ```
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository: repository);
});
