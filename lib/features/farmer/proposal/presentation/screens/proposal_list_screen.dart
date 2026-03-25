import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/empty_state_widget.dart';
import '../../domain/proposal_model.dart';
import '../providers/proposal_provider.dart';
import '../widgets/proposal_status_badge.dart';

/// Screen showing all proposals with tab-based status filtering.
class ProposalListScreen extends ConsumerStatefulWidget {
  const ProposalListScreen({super.key});

  @override
  ConsumerState<ProposalListScreen> createState() => _ProposalListScreenState();
}

class _ProposalListScreenState extends ConsumerState<ProposalListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Tab definitions with optional status filter.
  static const _tabs = <({String label, ProposalStatus? status})>[
    (label: 'All', status: null),
    (label: 'Draft', status: ProposalStatus.draft),
    (label: 'Submitted', status: ProposalStatus.submitted),
    (label: 'Approved', status: ProposalStatus.vetApproved),
    (label: 'Rejected', status: ProposalStatus.vetRejected),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Load proposals on first build.
    Future.microtask(() {
      ref.read(proposalListProvider.notifier).loadProposals();
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
      final status = _tabs[_tabController.index].status;
      ref.read(proposalListProvider.notifier).setFilter(status);
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(proposalListProvider.notifier).loadProposals();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(proposalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposals'),
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
      body: state.proposals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: _onRefresh,
        ),
        data: (_) => _buildList(state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farmer/animals/select-for-proposal'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Proposal'),
      ),
    );
  }

  Widget _buildList(ProposalListState state) {
    final proposals = state.filteredProposals;

    if (proposals.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.description_outlined,
        title: state.filterStatus != null
            ? 'No ${state.filterStatus!.label} proposals'
            : 'No proposals yet',
        subtitle: 'Create a new insurance proposal\nfor your registered animal.',
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: proposals.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          return _ProposalCard(
            proposal: proposals[index],
            onTap: () {
              ref.read(selectedProposalProvider.notifier).state =
                  proposals[index];
              context.push('/farmer/proposals/${proposals[index].id}');
            },
          );
        },
      ),
    );
  }
}

/// Card widget displaying a proposal summary.
class _ProposalCard extends StatelessWidget {
  final ProposalModel proposal;
  final VoidCallback? onTap;

  const _ProposalCard({
    required this.proposal,
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
                    child: Text(
                      proposal.animalName ?? 'Animal #${proposal.animalId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ProposalStatusBadge(status: proposal.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.sm),
              // Details row
              Row(
                children: [
                  // Date
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: dateFormat.format(proposal.createdAt),
                  ),
                  const Spacer(),
                  // Sum insured
                  if (proposal.sumInsured != null)
                    _InfoChip(
                      icon: Icons.currency_rupee,
                      label: NumberFormat.compact().format(proposal.sumInsured),
                    ),
                ],
              ),
              // Rejection reason
              if (proposal.status == ProposalStatus.vetRejected &&
                  proposal.rejectionReason != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.error),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          proposal.rejectionReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
