import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/app_colors.dart';

/// Data class for each captured muzzle scan
class MuzzleScanCapture {
  final String imagePath;
  final String angle; // front, left, right
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

/// Native CameraX + YOLOv8 muzzle capture screen.
/// Uses Android PlatformView for live camera with muzzle detection overlay.
class NativeMuzzleCameraScreen extends ConsumerStatefulWidget {
  final String species; // "cow" or "mule"
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
  static const _channel = MethodChannel('com.xora.cattleshield/muzzle_camera');

  final List<MuzzleScanCapture> _captures = [];
  int _currentAngle = 0;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  double _confidence = 0;
  String _statusMessage = 'Initializing camera...';
  String _detectedClass = '';
  Position? _currentPosition;

  final _angles = ['front', 'left', 'right'];
  final _angleLabels = ['Front Muzzle', 'Left Side', 'Right Side'];
  final _angleInstructions = [
    'Face the animal directly',
    'Move to the left side',
    'Move to the right side',
  ];

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _getLocation();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCameraReady':
          if (mounted) {
            setState(() {
              _isCameraReady = true;
              _statusMessage = 'Position muzzle in the guide';
            });
          }
          break;

        case 'onDetection':
          if (mounted) {
            final args = call.arguments as Map;
            setState(() {
              _confidence = (args['confidence'] as num).toDouble();
              _statusMessage = args['message'] as String;
              _detectedClass = args['className'] as String? ?? '';
            });
          }
          break;

        case 'onPhotoCaptured':
          if (mounted) {
            final args = call.arguments as Map;
            _handleCapture(args);
          }
          break;

        case 'onError':
          if (mounted) {
            final error = call.arguments as String;
            setState(() => _statusMessage = error);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
      }
    });
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  void _handleCapture(Map args) {
    final capture = MuzzleScanCapture(
      imagePath: args['path'] as String,
      angle: _angles[_currentAngle],
      timestamp: args['timestamp'] as String,
      sha256Hash: args['sha256'] as String,
      species: args['species'] as String,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );

    setState(() {
      _captures.add(capture);
      _isCapturing = false;

      if (_currentAngle < 2) {
        // Move to next angle
        _currentAngle++;
        _confidence = 0;
        _statusMessage = 'Great! Now capture ${_angleLabels[_currentAngle]}';
      } else {
        // All 3 angles captured!
        _statusMessage = 'All scans complete!';
      }
    });

    // Haptic feedback
    HapticFeedback.heavyImpact();

    // If all 3 captured, return results
    if (_captures.length == 3) {
      Future.delayed(const Duration(seconds: 1), () {
        if (widget.onComplete != null) {
          widget.onComplete!(_captures);
        } else {
          Navigator.of(context).pop(_captures);
        }
      });
    }
  }

  void _manualCapture() {
    if (_isCapturing || !_isCameraReady) return;
    setState(() => _isCapturing = true);

    try {
      _channel.invokeMethod('capturePhoto');
    } catch (e) {
      setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    try {
      _channel.invokeMethod('stopCamera');
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCaptured = _captures.length >= 3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────
            _buildHeader(),

            // ─── Camera View ─────────────────
            Expanded(
              child: Stack(
                children: [
                  // Native CameraX view with YOLOv8 overlay
                  if (!allCaptured && !kIsWeb)
                    AndroidView(
                      viewType: 'muzzle-camera-view',
                      creationParams: {'species': widget.species},
                      creationParamsCodec: const StandardMessageCodec(),
                    )
                  else if (allCaptured)
                    _buildReviewGrid()
                  else
                    _buildFallbackMessage(),

                  // Capture animation overlays
                  if (!_isCameraReady && !allCaptured)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading YOLOv8 model...',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ─── Controls ────────────────────
            _buildControls(allCaptured),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
          ),

          const SizedBox(width: 12),

          // Species badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.species == 'mule' ? Icons.pets : Icons.pets,
                  color: AppColors.secondary,
                  size: 16,
                ),
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

          // YOLOv8 badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'YOLOv8',
              style: GoogleFonts.robotoMono(
                color: Colors.blue[300],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Progress
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

  Widget _buildControls(bool allCaptured) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Capture progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final captured = i < _captures.length;
              final active = i == _currentAngle && !allCaptured;
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

          const SizedBox(height: 12),

          // Angle label
          if (!allCaptured) ...[
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
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
          ] else ...[
            Text(
              'All 3 scans captured!',
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Detection status
          Text(
            _statusMessage,
            style: GoogleFonts.inter(
              color: _confidence > 60 ? AppColors.secondary : Colors.white54,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),

          if (_detectedClass.isNotEmpty)
            Text(
              'Detected: $_detectedClass (${_confidence.toInt()}%)',
              style: GoogleFonts.robotoMono(
                color: Colors.blue[300],
                fontSize: 11,
              ),
            ),

          const SizedBox(height: 8),

          // Confidence bar
          if (!allCaptured)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_confidence / 100).clamp(0, 1),
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _confidence > 70
                      ? AppColors.secondary
                      : _confidence > 40
                          ? Colors.orange
                          : Colors.red,
                ),
                minHeight: 6,
              ),
            ),

          const SizedBox(height: 16),

          // GPS info
          if (_currentPosition != null)
            Text(
              'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
              style: GoogleFonts.robotoMono(
                color: Colors.green[400],
                fontSize: 11,
              ),
            ),

          const SizedBox(height: 16),

          // Manual capture button
          if (!allCaptured)
            GestureDetector(
              onTap: _isCameraReady ? _manualCapture : null,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isCameraReady ? Colors.white : Colors.grey,
                    width: 4,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing
                        ? Colors.red
                        : _isCameraReady
                            ? Colors.white
                            : Colors.grey[700],
                  ),
                ),
              ),
            ),

          if (!allCaptured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _isCameraReady
                    ? 'Auto-captures when muzzle detected'
                    : 'Camera initializing...',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewGrid() {
    return Container(
      color: Colors.black,
      child: GridView.count(
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
                Image.file(
                  File(capture.imagePath),
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capture.angle.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          capture.timestamp.substring(11, 19),
                          style: GoogleFonts.robotoMono(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFallbackMessage() {
    return Center(
      child: Text(
        'Native camera only available on Android',
        style: GoogleFonts.inter(color: Colors.white54),
      ),
    );
  }
}
