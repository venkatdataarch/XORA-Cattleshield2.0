import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/policy_repository.dart';
import '../../domain/policy_model.dart';

/// State for the policy list with loading, error, and data states.
class PolicyListState {
  final AsyncValue<List<PolicyModel>> policies;
  final PolicyStatus? filterStatus;

  const PolicyListState({
    this.policies = const AsyncValue.loading(),
    this.filterStatus,
  });

  PolicyListState copyWith({
    AsyncValue<List<PolicyModel>>? policies,
    PolicyStatus? filterStatus,
    bool clearFilter = false,
  }) {
    return PolicyListState(
      policies: policies ?? this.policies,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  /// Returns the filtered list of policies based on status filter.
  List<PolicyModel> get filteredPolicies {
    final data = policies.valueOrNull ?? [];
    if (filterStatus == null) return data;
    return data.where((p) => p.status == filterStatus).toList();
  }
}

/// StateNotifier managing the policy list and operations.
class PolicyListNotifier extends StateNotifier<PolicyListState> {
  final PolicyRepository _repository;

  PolicyListNotifier({required PolicyRepository repository})
      : _repository = repository,
        super(const PolicyListState());

  /// Loads all policies from the API.
  Future<void> loadPolicies() async {
    state = state.copyWith(policies: const AsyncValue.loading());

    final result = await _repository.getPolicies();

    result.when(
      success: (policies) {
        state = state.copyWith(policies: AsyncValue.data(policies));
      },
      failure: (error) {
        state = state.copyWith(
          policies: AsyncValue.error(error.message, StackTrace.current),
        );
      },
    );
  }

  /// Sets the status filter for the policy list.
  void setFilter(PolicyStatus? status) {
    if (status == state.filterStatus) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterStatus: status);
    }
  }
}

/// Provider for the policy list state and operations.
final policyListProvider =
    StateNotifierProvider<PolicyListNotifier, PolicyListState>((ref) {
  final repository = ref.watch(policyRepositoryProvider);
  return PolicyListNotifier(repository: repository);
});

/// Provider for the currently selected policy in detail view.
final selectedPolicyProvider = StateProvider<PolicyModel?>((ref) => null);
