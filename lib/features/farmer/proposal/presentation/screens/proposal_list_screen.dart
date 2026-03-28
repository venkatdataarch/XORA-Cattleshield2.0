import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
                          child: const Icon(Icons.description, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Proposals',
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
                child: state.proposals.when(
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/farmer/animals/select-for-proposal'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add),
          label: Text('New Proposal', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: proposals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    proposal.animalName ?? 'Animal #${proposal.animalId}',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ProposalStatusBadge(status: proposal.status),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: dateFormat.format(proposal.createdAt),
                ),
                const Spacer(),
                if (proposal.sumInsured != null)
                  _InfoChip(
                    icon: Icons.currency_rupee,
                    label: NumberFormat.compact().format(proposal.sumInsured),
                  ),
              ],
            ),
            if (proposal.status == ProposalStatus.vetRejected &&
                proposal.rejectionReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        proposal.rejectionReason!,
                        style: GoogleFonts.manrope(
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
