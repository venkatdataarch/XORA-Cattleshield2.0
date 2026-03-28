import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Premium header with tabs
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Claims',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.white,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
                        unselectedLabelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500),
                        tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: state.claims.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  error: (error, _) => AppErrorWidget(
                    message: error.toString(),
                    onRetry: _onRefresh,
                  ),
                  data: (_) => _buildList(state),
                ),
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: claims.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ClaimStatusBadge(status: claim.status),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            // Details row
            Row(
              children: [
                ClaimTypeBadge(type: claim.type),
                const Spacer(),
                if (claim.aiMuzzleMatchScore != null) ...[
                  _AiScoreChip(score: claim.aiMuzzleMatchScore!),
                  const SizedBox(width: 8),
                ],
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: dateFormat.format(claim.createdAt),
                ),
              ],
            ),
            // Settlement info
            if (claim.isSettled && claim.settlementAmount != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.paid, size: 14, color: Colors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'Settled: ${NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0).format(claim.settlementAmount)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$percentage%',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
