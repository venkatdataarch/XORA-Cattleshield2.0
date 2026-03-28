import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Muzzle capture screen using Flutter's camera package with custom overlay.
/// Works reliably on all Android devices.
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
    extends ConsumerState<NativeMuzzleCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  String _statusMessage = 'Initializing camera...';
  Position? _currentPosition;

  final List<MuzzleScanCapture> _captures = [];
  int _currentAngle = 0;

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
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _getLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      setState(() => _isCameraReady = false);
      // Dispose after setState to avoid rebuild issues
      Future.microtask(() {
        controller.dispose();
        _cameraController = null;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      // Step 1: Request camera permission explicitly
      var cameraStatus = await Permission.camera.status;
      debugPrint('Camera permission status: $cameraStatus');

      if (cameraStatus.isDenied) {
        cameraStatus = await Permission.camera.request();
        debugPrint('Camera permission after request: $cameraStatus');
      }

      if (cameraStatus.isPermanentlyDenied) {
        if (!mounted) return;
        setState(() => _statusMessage = 'Camera permission denied');
        _showPermissionDeniedDialog();
        return;
      }

      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        setState(() => _statusMessage = 'Camera permission required');
        return;
      }

      // Step 2: Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _statusMessage = 'No camera found');
        return;
      }

      // Find back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Step 3: Initialize camera controller
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      // Lock focus mode for close-up muzzle shots
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _statusMessage = 'Position muzzle in the guide';
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _statusMessage = 'Camera error — tap to retry');
      }
    }
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'CattleShield needs camera access to scan animal muzzles. '
          'Please grant camera permission in your phone settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close camera screen
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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

  // YOLOv8 Platform Channel
  static const _yoloChannel = MethodChannel('com.xora.cattleshield/muzzle_camera');
  double _detectionConfidence = 0;
  String _detectedClass = '';
  bool _yoloAvailable = true;

  /// Run YOLOv8 detection on an image file (non-blocking, never crashes)
  Future<Map<String, dynamic>?> _runYoloDetection(String imagePath) async {
    if (!_yoloAvailable) return null;

    try {
      final result = await _yoloChannel.invokeMethod('detectMuzzle', {
        'imagePath': imagePath,
        'species': widget.species,
      });
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } on MissingPluginException {
      // Platform channel not registered (e.g., on web or emulator)
      _yoloAvailable = false;
      debugPrint('YOLOv8: MissingPluginException — disabling');
      return null;
    } on PlatformException catch (e) {
      // Native side error (ONNX model failed, bitmap decode error, etc.)
      debugPrint('YOLOv8 PlatformException: ${e.message}');
      // Don't disable — might work on next frame
      return null;
    } catch (e) {
      debugPrint('YOLOv8 detection error: $e');
      return null;
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    if (_cameraController == null || !_isCameraReady) {
      if (mounted) {
        setState(() => _statusMessage = 'Camera not ready — please wait');
      }
      return;
    }
    if (!_cameraController!.value.isInitialized) {
      if (mounted) {
        setState(() => _statusMessage = 'Camera initializing...');
      }
      return;
    }

    setState(() => _isCapturing = true);

    try {
      // Take picture with safety check
      final XFile xFile;
      try {
        xFile = await _cameraController!.takePicture();
      } catch (cameraError) {
        debugPrint('Camera takePicture error: $cameraError');
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _statusMessage = 'Camera error — tap to retry';
          });
        }
        return;
      }

      // Verify file exists
      if (!await File(xFile.path).exists()) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _statusMessage = 'Photo not saved — tap to retry';
          });
        }
        return;
      }

      // Check if still mounted after async gap
      if (!mounted) return;

      // Run YOLOv8 detection (optional — never crashes the app)
      try {
        final detection = await _runYoloDetection(xFile.path);

        if (mounted && detection != null && _yoloAvailable) {
          final detected = detection['detected'] as bool? ?? false;
          final confidence = (detection['confidence'] as num?)?.toDouble() ?? 0;
          final message = detection['message'] as String? ?? '';
          final className = detection['className'] as String? ?? '';

          setState(() {
            _detectionConfidence = confidence;
            _detectedClass = className;
          });

          // If confidence too low, reject and ask to retake
          if (!detected || confidence < 25) {
            setState(() {
              _isCapturing = false;
              _statusMessage = 'No muzzle detected — try again. $message';
            });
            // Delete the bad photo safely
            try { await File(xFile.path).delete(); } catch (_) {}
            return;
          }
        }
      } catch (yoloError) {
        // YOLOv8 failed — continue without detection (still save the photo)
        debugPrint('YOLOv8 post-capture error (ignored): $yoloError');
      }

      if (!mounted) return;

      // Read bytes for hash
      final bytes = await File(xFile.path).readAsBytes();
      final hash = sha256.convert(bytes).toString();

      // IST timestamp
      final now = DateTime.now();
      final istTimestamp = now.toLocal().toIso8601String();

      final capture = MuzzleScanCapture(
        imagePath: xFile.path,
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
        _isCapturing = false;

        if (_currentAngle < 2) {
          _currentAngle++;
          _statusMessage = _yoloAvailable && _detectedClass.isNotEmpty
              ? 'YOLOv8: $_detectedClass (${_detectionConfidence.toStringAsFixed(0)}%) ✓ Now capture ${_angleLabels[_currentAngle]}'
              : 'Great! Now capture ${_angleLabels[_currentAngle]}';
        } else {
          _statusMessage = 'All 3 scans complete!';
        }
      });

      // If all 3 captured, return results after brief delay
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
      setState(() {
        _isCapturing = false;
        _statusMessage = 'Capture failed: $e';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _cameraController?.dispose();
    } catch (e) {
      debugPrint('Camera dispose error: $e');
    }
    _cameraController = null;
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
            _buildHeader(),
            Expanded(
              child: allCaptured ? _buildReviewGrid() : _buildCameraView(),
            ),
            _buildControls(allCaptured),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_isCameraReady && _cameraController != null)
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize?.height ?? 1920,
                height: _cameraController!.value.previewSize?.width ?? 1080,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          ),

        // Muzzle guide overlay
        if (_isCameraReady)
          CustomPaint(
            size: Size.infinite,
            painter: _MuzzleOverlayPainter(
              species: widget.species,
              angleIndex: _currentAngle,
            ),
          ),

        // Status text overlay
        if (!_isCameraReady)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.secondary),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
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
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
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
          const SizedBox(height: 10),

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
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ] else
            Text(
              'All 3 scans captured!',
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

          const SizedBox(height: 6),

          Text(
            _statusMessage,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),

          // YOLOv8 detection info
          if (_detectionConfidence > 0 && _yoloAvailable) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'YOLOv8',
                    style: GoogleFonts.robotoMono(
                      color: Colors.blue[300],
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_detectedClass ${_detectionConfidence.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: _detectionConfidence > 50 ? Colors.green[400] : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _detectionConfidence > 50 ? Icons.check_circle : Icons.warning,
                  color: _detectionConfidence > 50 ? Colors.green[400] : Colors.orange,
                  size: 14,
                ),
              ],
            ),
          ],

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

          const SizedBox(height: 12),

          // Capture button
          if (!allCaptured)
            GestureDetector(
              onTap: _isCameraReady && !_isCapturing ? _capturePhoto : null,
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
                        ? Colors.grey
                        : _isCameraReady
                            ? Colors.red
                            : Colors.grey[700],
                  ),
                  child: _isCapturing
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

          if (!allCaptured)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tap to capture',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              ),
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
                  decoration: BoxDecoration(
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

    // Guide zone
    final guideRect = species == 'mule'
        ? Rect.fromLTRB(w * 0.15, h * 0.25, w * 0.85, h * 0.65)
        : Rect.fromLTRB(w * 0.2, h * 0.28, w * 0.8, h * 0.62);

    // Dim outside guide
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final guidePath = Path();
    if (species == 'mule') {
      guidePath.addRRect(RRect.fromRectAndRadius(guideRect, const Radius.circular(40)));
    } else {
      guidePath.addOval(guideRect);
    }

    // Draw dim overlay with cutout
    canvas.save();
    canvas.clipPath(guidePath, doAntiAlias: true);
    canvas.restore();

    // Full screen dim
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    final combinedPath = Path.combine(PathOperation.difference, fullPath, guidePath);
    canvas.drawPath(combinedPath, dimPaint);

    // Guide border
    final guidePaint = Paint()
      ..color = Colors.white
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
    const len = 25.0;

    canvas.drawLine(Offset(guideRect.left, guideRect.top), Offset(guideRect.left + len, guideRect.top), cornerPaint);
    canvas.drawLine(Offset(guideRect.left, guideRect.top), Offset(guideRect.left, guideRect.top + len), cornerPaint);

    canvas.drawLine(Offset(guideRect.right - len, guideRect.top), Offset(guideRect.right, guideRect.top), cornerPaint);
    canvas.drawLine(Offset(guideRect.right, guideRect.top), Offset(guideRect.right, guideRect.top + len), cornerPaint);

    canvas.drawLine(Offset(guideRect.left, guideRect.bottom), Offset(guideRect.left + len, guideRect.bottom), cornerPaint);
    canvas.drawLine(Offset(guideRect.left, guideRect.bottom - len), Offset(guideRect.left, guideRect.bottom), cornerPaint);

    canvas.drawLine(Offset(guideRect.right - len, guideRect.bottom), Offset(guideRect.right, guideRect.bottom), cornerPaint);
    canvas.drawLine(Offset(guideRect.right, guideRect.bottom - len), Offset(guideRect.right, guideRect.bottom), cornerPaint);

    // Guide label
    final labelText = species == 'mule' ? 'Mule Nose + Lip Area' : 'Cow Muzzle (Nasal Ridge)';
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset((w - textPainter.width) / 2, guideRect.top - 35));

    // Bottom instruction
    final instructPainter = TextPainter(
      text: const TextSpan(
        text: 'Position muzzle in the guide',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    instructPainter.paint(canvas, Offset((w - instructPainter.width) / 2, guideRect.bottom + 15));
  }

  @override
  bool shouldRepaint(covariant _MuzzleOverlayPainter old) =>
      old.species != species || old.angleIndex != angleIndex;
}
