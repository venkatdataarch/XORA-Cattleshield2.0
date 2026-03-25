import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';
import '../providers/health_scan_provider.dart';

/// Multi-image health assessment capture screen.
///
/// Provides a grid of image slots for different body angles. The user must
/// capture at least 3 required images before submitting for AI analysis.
class HealthCaptureScreen extends ConsumerStatefulWidget {
  final String animalId;
  final AnimalSpecies species;
  final AnimalSex? sex;

  const HealthCaptureScreen({
    super.key,
    required this.animalId,
    required this.species,
    this.sex,
  });

  @override
  ConsumerState<HealthCaptureScreen> createState() =>
      _HealthCaptureScreenState();
}

class _HealthCaptureScreenState extends ConsumerState<HealthCaptureScreen> {
  final _picker = ImagePicker();

  List<HealthImageSlot> get _visibleSlots {
    final slots = List<HealthImageSlot>.from(HealthImageSlot.values);
    // Only show udder for female cattle
    if (widget.sex != AnimalSex.female || !widget.species.isCattle) {
      slots.remove(HealthImageSlot.udder);
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthScanProvider);
    final notifier = ref.read(healthScanProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Assessment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        isLoading: state.isProcessing,
        message: 'Analyzing health indicators...',
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.background,
              child: Row(
                children: [
                  Icon(
                    Icons.photo_camera,
                    size: 20,
                    color: state.hasMinimumRequired
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${state.capturedCount} of ${_visibleSlots.length} photos captured',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: state.hasMinimumRequired
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Spacer(),
                  if (state.hasMinimumRequired)
                    const Icon(Icons.check_circle,
                        size: 20, color: AppColors.success),
                ],
              ),
            ),

            // Image grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.85,
                ),
                itemCount: _visibleSlots.length,
                itemBuilder: (context, index) {
                  final slot = _visibleSlots[index];
                  final imagePath = state.capturedImages[slot];
                  return _ImageSlotCard(
                    slot: slot,
                    imagePath: imagePath,
                    onCapture: () => _captureImage(slot, notifier),
                    onRetake: imagePath != null
                        ? () => notifier.removeImage(slot)
                        : null,
                  );
                },
              ),
            ),

            // Error message
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Submit button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimaryButton(
                label: 'Submit for Analysis',
                icon: Icons.analytics,
                isLoading: state.isProcessing,
                isDisabled: !state.hasMinimumRequired,
                onPressed: state.hasMinimumRequired
                    ? () => _submit(notifier)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage(
    HealthImageSlot slot,
    HealthScanNotifier notifier,
  ) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image != null) {
        notifier.addImage(slot, image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _submit(HealthScanNotifier notifier) {
    notifier.submitForAnalysis(widget.animalId, widget.species);

    // Navigate to results when done
    ref.listenManual(healthScanProvider, (prev, next) {
      if (next.result != null && !next.isProcessing && mounted) {
        context.push('/ai/health/result');
      }
    });
  }
}

class _ImageSlotCard extends StatelessWidget {
  final HealthImageSlot slot;
  final String? imagePath;
  final VoidCallback? onCapture;
  final VoidCallback? onRetake;

  const _ImageSlotCard({
    required this.slot,
    this.imagePath,
    this.onCapture,
    this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;

    return GestureDetector(
      onTap: hasImage ? onRetake : onCapture,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: hasImage
                ? AppColors.success
                : slot.isRequired
                    ? AppColors.secondary.withValues(alpha: 0.5)
                    : AppColors.cardBorder,
            width: hasImage || slot.isRequired ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AppSpacing.cardRadius - 1),
          child: Stack(
            children: [
              // Image or placeholder
              if (hasImage)
                Positioned.fill(
                  child: Image.file(
                    File(imagePath!),
                    fit: BoxFit.cover,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 36,
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to capture',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                      ),
                    ],
                  ),
                ),

              // Label at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasImage
                        ? Colors.black.withValues(alpha: 0.6)
                        : AppColors.background,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          slot.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: hasImage
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (slot.isRequired && !hasImage)
                        Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      if (hasImage)
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.success),
                    ],
                  ),
                ),
              ),

              // Retake overlay
              if (hasImage)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
