import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/dio_client.dart';

/// Aggregated dashboard statistics for a farmer.
class DashboardStats {
  final int activePolicies;
  final int expiringPolicies;
  final int expiredPolicies;
  final int totalAnimals;
  final int pendingClaims;

  const DashboardStats({
    this.activePolicies = 0,
    this.expiringPolicies = 0,
    this.expiredPolicies = 0,
    this.totalAnimals = 0,
    this.pendingClaims = 0,
  });

  /// Total number of policies across all statuses.
  int get totalPolicies => activePolicies + expiringPolicies + expiredPolicies;

  /// Deserialises from JSON.
  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      activePolicies: _parseInt(json['activePolicies'] ?? json['active_policies']),
      expiringPolicies:
          _parseInt(json['expiringPolicies'] ?? json['expiring_policies']),
      expiredPolicies:
          _parseInt(json['expiredPolicies'] ?? json['expired_policies']),
      totalAnimals: _parseInt(json['totalAnimals'] ?? json['total_animals']),
      pendingClaims: _parseInt(json['pendingClaims'] ?? json['pending_claims']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

/// Repository for fetching farmer dashboard data.
class FarmerDashboardRepository {
  final DioClient _client;

  FarmerDashboardRepository({required DioClient client}) : _client = client;

  /// Fetches aggregated statistics for the farmer dashboard.
  Future<ApiResult<DashboardStats>> getDashboardStats() async {
    try {
      final result = await _client.get(ApiEndpoints.dashboardStats);

      return result.when(
        success: (Response response) {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final statsData = (data['data'] as Map<String, dynamic>?) ??
                (data['stats'] as Map<String, dynamic>?) ??
                data;
            return ApiResult.success(DashboardStats.fromJson(statsData));
          }
          return const ApiResult.success(DashboardStats());
        },
        failure: (error) => ApiResult.failure(error),
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }
}

/// Riverpod provider for [FarmerDashboardRepository].
final farmerDashboardRepositoryProvider =
    Provider<FarmerDashboardRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return FarmerDashboardRepository(client: client);
});

/// Provider that exposes the dashboard stats as an async value.
final farmerDashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  final repository = ref.watch(farmerDashboardRepositoryProvider);
  final result = await repository.getDashboardStats();

  return result.when(
    success: (stats) => stats,
    failure: (error) => throw error,
  );
});
