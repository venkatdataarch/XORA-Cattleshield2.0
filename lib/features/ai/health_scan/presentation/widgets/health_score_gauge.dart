import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';

/// Custom painted circular gauge showing the CHI score (0-100).
///
/// Animates the arc fill on first render, with color gradient based on
/// score range:
/// - 85-100: Green (Excellent)
/// - 70-84: Blue (Good)
/// - 50-69: Amber (Fair)
/// - 0-49: Red (Poor)
class HealthScoreGauge extends StatefulWidget {
  final int score;
  final double size;

  const HealthScoreGauge({
    super.key,
    required this.score,
    this.size = 160,
  });

  @override
  State<HealthScoreGauge> createState() => _HealthScoreGaugeState();
}

class _HealthScoreGaugeState extends State<HealthScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(HealthScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.score / 100,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (widget.score >= 85) return AppColors.success;
    if (widget.score >= 70) return AppColors.info;
    if (widget.score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String get _riskCategory {
    if (widget.score >= 85) return 'Excellent';
    if (widget.score >= 70) return 'Good';
    if (widget.score >= 50) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _GaugePainter(
              progress: _animation.value,
              color: _scoreColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (_animation.value * 100).toInt().toString(),
                    style: TextStyle(
                      fontSize: widget.size * 0.25,
                      fontWeight: FontWeight.bold,
                      color: _scoreColor,
                    ),
                  ),
                  Text(
                    _riskCategory,
                    style: TextStyle(
                      fontSize: widget.size * 0.09,
                      fontWeight: FontWeight.w600,
                      color: _scoreColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 12.0;
    const startAngle = -pi * 0.75; // Start from bottom-left
    const sweepRange = pi * 1.5; // 270 degrees

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepRange,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepRange * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
