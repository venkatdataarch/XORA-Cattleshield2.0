import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/status_badge.dart';
import 'package:cattleshield/shared/widgets/empty_state_widget.dart';
import 'package:cattleshield/features/farmer/proposal/domain/proposal_model.dart';
import 'package:cattleshield/features/farmer/claim/domain/claim_model.dart';

/// A combined pending-review item that can represent either a proposal or a
/// claim awaiting vet action.
class PendingReviewItem {
  final String id;
  final bool isProposal;
  final String farmerName;
  final String animalType;
  final String? tag;
  final DateTime date;
  final double? claimAmount;
  final double? aiMatchScore;

  const PendingReviewItem({
    required this.id,
    required this.isProposal,
    required this.farmerName,
    required this.animalType,
    this.tag,
    required this.date,
    this.claimAmount,
    this.aiMatchScore,
  });

  factory PendingReviewItem.fromProposal(ProposalModel p) {
    return PendingReviewItem(
      id: p.id,
      isProposal: true,
      farmerName: p.formData['farmerName']?.toString() ?? 'Unknown Farmer',
      animalType: p.animalSpecies ?? 'Cattle',
      tag: p.animalName,
      date: p.submittedAt ?? p.createdAt,
    );
  }

  factory PendingReviewItem.fromClaim(ClaimModel c) {
    return PendingReviewItem(
      id: c.id,
      isProposal: false,
      farmerName: c.formData['farmerName']?.toString() ?? 'Unknown Farmer',
      animalType: c.animalName ?? 'Cattle',
      tag: c.claimNumber,
      date: c.createdAt,
      claimAmount: c.settlementAmount,
      aiMatchScore: c.aiMuzzleMatchScore,
    );
  }
}

/// ListView of pending proposals and claims for the vet to review.
class PendingReviewsList extends StatelessWidget {
  final List<PendingReviewItem> items;
  final void Function(PendingReviewItem item)? onScreenImages;
  final void Function(PendingReviewItem item)? onAnalyse;

  const PendingReviewsList({
    super.key,
    required this.items,
    this.onScreenImages,
    this.onAnalyse,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: 'No Pending Reviews',
        subtitle: 'All caught up! No items awaiting your review.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return _PendingReviewCard(
          item: item,
          onScreenImages: onScreenImages != null
              ? () => onScreenImages!(item)
              : null,
          onAnalyse: onAnalyse != null ? () => onAnalyse!(item) : null,
        );
      },
    );
  }
}

class _PendingReviewCard extends StatelessWidget {
  final PendingReviewItem item;
  final VoidCallback? onScreenImages;
  final VoidCallback? onAnalyse;

  const _PendingReviewCard({
    required this.item,
    this.onScreenImages,
    this.onAnalyse,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isProposal = item.isProposal;

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
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isProposal
                        ? AppColors.info.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isProposal ? Icons.pets : Icons.warning_amber_rounded,
                    size: 20,
                    color: isProposal ? AppColors.info : AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.farmerName,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.animalType}${item.tag != null ? ' - ${item.tag}' : ''}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: isProposal ? 'NEW PROPOSAL' : 'DECEASED CLAIM',
                  color: isProposal ? AppColors.info : AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Info row
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(item.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
                if (!isProposal && item.claimAmount != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.currency_rupee,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 2),
                  Text(
                    NumberFormat('#,##0').format(item.claimAmount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                if (!isProposal && item.aiMatchScore != null) ...[
                  const Spacer(),
                  _AiMatchBadge(score: item.aiMatchScore!),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onScreenImages,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Screen Images'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAnalyse,
                    icon: Icon(
                      isProposal ? Icons.analytics : Icons.fact_check,
                      size: 18,
                    ),
                    label: Text(
                      isProposal ? 'Analyse Proposal' : 'Analyse Claim',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small badge showing the AI muzzle match percentage with color coding.
class _AiMatchBadge extends StatelessWidget {
  final double score;

  const _AiMatchBadge({required this.score});

  Color get _color {
    if (score >= 85) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fingerprint, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(0)}% Match',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
