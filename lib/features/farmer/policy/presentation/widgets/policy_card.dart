import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/status_badge.dart';
import '../../domain/policy_model.dart';

/// Card widget for displaying a policy summary in the policy list.
///
/// Displays the animal name with species icon, policy number in mono font,
/// date range, sum insured, and days remaining indicator.
class PolicyCard extends StatelessWidget {
  final PolicyModel policy;
  final VoidCallback? onTap;
  final VoidCallback? onFileClaim;

  const PolicyCard({
    super.key,
    required this.policy,
    this.onTap,
    this.onFileClaim,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: policy.isExpiringSoon
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Animal name + species icon + status
              Row(
                children: [
                  // Species icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: policy.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _speciesIcon,
                      color: policy.statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Animal name + policy number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy.animalName ?? 'Animal #${policy.animalId}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          policy.policyNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(
                    label: policy.statusLabel,
                    color: policy.statusColor,
                    icon: policy.status.icon,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.sm),
              // Date range
              Row(
                children: [
                  const Icon(Icons.date_range, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(policy.startDate)} - ${dateFormat.format(policy.endDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Sum insured + days remaining
              Row(
                children: [
                  // Sum insured
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.shield, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          currencyFormat.format(policy.sumInsured),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Days remaining indicator
                  _DaysRemainingBadge(days: policy.daysRemaining, status: policy.status),
                ],
              ),
              // Quick actions
              if (policy.isClaimable && onFileClaim != null) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: onFileClaim,
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('File Claim'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the appropriate icon for the animal species.
  IconData get _speciesIcon {
    final species = (policy.animalSpecies ?? '').toLowerCase();
    if (species == 'mule' || species == 'horse' || species == 'donkey') {
      return Icons.pest_control;
    }
    return Icons.pets;
  }
}

/// Badge showing days remaining until policy expiry.
class _DaysRemainingBadge extends StatelessWidget {
  final int days;
  final PolicyStatus status;

  const _DaysRemainingBadge({
    required this.days,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;

    if (status == PolicyStatus.expired) {
      color = Colors.grey;
      text = 'Expired';
    } else if (days <= 0) {
      color = AppColors.error;
      text = 'Expired';
    } else if (days <= 7) {
      color = AppColors.error;
      text = '$days days left';
    } else if (days <= 30) {
      color = AppColors.warning;
      text = '$days days left';
    } else {
      color = AppColors.success;
      text = '$days days left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
