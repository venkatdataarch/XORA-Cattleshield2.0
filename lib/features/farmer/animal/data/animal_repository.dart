import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../domain/animal_model.dart';
import 'animal_remote_source.dart';

/// Repository that abstracts cattle and mule endpoints behind a unified
/// animal API, routing calls to the correct legacy endpoint based on species.
class AnimalRepository {
  final AnimalRemoteSource _remoteSource;

  AnimalRepository({required AnimalRemoteSource remoteSource})
      : _remoteSource = remoteSource;

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers a new animal. Routes to cattle or mule endpoint based on [species].
  Future<ApiResult<AnimalModel>> registerAnimal(
    AnimalSpecies species,
    FormData data,
  ) async {
    try {
      final Map<String, dynamic> json;
      if (species.isCattle) {
        json = await _remoteSource.registerCattle(data);
      } else {
        json = await _remoteSource.registerMule(data);
      }

      // Inject species into json if not present.
      if (!json.containsKey('species')) {
        json['species'] = species.name;
      }

      final animal = AnimalModel.fromJson(json);
      return ApiResult.success(animal);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Identification
  // ---------------------------------------------------------------------------

  /// Identifies an animal by muzzle scan. Routes based on [species].
  Future<ApiResult<AnimalModel>> identifyAnimal(
    AnimalSpecies species,
    FormData data,
  ) async {
    try {
      final Map<String, dynamic> json;
      if (species.isCattle) {
        json = await _remoteSource.identifyCattle(data);
      } else {
        json = await _remoteSource.identifyMule(data);
      }

      if (!json.containsKey('species')) {
        json['species'] = species.name;
      }

      final animal = AnimalModel.fromJson(json);
      return ApiResult.success(animal);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch animals
  // ---------------------------------------------------------------------------

  /// Fetches all animals (cattle + mule) for the authenticated user.
  ///
  /// Merges results from both legacy endpoints into a single list.
  Future<ApiResult<List<AnimalModel>>> getAnimals() async {
    try {
      final List<AnimalModel> allAnimals = [];

      // Fetch cattle
      try {
        final cattleList = await _remoteSource.getAllCattle();
        for (final json in cattleList) {
          if (!json.containsKey('species')) {
            json['species'] = 'cow';
          }
          allAnimals.add(AnimalModel.fromJson(json));
        }
      } on ApiException {
        // If cattle endpoint fails, continue with mule.
      }

      // Fetch mule
      try {
        final muleList = await _remoteSource.getAllMule();
        for (final json in muleList) {
          if (!json.containsKey('species')) {
            json['species'] = 'mule';
          }
          allAnimals.add(AnimalModel.fromJson(json));
        }
      } on ApiException {
        // If mule endpoint fails, return whatever we have.
      }

      // Sort by creation date descending.
      allAnimals.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return ApiResult.success(allAnimals);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch single animal
  // ---------------------------------------------------------------------------

  /// Fetches a single animal by [id], routing to the correct endpoint
  /// based on [species].
  Future<ApiResult<AnimalModel>> getAnimalById(
    String id,
    AnimalSpecies species,
  ) async {
    try {
      final Map<String, dynamic> json;
      if (species.isCattle) {
        json = await _remoteSource.getCattleById(id);
      } else {
        json = await _remoteSource.getMuleById(id);
      }

      if (!json.containsKey('species')) {
        json['species'] = species.name;
      }

      final animal = AnimalModel.fromJson(json);
      return ApiResult.success(animal);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Health scan
  // ---------------------------------------------------------------------------

  /// Submits a health scan for an animal, routing based on [species].
  Future<ApiResult<Map<String, dynamic>>> submitHealthScan(
    String id,
    AnimalSpecies species,
    FormData data,
  ) async {
    try {
      final Map<String, dynamic> json;
      if (species.isCattle) {
        json = await _remoteSource.submitCattleHealthScan(id, data);
      } else {
        json = await _remoteSource.submitMuleHealthScan(id, data);
      }

      return ApiResult.success(json);
    } on ApiException catch (e) {
      return ApiResult.failure(e);
    } catch (e) {
      return ApiResult.failure(ApiException(message: e.toString()));
    }
  }
}

/// Riverpod provider for [AnimalRepository].
final animalRepositoryProvider = Provider<AnimalRepository>((ref) {
  final remoteSource = ref.watch(animalRemoteSourceProvider);
  return AnimalRepository(remoteSource: remoteSource);
});
