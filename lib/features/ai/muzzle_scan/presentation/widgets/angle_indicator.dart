import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';
import '../providers/muzzle_scan_provider.dart';

/// Row of 3 step circles indicating which muzzle angle is being captured.
///
/// - Current step: amber filled
/// - Completed: green with checkmark
/// - Upcoming: grey outlined
class AngleIndicator extends StatelessWidget {
  final int currentStep; // 0, 1, or 2
  final Set<MuzzleAngle> completedAngles;

  const AngleIndicator({
    super.key,
    required this.currentStep,
    required this.completedAngles,
  });

  static const _labels = ['Front', 'Left', 'Right'];
  static const _angles = [
    MuzzleAngle.front,
    MuzzleAngle.left,
    MuzzleAngle.right,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isCompleted = completedAngles.contains(_angles[i]);
        final isCurrent = i == currentStep && !isCompleted;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i > 0)
              Container(
                width: 32,
                height: 2,
                color: isCompleted || i <= currentStep
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.cardBorder,
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.secondary
                            : Colors.transparent,
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.success
                          : isCurrent
                              ? AppColors.secondary
                              : AppColors.textTertiary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check,
                            size: 18, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : AppColors.textTertiary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isCompleted
                            ? AppColors.success
                            : isCurrent
                                ? AppColors.secondary
                                : AppColors.textTertiary,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
