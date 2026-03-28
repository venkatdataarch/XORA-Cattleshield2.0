import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../shared/widgets/status_badge.dart';

/// Status of an insurance policy.
enum PolicyStatus {
  active,
  expiring,
  expired;

  String get label {
    switch (this) {
      case PolicyStatus.active:
        return 'Active';
      case PolicyStatus.expiring:
        return 'Expiring Soon';
      case PolicyStatus.expired:
        return 'Expired';
    }
  }

  Color get color {
    switch (this) {
      case PolicyStatus.active:
        return AppColors.success;
      case PolicyStatus.expiring:
        return AppColors.warning;
      case PolicyStatus.expired:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case PolicyStatus.active:
        return Icons.check_circle_outline;
      case PolicyStatus.expiring:
        return Icons.schedule;
      case PolicyStatus.expired:
        return Icons.cancel_outlined;
    }
  }
}

/// Data class for policy summary display.
class PolicySummary {
  final String id;
  final String animalName;
  final bool isCattle;
  final String policyNumber;
  final DateTime validFrom;
  final DateTime validTo;
  final double sumInsured;
  final PolicyStatus status;

  const PolicySummary({
    required this.id,
    required this.animalName,
    this.isCattle = true,
    required this.policyNumber,
    required this.validFrom,
    required this.validTo,
    required this.sumInsured,
    required this.status,
  });
}

/// Card displaying a policy summary with animal info, dates, and actions.
class PolicySummaryCard extends StatelessWidget {
  final PolicySummary policy;
  final VoidCallback? onView;
  final VoidCallback? onClaim;

  const PolicySummaryCard({
    super.key,
    required this.policy,
    this.onView,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: animal name + status
            Row(
              children: [
                Icon(
                  policy.isCattle ? Icons.pets : Icons.agriculture,
                  color: policy.isCattle
                      ? AppColors.primary
                      : AppColors.muleAccent,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    policy.animalName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(
                  label: policy.status.label,
                  color: policy.status.color,
                  icon: policy.status.icon,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Policy number
            Row(
              children: [
                Text(
                  'Policy: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  policy.policyNumber,
                  style: AppTypography.mono.copyWith(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Valid dates
            Row(
              children: [
                Text(
                  'Valid: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${_formatDate(policy.validFrom)} - ${_formatDate(policy.validTo)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Sum insured
            Row(
              children: [
                Text(
                  'Sum Insured: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  _formatCurrency(policy.sumInsured),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('View'),
                  ),
                ),
                if (policy.status == PolicyStatus.active) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onClaim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.buttonRadius),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Claim'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20B9${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20B9${amount.toStringAsFixed(0)}';
  }
}
