import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: const Text('Policies'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: state.policies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: _onRefresh,
        ),
        data: (_) => _buildList(state),
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
        padding: AppSpacing.screenPadding,
        itemCount: policies.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
