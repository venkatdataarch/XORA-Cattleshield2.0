import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/animal_repository.dart';
import '../../domain/animal_model.dart';

/// State for the animal list with loading, error, and data states.
class AnimalListState {
  final AsyncValue<List<AnimalModel>> animals;
  final AnimalSpecies? filterSpecies;
  final String searchQuery;

  const AnimalListState({
    this.animals = const AsyncValue.loading(),
    this.filterSpecies,
    this.searchQuery = '',
  });

  AnimalListState copyWith({
    AsyncValue<List<AnimalModel>>? animals,
    AnimalSpecies? filterSpecies,
    bool clearFilter = false,
    String? searchQuery,
  }) {
    return AnimalListState(
      animals: animals ?? this.animals,
      filterSpecies: clearFilter ? null : (filterSpecies ?? this.filterSpecies),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Returns the filtered list of animals based on species filter and search.
  List<AnimalModel> get filteredAnimals {
    final data = animals.valueOrNull ?? [];

    return data.where((animal) {
      // Species filter
      if (filterSpecies != null && animal.species != filterSpecies) {
        return false;
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesTag =
            animal.identificationTag?.toLowerCase().contains(query) ?? false;
        final matchesBreed =
            animal.speciesBreed?.toLowerCase().contains(query) ?? false;
        final matchesName = animal.displayName.toLowerCase().contains(query);
        final matchesId = animal.uniqueId?.toLowerCase().contains(query) ?? false;
        return matchesTag || matchesBreed || matchesName || matchesId;
      }

      return true;
    }).toList();
  }
}

/// StateNotifier managing the animal list and operations.
class AnimalListNotifier extends StateNotifier<AnimalListState> {
  final AnimalRepository _repository;

  AnimalListNotifier({required AnimalRepository repository})
      : _repository = repository,
        super(const AnimalListState());

  /// Loads all animals from the API.
  Future<void> loadAnimals() async {
    state = state.copyWith(animals: const AsyncValue.loading());

    final result = await _repository.getAnimals();

    result.when(
      success: (animals) {
        state = state.copyWith(animals: AsyncValue.data(animals));
      },
      failure: (error) {
        state = state.copyWith(
          animals: AsyncValue.error(error.message, StackTrace.current),
        );
      },
    );
  }

  /// Registers a new animal and adds it to the list on success.
  Future<AnimalModel?> registerAnimal(
    AnimalSpecies species,
    FormData data,
  ) async {
    final result = await _repository.registerAnimal(species, data);

    return result.when(
      success: (animal) {
        final currentList = state.animals.valueOrNull ?? [];
        state = state.copyWith(
          animals: AsyncValue.data([animal, ...currentList]),
        );
        return animal;
      },
      failure: (error) {
        return null;
      },
    );
  }

  /// Sets the species filter for the animal list.
  void setFilter(AnimalSpecies? species) {
    if (species == state.filterSpecies) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterSpecies: species);
    }
  }

  /// Sets the search query for filtering the animal list.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

/// Provider for the animal list state and operations.
final animalListProvider =
    StateNotifierProvider<AnimalListNotifier, AnimalListState>((ref) {
  final repository = ref.watch(animalRepositoryProvider);
  return AnimalListNotifier(repository: repository);
});

/// Provider for the currently selected animal in detail view.
final selectedAnimalProvider = StateProvider<AnimalModel?>((ref) => null);
