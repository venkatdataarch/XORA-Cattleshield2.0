import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';

/// Animated progress bar shown during AI muzzle processing.
///
/// Displays a pulsing amber bar with descriptive text.
class ScanProgressBar extends StatefulWidget {
  final String message;

  const ScanProgressBar({
    super.key,
    this.message = 'Analyzing muzzle pattern...',
  });

  @override
  State<ScanProgressBar> createState() => _ScanProgressBarState();
}

class _ScanProgressBarState extends State<ScanProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Opacity(
                opacity: _animation.value,
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Color(0xFFFFF3E0),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Opacity(
                opacity: 0.5 + (_animation.value * 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fingerprint,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.message,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
