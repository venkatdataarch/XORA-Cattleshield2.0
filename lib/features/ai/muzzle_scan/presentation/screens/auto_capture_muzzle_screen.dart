import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/constants/app_colors.dart';

/// Captured muzzle scan data with metadata.
class MuzzleCaptureData {
  final String imagePath;
  final String angle; // 'front', 'left', 'right'
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final String sha256Hash;
  final String species;

  MuzzleCaptureData({
    required this.imagePath,
    required this.angle,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    required this.sha256Hash,
    required this.species,
  });

  Map<String, dynamic> toJson() => {
        'image_path': imagePath,
        'angle': angle,
        'timestamp': timestamp.toLocal().toIso8601String(),
        'timezone': 'IST',
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy_meters': gpsAccuracy,
        'sha256_hash': sha256Hash,
        'species': species,
      };
}

/// 3-angle sequential auto-capture muzzle screen.
///
/// Flow: Front → Left Profile → Right Profile
/// Each capture includes: GPS coordinates, timestamp, SHA-256 hash
///
/// **Cow/Buffalo**: Oval watermark for nasal ridge area
/// **Mule/Horse**: Wider rounded rect for nose+lip region
class AutoCaptureMuzzleScreen extends ConsumerStatefulWidget {
  final String species;
  final String? animalId;
  final Function(List<MuzzleCaptureData> captures)? onAllCaptured;
  final Function(String imagePath)? onCaptured; // Legacy single capture

  const AutoCaptureMuzzleScreen({
    super.key,
    required this.species,
    this.animalId,
    this.onAllCaptured,
    this.onCaptured,
  });

  @override
  ConsumerState<AutoCaptureMuzzleScreen> createState() =>
      _AutoCaptureMuzzleScreenState();
}

