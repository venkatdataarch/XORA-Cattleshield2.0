import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../shared/widgets/status_badge.dart';
import '../../domain/animal_model.dart';

/// Card widget for displaying an animal in a list.
///
/// Shows species icon, breed/name, tag number, health score badge,
/// age, sex, and a species-themed accent color.
class AnimalCard extends StatelessWidget {
  final AnimalModel animal;
  final VoidCallback? onTap;

  const AnimalCard({
    super.key,
    required this.animal,
    this.onTap,
  });

  Color get _accentColor =>
      animal.isCattle ? AppColors.primary : AppColors.muleAccent;

  IconData get _speciesIcon =>
      animal.isCattle ? Icons.pets : Icons.agriculture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              // Species accent strip
              Container(
                width: 4,
                height: 90,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.cardRadius),
                    bottomLeft: Radius.circular(AppSpacing.cardRadius),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // Species icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.cardRadius),
                        ),
                        child: Icon(
                          _speciesIcon,
                          color: _accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name / breed
                            Text(
                              animal.speciesBreed ?? animal.speciesLabel,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Tag number
                            if (animal.identificationTag != null)
                              Text(
                                animal.identificationTag!,
                                style: AppTypography.mono.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),

                            const SizedBox(height: AppSpacing.xs),

                            // Age and sex row
                            Row(
                              children: [
                                if (animal.ageYears != null)
                                  _InfoChip(
                                    label: '${animal.ageYears!.toStringAsFixed(1)} yrs',
                                  ),
                                if (animal.sex != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _InfoChip(label: animal.sex!.label),
                                ],
                                if (animal.isMule &&
                                    animal.species != AnimalSpecies.cow) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _InfoChip(label: animal.speciesLabel),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Health score badge
                      if (animal.healthScore != null)
                        _HealthScoreBadge(score: animal.healthScore!),

                      // Chevron
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small info chip for displaying age, sex, etc.
class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
            ),
      ),
    );
  }
}

/// Circular health score indicator with color coding.
class _HealthScoreBadge extends StatelessWidget {
  final int score;

  const _HealthScoreBadge({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.riskLow;
    if (score >= 60) return AppColors.riskMedium;
    if (score >= 40) return AppColors.riskHigh;
    return AppColors.riskCritical;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color.withValues(alpha: 0.12),
        border: Border.all(color: _color, width: 2),
      ),
      child: Center(
        child: Text(
          score.toString(),
          style: AppTypography.mono.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ),
    );
  }
}
