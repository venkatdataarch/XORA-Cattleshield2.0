import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/proposal_repository.dart';
import '../../domain/proposal_model.dart';

/// State for the proposal list with loading, error, and data states.
class ProposalListState {
  final AsyncValue<List<ProposalModel>> proposals;
  final ProposalStatus? filterStatus;

  const ProposalListState({
    this.proposals = const AsyncValue.loading(),
    this.filterStatus,
  });

  ProposalListState copyWith({
    AsyncValue<List<ProposalModel>>? proposals,
    ProposalStatus? filterStatus,
    bool clearFilter = false,
  }) {
    return ProposalListState(
      proposals: proposals ?? this.proposals,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  /// Returns the filtered list of proposals based on status filter.
  List<ProposalModel> get filteredProposals {
    final data = proposals.valueOrNull ?? [];
    if (filterStatus == null) return data;
    return data.where((p) => p.status == filterStatus).toList();
  }
}

/// StateNotifier managing the proposal list and operations.
class ProposalListNotifier extends StateNotifier<ProposalListState> {
  final ProposalRepository _repository;

  ProposalListNotifier({required ProposalRepository repository})
      : _repository = repository,
        super(const ProposalListState());

  /// Loads all proposals from the API.
  Future<void> loadProposals() async {
    state = state.copyWith(proposals: const AsyncValue.loading());

    final result = await _repository.getProposals();

    result.when(
      success: (proposals) {
        state = state.copyWith(proposals: AsyncValue.data(proposals));
      },
      failure: (error) {
        state = state.copyWith(
          proposals: AsyncValue.error(error.message, StackTrace.current),
        );
      },
    );
  }

  /// Creates a new proposal and adds it to the list on success.
  Future<ProposalModel?> createProposal(
    String animalId,
    Map<String, dynamic> formData,
  ) async {
    final result = await _repository.createProposal(animalId, formData);

    return result.when(
      success: (proposal) {
        final currentList = state.proposals.valueOrNull ?? [];
        state = state.copyWith(
          proposals: AsyncValue.data([proposal, ...currentList]),
        );
        return proposal;
      },
      failure: (error) => null,
    );
  }

  /// Updates an existing proposal.
  Future<ProposalModel?> updateProposal(
    String id,
    Map<String, dynamic> formData, {
    ProposalStatus? status,
  }) async {
    final result = await _repository.updateProposal(id, formData, status: status);

    return result.when(
      success: (proposal) {
        final currentList = state.proposals.valueOrNull ?? [];
        final updatedList = currentList.map((p) {
          return p.id == proposal.id ? proposal : p;
        }).toList();
        state = state.copyWith(proposals: AsyncValue.data(updatedList));
        return proposal;
      },
      failure: (error) => null,
    );
  }

  /// Submits a draft proposal.
  Future<ProposalModel?> submitProposal(String id) async {
    final result = await _repository.submitProposal(id);

    return result.when(
      success: (proposal) {
        final currentList = state.proposals.valueOrNull ?? [];
        final updatedList = currentList.map((p) {
          return p.id == proposal.id ? proposal : p;
        }).toList();
        state = state.copyWith(proposals: AsyncValue.data(updatedList));
        return proposal;
      },
      failure: (error) => null,
    );
  }

  /// Sets the status filter for the proposal list.
  void setFilter(ProposalStatus? status) {
    if (status == state.filterStatus) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterStatus: status);
    }
  }
}

/// Provider for the proposal list state and operations.
final proposalListProvider =
    StateNotifierProvider<ProposalListNotifier, ProposalListState>((ref) {
  final repository = ref.watch(proposalRepositoryProvider);
  return ProposalListNotifier(repository: repository);
});

/// Provider for the currently selected proposal in detail view.
final selectedProposalProvider = StateProvider<ProposalModel?>((ref) => null);
