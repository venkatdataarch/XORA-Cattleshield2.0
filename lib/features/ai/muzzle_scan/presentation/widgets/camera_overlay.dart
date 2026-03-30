import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';

/// Custom overlay for muzzle capture screens.
///
/// Paints a semi-transparent dark background with an oval cutout in the
/// center for positioning the muzzle, surrounded by an amber border and
/// corner alignment brackets.
class CameraOverlay extends StatelessWidget {
  final String instruction;

  const CameraOverlay({
    super.key,
    this.instruction = 'Position the muzzle within the frame',
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _CameraOverlayPainter(),
              size: Size.infinite,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            color: Colors.black.withValues(alpha: 0.6),
            child: Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.6;
    final ovalHeight = size.height * 0.45;
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Dark overlay with oval cutout
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(ovalRect);
    final combinedPath =
        Path.combine(PathOperation.difference, overlayPath, ovalPath);

    canvas.drawPath(
      combinedPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Amber border around oval
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Corner brackets
    final bracketLength = 24.0;
    final bracketPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Calculate bracket positions on the oval
    final positions = [
      _ovalPoint(ovalRect, -pi * 0.75), // top-left
      _ovalPoint(ovalRect, -pi * 0.25), // top-right
      _ovalPoint(ovalRect, pi * 0.25),  // bottom-right
      _ovalPoint(ovalRect, pi * 0.75),  // bottom-left
    ];

    for (final pos in positions) {
      // Draw small L-shaped brackets
      canvas.drawLine(
        Offset(pos.dx - bracketLength / 2, pos.dy),
        Offset(pos.dx + bracketLength / 2, pos.dy),
        bracketPaint,
      );
    }
  }

  Offset _ovalPoint(Rect rect, double angle) {
    return Offset(
      rect.center.dx + (rect.width / 2) * cos(angle),
      rect.center.dy + (rect.height / 2) * sin(angle),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
