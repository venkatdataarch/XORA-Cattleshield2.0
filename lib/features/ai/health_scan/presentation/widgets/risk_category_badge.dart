import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';

/// Risk level for health assessment.
enum RiskLevel {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.low:
        return AppColors.riskLow;
      case RiskLevel.medium:
        return AppColors.riskMedium;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.critical:
        return AppColors.riskCritical;
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.medium:
        return Icons.info;
      case RiskLevel.high:
        return Icons.warning_amber_rounded;
      case RiskLevel.critical:
        return Icons.error;
    }
  }

  /// Determines risk level from a CHI score.
  static RiskLevel fromScore(int score) {
    if (score >= 85) return RiskLevel.low;
    if (score >= 70) return RiskLevel.medium;
    if (score >= 50) return RiskLevel.high;
    return RiskLevel.critical;
  }
}

/// Badge widget showing a risk level with icon and colored background.
class RiskCategoryBadge extends StatelessWidget {
  final RiskLevel level;

  const RiskCategoryBadge({super.key, required this.level});

  /// Convenience constructor from a CHI score.
  factory RiskCategoryBadge.fromScore(int score) {
    return RiskCategoryBadge(level: RiskLevel.fromScore(score));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: level.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 16, color: level.color),
          const SizedBox(width: 6),
          Text(
            level.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: level.color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
