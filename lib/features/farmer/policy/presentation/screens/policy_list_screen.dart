import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/empty_state_widget.dart';
import '../../domain/policy_model.dart';
import '../providers/policy_provider.dart';
import '../widgets/policy_card.dart';

/// Screen showing all policies with tab-based status filtering.
class PolicyListScreen extends ConsumerStatefulWidget {
  const PolicyListScreen({super.key});

  @override
  ConsumerState<PolicyListScreen> createState() => _PolicyListScreenState();
}

class _PolicyListScreenState extends ConsumerState<PolicyListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Tab definitions with optional status filter.
  static const _tabs = <({String label, PolicyStatus? status})>[
    (label: 'Active', status: PolicyStatus.active),
    (label: 'Expiring Soon', status: PolicyStatus.expiringSoon),
    (label: 'Expired', status: PolicyStatus.expired),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    Future.microtask(() {
      ref.read(policyListProvider.notifier).loadPolicies();
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
      ref.read(policyListProvider.notifier).setFilter(status);
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(policyListProvider.notifier).loadPolicies();
  }

  /// Filter policies for the current tab, supporting computed status matching.
  List<PolicyModel> _getFilteredPolicies(PolicyListState state) {
    final all = state.policies.valueOrNull ?? [];
    final tabStatus = _tabs[_tabController.index].status;
    if (tabStatus == null) return all;
    return all.where((p) => p.status == tabStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(policyListProvider);

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
              // Premium header
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
                          child: const Icon(Icons.policy, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Policies',
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
                    // Tab bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.white,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Content
              Expanded(
                child: state.policies.when(
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

  Widget _buildList(PolicyListState state) {
    final policies = _getFilteredPolicies(state);

    if (policies.isEmpty) {
      final tabLabel = _tabs[_tabController.index].label;
      return EmptyStateWidget(
        icon: Icons.policy_outlined,
        title: 'No $tabLabel policies',
        subtitle: 'Policies will appear here once\nyour proposals are approved.',
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: policies.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final policy = policies[index];
          return PolicyCard(
            policy: policy,
            onTap: () {
              ref.read(selectedPolicyProvider.notifier).state = policy;
              context.push('/farmer/policies/${policy.id}');
            },
            onFileClaim: policy.isClaimable
                ? () {
                    ref.read(selectedPolicyProvider.notifier).state = policy;
                    context.push('/farmer/claims/new/${policy.id}');
                  }
                : null,
          );
        },
      ),
    );
  }
}
