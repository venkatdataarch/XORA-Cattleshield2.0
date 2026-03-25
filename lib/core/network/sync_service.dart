import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../storage/local_db_service.dart';
import 'dio_client.dart';
import '../di/providers.dart';
import '../../shared/utils/logger.dart';

enum SyncStatus { idle, syncing, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncAt;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastError,
    this.lastSyncAt,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    String? lastError,
    DateTime? lastSyncAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError ?? this.lastError,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  final LocalDbService _db;
  final DioClient _dio;
  final Ref _ref;
  bool _isListening = false;

  SyncService(this._db, this._dio, this._ref) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    await _updatePendingCount();
    _startListening();
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;

    _ref.listen(connectivityProvider, (previous, next) {
      next.whenData((results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline && state.pendingCount > 0) {
          syncAll();
        }
      });
    });
  }

  Future<void> _updatePendingCount() async {
    final pending = await _db.getPendingQueueItems();
    state = state.copyWith(pendingCount: pending.length);
  }

  Future<void> syncAll() async {
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing);
    AppLogger.info('SyncService: Starting sync...');

    try {
      final pendingItems = await _db.getPendingQueueItems();

      for (final item in pendingItems) {
        await _syncItem(item);
      }

      await _updatePendingCount();
      state = state.copyWith(
        status: SyncStatus.idle,
        lastSyncAt: DateTime.now(),
        lastError: null,
      );
      AppLogger.info('SyncService: Sync complete.');
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastError: e.toString(),
      );
      AppLogger.error('SyncService: Sync failed', e);
    }
  }

  Future<void> _syncItem(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    final action = item['action'] as String;
    final endpoint = item['endpoint'] as String;
    final payload = jsonDecode(item['payload'] as String);
    final retryCount = item['retry_count'] as int? ?? 0;

    if (retryCount >= 5) {
      await _db.updateQueueItemStatus(id, 'failed');
      AppLogger.warning('SyncService: Item $id exceeded max retries');
      return;
    }

    try {
      await _db.updateQueueItemStatus(id, 'syncing');

      switch (action) {
        case 'POST':
          await _dio.post(endpoint, data: payload);
          break;
        case 'PUT':
          await _dio.put(endpoint, data: payload);
          break;
        case 'PATCH':
          await _dio.patch(endpoint, data: payload);
          break;
        default:
          await _dio.post(endpoint, data: payload);
      }

      await _db.updateQueueItemStatus(id, 'synced');
      AppLogger.info('SyncService: Synced item $id ($action $endpoint)');
    } catch (e) {
      await _db.incrementQueueItemRetry(id);
      AppLogger.error('SyncService: Failed to sync item $id', e);
    }
  }

  Future<void> addToQueue({
    required String action,
    required String endpoint,
    required Map<String, dynamic> payload,
    List<String>? imagePaths,
  }) async {
    await _db.addToQueue(
      action: action,
      endpoint: endpoint,
      payload: jsonEncode(payload),
      images: imagePaths != null ? jsonEncode(imagePaths) : null,
    );
    await _updatePendingCount();
  }

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>(
  (ref) {
    final db = ref.watch(localDbProvider);
    final dio = ref.watch(dioClientProvider);
    return SyncService(db, dio, ref);
  },
);
