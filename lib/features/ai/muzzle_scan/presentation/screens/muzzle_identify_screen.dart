import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/shared/widgets/status_badge.dart';
import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';
import '../providers/muzzle_scan_provider.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/scan_progress_bar.dart';

/// Single-capture muzzle identity verification screen used during claims.
///
/// Captures a front-angle muzzle image, processes it via AI, and shows
/// a match percentage against the registered muzzle pattern.
class MuzzleIdentifyScreen extends ConsumerStatefulWidget {
  final AnimalSpecies species;
  final String? claimId;
  final String? originalMuzzleUrl;

  const MuzzleIdentifyScreen({
    super.key,
    required this.species,
    this.claimId,
    this.originalMuzzleUrl,
  });

  @override
  ConsumerState<MuzzleIdentifyScreen> createState() =>
      _MuzzleIdentifyScreenState();
}

class _MuzzleIdentifyScreenState extends ConsumerState<MuzzleIdentifyScreen> {
  final _picker = ImagePicker();
  String? _capturedPath;
  bool _showResult = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(muzzleScanProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        isLoading: state.isProcessing,
        message: 'Verifying identity...',
        child: _showResult && state.confidence != null
            ? _buildResultView(context, state)
            : _buildCaptureView(context, state),
      ),
    );
  }

  Widget _buildCaptureView(BuildContext context, MuzzleScanState state) {
    if (_capturedPath != null) {
      return _buildPreviewView(context, state);
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3)),
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
              const CameraOverlay(
                instruction: 'Capture front muzzle for verification',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: GestureDetector(
            onTap: _captureImage,
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
                  child: const Icon(Icons.camera_alt,
                      color: Colors.black, size: 28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView(BuildContext context, MuzzleScanState state) {
    return Column(
      children: [
        Expanded(
          child: Image.file(File(_capturedPath!), fit: BoxFit.cover),
        ),
        if (state.isProcessing)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: ScanProgressBar(
              message: 'Matching muzzle pattern...',
            ),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: Colors.black.withValues(alpha: 0.8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.isProcessing
                      ? null
                      : () {
                          setState(() => _capturedPath = null);
                          ref.read(muzzleScanProvider.notifier).reset();
                        },
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
                  onPressed: state.isProcessing ? null : _submitForVerification,
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Verify'),
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
      ],
    );
  }

  Widget _buildResultView(BuildContext context, MuzzleScanState state) {
    final score = state.confidence ?? 0;
    Color matchColor;
    String matchLabel;
    IconData matchIcon;

    if (score >= 85) {
      matchColor = AppColors.success;
      matchLabel = 'Identity Verified';
      matchIcon = Icons.check_circle;
    } else if (score >= 60) {
      matchColor = AppColors.warning;
      matchLabel = 'Uncertain Match';
      matchIcon = Icons.warning_amber_rounded;
    } else {
      matchColor = AppColors.error;
      matchLabel = 'No Match';
      matchIcon = Icons.cancel;
    }

    return Container(
      color: AppColors.background,
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            const Spacer(),

            // Match gauge
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 12,
                      backgroundColor: matchColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(matchColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: matchColor,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Status badge
            StatusBadge(
              label: matchLabel,
              color: matchColor,
              icon: matchIcon,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Side by side comparison
            if (widget.originalMuzzleUrl != null || _capturedPath != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.originalMuzzleUrl != null) ...[
                    _buildComparisonImage(
                      context,
                      'Original',
                      widget.originalMuzzleUrl!,
                      isNetwork: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (_capturedPath != null)
                    _buildComparisonImage(
                      context,
                      'New Capture',
                      _capturedPath!,
                      isNetwork: false,
                    ),
                ],
              ),

            const Spacer(),

            // Continue
            PrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              onPressed: () => context.pop(score),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonImage(
    BuildContext context,
    String label,
    String path, {
    required bool isNetwork,
  }) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 100,
            child: isNetwork
                ? Image.network(path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: AppColors.background,
                          child: const Icon(Icons.image,
                              color: AppColors.textTertiary),
                        ))
                : Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Future<void> _captureImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image != null) {
        setState(() => _capturedPath = image.path);
        ref
            .read(muzzleScanProvider.notifier)
            .addCapture(MuzzleAngle.front, image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _submitForVerification() {
    ref.read(muzzleScanProvider.notifier).submitForIdentification(
          widget.species,
          claimId: widget.claimId,
        );

    // Watch for result
    ref.listenManual(muzzleScanProvider, (prev, next) {
      if (next.confidence != null && !next.isProcessing) {
        setState(() => _showResult = true);
      }
    });
  }
}
