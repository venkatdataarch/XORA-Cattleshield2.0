import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/gps_service.dart';

/// A captured photo with GPS and timestamp metadata.
class CapturedPhoto {
  final String path;
  final String angleLabel;
  final GpsData? gps;
  final DateTime capturedAt;

  const CapturedPhoto({
    required this.path,
    required this.angleLabel,
    this.gps,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'angle': angleLabel,
        'gps': gps?.toJson(),
        'capturedAt': capturedAt.toIso8601String(),
      };
}

/// Guided 6-shot 360° photo capture (Scope 2b — 10 marks).
///
/// Guides user through 6 angles with on-screen diagram showing which
/// angle is next. GPS + timestamp locked per shot.
class GuidedPhotoCaptureScreen extends StatefulWidget {
  final String animalName;
  final Function(List<CapturedPhoto>)? onComplete;

  const GuidedPhotoCaptureScreen({
    super.key,
    this.animalName = 'Animal',
    this.onComplete,
  });

  @override
  State<GuidedPhotoCaptureScreen> createState() =>
      _GuidedPhotoCaptureScreenState();
}

class _GuidedPhotoCaptureScreenState extends State<GuidedPhotoCaptureScreen> {
  final _picker = ImagePicker();
  final List<CapturedPhoto> _photos = [];
  int _currentAngle = 0;
  bool _capturing = false;

  static const _angles = [
    _AngleConfig(
      label: 'Front',
      instruction: 'Stand directly in front of the animal',
      icon: Icons.arrow_upward,
      rotation: 0,
    ),
    _AngleConfig(
      label: 'Right Side',
      instruction: 'Move to the RIGHT side of the animal',
      icon: Icons.arrow_forward,
      rotation: 90,
    ),
    _AngleConfig(
      label: 'Rear',
      instruction: 'Move to the REAR of the animal',
      icon: Icons.arrow_downward,
      rotation: 180,
    ),
    _AngleConfig(
      label: 'Left Side',
      instruction: 'Move to the LEFT side of the animal',
      icon: Icons.arrow_back,
      rotation: 270,
    ),
    _AngleConfig(
      label: 'Top / Back',
      instruction: 'Capture the BACK / TOP view',
      icon: Icons.vertical_align_top,
      rotation: 0,
    ),
    _AngleConfig(
      label: 'Farmer in Frame',
      instruction: 'Include YOURSELF with the animal in this photo',
      icon: Icons.person,
      rotation: 0,
    ),
  ];

  Future<void> _capturePhoto() async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (image != null && mounted) {
        // Capture GPS simultaneously
        final gps = await GpsService.captureLocation();

        final photo = CapturedPhoto(
          path: image.path,
          angleLabel: _angles[_currentAngle].label,
          gps: gps,
          capturedAt: DateTime.now(),
        );

        setState(() {
          _photos.add(photo);
          if (_currentAngle < _angles.length - 1) {
            _currentAngle++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _retake(int index) {
    setState(() {
      _photos.removeAt(index);
      _currentAngle = index;
    });
  }

  void _submit() {
    widget.onComplete?.call(_photos);
    Navigator.of(context).pop(_photos);
  }

  @override
  Widget build(BuildContext context) {
    final allCaptured = _photos.length >= _angles.length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('360° Photo Capture (${_photos.length}/${_angles.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: allCaptured ? _buildReview() : _buildCaptureView(),
    );
  }

  Widget _buildCaptureView() {
    final angle = _angles[_currentAngle];

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _photos.length / _angles.length,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
          minHeight: 6,
        ),

        // Angle diagram
        Padding(
          padding: const EdgeInsets.all(16),
          child: _AngleDiagram(
            currentAngle: _currentAngle,
            completedCount: _photos.length,
          ),
        ),

        // Instruction
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(angle.icon, color: AppColors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shot ${_currentAngle + 1}: ${angle.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      angle.instruction,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // GPS indicator
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gps_fixed, size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                'GPS + Timestamp will be locked',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Previously captured thumbnails
        if (_photos.isNotEmpty) ...[
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: kIsWeb
                            ? Container(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                child: const Icon(Icons.check, color: Colors.green),
                              )
                            : const Icon(Icons.check, color: Colors.green),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.black54,
                          child: Text(
                            _photos[index].angleLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Capture button
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _capturing ? null : _capturePhoto,
              icon: _capturing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt, size: 24),
              label: Text(
                _capturing ? 'Capturing...' : 'Capture ${angle.label}',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Review All Photos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            photo.angleLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // GPS badge
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.gps_fixed, size: 12, color: Colors.white),
                      ),
                    ),
                    // Retake button
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _retake(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.refresh, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Submit All Photos', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AngleConfig {
  final String label;
  final String instruction;
  final IconData icon;
  final double rotation;

  const _AngleConfig({
    required this.label,
    required this.instruction,
    required this.icon,
    required this.rotation,
  });
}

/// Visual diagram showing the 6 capture angles around the animal.
class _AngleDiagram extends StatelessWidget {
  final int currentAngle;
  final int completedCount;

  const _AngleDiagram({
    required this.currentAngle,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Front', 'Right', 'Rear', 'Left', 'Top', 'You+Animal'];
    const positions = [
      Offset(0.5, 0.05),  // Front (top)
      Offset(0.9, 0.4),   // Right
      Offset(0.5, 0.75),  // Rear (bottom)
      Offset(0.1, 0.4),   // Left
      Offset(0.3, 0.2),   // Top
      Offset(0.7, 0.65),  // Farmer+Animal
    ];

    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          // Animal icon in center
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pets, size: 36, color: AppColors.primary),
            ),
          ),
          // Angle indicators
          ...List.generate(6, (i) {
            final isCompleted = i < completedCount;
            final isCurrent = i == currentAngle;

            return Positioned(
              left: positions[i].dx * (MediaQuery.of(context).size.width - 80),
              top: positions[i].dy * 160,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                          ? AppColors.primary
                          : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isCompleted || isCurrent ? Colors.white : Colors.black54,
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
