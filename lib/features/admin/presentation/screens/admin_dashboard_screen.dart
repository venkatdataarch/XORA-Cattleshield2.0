import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';

// ---------------------------------------------------------------------------
// Admin dashboard stats model & provider
// ---------------------------------------------------------------------------

class AdminDashboardStats {
  final int totalAnimals;
  final int activePolicies;
  final int pendingApprovals;
  final int fraudAlerts;

  const AdminDashboardStats({
    this.totalAnimals = 0,
    this.activePolicies = 0,
    this.pendingApprovals = 0,
    this.fraudAlerts = 0,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalAnimals: _parseInt(json['totalAnimals'] ?? json['total_animals']),
      activePolicies: _parseInt(json['activePolicies'] ?? json['active_policies']),
      pendingApprovals: _parseInt(json['pendingApprovals'] ?? json['pending_approvals'] ?? json['pendingClaims'] ?? json['pending_claims']),
      fraudAlerts: _parseInt(json['fraudAlerts'] ?? json['fraud_alerts']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

final adminDashboardStatsProvider =
    FutureProvider.autoDispose<AdminDashboardStats>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.dashboardStats);
  return result.when(
    success: (response) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final statsData = (data['data'] as Map<String, dynamic>?) ??
            (data['stats'] as Map<String, dynamic>?) ??
            data;
        return AdminDashboardStats.fromJson(statsData);
      }
      return const AdminDashboardStats();
    },
    failure: (e) => throw Exception(e.message),
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UIIC Admin Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardStatsProvider);
          await ref.read(adminDashboardStatsProvider.future).catchError((_) => const AdminDashboardStats());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats cards row
              statsAsync.when(
                loading: () => const _StatsShimmer(),
                error: (err, _) => _buildStatsGrid(context, const AdminDashboardStats(), onPendingTap: () => context.go('/admin/pending-approvals')),
                data: (stats) => _buildStatsGrid(context, stats, onPendingTap: () => context.go('/admin/pending-approvals')),
              ),

              const SizedBox(height: 24),

              // Quick actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              _ActionTile(
                icon: Icons.approval,
                title: 'Pending Approvals',
                subtitle: 'Review vet-approved proposals for final decision',
                onTap: () => context.go('/admin/pending-approvals'),
              ),
              _ActionTile(
                icon: Icons.history,
                title: 'Audit Trail',
                subtitle: 'View immutable audit log of all system actions',
                onTap: () => context.go('/admin/audit-logs'),
              ),
              _ActionTile(
                icon: Icons.warning,
                title: 'Fraud Alerts',
                subtitle: 'Review and resolve fraud detection alerts',
                onTap: () => context.go('/admin/fraud-alerts'),
              ),
              _ActionTile(
                icon: Icons.people,
                title: 'User Management',
                subtitle: 'Manage farmers, vets, agents, and admins',
                onTap: () {},
              ),
              _ActionTile(
                icon: Icons.map,
                title: 'GPS Map View',
                subtitle: 'View proposal/claim locations on map',
                onTap: () {},
              ),
              _ActionTile(
                icon: Icons.analytics,
                title: 'MIS Reports',
                subtitle: 'Generate and view management reports',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, AdminDashboardStats stats, {VoidCallback? onPendingTap}) {
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              title: 'Total Animals',
              value: stats.totalAnimals.toString(),
              icon: Icons.pets,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            _StatCard(
              title: 'Active Policies',
              value: stats.activePolicies.toString(),
              icon: Icons.policy,
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              title: 'Pending Approvals',
              value: stats.pendingApprovals.toString(),
              icon: Icons.assignment,
              color: Colors.orange,
              onTap: onPendingTap,
            ),
            const SizedBox(width: 12),
            _StatCard(
              title: 'Fraud Alerts',
              value: stats.fraudAlerts.toString(),
              icon: Icons.warning_amber,
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Container(width: 80, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Container(width: 80, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Container(width: 80, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Container(width: 80, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
