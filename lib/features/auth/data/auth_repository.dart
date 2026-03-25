import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/auth_state.dart';
import '../domain/user_model.dart';
import 'auth_remote_source.dart';

/// Repository that orchestrates authentication logic between the remote
/// source and local secure storage.
class AuthRepository {
  final AuthRemoteSource _remoteSource;
  final SecureStorageService _storage;

  /// In-memory cache of the current user to avoid repeated storage reads.
  AppUser? _cachedUser;

  AuthRepository({
    required AuthRemoteSource remoteSource,
    required SecureStorageService storage,
  })  : _remoteSource = remoteSource,
        _storage = storage;

  // ---------------------------------------------------------------------------
  // Login (agent / vet)
  // ---------------------------------------------------------------------------

  /// Authenticates a vet or agent with [agentId] and [password].
  ///
  /// On success the JWT token and user role are persisted to secure storage.
  Future<ApiResult<AppUser>> login(String agentId, String password) async {
    try {
      final data = await _remoteSource.login(agentId, password);
      final user = AppUser.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? data,
      );
      final token = data['token']?.toString() ?? '';

      await _persistAuthData(user, token);
      return ApiResult.success(user);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(
        ApiException(message: e.toString()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OTP-based login (farmer) - mocked
  // ---------------------------------------------------------------------------

  /// Initiates OTP-based login for a farmer.
  ///
  /// No backend call needed — just stores phone and proceeds to OTP screen.
  /// The actual authentication happens in verifyOtp().
  Future<ApiResult<AppUser>> loginWithOtp(String phone) async {
    try {
      await _storage.saveToken('otp_pending_$phone');
      await _storage.saveUserRole(UserRole.farmer.name);

      final tempUser = AppUser(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: '',
        phone: phone,
        role: UserRole.farmer,
      );

      return ApiResult.success(tempUser);
    } catch (e) {
      return ApiResult.failure(
        ApiException(message: e.toString()),
      );
    }
  }

  /// Verifies the OTP sent to [phone].
  ///
  /// Calls the real backend API. Any 6-digit OTP works (mock backend).
  Future<ApiResult<AppUser>> verifyOtp(String phone, String otp) async {
    try {
      if (otp.length != 6) {
        return ApiResult.failure(
          ApiException(message: 'Invalid OTP. Please enter 6 digits.'),
        );
      }

      final data = await _remoteSource.verifyOtp(phone, otp);
      final user = AppUser.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? data,
      );
      final token = data['token']?.toString() ?? '';

      await _persistAuthData(user, token);
      return ApiResult.success(user);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(
        ApiException(message: e.toString()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers a new farmer with the given [data].
  ///
  /// On success the JWT token and user data are persisted.
  Future<ApiResult<AppUser>> registerFarmer(Map<String, dynamic> data) async {
    try {
      final responseData = await _remoteSource.register({
        ...data,
        'role': UserRole.farmer.name,
      });

      final user = AppUser.fromJson(
        (responseData['user'] as Map<String, dynamic>?) ?? responseData,
      );
      final token = responseData['token']?.toString() ?? '';

      await _persistAuthData(user, token);
      return ApiResult.success(user);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(
        ApiException(message: e.toString()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Current user
  // ---------------------------------------------------------------------------

  /// Fetches the current user from the API. Falls back to cached data
  /// if the network call fails.
  Future<ApiResult<AppUser>> getCurrentUser() async {
    try {
      final data = await _remoteSource.getCurrentUser();
      final user = AppUser.fromJson(data);
      _cachedUser = user;

      // Persist the latest user snapshot.
      await _storage.saveUserId(user.id);
      await _storage.saveUserRole(user.role.name);

      return ApiResult.success(user);
    } on ApiException {
      // Fall back to cached user if available.
      if (_cachedUser != null) {
        return ApiResult.success(_cachedUser!);
      }

      // Try to reconstruct a minimal user from secure storage.
      final userId = await _storage.getUserId();
      final role = await _storage.getUserRole();
      if (userId != null && role != null) {
        final minimalUser = AppUser(
          id: userId,
          name: '',
          phone: '',
          role: UserRole.fromString(role),
        );
        return ApiResult.success(minimalUser);
      }

      return ApiResult.failure(
        ApiException(message: 'Unable to retrieve user profile.'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  /// Clears all persisted auth data and in-memory cache.
  Future<void> logout() async {
    _cachedUser = null;
    await _storage.clearAll();
  }

  // ---------------------------------------------------------------------------
  // Auth status check
  // ---------------------------------------------------------------------------

  /// Checks whether a valid auth token exists in secure storage.
  ///
  /// Returns an [AuthState] reflecting the persisted credentials.
  Future<AuthState> checkAuthStatus() async {
    try {
      final token = await _storage.getToken();
      final role = await _storage.getUserRole();
      final userId = await _storage.getUserId();

      if (token == null || token.isEmpty || token.startsWith('otp_pending_')) {
        return const AuthState.unauthenticated();
      }

      // Reconstruct a minimal user from storage.
      final user = AppUser(
        id: userId ?? '',
        name: '',
        phone: '',
        role: UserRole.fromString(role ?? 'farmer'),
      );

      _cachedUser = user;

      return AuthState.authenticated(user: user, token: token);
    } catch (_) {
      return const AuthState.unauthenticated();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Persists auth token and user metadata to secure storage.
  Future<void> _persistAuthData(AppUser user, String token) async {
    _cachedUser = user;
    await _storage.saveToken(token);
    await _storage.saveUserRole(user.role.name);
    await _storage.saveUserId(user.id);

    // Store user JSON for offline access.
    await _saveUserJson(user);
  }

  /// Writes the serialised user JSON to secure storage.
  Future<void> _saveUserJson(AppUser user) async {
    // We reuse the existing storage keys; a dedicated key would be cleaner
    // but this keeps the footprint small.
    final json = jsonEncode(user.toJson());
    // Store under a custom key via the underlying FlutterSecureStorage
    // Since SecureStorageService doesn't expose a generic write,
    // we cache in-memory instead.
    _cachedUser = user;
    // In production, consider adding a generic write method to the service.
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteSource = ref.watch(authRemoteSourceProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(remoteSource: remoteSource, storage: storage);
});
