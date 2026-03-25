import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/shared/widgets/secondary_button.dart';
import '../providers/health_scan_provider.dart';
import '../widgets/health_score_gauge.dart';
import '../widgets/risk_category_badge.dart';

/// Displays the AI health analysis result.
///
/// Shows CHI score gauge, body condition score, observations,
/// recommendations, and risk factors.
class HealthResultScreen extends ConsumerWidget {
  const HealthResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(healthScanProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Health Result'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No health scan result available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Analysis'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // CHI Score Gauge
                  HealthScoreGauge(score: result.chiScore, size: 180),
                  const SizedBox(height: AppSpacing.md),

                  // Risk badge
                  RiskCategoryBadge.fromScore(result.chiScore),
                  const SizedBox(height: AppSpacing.lg),

                  // Body Condition Score
                  _buildBcsCard(context, result.bodyConditionScore),
                  const SizedBox(height: AppSpacing.md),

                  // Observations
                  if (result.observations.isNotEmpty)
                    _buildListCard(
                      context,
                      title: 'Observations',
                      icon: Icons.visibility,
                      items: result.observations,
                      iconColor: AppColors.info,
                    ),
                  if (result.observations.isNotEmpty)
                    const SizedBox(height: AppSpacing.md),

                  // Recommendations
                  if (result.recommendations.isNotEmpty)
                    _buildListCard(
                      context,
                      title: 'Recommendations',
                      icon: Icons.lightbulb_outline,
                      items: result.recommendations,
                      iconColor: AppColors.secondary,
                    ),
                  if (result.recommendations.isNotEmpty)
                    const SizedBox(height: AppSpacing.md),

                  // Risk factors
                  if (result.riskFactors.isNotEmpty)
                    _buildRiskFactors(context, result.riskFactors),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              bottom:
                  MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Share Report',
                    icon: Icons.share,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Report sharing will be available soon'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward,
                    onPressed: () => context.pop(result.chiScore),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBcsCard(BuildContext context, double bcs) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            'Body Condition Score',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // BCS scale visualization
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final score = i + 1;
              final isActive = score <= bcs.round();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? _bcsColor(bcs).withValues(alpha: 0.15)
                            : AppColors.background,
                        border: Border.all(
                          color: isActive
                              ? _bcsColor(bcs)
                              : AppColors.cardBorder,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$score',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? _bcsColor(bcs)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bcsLabel(score),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: AppColors.textTertiary,
                              ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Score: ${bcs.toStringAsFixed(1)} / 5.0',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _bcsColor(bcs),
                ),
          ),
        ],
      ),
    );
  }

  Color _bcsColor(double bcs) {
    if (bcs >= 3.5) return AppColors.success;
    if (bcs >= 2.5) return AppColors.info;
    if (bcs >= 1.5) return AppColors.warning;
    return AppColors.error;
  }

  String _bcsLabel(int score) {
    switch (score) {
      case 1:
        return 'Thin';
      case 2:
        return 'Lean';
      case 3:
        return 'Ideal';
      case 4:
        return 'Heavy';
      case 5:
        return 'Obese';
      default:
        return '';
    }
  }

  Widget _buildListCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> items,
    Color iconColor = AppColors.primary,
  }) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withValues(alpha: 0.6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskFactors(
    BuildContext context,
    List<String> riskFactors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning, size: 20, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Risk Factors',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...riskFactors.map(
          (factor) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius:
                  BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    factor,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
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
}
