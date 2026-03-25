import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/empty_state_widget.dart';
import '../../domain/claim_model.dart';
import '../providers/claim_provider.dart';
import '../widgets/claim_status_badge.dart';

/// Screen showing all claims with tab-based status filtering.
class ClaimListScreen extends ConsumerStatefulWidget {
  const ClaimListScreen({super.key});

  @override
  ConsumerState<ClaimListScreen> createState() => _ClaimListScreenState();
}

class _ClaimListScreenState extends ConsumerState<ClaimListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Tab definitions mapping labels to optional status filters.
  static const _tabs = <({String label, List<ClaimStatus>? statuses})>[
    (label: 'All', statuses: null),
    (label: 'Pending', statuses: [ClaimStatus.submitted]),
    (label: 'Under Review', statuses: [ClaimStatus.vetReview, ClaimStatus.vetApproved, ClaimStatus.uiicProcessing]),
    (label: 'Settled', statuses: [ClaimStatus.settled]),
    (label: 'Rejected', statuses: [ClaimStatus.vetRejected, ClaimStatus.repudiated]),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    Future.microtask(() {
      ref.read(claimListProvider.notifier).loadClaims();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Use null filter for "All", first status for other tabs.
      final statuses = _tabs[_tabController.index].statuses;
      ref.read(claimListProvider.notifier).setFilter(
            statuses?.first,
          );
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(claimListProvider.notifier).loadClaims();
  }

  /// Filter claims for the current tab (supports multi-status tabs).
  List<ClaimModel> _getFilteredClaims(ClaimListState state) {
    final all = state.claims.valueOrNull ?? [];
    final tabIndex = _tabController.index;
    final statuses = _tabs[tabIndex].statuses;
    if (statuses == null) return all;
    return all.where((c) => statuses.contains(c.status)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claims'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: state.claims.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: _onRefresh,
        ),
        data: (_) => _buildList(state),
      ),
    );
  }

  Widget _buildList(ClaimListState state) {
    final claims = _getFilteredClaims(state);

    if (claims.isEmpty) {
      final tabLabel = _tabs[_tabController.index].label;
      return EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: tabLabel == 'All' ? 'No claims yet' : 'No $tabLabel claims',
        subtitle: 'File a claim from an active policy\nwhen needed.',
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: claims.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          return _ClaimCard(
            claim: claims[index],
            onTap: () {
              ref.read(selectedClaimProvider.notifier).state = claims[index];
              context.push('/farmer/claims/${claims[index].id}');
            },
          );
        },
      ),
    );
  }
}

/// Card widget displaying a claim summary.
class _ClaimCard extends StatelessWidget {
  final ClaimModel claim;
  final VoidCallback? onTap;

  const _ClaimCard({
    required this.claim,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Animal name + status badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.animalName ?? 'Animal #${claim.animalId}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          claim.claimNumber.isNotEmpty
                              ? claim.claimNumber
                              : 'Claim #${claim.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ClaimStatusBadge(status: claim.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.sm),
              // Details row
              Row(
                children: [
                  // Claim type
                  ClaimTypeBadge(type: claim.type),
                  const Spacer(),
                  // AI score
                  if (claim.aiMuzzleMatchScore != null) ...[
                    _AiScoreChip(score: claim.aiMuzzleMatchScore!),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Date
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: dateFormat.format(claim.createdAt),
                  ),
                ],
              ),
              // Settlement info
              if (claim.isSettled && claim.settlementAmount != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.paid, size: 14, color: Colors.teal),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Settled: ${NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0).format(claim.settlementAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AiScoreChip extends StatelessWidget {
  final double score;

  const _AiScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).round();
    final color = percentage >= 80
        ? AppColors.success
        : percentage >= 50
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
