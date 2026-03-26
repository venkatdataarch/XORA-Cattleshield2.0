import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';
import '../../data/health_scan_repository.dart';

/// Labels for each health scan image slot.
enum HealthImageSlot {
  fullBodyFront,
  sideView,
  rearView,
  legsHooves,
  udder;

  String get label {
    switch (this) {
      case HealthImageSlot.fullBodyFront:
        return 'Full Body Front';
      case HealthImageSlot.sideView:
        return 'Side View';
      case HealthImageSlot.rearView:
        return 'Rear View';
      case HealthImageSlot.legsHooves:
        return 'Legs & Hooves';
      case HealthImageSlot.udder:
        return 'Udder';
    }
  }

  bool get isRequired =>
      this == fullBodyFront || this == sideView || this == rearView;

  IconData get iconData {
    switch (this) {
      case HealthImageSlot.fullBodyFront:
        return const IconData(0xe3b0, fontFamily: 'MaterialIcons'); // photo_camera_front
      case HealthImageSlot.sideView:
        return const IconData(0xe41b, fontFamily: 'MaterialIcons'); // panorama
      case HealthImageSlot.rearView:
        return const IconData(0xe3b6, fontFamily: 'MaterialIcons'); // photo_library
      case HealthImageSlot.legsHooves:
        return const IconData(0xe574, fontFamily: 'MaterialIcons'); // straighten
      case HealthImageSlot.udder:
        return const IconData(0xf04bd, fontFamily: 'MaterialIcons'); // water_drop
    }
  }
}

/// State for the health scan flow.
class HealthScanState {
  final Map<HealthImageSlot, String> capturedImages;
  final HealthResult? result;
  final bool isProcessing;
  final String? errorMessage;

  const HealthScanState({
    this.capturedImages = const {},
    this.result,
    this.isProcessing = false,
    this.errorMessage,
  });

  int get capturedCount => capturedImages.length;

  int get totalSlots => HealthImageSlot.values.length;

  bool get hasMinimumRequired {
    return capturedImages.containsKey(HealthImageSlot.fullBodyFront) &&
        capturedImages.containsKey(HealthImageSlot.sideView) &&
        capturedImages.containsKey(HealthImageSlot.rearView);
  }

  HealthScanState copyWith({
    Map<HealthImageSlot, String>? capturedImages,
    HealthResult? result,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return HealthScanState(
      capturedImages: capturedImages ?? this.capturedImages,
      result: result ?? this.result,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier managing the health scan capture and submission.
class HealthScanNotifier extends StateNotifier<HealthScanState> {
  final HealthScanRepository _repo;

  HealthScanNotifier(this._repo) : super(const HealthScanState());

  void addImage(HealthImageSlot slot, String path) {
    final images = {...state.capturedImages, slot: path};
    state = state.copyWith(capturedImages: images);
  }

  void removeImage(HealthImageSlot slot) {
    final images = {...state.capturedImages}..remove(slot);
    state = state.copyWith(capturedImages: images);
  }

  void reset() {
    state = const HealthScanState();
  }

  /// Submits captured images for AI health analysis.
  Future<void> submitForAnalysis(
    String animalId,
    AnimalSpecies species,
  ) async {
    if (!state.hasMinimumRequired) return;

    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      final formData = FormData();

      for (final entry in state.capturedImages.entries) {
        formData.files.add(MapEntry(
          'health_${entry.key.name}',
          await MultipartFile.fromFile(
            entry.value,
            filename: 'health_${entry.key.name}.jpg',
          ),
        ));
      }

      formData.fields.add(MapEntry('species', species.name));
      formData.fields.add(MapEntry('animalId', animalId));

      final result = await _repo.submitHealthScan(
        animalId,
        species,
        formData,
      );

      result.when(
        success: (healthResult) {
          state = state.copyWith(
            isProcessing: false,
            result: healthResult,
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
}

/// Riverpod provider for [HealthScanNotifier].
final healthScanProvider =
    StateNotifierProvider.autoDispose<HealthScanNotifier, HealthScanState>(
        (ref) {
  final repo = ref.watch(healthScanRepositoryProvider);
  return HealthScanNotifier(repo);
});