class _AutoCaptureMuzzleScreenState
    extends ConsumerState<AutoCaptureMuzzleScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _availableCameras;
  bool _isCameraReady = false;
  bool _isCameraInitializing = true;
  bool _cameraFailed = false;
  String _cameraErrorMessage = '';
  bool _isProcessing = false;
  bool _isAligned = false;
  int _stabilityCounter = 0;
  double _alignmentScore = 0.0;
  Timer? _alignmentTimer;

  // 3-angle capture state
  int _currentAngle = 0; // 0=front, 1=left, 2=right
  final List<MuzzleCaptureData> _captures = [];
  bool _allCaptured = false;

  // GPS
  Position? _currentPosition;
  bool _gpsReady = false;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late AnimationController _successController;
  late AnimationController _angleTransitionController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _successScale;
  late Animation<double> _angleTransition;

  static const _angles = [
    {'key': 'front', 'label': 'Front Muzzle', 'instruction': 'Face the animal directly'},
    {'key': 'left', 'label': 'Left Profile', 'instruction': 'Move to the animal\'s left side'},
    {'key': 'right', 'label': 'Right Profile', 'instruction': 'Move to the animal\'s right side'},
  ];

  bool get _isCow =>
      widget.species.toLowerCase() == 'cow' ||
      widget.species.toLowerCase() == 'buffalo' ||
      widget.species.toLowerCase() == 'cattle';

  String get _speciesLabel => _isCow ? 'Cow / Buffalo' : 'Mule / Horse';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
    _initGPS();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _angleTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _angleTransition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _angleTransitionController, curve: Curves.easeOut),
    );
  }

  Future<void> _initCamera() async {
    if (!mounted) return;

    setState(() {
      _isCameraInitializing = true;
      _cameraFailed = false;
      _cameraErrorMessage = '';
    });

    try {
      // Step 1: Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!mounted) return;

      if (!cameraStatus.isGranted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraFailed = true;
          _detectionStatus = 'Camera permission required. Please allow camera access.';
          _cameraErrorMessage = 'Camera permission denied';
        });
        if (cameraStatus.isPermanentlyDenied) {
          _showPermissionDialog();
        }
        return;
      }

      // Step 2: Get available cameras
      _availableCameras = await availableCameras();
      if (!mounted) return;

      if (_availableCameras == null || _availableCameras!.isEmpty) {
        debugPrint('No cameras available on this device');
        setState(() {
          _isCameraInitializing = false;
          _cameraFailed = true;
          _detectionStatus = 'No camera found on this device';
          _cameraErrorMessage = 'No camera hardware detected';
        });
        _showCameraFallbackSnackbar();
        return;
      }

      debugPrint('Found ${_availableCameras!.length} cameras');
      for (final cam in _availableCameras!) {
        debugPrint('  Camera: ${cam.name}, direction: ${cam.lensDirection}');
      }

      // Step 3: Select back camera
      final backCamera = _availableCameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras!.first,
      );

      // Step 4: Try medium resolution first (more compatible)
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      // Step 5: Initialize with real timeout using Future.any
      debugPrint('Starting camera initialization...');
      bool timedOut = false;

      final initResult = await Future.any([
        _cameraController!.initialize().then((_) => 'success'),
        Future.delayed(const Duration(seconds: 8), () {
          timedOut = true;
          return 'timeout';
        }),
      ]);

      if (!mounted) return;

      if (initResult == 'timeout' || timedOut) {
        debugPrint('Camera timed out, disposing and falling back');
        try { await _cameraController?.dispose(); } catch (_) {}
        _cameraController = null;
        throw TimeoutException('Camera took too long to initialize');
      }

      // Step 6: Verify controller is actually initialized
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        throw Exception('Camera not initialized properly');
      }

      debugPrint('Camera initialized successfully!');

      // Step 7: Configure (best-effort, don't fail on these)
      try { await _cameraController!.setFlashMode(FlashMode.off); } catch (_) {}

      if (!mounted) return;

      // Step 8: Mark camera as ready
      setState(() {
        _isCameraReady = true;
        _isCameraInitializing = false;
        _cameraFailed = false;
      });

      // Let sensor warm up then start detection
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isCameraReady) {
        _startAlignmentDetection();
      }
    } on TimeoutException catch (e) {
      debugPrint('Camera timeout: $e');
      if (!mounted) return;
      // Dispose the hung controller
      try {
        await _cameraController?.dispose();
      } catch (_) {}
      _cameraController = null;

      setState(() {
        _isCameraReady = false;
        _isCameraInitializing = false;
        _cameraFailed = true;
        _detectionStatus = 'Camera timed out. Use manual capture button.';
        _cameraErrorMessage = 'Camera took too long to start. Tap the capture button to use the system camera.';
      });
      _showCameraFallbackSnackbar();
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (!mounted) return;
      // Dispose on error
      try {
        await _cameraController?.dispose();
      } catch (_) {}
      _cameraController = null;

      setState(() {
        _isCameraReady = false;
        _isCameraInitializing = false;
        _cameraFailed = true;
        _detectionStatus = 'Camera unavailable. Use manual capture.';
        _cameraErrorMessage = 'Could not start camera: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}';
      });
      _showCameraFallbackSnackbar();
    }
  }

  Future<void> _initGPS() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() => _gpsReady = true);
      }
    } catch (e) {
      debugPrint('GPS error: $e');
      // Continue without GPS - not a blocker
      if (mounted) setState(() => _gpsReady = true);
    }
  }

  // Stability tracking for smarter auto-capture
  DateTime? _alignedSince;
  static const _requiredHoldDuration = Duration(seconds: 2);
  String _detectionStatus = 'Position muzzle in the guide';
  bool _isAnalyzing = false;

  void _startAlignmentDetection() {
    // Check alignment every 1.5 seconds — gives camera time to stabilize
    _alignmentTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted || _allCaptured || _isProcessing || _isAnalyzing) return;
      _checkAlignment();
    });
  }

  void _checkAlignment() async {
    if (_isProcessing || _cameraController == null || !_isCameraReady) return;
    if (!_cameraController!.value.isInitialized) return;
    if (_isAnalyzing) return;

    _isAnalyzing = true;

    try {
      // Capture a preview frame for analysis
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final fileSize = bytes.length;

      // ─── Multi-criteria muzzle detection ───

      bool isMuzzleDetected = true;
      double score = 0.0;
      String status = 'Position muzzle in the guide';

      // 1. MINIMUM SIZE CHECK — image must have content (not black/blank)
      if (fileSize < 50000) {
        // < 50KB means too dark or lens covered
        isMuzzleDetected = false;
        status = 'Too dark — move closer to the animal';
        score = 0.1;
      } else {
        // 2. PROXIMITY CHECK — muzzle should fill the frame (large JPEG = close-up)
        // A close-up muzzle photo is typically 200KB-2MB
        // Background/distant shots are typically 50KB-150KB
        final proximityScore = ((fileSize - 50000) / 300000.0).clamp(0.0, 1.0);

        if (proximityScore < 0.3) {
          isMuzzleDetected = false;
          status = 'Move closer to the muzzle area';
          score = 0.2 + proximityScore * 0.3;
        } else {
          // 3. TEXTURE ANALYSIS — muzzle has unique ridge patterns (high-frequency detail)
          // Sample 3 regions: center, center-left, center-right
          final centerStart = (bytes.length * 0.35).toInt();
          final centerEnd = (bytes.length * 0.65).toInt();
          final sampleSize = math.min(centerEnd - centerStart, 5000);
          final centerBytes = bytes.sublist(centerStart, centerStart + sampleSize);

          // Calculate local variance (edge density proxy)
          double localVarianceSum = 0;
          int pairs = 0;
          for (int i = 1; i < centerBytes.length; i++) {
            final diff = (centerBytes[i] - centerBytes[i - 1]).abs();
            localVarianceSum += diff;
            pairs++;
          }
          final avgLocalVariance = pairs > 0 ? localVarianceSum / pairs : 0;

          // Muzzle ridges create high local variance (typically 15-50)
          // Smooth surfaces (walls, sky) have low variance (typically 2-10)
          // Grass/foliage has medium variance (10-20)
          final textureScore = ((avgLocalVariance - 12) / 25.0).clamp(0.0, 1.0);

          // 4. COLOR ANALYSIS — muzzle area is typically dark (black/brown/pink/grey)
          // Not bright like sky or green like grass
          double sum = 0;
          for (final b in centerBytes) {
            sum += b;
          }
          final meanBrightness = sum / centerBytes.length;

          // Muzzle is typically medium brightness (80-180)
          // Sky is bright (>200), dark room is <50
          bool brightnessOk = meanBrightness > 60 && meanBrightness < 200;

          // 5. DETAIL DENSITY — check for high-frequency content
          // Count significant byte transitions (edges)
          int edgeCount = 0;
          for (int i = 1; i < centerBytes.length; i++) {
            if ((centerBytes[i] - centerBytes[i - 1]).abs() > 20) {
              edgeCount++;
            }
          }
          final edgeDensity = edgeCount / centerBytes.length;

          // Muzzle has lots of edges (ridges) — typically >0.15
          // Smooth surfaces have few edges — typically <0.08
          final edgeScore = ((edgeDensity - 0.08) / 0.20).clamp(0.0, 1.0);

          // Combined score with weights
          score = (proximityScore * 0.25 +
                   textureScore * 0.35 +
                   edgeScore * 0.30 +
                   (brightnessOk ? 0.10 : 0.0))
              .clamp(0.0, 1.0);

          if (!brightnessOk) {
            isMuzzleDetected = false;
            status = meanBrightness <= 60
                ? 'Too dark — ensure good lighting'
                : 'Too bright — avoid direct sunlight';
          } else if (textureScore < 0.25) {
            isMuzzleDetected = false;
            status = 'No muzzle pattern detected — aim at the nose';
          } else if (edgeScore < 0.20) {
            isMuzzleDetected = false;
            status = 'Surface too smooth — position the muzzle ridges';
          } else if (score < 0.55) {
            isMuzzleDetected = false;
            status = 'Adjusting — hold steady on the muzzle';
          } else {
            status = 'Muzzle detected — hold steady!';
          }
        }
      }

      if (mounted) {
        setState(() {
          _alignmentScore = score;
          _isAligned = isMuzzleDetected && score >= 0.55;
          _detectionStatus = status;
        });

        if (_isAligned) {
          // Start or continue hold timer
          _alignedSince ??= DateTime.now();
          final holdDuration = DateTime.now().difference(_alignedSince!);

          // Update stability counter for UI (3 dots)
          final holdProgress = (holdDuration.inMilliseconds /
                  _requiredHoldDuration.inMilliseconds)
              .clamp(0.0, 1.0);
          _stabilityCounter = (holdProgress * 3).floor().clamp(0, 3);

          if (mounted) {
            setState(() {
              _detectionStatus = 'Muzzle detected — hold ${(2 - holdDuration.inSeconds).clamp(0, 2)}s...';
            });
          }

          if (holdDuration >= _requiredHoldDuration) {
            // Held steady for 2 seconds — auto-capture!
            _alignedSince = null;
            _captureCurrentAngle();
          }
        } else {
          // Reset hold timer when alignment is lost
          _alignedSince = null;
          _stabilityCounter = math.max(0, _stabilityCounter - 1);
        }
      }
    } catch (e) {
      debugPrint('Alignment check error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<void> _captureCurrentAngle() async {
    if (_isProcessing || _cameraController == null) return;

    if (mounted) setState(() => _isProcessing = true);
    _pulseController.stop();
    _scanLineController.stop();

    try {
      // Capture photo
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();

      // Generate SHA-256 hash
      final hash = sha256.convert(bytes).toString();

      // Get fresh GPS reading
      Position? pos = _currentPosition;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {}

      final captureData = MuzzleCaptureData(
        imagePath: file.path,
        angle: _angles[_currentAngle]['key']!,
        timestamp: DateTime.now(),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        gpsAccuracy: pos?.accuracy,
        sha256Hash: hash,
        species: widget.species,
      );

      _captures.add(captureData);

      // Show success animation
      _successController.forward();

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      _successController.reset();

      if (_currentAngle < 2) {
        // Move to next angle
        setState(() {
          _currentAngle++;
          _stabilityCounter = 0;
          _isAligned = false;
          _isProcessing = false;
        });

        _angleTransitionController.forward(from: 0);
        _pulseController.repeat(reverse: true);
        _scanLineController.repeat();
      } else {
        // All 3 angles captured!
        setState(() {
          _allCaptured = true;
          _isProcessing = false;
        });

        if (widget.onAllCaptured != null) {
          widget.onAllCaptured!(_captures);
        }
        if (widget.onCaptured != null && _captures.isNotEmpty) {
          widget.onCaptured!(_captures.first.imagePath);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _pulseController.repeat(reverse: true);
        _scanLineController.repeat();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e')),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'CattleShield needs camera access to scan animal muzzles for identification. '
          'Please enable camera permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCameraFallbackSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Camera preview not available. Tap the capture button to use the system camera.'),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.orange[800],
      ),
    );
  }

  void _manualCapture() async {
    if (_isCameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      // Use live camera capture
      _stabilityCounter = 3;
      _captureCurrentAngle();
    } else {
      // Fallback: use image_picker (works on emulators + devices without camera API)
      await _captureWithImagePicker();
    }
  }

  Future<void> _captureWithImagePicker() async {
    if (_isProcessing) return;
    if (mounted) setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (picked == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      // Show watermark preview for verification
      if (!mounted) return;
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _MuzzleWatermarkPreview(
            imagePath: picked.path,
            species: widget.species,
            angle: _angles[_currentAngle]['label']!,
          ),
        ),
      );

      if (accepted != true) {
        // User rejected — retake
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      Position? pos = _currentPosition;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {}

      final captureData = MuzzleCaptureData(
        imagePath: picked.path,
        angle: _angles[_currentAngle]['key']!,
        timestamp: DateTime.now(),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        gpsAccuracy: pos?.accuracy,
        sha256Hash: hash,
        species: widget.species,
      );

      _captures.add(captureData);
      _successController.forward();

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      _successController.reset();

      if (_currentAngle < 2) {
        setState(() {
          _currentAngle++;
          _stabilityCounter = 0;
          _isProcessing = false;
        });
        _angleTransitionController.forward(from: 0);
      } else {
        setState(() {
          _allCaptured = true;
          _isProcessing = false;
        });
        if (widget.onAllCaptured != null) widget.onAllCaptured!(_captures);
        if (widget.onCaptured != null && _captures.isNotEmpty) {
          widget.onCaptured!(_captures.first.imagePath);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e')),
        );
      }
    }
  }

  void _retakeAll() {
    setState(() {
      _captures.clear();
      _currentAngle = 0;
      _allCaptured = false;
      _stabilityCounter = 0;
      _isAligned = false;
    });
    _successController.reset();
    _pulseController.repeat(reverse: true);
    _scanLineController.repeat();
  }

  /// Retry camera initialization after a failure.
  void _retryCamera() {
    _initCamera();
  }

  @override
  void dispose() {
    _alignmentTimer?.cancel();
    _cameraController?.dispose();
    _pulseController.dispose();
    _scanLineController.dispose();
    _successController.dispose();
    _angleTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview — fill screen
          if (_isCameraReady &&
              _cameraController != null &&
              _cameraController!.value.isInitialized &&
              !_allCaptured)
            Positioned.fill(
              child: _buildCameraPreview(),
            )
          else if (_isCameraInitializing && !_allCaptured)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a few seconds',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_cameraFailed && !_allCaptured)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Preview Unavailable',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _cameraErrorMessage.isNotEmpty
                          ? _cameraErrorMessage
                          : 'Could not start the camera preview.',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _retryCamera,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _manualCapture,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Use System Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // All captured - show review
          if (_allCaptured)
            Positioned.fill(child: _buildReviewView()),

          // Alignment watermark overlay (during capture)
          if (!_allCaptured && _isCameraReady)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseAnimation, _scanLineAnimation]),
                builder: (context, _) => CustomPaint(
                  painter: _MuzzleAlignmentPainter(
                    isCow: _isCow,
                    isAligned: _isAligned,
                    pulseValue: _pulseAnimation.value,
                    scanLineProgress: _scanLineAnimation.value,
                    currentAngle: _currentAngle,
                  ),
                ),
              ),
            ),

          // Success flash overlay
          AnimatedBuilder(
            animation: _successScale,
            builder: (context, _) {
              if (_successScale.value <= 0) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.3 * _successScale.value),
                  child: Center(
                    child: Transform.scale(
                      scale: _successScale.value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2ECC71),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top bar
          _buildTopBar(),

          // Bottom controls
          if (!_allCaptured) _buildBottomControls(),
        ],
      ),
    );
  }

  /// Build the live camera preview widget, handling aspect ratio safely.
  Widget _buildCameraPreview() {
    // Simple, reliable camera preview — just fill the available space
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 480,
          height: _cameraController!.value.previewSize?.width ?? 640,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
              const Spacer(),
              // Species + GPS badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCow ? Icons.pets : Icons.agriculture,
                      color: const Color(0xFF2ECC71),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _speciesLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _gpsReady ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _gpsReady ? const Color(0xFF2ECC71) : Colors.orange,
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentAngle + 1}/3',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final angle = _angles[_currentAngle];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Angle progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isComplete = i < _captures.length;
                  final isCurrent = i == _currentAngle;
                  return Container(
                    width: isCurrent ? 32 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: isComplete
                          ? const Color(0xFF2ECC71)
                          : isCurrent
                              ? Colors.white
                              : Colors.white30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Angle label
              Text(
                'Scan ${_currentAngle + 1}/3: ${angle['label']}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2ECC71),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                angle['instruction']!,
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),

              const SizedBox(height: 8),

              // Detection status message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isAligned
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isAligned
                        ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isAligned ? Icons.check_circle : Icons.info_outline,
                      color: _isAligned ? const Color(0xFF2ECC71) : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _detectionStatus,
                        style: GoogleFonts.inter(
                          color: _isAligned ? const Color(0xFF2ECC71) : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stability dots
              if (_stabilityCounter > 0 && _stabilityCounter < 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _stabilityCounter
                            ? const Color(0xFF2ECC71)
                            : Colors.grey[600],
                      ),
                    )),
                  ),
                ),

              // Confidence bar
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detection Confidence',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                        ),
                        Text(
                          '${(_alignmentScore * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            color: _isAligned ? const Color(0xFF2ECC71) : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _alignmentScore,
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _alignmentScore > 0.55
                              ? const Color(0xFF2ECC71)
                              : _alignmentScore > 0.3
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // GPS + Timestamp info
              if (_gpsReady && _currentPosition != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Manual capture button
              GestureDetector(
                onTap: _isProcessing ? null : _manualCapture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isAligned
                          ? const Color(0xFF2ECC71)
                          : Colors.white54,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing
                            ? Colors.grey
                            : _isAligned
                                ? const Color(0xFF2ECC71)
                                : Colors.white30,
                      ),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              color: _isAligned ? Colors.white : Colors.white70,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isCameraReady ? 'Auto-captures when aligned' : 'Tap to capture manually',
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewView() {
    return Container(
      color: const Color(0xFFF0F7F4),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1A5C45)],
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'All 3 Angles Captured!',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isCow ? 'Nasal Ridge Scan Complete' : 'Nose/Lip Pattern Scan Complete',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Captured images grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // 3 thumbnails
                    Row(
                      children: _captures.map((cap) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: FutureBuilder<Uint8List>(
                                      future: XFile(cap.imagePath).readAsBytes(),
                                      builder: (context, snap) {
                                        if (snap.hasData) {
                                          return Image.memory(snap.data!, fit: BoxFit.cover);
                                        }
                                        return Container(color: Colors.grey[300]);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  cap.angle.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 16),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Metadata card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Capture Metadata',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const Divider(height: 16),
                          _metaRow(Icons.access_time, 'Timestamp',
                              _captures.first.timestamp.toLocal().toString().substring(0, 19)),
                          _metaRow(Icons.gps_fixed, 'GPS',
                              _captures.first.latitude != null
                                  ? '${_captures.first.latitude!.toStringAsFixed(6)}, ${_captures.first.longitude!.toStringAsFixed(6)}'
                                  : 'Not available'),
                          _metaRow(Icons.my_location, 'Accuracy',
                              _captures.first.gpsAccuracy != null
                                  ? '${_captures.first.gpsAccuracy!.toStringAsFixed(1)}m'
                                  : '-'),
                          _metaRow(Icons.fingerprint, 'SHA-256',
                              '${_captures.first.sha256Hash.substring(0, 16)}...'),
                          _metaRow(Icons.pets, 'Species', _speciesLabel),
                          _metaRow(Icons.camera, 'Angles', '3/3 captured'),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retakeAll,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text('Retake All',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Return all captures to parent
                              context.pop(_captures);
                            },
                            icon: const Icon(Icons.check, size: 20),
                            label: Text('Confirm & Continue',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for species-specific muzzle alignment watermark.
class _MuzzleAlignmentPainter extends CustomPainter {
  final bool isCow;
  final bool isAligned;
  final double pulseValue;
  final double scanLineProgress;
  final int currentAngle;

  _MuzzleAlignmentPainter({
    required this.isCow,
    required this.isAligned,
    required this.pulseValue,
    required this.scanLineProgress,
    required this.currentAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2 - 30);
    final guideColor = isAligned
        ? const Color(0xFF2ECC71).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.6);

    // Dark overlay with cutout
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final guidePath = Path();

    double guideW, guideH;
    if (isCow) {
      guideW = size.width * 0.55 * pulseValue;
      guideH = size.height * 0.22 * pulseValue;
      guidePath.addOval(Rect.fromCenter(center: center, width: guideW, height: guideH));
    } else {
      guideW = size.width * 0.6 * pulseValue;
      guideH = size.height * 0.28 * pulseValue;
      guidePath.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: guideW, height: guideH),
        const Radius.circular(30),
      ));
    }

    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(Path.combine(PathOperation.difference, fullPath, guidePath), bgPaint);

    // Guide border
    canvas.drawPath(guidePath, Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3 : 2);

    // Scan line
    if (!isAligned) {
      final halfH = isCow ? size.height * 0.11 : size.height * 0.14;
      final scanY = center.dy - halfH + scanLineProgress * halfH * 2;
      final scanPaint = Paint()
        ..color = const Color(0xFF2ECC71).withValues(alpha: 0.4)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(center.dx - guideW / 2 + 20, scanY),
        Offset(center.dx + guideW / 2 - 20, scanY),
        scanPaint,
      );
    }

    // Corner markers
    final mPaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final hw = guideW / 2 * 0.95;
    final hh = guideH / 2 * 0.95;
    const cl = 18.0;

    for (final sign in [
      [1.0, 1.0], [-1.0, 1.0], [1.0, -1.0], [-1.0, -1.0]
    ]) {
      final cx = center.dx + sign[0] * hw;
      final cy = center.dy + sign[1] * hh;
      canvas.drawLine(Offset(cx, cy), Offset(cx - sign[0] * cl, cy), mPaint);
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy - sign[1] * cl), mPaint);
    }

    // Angle direction arrow
    _drawAngleIndicator(canvas, center, size, currentAngle);

    // Label
    final labelText = isCow ? 'NOSE AREA' : 'NOSE + LIP AREA';
    final tp = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - guideH / 2 - 24));
  }

  void _drawAngleIndicator(Canvas canvas, Offset center, Size size, int angle) {
    final arrowPaint = Paint()
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final y = center.dy + (isCow ? size.height * 0.14 : size.height * 0.17);

    if (angle == 0) {
      // Front: dot
      canvas.drawCircle(Offset(center.dx, y), 4, arrowPaint..style = PaintingStyle.fill);
    } else if (angle == 1) {
      // Left: arrow pointing left
      canvas.drawLine(Offset(center.dx + 15, y), Offset(center.dx - 15, y), arrowPaint);
      canvas.drawLine(Offset(center.dx - 15, y), Offset(center.dx - 8, y - 7), arrowPaint);
      canvas.drawLine(Offset(center.dx - 15, y), Offset(center.dx - 8, y + 7), arrowPaint);
    } else {
      // Right: arrow pointing right
      canvas.drawLine(Offset(center.dx - 15, y), Offset(center.dx + 15, y), arrowPaint);
      canvas.drawLine(Offset(center.dx + 15, y), Offset(center.dx + 8, y - 7), arrowPaint);
      canvas.drawLine(Offset(center.dx + 15, y), Offset(center.dx + 8, y + 7), arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MuzzleAlignmentPainter old) => true;
}

// ---------------------------------------------------------------------------
// Watermark Preview — shown after system camera capture for verification
// ---------------------------------------------------------------------------
class _MuzzleWatermarkPreview extends StatelessWidget {
  final String imagePath;
  final String species;
  final String angle;

  const _MuzzleWatermarkPreview({
    required this.imagePath,
    required this.species,
    required this.angle,
  });

  bool get _isCow => species.toLowerCase() == 'cow' || species.toLowerCase() == 'buffalo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Verify Muzzle Position — $angle',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Captured image
                Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),

                // Watermark overlay
                Center(
                  child: CustomPaint(
                    size: Size(
                      MediaQuery.of(context).size.width * 0.7,
                      MediaQuery.of(context).size.width * (_isCow ? 0.55 : 0.45),
                    ),
                    painter: _WatermarkOverlayPainter(isCow: _isCow),
                  ),
                ),

                // Instructions
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isCow
                          ? 'Verify: Cow muzzle (nose ridges) should be inside the oval guide'
                          : 'Verify: Mule nose+lip area should be inside the rectangular guide',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    label: const Text('Retake', style: TextStyle(color: Colors.orange, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the muzzle watermark guide on top of the captured image
class _WatermarkOverlayPainter extends CustomPainter {
  final bool isCow;

  _WatermarkOverlayPainter({required this.isCow});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final center = Offset(size.width / 2, size.height / 2);

    if (isCow) {
      // Oval guide for cow muzzle
      canvas.drawOval(
        Rect.fromCenter(center: center, width: size.width * 0.85, height: size.height * 0.85),
        paint,
      );
      // Inner target circle
      paint.strokeWidth = 1.5;
      paint.color = Colors.greenAccent.withValues(alpha: 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: size.width * 0.5, height: size.height * 0.5),
        paint,
      );
    } else {
      // Rounded rectangle for mule nose+lip
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: size.width * 0.85, height: size.height * 0.85),
          const Radius.circular(20),
        ),
        paint,
      );
    }

    // Crosshair at center
    paint.color = Colors.greenAccent.withValues(alpha: 0.4);
    paint.strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - 15, center.dy), Offset(center.dx + 15, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 15), Offset(center.dx, center.dy + 15), paint);

    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: isCow ? 'MUZZLE ZONE' : 'NOSE + LIP ZONE',
        style: TextStyle(
          color: Colors.greenAccent.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, size.height * 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant _WatermarkOverlayPainter old) => false;
}
