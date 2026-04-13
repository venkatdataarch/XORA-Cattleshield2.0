import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/claim_repository.dart';
import '../../domain/claim_model.dart';

/// State for the claim list with loading, error, and data states.
class ClaimListState {
  final AsyncValue<List<ClaimModel>> claims;
  final ClaimStatus? filterStatus;

  const ClaimListState({
    this.claims = const AsyncValue.loading(),
    this.filterStatus,
  });

  ClaimListState copyWith({
    AsyncValue<List<ClaimModel>>? claims,
    ClaimStatus? filterStatus,
    bool clearFilter = false,
  }) {
    return ClaimListState(
      claims: claims ?? this.claims,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  /// Returns the filtered list of claims based on status filter.
  List<ClaimModel> get filteredClaims {
    final data = claims.valueOrNull ?? [];
    if (filterStatus == null) return data;
    return data.where((c) => c.status == filterStatus).toList();
  }
}

/// StateNotifier managing the claim list and operations.
class ClaimListNotifier extends StateNotifier<ClaimListState> {
  final ClaimRepository _repository;

  ClaimListNotifier({required ClaimRepository repository})
      : _repository = repository,
        super(const ClaimListState());

  /// Loads all claims from the API.
  Future<void> loadClaims() async {
    state = state.copyWith(claims: const AsyncValue.loading());

    final result = await _repository.getClaims();

    result.when(
      success: (claims) {
        state = state.copyWith(claims: AsyncValue.data(claims));
      },
      failure: (error) {
        state = state.copyWith(
          claims: AsyncValue.error(error.message, StackTrace.current),
        );
      },
    );
  }

  /// Creates a new claim and adds it to the list on success.
  Future<ClaimModel?> createClaim(
    String policyId,
    ClaimType type,
    Map<String, dynamic> formData,
  ) async {
    final result = await _repository.createClaim(policyId, type, formData);

    return result.when(
      success: (claim) {
        final currentList = state.claims.valueOrNull ?? [];
        state = state.copyWith(
          claims: AsyncValue.data([claim, ...currentList]),
        );
        return claim;
      },
      failure: (error) => null,
    );
  }

  /// Sets the status filter for the claim list.
  void setFilter(ClaimStatus? status) {
    if (status == state.filterStatus) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterStatus: status);
    }
  }
}

/// Provider for the claim list state and operations.
final claimListProvider =
    StateNotifierProvider<ClaimListNotifier, ClaimListState>((ref) {
  final repository = ref.watch(claimRepositoryProvider);
  return ClaimListNotifier(repository: repository);
});

/// Provider for the currently selected claim in detail view.
final selectedClaimProvider = StateProvider<ClaimModel?>((ref) => null);
