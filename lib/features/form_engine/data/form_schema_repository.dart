import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/core/storage/local_db_service.dart';
import '../domain/form_schema_model.dart';

/// Repository responsible for loading, caching and serving [FormSchema]
/// definitions.
///
/// Resolution order for [getSchema]:
/// 1. Local SQLite cache (fastest, works offline).
/// 2. Bundled JSON asset in `assets/schemas/`.
/// 3. Remote API endpoint.
///
/// Successful remote fetches automatically update the local cache.
class FormSchemaRepository {
  final DioClient _dioClient;
  final LocalDbService _localDb;

  FormSchemaRepository({
    required DioClient dioClient,
    required LocalDbService localDb,
  })  : _dioClient = dioClient,
        _localDb = localDb;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the [FormSchema] for the given [formType].
  ///
  /// Tries local cache first, then bundled asset, then the remote API.
  /// Throws [Exception] when no schema can be resolved.
  Future<FormSchema> getSchema(String formType) async {
    // 1. Try local DB cache
    final cached = await _localDb.getCachedSchema(formType);
    if (cached != null) {
      final schemaMap = cached['schema'] as Map<String, dynamic>;
      return FormSchema.fromJson(schemaMap);
    }

    // 2. Try bundled asset
    try {
      final assetJson = await rootBundle.loadString(
        'assets/schemas/$formType.json',
      );
      final schemaMap = jsonDecode(assetJson) as Map<String, dynamic>;
      final schema = FormSchema.fromJson(schemaMap);

      // Populate cache for next time
      await cacheSchema(schema);
      return schema;
    } catch (_) {
      // Asset not found or parse error - fall through to API
    }

    // 3. Try remote API
    final result = await _dioClient.get(ApiEndpoints.formSchema(formType));

    return result.when(
      success: (response) async {
        final schemaMap = response.data as Map<String, dynamic>;
        final schema = FormSchema.fromJson(schemaMap);
        await cacheSchema(schema);
        return schema;
      },
      failure: (error) {
        throw Exception(
          'Failed to load form schema "$formType": ${error.message}',
        );
      },
    );
  }

  /// Returns all locally-available schemas (cached + bundled assets).
  Future<List<FormSchema>> getAllSchemas() async {
    final cachedRows = await _localDb.getAllCachedSchemas();
    return cachedRows.map((row) {
      final schemaMap = row['schema'] as Map<String, dynamic>;
      return FormSchema.fromJson(schemaMap);
    }).toList();
  }

  /// Persists a [FormSchema] into the local SQLite cache.
  Future<void> cacheSchema(FormSchema schema) async {
    await _localDb.cacheSchema(
      id: schema.formType,
      schema: schema.toJson(),
      version: schema.version,
    );
  }

  /// Removes a cached schema by [formType].
  Future<void> deleteCachedSchema(String formType) async {
    await _localDb.deleteCachedSchema(formType);
  }

  /// Forces a fresh download of [formType] from the API and updates the cache.
  Future<FormSchema> refreshSchema(String formType) async {
    await _localDb.deleteCachedSchema(formType);
    return getSchema(formType);
  }
}

/// Riverpod provider for [FormSchemaRepository].
final formSchemaRepositoryProvider = Provider<FormSchemaRepository>((ref) {
  return FormSchemaRepository(
    dioClient: ref.watch(dioClientProvider),
    localDb: ref.watch(localDbProvider),
  );
});
