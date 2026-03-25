import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';
import '../providers/muzzle_scan_provider.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/angle_indicator.dart';
import '../widgets/scan_progress_bar.dart';

/// 3-angle muzzle capture screen.
///
/// Guides the user through capturing Front, Left Profile, and Right Profile
/// muzzle images. Falls back to [image_picker] if the camera package is
/// not initialized.
class MuzzleCaptureScreen extends ConsumerStatefulWidget {
  final AnimalSpecies species;

  const MuzzleCaptureScreen({super.key, required this.species});

  @override
  ConsumerState<MuzzleCaptureScreen> createState() =>
      _MuzzleCaptureScreenState();
}

class _MuzzleCaptureScreenState extends ConsumerState<MuzzleCaptureScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late AnimationController _scanLineController;

  static const _angleInstructions = {
    MuzzleAngle.front: 'Capture the muzzle from the FRONT',
    MuzzleAngle.left: 'Capture the LEFT PROFILE of the muzzle',
    MuzzleAngle.right: 'Capture the RIGHT PROFILE of the muzzle',
  };

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(muzzleScanProvider);
    final notifier = ref.read(muzzleScanProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Muzzle Scan (${state.stepIndex + 1}/3)',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: state.isProcessing,
        message: 'Processing muzzle pattern...',
        child: state.allCaptured && !state.isProcessing
            ? _buildReviewAll(context, state, notifier)
            : _buildCaptureView(context, state, notifier),
      ),
    );
  }

  Widget _buildCaptureView(
    BuildContext context,
    MuzzleScanState state,
    MuzzleScanNotifier notifier,
  ) {
    final currentAngle = state.currentAngle;
    final capturedPath = state.capturedPaths[currentAngle];
    final hasCaptured = capturedPath != null;

    return Column(
      children: [
        // Angle indicator
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: AngleIndicator(
            currentStep: state.stepIndex,
            completedAngles: state.capturedAngles,
          ),
        ),

        // Camera / Preview area
        Expanded(
          child: hasCaptured
              ? _buildPreview(context, capturedPath, currentAngle, notifier)
              : _buildCameraPlaceholder(context, currentAngle),
        ),

        // Capture button
        if (!hasCaptured)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildCaptureButton(context, currentAngle, notifier),
          ),
      ],
    );
  }

  Widget _buildCameraPlaceholder(
    BuildContext context,
    MuzzleAngle angle,
  ) {
    return Stack(
      children: [
        // Dark camera placeholder
        Container(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Camera Preview',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Overlay with oval guide
        CameraOverlay(
          instruction:
              _angleInstructions[angle] ?? 'Position the muzzle',
        ),

        // Scan line animation
        AnimatedBuilder(
          animation: _scanLineController,
          builder: (context, _) {
            return Positioned(
              left: 0,
              right: 0,
              top: _scanLineController.value *
                  (MediaQuery.of(context).size.height * 0.5),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.secondary.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview(
    BuildContext context,
    String path,
    MuzzleAngle angle,
    MuzzleScanNotifier notifier,
  ) {
    return Stack(
      children: [
        // Captured image
        Positioned.fill(
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
          ),
        ),
        // Overlay buttons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => notifier.retake(angle),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Move to next angle by marking current as done
                      notifier.addCapture(angle, path);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton(
    BuildContext context,
    MuzzleAngle angle,
    MuzzleScanNotifier notifier,
  ) {
    return GestureDetector(
      onTap: () => _captureImage(angle, notifier),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.secondary, width: 4),
        ),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewAll(
    BuildContext context,
    MuzzleScanState state,
    MuzzleScanNotifier notifier,
  ) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Review Captures',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 3 thumbnails
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: MuzzleAngle.values.map((angle) {
                final path = state.capturedPaths[angle];
                return Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 0.75,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: path != null
                                ? Image.file(File(path),
                                    fit: BoxFit.cover)
                                : Container(color: Colors.grey[800]),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          angle.name[0].toUpperCase() +
                              angle.name.substring(1),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Spacer(),

          if (state.isProcessing)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: ScanProgressBar(),
            ),

          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isProcessing
                    ? null
                    : () => notifier
                        .submitForRegistration(widget.species),
                icon: const Icon(Icons.send),
                label: const Text('Submit for Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage(
    MuzzleAngle angle,
    MuzzleScanNotifier notifier,
  ) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image != null) {
        notifier.addCapture(angle, image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }
}
