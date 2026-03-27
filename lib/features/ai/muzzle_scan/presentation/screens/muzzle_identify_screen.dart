import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../farmer/animal/domain/animal_model.dart';
import '../providers/muzzle_scan_provider.dart';

/// Muzzle identification screen with real camera + watermark overlay.
///
/// Captures a front muzzle image, matches against DB, and shows results.
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

class _MuzzleIdentifyScreenState extends ConsumerState<MuzzleIdentifyScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isAligned = false;
  int _stabilityCounter = 0;
  Timer? _alignmentTimer;
  String? _capturedPath;
  bool _showResult = false;

  // Species selection for identify mode
  String _selectedSpecies = 'cow';

  // Animations
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _successScale;

  bool get _isCow =>
      _selectedSpecies == 'cow' ||
      _selectedSpecies == 'buffalo' ||
      _selectedSpecies == 'cattle';

  @override
  void initState() {
    super.initState();
    _selectedSpecies = widget.species.name;
    _initAnimations();
    _initCamera();
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
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
        _startAlignmentDetection();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startAlignmentDetection() {
    _alignmentTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || _capturedPath != null || _isProcessing) return;
      _checkAlignment();
    });
  }

  void _checkAlignment() async {
    if (_isProcessing || _cameraController == null || !_isCameraReady) return;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final fileSize = bytes.length;

      final hasContent = fileSize > 30000;
      double score = 0.0;

      if (hasContent && bytes.length > 1000) {
        final centerStart = (bytes.length * 0.4).toInt();
        final centerEnd = (bytes.length * 0.6).toInt();
        final centerBytes = bytes.sublist(centerStart, centerEnd);

        double sum = 0;
        double sumSq = 0;
        for (final b in centerBytes) {
          sum += b;
          sumSq += b * b;
        }
        final mean = sum / centerBytes.length;
        final variance = (sumSq / centerBytes.length) - (mean * mean);
        score = (variance / 3000.0).clamp(0.0, 1.0);
      }

      if (mounted) {
        setState(() => _isAligned = score > 0.5);

        if (_isAligned) {
          _stabilityCounter++;
          if (_stabilityCounter >= 3) {
            _autoCapture();
          }
        } else {
          _stabilityCounter = math.max(0, _stabilityCounter - 1);
        }
      }
    } catch (e) {
      debugPrint('Alignment check error: $e');
    }
  }

  Future<void> _autoCapture() async {
    if (_isProcessing || _cameraController == null) return;

    setState(() => _isProcessing = true);
    _pulseController.stop();
    _scanLineController.stop();

    try {
      final file = await _cameraController!.takePicture();
      _successController.forward();

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() {
          _capturedPath = file.path;
          _isProcessing = false;
        });
        _alignmentTimer?.cancel();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _pulseController.repeat(reverse: true);
        _scanLineController.repeat();
      }
    }
  }

  void _manualCapture() async {
    if (_isProcessing || _cameraController == null) return;
    setState(() => _isProcessing = true);

    try {
      final file = await _cameraController!.takePicture();
      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() {
          _capturedPath = file.path;
          _isProcessing = false;
        });
        _alignmentTimer?.cancel();
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _retake() {
    setState(() {
      _capturedPath = null;
      _showResult = false;
      _stabilityCounter = 0;
      _isAligned = false;
    });
    _successController.reset();
    _pulseController.repeat(reverse: true);
    _scanLineController.repeat();
    ref.read(muzzleScanProvider.notifier).reset();
    _startAlignmentDetection();
  }

  void _submitForVerification() {
    if (_capturedPath == null) return;

    ref.read(muzzleScanProvider.notifier).addCapture(
          MuzzleAngle.front,
          _capturedPath!,
        );
    ref.read(muzzleScanProvider.notifier).submitForIdentification(
          widget.species,
          claimId: widget.claimId,
        );

    ref.listenManual(muzzleScanProvider, (prev, next) {
      if (next.confidence != null && !next.isProcessing) {
        if (mounted) setState(() => _showResult = true);
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _alignmentTimer?.cancel();
    _pulseController.dispose();
    _scanLineController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(muzzleScanProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Show result view
          if (_showResult && state.confidence != null)
            Positioned.fill(child: _buildResultView(context, state))
          // Show captured preview
          else if (_capturedPath != null)
            Positioned.fill(child: _buildPreviewView(context, state))
          // Camera with watermark overlay
          else ...[
            // Camera preview
            if (_isCameraReady && _cameraController != null)
              Positioned.fill(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? 1,
                        height: _cameraController!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text('Initializing camera...',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),

            // Muzzle watermark overlay
            if (_isCameraReady)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _scanLineAnimation]),
                  builder: (context, _) => CustomPaint(
                    painter: _IdentifyOverlayPainter(
                      isCow: _isCow,
                      isAligned: _isAligned,
                      pulseValue: _pulseAnimation.value,
                      scanLineProgress: _scanLineAnimation.value,
                    ),
                  ),
                ),
              ),

            // Success flash
            AnimatedBuilder(
              animation: _successScale,
              builder: (context, _) {
                if (_successScale.value <= 0) return const SizedBox.shrink();
                return Positioned.fill(
                  child: Container(
                    color: const Color(0xFF2ECC71)
                        .withValues(alpha: 0.3 * _successScale.value),
                    child: Center(
                      child: Transform.scale(
                        scale: _successScale.value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          // Top bar
          _buildTopBar(),

          // Bottom controls (camera mode only)
          if (_capturedPath == null && !_showResult && _isCameraReady)
            _buildBottomControls(),
        ],
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
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint,
                        color: Color(0xFF2ECC71), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Identify Animal',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
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
              // Stability indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < _stabilityCounter;
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? const Color(0xFF2ECC71)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              Text(
                'Point camera at the muzzle',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2ECC71),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isAligned
                    ? 'Hold steady... auto-capturing'
                    : 'Align muzzle within the guide',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Manual capture button
              GestureDetector(
                onTap: _manualCapture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isAligned
                          ? const Color(0xFF2ECC71)
                          : Colors.white.withValues(alpha: 0.6),
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isAligned
                            ? const Color(0xFF2ECC71)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: _isAligned ? Colors.white : Colors.black87,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'or tap to capture manually',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewView(BuildContext context, MuzzleScanState state) {
    return Column(
      children: [
        Expanded(
          child: Image.file(File(_capturedPath!), fit: BoxFit.cover),
        ),
        if (state.isProcessing)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF2ECC71)),
                ),
                const SizedBox(height: 8),
                Text('Matching muzzle pattern...',
                    style: GoogleFonts.inter(color: Colors.white70)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black.withValues(alpha: 0.9),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isProcessing ? null : _retake,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        state.isProcessing ? null : _submitForVerification,
                    icon: const Icon(Icons.fingerprint, size: 18),
                    label: const Text('Identify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Widget _buildResultView(BuildContext context, MuzzleScanState state) {
    final score = state.confidence ?? 0;
    Color matchColor;
    String matchLabel;
    IconData matchIcon;

    if (score >= 85) {
      matchColor = const Color(0xFF2ECC71);
      matchLabel = 'Identity Verified';
      matchIcon = Icons.check_circle;
    } else if (score >= 60) {
      matchColor = Colors.orange;
      matchLabel = 'Uncertain Match';
      matchIcon = Icons.warning_amber_rounded;
    } else {
      matchColor = Colors.red;
      matchLabel = 'No Match Found';
      matchIcon = Icons.cancel;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, const Color(0xFF0A2E22)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Match gauge
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 14,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(matchColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Match Score',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: matchColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: matchColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(matchIcon, color: matchColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      matchLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: matchColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Side by side comparison
              if (_capturedPath != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Captured image
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 120,
                                width: double.infinity,
                                child: Image.file(File(_capturedPath!),
                                    fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Captured',
                                style: GoogleFonts.inter(
                                    color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          score >= 85
                              ? Icons.compare_arrows
                              : Icons.not_interested,
                          color: matchColor,
                          size: 28,
                        ),
                      ),
                      // Original image
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.white.withValues(alpha: 0.05),
                                child: widget.originalMuzzleUrl != null
                                    ? Image.network(widget.originalMuzzleUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _placeholderIcon())
                                    : _placeholderIcon(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Registered',
                                style: GoogleFonts.inter(
                                    color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retake,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Scan Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.pop(score),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: matchColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Center(
      child: Icon(Icons.pets, color: Colors.white.withValues(alpha: 0.2), size: 40),
    );
  }
}

/// Paints the muzzle alignment watermark overlay for identification.
class _IdentifyOverlayPainter extends CustomPainter {
  final bool isCow;
  final bool isAligned;
  final double pulseValue;
  final double scanLineProgress;

  _IdentifyOverlayPainter({
    required this.isCow,
    required this.isAligned,
    required this.pulseValue,
    required this.scanLineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final guideColor = isAligned ? const Color(0xFF2ECC71) : Colors.white;

    // Semi-transparent overlay outside the guide area
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Guide shape dimensions
    final double guideWidth;
    final double guideHeight;

    if (isCow) {
      guideWidth = size.width * 0.55;
      guideHeight = guideWidth * 1.2;
    } else {
      guideWidth = size.width * 0.6;
      guideHeight = guideWidth * 0.85;
    }

    // Draw darkened overlay with cutout
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final guidePath = Path();

    if (isCow) {
      guidePath.addOval(Rect.fromCenter(
          center: center, width: guideWidth * pulseValue, height: guideHeight * pulseValue));
    } else {
      guidePath.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center, width: guideWidth * pulseValue, height: guideHeight * pulseValue),
        const Radius.circular(30),
      ));
    }

    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(fullRect), guidePath),
      overlayPaint,
    );

    // Draw guide border
    final guideBorderPaint = Paint()
      ..color = guideColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (isCow) {
      canvas.drawOval(
        Rect.fromCenter(
            center: center, width: guideWidth * pulseValue, height: guideHeight * pulseValue),
        guideBorderPaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: center, width: guideWidth * pulseValue, height: guideHeight * pulseValue),
          const Radius.circular(30),
        ),
        guideBorderPaint,
      );
    }

    // Corner markers
    final cornerPaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final double cornerLen = 25;
    final left = center.dx - guideWidth / 2 * pulseValue;
    final right = center.dx + guideWidth / 2 * pulseValue;
    final top = center.dy - guideHeight / 2 * pulseValue;
    final bottom = center.dy + guideHeight / 2 * pulseValue;

    // Top-left
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(right, top), Offset(right - cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLen, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLen, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLen), cornerPaint);

    // Scanning line
    if (!isAligned) {
      final scanY = top + (bottom - top) * scanLineProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            guideColor.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(left, scanY - 1, right - left, 2));

      canvas.drawLine(Offset(left + 10, scanY), Offset(right - 10, scanY), scanPaint..strokeWidth = 2);
    }

    // Label
    final labelPainter = TextPainter(
      text: TextSpan(
        text: isCow ? 'POSITION MUZZLE HERE' : 'POSITION NOSE HERE',
        style: TextStyle(
          color: guideColor.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, bottom + 16),
    );
  }

  @override
  bool shouldRepaint(covariant _IdentifyOverlayPainter old) =>
      old.isAligned != isAligned ||
      old.pulseValue != pulseValue ||
      old.scanLineProgress != scanLineProgress;
}
