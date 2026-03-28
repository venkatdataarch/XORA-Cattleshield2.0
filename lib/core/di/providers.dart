/// Central dependency-injection barrel file for CattleShield 2.0.
///
/// Re-exports all core Riverpod providers so feature modules only need a
/// single import:
/// ```dart
/// import 'package:cattleshield/core/di/providers.dart';
/// ```
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Re-export providers defined alongside their services.
export '../network/dio_client.dart' show dioClientProvider;
export '../storage/local_db_service.dart' show localDbProvider;
export '../storage/secure_storage_service.dart' show secureStorageProvider;

/// Emits connectivity change events via [Connectivity.onConnectivityChanged].
///
/// Usage:
/// ```dart
/// ref.watch(connectivityProvider).when(
///   data: (results) {
///     final isOffline = results.contains(ConnectivityResult.none);
///   },
///   ...
/// );
/// ```
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});
