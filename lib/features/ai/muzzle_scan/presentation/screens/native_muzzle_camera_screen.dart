import 'dart:io';
import 'dart:math' as math;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/app_colors.dart';

/// Data class for each captured muzzle scan
class MuzzleScanCapture {
  final String imagePath;
  final String angle;
  final String timestamp;
  final String sha256Hash;
  final String species;
  final double? latitude;
  final double? longitude;

  MuzzleScanCapture({
    required this.imagePath,
    required this.angle,
    required this.timestamp,
    required this.sha256Hash,
    required this.species,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'image_path': imagePath,
        'angle': angle,
        'timestamp': timestamp,
        'timezone': 'IST',
        'sha256_hash': sha256Hash,
        'species': species,
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Production-grade muzzle capture screen using CameraAwesome (CameraX backend).
/// 3-angle sequential capture with muzzle guide overlay.
class NativeMuzzleCameraScreen extends ConsumerStatefulWidget {
  final String species;
  final Function(List<MuzzleScanCapture>)? onComplete;

  const NativeMuzzleCameraScreen({
    super.key,
    required this.species,
    this.onComplete,
  });

  @override
  ConsumerState<NativeMuzzleCameraScreen> createState() =>
      _NativeMuzzleCameraScreenState();
}

class _NativeMuzzleCameraScreenState
    extends ConsumerState<NativeMuzzleCameraScreen> {
  Position? _currentPosition;
  final List<MuzzleScanCapture> _captures = [];
  int _currentAngle = 0;
  bool _isProcessing = false;
  String _statusMessage = 'Position muzzle in the guide';

  final _angles = ['front', 'left', 'right'];
  final _angleLabels = ['Front Muzzle', 'Left Side', 'Right Side'];
  final _angleInstructions = [
    'Face the animal directly — capture the nasal ridge',
    'Move to the left side of the animal',
    'Move to the right side of the animal',
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  Future<void> _onPhotoTaken(String filePath) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Photo not saved — try again';
        });
        return;
      }

      // Read bytes for hash
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      // IST timestamp
      final now = DateTime.now();
      final istTimestamp = now.toLocal().toIso8601String();

      final capture = MuzzleScanCapture(
        imagePath: filePath,
        angle: _angles[_currentAngle],
        timestamp: istTimestamp,
        sha256Hash: hash,
        species: widget.species,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      // Haptic feedback
      HapticFeedback.heavyImpact();

      setState(() {
        _captures.add(capture);
        _isProcessing = false;

        if (_currentAngle < 2) {
          _currentAngle++;
          _statusMessage = 'Great! Now capture ${_angleLabels[_currentAngle]}';
        } else {
          _statusMessage = 'All 3 scans complete!';
        }
      });

      // If all 3 captured, return results
      if (_captures.length >= 3) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        if (widget.onComplete != null) {
          widget.onComplete!(_captures);
        } else {
          Navigator.of(context).pop(_captures);
        }
      }
    } catch (e) {
      debugPrint('Capture processing error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error processing — try again';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCaptured = _captures.length >= 3;

    if (allCaptured) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildReviewGrid()),
              _buildCompletedControls(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: CameraAwesomeBuilder.custom(
                saveConfig: SaveConfig.photo(),
                sensorConfig: SensorConfig.single(
                  sensor: Sensor.position(SensorPosition.back),
                  aspectRatio: CameraAspectRatios.ratio_4_3,
                ),
                builder: (cameraState, preview) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Muzzle guide overlay on top of camera preview
                      CustomPaint(
                        painter: _MuzzleOverlayPainter(
                          species: widget.species,
                          angleIndex: _currentAngle,
                        ),
                      ),
                      // Capture button centered at bottom of preview
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _isProcessing
                                ? null
                                : () {
                                    cameraState.when(
                                      onPhotoMode: (photoState) {
                                        photoState.takePhoto().then((request) {
                                          request.when(
                                            single: (single) {
                                              if (single.file != null) {
                                                _onPhotoTaken(single.file!.path);
                                              }
                                            },
                                          );
                                        });
                                      },
                                    );
                                  },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isProcessing ? Colors.grey : Colors.red,
                                ),
                                child: _isProcessing
                                    ? const Padding(
                                        padding: EdgeInsets.all(18),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Processing overlay
                      if (_isProcessing)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets, color: AppColors.secondary, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.species == 'mule' ? 'Mule' : 'Cow / Buffalo',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Text(
              'CameraX',
              style: GoogleFonts.robotoMono(
                color: Colors.green[300],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_currentAngle + 1}/3',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final captured = i < _captures.length;
              final active = i == _currentAngle;
              return Container(
                width: captured ? 36 : 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: captured
                      ? AppColors.secondary
                      : active
                          ? Colors.orange
                          : Colors.grey[700],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          Text(
            'Scan ${_currentAngle + 1}/3: ${_angleLabels[_currentAngle]}',
            style: GoogleFonts.inter(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _angleInstructions[_currentAngle],
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _statusMessage,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),

          // GPS
          if (_currentPosition != null) ...[
            const SizedBox(height: 4),
            Text(
              'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
              style: GoogleFonts.robotoMono(
                color: Colors.green[400],
                fontSize: 11,
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Use the camera button above to capture',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Container(
              width: 36,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AppColors.secondary,
              ),
            )),
          ),
          const SizedBox(height: 12),
          Text(
            'All 3 scans captured! ✓',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Processing...',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewGrid() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: _captures.map((capture) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(capture.imagePath), fit: BoxFit.cover),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    capture.angle.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.check_circle, color: AppColors.secondary, size: 24),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Custom painter for the muzzle guide overlay.
class _MuzzleOverlayPainter extends CustomPainter {
  final String species;
  final int angleIndex;

  _MuzzleOverlayPainter({required this.species, required this.angleIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w == 0 || h == 0) return;

    // Guide zone — centered in the camera preview
    final guideRect = species == 'mule'
        ? Rect.fromLTRB(w * 0.12, h * 0.22, w * 0.88, h * 0.68)
        : Rect.fromLTRB(w * 0.18, h * 0.25, w * 0.82, h * 0.65);

    // Create guide path
    final guidePath = Path();
    if (species == 'mule') {
      guidePath.addRRect(RRect.fromRectAndRadius(guideRect, const Radius.circular(40)));
    } else {
      guidePath.addOval(guideRect);
    }

    // Dim outside guide
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    final combinedPath = Path.combine(PathOperation.difference, fullPath, guidePath);
    canvas.drawPath(combinedPath, dimPaint);

    // Guide border — animated glow effect
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (species == 'mule') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(guideRect, const Radius.circular(40)),
        guidePaint,
      );
    } else {
      canvas.drawOval(guideRect, guidePaint);
    }

    // Corner markers
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const len = 28.0;

    // Top-left
    canvas.drawLine(Offset(guideRect.left, guideRect.top), Offset(guideRect.left + len, guideRect.top), cornerPaint);
    canvas.drawLine(Offset(guideRect.left, guideRect.top), Offset(guideRect.left, guideRect.top + len), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(guideRect.right - len, guideRect.top), Offset(guideRect.right, guideRect.top), cornerPaint);
    canvas.drawLine(Offset(guideRect.right, guideRect.top), Offset(guideRect.right, guideRect.top + len), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(guideRect.left, guideRect.bottom), Offset(guideRect.left + len, guideRect.bottom), cornerPaint);
    canvas.drawLine(Offset(guideRect.left, guideRect.bottom - len), Offset(guideRect.left, guideRect.bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(guideRect.right - len, guideRect.bottom), Offset(guideRect.right, guideRect.bottom), cornerPaint);
    canvas.drawLine(Offset(guideRect.right, guideRect.bottom - len), Offset(guideRect.right, guideRect.bottom), cornerPaint);

    // Guide label at top
    final labelText = species == 'mule' ? 'Mule Nose + Lip Area' : 'Cow Muzzle (Nasal Ridge)';
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset((w - textPainter.width) / 2, guideRect.top - 35));

    // Bottom instruction
    final instructPainter = TextPainter(
      text: const TextSpan(
        text: 'Position muzzle in the guide',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    instructPainter.paint(canvas, Offset((w - instructPainter.width) / 2, guideRect.bottom + 15));
  }

  @override
  bool shouldRepaint(covariant _MuzzleOverlayPainter old) =>
      old.species != species || old.angleIndex != angleIndex;
}
