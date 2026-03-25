import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';
import '../../data/muzzle_scan_repository.dart';

/// Which muzzle angle is being captured.
enum MuzzleAngle { front, left, right }

/// State for the muzzle scan flow.
class MuzzleScanState {
  /// Which angles have been captured so far.
  final Set<MuzzleAngle> capturedAngles;

  /// File paths for each captured angle.
  final Map<MuzzleAngle, String> capturedPaths;

  /// Result after AI processing.
  final String? uniqueId; // UCID or MUID
  final double? confidence;

  /// Loading / error.
  final bool isProcessing;
  final String? errorMessage;

  const MuzzleScanState({
    this.capturedAngles = const {},
    this.capturedPaths = const {},
    this.uniqueId,
    this.confidence,
    this.isProcessing = false,
    this.errorMessage,
  });

  bool get allCaptured =>
      capturedAngles.contains(MuzzleAngle.front) &&
      capturedAngles.contains(MuzzleAngle.left) &&
      capturedAngles.contains(MuzzleAngle.right);

  MuzzleAngle get currentAngle {
    if (!capturedAngles.contains(MuzzleAngle.front)) return MuzzleAngle.front;
    if (!capturedAngles.contains(MuzzleAngle.left)) return MuzzleAngle.left;
    return MuzzleAngle.right;
  }

  int get stepIndex {
    if (!capturedAngles.contains(MuzzleAngle.front)) return 0;
    if (!capturedAngles.contains(MuzzleAngle.left)) return 1;
    return 2;
  }

  MuzzleScanState copyWith({
    Set<MuzzleAngle>? capturedAngles,
    Map<MuzzleAngle, String>? capturedPaths,
    String? uniqueId,
    double? confidence,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return MuzzleScanState(
      capturedAngles: capturedAngles ?? this.capturedAngles,
      capturedPaths: capturedPaths ?? this.capturedPaths,
      uniqueId: uniqueId ?? this.uniqueId,
      confidence: confidence ?? this.confidence,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier managing the muzzle scan capture and submission flow.
class MuzzleScanNotifier extends StateNotifier<MuzzleScanState> {
  final MuzzleScanRepository _repo;

  MuzzleScanNotifier(this._repo) : super(const MuzzleScanState());

  /// Records a captured image for the given [angle].
  void addCapture(MuzzleAngle angle, String filePath) {
    final angles = {...state.capturedAngles, angle};
    final paths = {...state.capturedPaths, angle: filePath};
    state = state.copyWith(capturedAngles: angles, capturedPaths: paths);
  }

  /// Removes a capture, allowing retake.
  void retake(MuzzleAngle angle) {
    final angles = {...state.capturedAngles}..remove(angle);
    final paths = {...state.capturedPaths}..remove(angle);
    state = state.copyWith(capturedAngles: angles, capturedPaths: paths);
  }

  /// Resets all captured state.
  void reset() {
    state = const MuzzleScanState();
  }

  /// Compresses an image file to approximately [targetKb] kilobytes.
  Future<File> _compressImage(String path, {int targetKb = 150}) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;

    // Resize if too large
    var resized = decoded;
    if (decoded.width > 800) {
      resized = img.copyResize(decoded, width: 800);
    }

    // Encode as JPEG with quality targeting ~150KB
    int quality = 85;
    List<int> encoded = img.encodeJpg(resized, quality: quality);
    while (encoded.length > targetKb * 1024 && quality > 20) {
      quality -= 10;
      encoded = img.encodeJpg(resized, quality: quality);
    }

    final tempDir = await getTemporaryDirectory();
    final compressedFile = File(
      '${tempDir.path}/muzzle_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await compressedFile.writeAsBytes(encoded);
    return compressedFile;
  }

  /// Submits all captured muzzle images for registration.
  Future<void> submitForRegistration(AnimalSpecies species) async {
    if (!state.allCaptured) return;

    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      final formData = FormData();

      for (final entry in state.capturedPaths.entries) {
        final compressed = await _compressImage(entry.value);
        formData.files.add(MapEntry(
          'muzzle_${entry.key.name}',
          await MultipartFile.fromFile(
            compressed.path,
            filename: 'muzzle_${entry.key.name}.jpg',
          ),
        ));
      }

      formData.fields.add(MapEntry('species', species.name));

      final result = await _repo.registerWithMuzzle(species, formData);
      result.when(
        success: (data) {
          state = state.copyWith(
            isProcessing: false,
            uniqueId: data['uniqueId']?.toString() ??
                data['ucid']?.toString() ??
                data['muid']?.toString(),
            confidence: _parseDouble(data['confidence'] ?? data['score']),
          );
        },
        failure: (e) {
          state = state.copyWith(
            isProcessing: false,
            errorMessage: e.message,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Submits a single muzzle image for identity verification (claims).
  Future<void> submitForIdentification(
    AnimalSpecies species, {
    String? claimId,
  }) async {
    final frontPath = state.capturedPaths[MuzzleAngle.front];
    if (frontPath == null) return;

    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      final compressed = await _compressImage(frontPath);
      final formData = FormData.fromMap({
        'muzzle_front': await MultipartFile.fromFile(
          compressed.path,
          filename: 'muzzle_front.jpg',
        ),
        'species': species.name,
      });

      final result = claimId != null
          ? await _repo.verifyMuzzle(claimId, formData)
          : await _repo.identifyByMuzzle(species, formData);

      result.when(
        success: (data) {
          state = state.copyWith(
            isProcessing: false,
            uniqueId: data['uniqueId']?.toString() ??
                data['ucid']?.toString() ??
                data['muid']?.toString(),
            confidence: _parseDouble(
              data['matchPercentage'] ??
                  data['confidence'] ??
                  data['score'],
            ),
          );
        },
        failure: (e) {
          state = state.copyWith(
            isProcessing: false,
            errorMessage: e.message,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Riverpod provider for [MuzzleScanNotifier].
final muzzleScanProvider =
    StateNotifierProvider.autoDispose<MuzzleScanNotifier, MuzzleScanState>(
        (ref) {
  final repo = ref.watch(muzzleScanRepositoryProvider);
  return MuzzleScanNotifier(repo);
});
