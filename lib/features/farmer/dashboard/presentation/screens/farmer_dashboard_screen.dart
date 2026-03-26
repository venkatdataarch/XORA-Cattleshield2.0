import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../data/farmer_dashboard_repository.dart';
import '../widgets/quick_action_grid.dart';

/// The main dashboard screen for farmers.
///
/// Displays a welcome header, stats row, quick actions grid,
/// and recent activity section with pull-to-refresh support.
class FarmerDashboardScreen extends ConsumerStatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  ConsumerState<FarmerDashboardScreen> createState() =>
      _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends ConsumerState<FarmerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh user profile on dashboard load.
    Future.microtask(() {
      ref.read(authProvider.notifier).refreshUser();
    });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(farmerDashboardStatsProvider);
    await ref.read(farmerDashboardStatsProvider.future).catchError((_) => DashboardStats());
    ref.read(authProvider.notifier).refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(farmerDashboardStatsProvider);
    final userName = authState.user?.name ?? 'Farmer';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        title: const Text('CattleShield'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Notifications - future feature
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              _WelcomeHeader(userName: userName),

              Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    statsAsync.when(
                      data: (stats) => _StatsRow(stats: stats),
                      loading: () => const _StatsRowShimmer(),
                      error: (_, __) => _StatsRow(
                        stats: const DashboardStats(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Quick actions
                    QuickActionGrid(
                      actions: [
                        QuickAction(
                          icon: Icons.add_circle_outline,
                          label: 'Register Animal',
                          onTap: () => context.push('/farmer/animals/onboard'),
                        ),
                        QuickAction(
                          icon: Icons.description_outlined,
                          label: 'New Proposal',
                          onTap: () => context.push('/farmer/proposals/new'),
                        ),
                        QuickAction(
                          icon: Icons.report_outlined,
                          label: 'File Claim',
                          onTap: () => context.push('/farmer/claims/new'),
                        ),
                        QuickAction(
                          icon: Icons.qr_code_scanner,
                          label: 'Identify Animal',
                          onTap: () => context.push('/scan/muzzle-identify'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Recent activity
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RecentActivityList(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      elevation: 8,
      onTap: (index) {
        switch (index) {
          case 0:
            break; // Already on dashboard
          case 1:
            context.push('/farmer/animals');
            break;
          case 2:
            context.push('/farmer/policies');
            break;
          case 3:
            context.push('/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pets_outlined),
          activeIcon: Icon(Icons.pets),
          label: 'Animals',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.policy_outlined),
          activeIcon: Icon(Icons.policy),
          label: 'Policies',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

/// Welcome banner at the top of the dashboard.
class _WelcomeHeader extends StatelessWidget {
  final String userName;

  const _WelcomeHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = userName.split(' ').first;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            firstName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of stat cards showing key metrics.
class _StatsRow extends StatelessWidget {
  final DashboardStats stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Active Policies',
            value: stats.activePolicies.toString(),
            icon: Icons.verified_outlined,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Pending Claims',
            value: stats.pendingClaims.toString(),
            icon: Icons.pending_actions,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Animals',
            value: stats.totalAnimals.toString(),
            icon: Icons.pets,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Individual stat card in the stats row.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for stats row while loading.
class _StatsRowShimmer extends StatelessWidget {
  const _StatsRowShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            height: 90,
            margin: EdgeInsets.only(
              left: index > 0 ? AppSpacing.sm : 0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Placeholder list for recent activity.
class _RecentActivityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activities = [
      _ActivityItem(
        icon: Icons.add_circle,
        color: AppColors.success,
        title: 'Animal Registered',
        subtitle: 'Gir Cow - HF-0042 registered successfully',
        time: '2 hours ago',
      ),
      _ActivityItem(
        icon: Icons.description,
        color: AppColors.info,
        title: 'Proposal Submitted',
        subtitle: 'Insurance proposal for Buffalo - BF-0015',
        time: '1 day ago',
      ),
      _ActivityItem(
        icon: Icons.verified,
        color: AppColors.primary,
        title: 'Policy Issued',
        subtitle: 'Policy POL-2024-0089 is now active',
        time: '3 days ago',
      ),
    ];

    return Column(
      children: activities.map((activity) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activity.color.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Icon(
                  activity.icon,
                  color: activity.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                activity.time,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
