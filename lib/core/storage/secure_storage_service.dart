import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used for secure storage entries.
abstract final class _StorageKeys {
  static const String authToken = 'auth_token';
  static const String userRole = 'user_role';
  static const String userId = 'user_id';
  static const String refreshToken = 'refresh_token';
}

/// Wrapper around [FlutterSecureStorage] providing typed access
/// to authentication tokens and user metadata.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  // ---------------------------------------------------------------------------
  // Auth token
  // ---------------------------------------------------------------------------

  /// Persists the JWT [token] to secure storage.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _StorageKeys.authToken, value: token);
  }

  /// Returns the stored JWT token, or `null` if none exists.
  Future<String?> getToken() async {
    return _storage.read(key: _StorageKeys.authToken);
  }

  /// Removes the stored JWT token.
  Future<void> deleteToken() async {
    await _storage.delete(key: _StorageKeys.authToken);
  }

  // ---------------------------------------------------------------------------
  // Refresh token
  // ---------------------------------------------------------------------------

  /// Persists the refresh [token] to secure storage.
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _StorageKeys.refreshToken, value: token);
  }

  /// Returns the stored refresh token, or `null` if none exists.
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _StorageKeys.refreshToken);
  }

  /// Removes the stored refresh token.
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _StorageKeys.refreshToken);
  }

  // ---------------------------------------------------------------------------
  // User role
  // ---------------------------------------------------------------------------

  /// Persists the user [role] (e.g. 'vet', 'agent', 'admin').
  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _StorageKeys.userRole, value: role);
  }

  /// Returns the stored user role, or `null` if none exists.
  Future<String?> getUserRole() async {
    return _storage.read(key: _StorageKeys.userRole);
  }

  // ---------------------------------------------------------------------------
  // User ID
  // ---------------------------------------------------------------------------

  /// Persists the user [id].
  Future<void> saveUserId(String id) async {
    await _storage.write(key: _StorageKeys.userId, value: id);
  }

  /// Returns the stored user ID, or `null` if none exists.
  Future<String?> getUserId() async {
    return _storage.read(key: _StorageKeys.userId);
  }

  // ---------------------------------------------------------------------------
  // Bulk operations
  // ---------------------------------------------------------------------------

  /// Deletes **all** entries from secure storage (logout scenario).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

/// Global Riverpod provider for [SecureStorageService].
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
