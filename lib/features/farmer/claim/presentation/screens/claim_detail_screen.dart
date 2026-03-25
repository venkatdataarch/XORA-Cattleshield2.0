import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import '../../data/claim_repository.dart';
import '../../domain/claim_model.dart';
import '../providers/claim_provider.dart';
import '../widgets/claim_status_badge.dart';
import '../widgets/evidence_gallery.dart';

/// Provider to load full claim detail by ID.
final _claimDetailProvider =
    FutureProvider.family<ClaimModel, String>((ref, id) async {
  final repo = ref.watch(claimRepositoryProvider);
  final result = await repo.getClaimById(id);
  return result.when(
    success: (claim) => claim,
    failure: (error) => throw Exception(error.message),
  );
});

/// Screen showing full detail of a claim.
class ClaimDetailScreen extends ConsumerWidget {
  final String claimId;

  const ClaimDetailScreen({
    super.key,
    required this.claimId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimAsync = ref.watch(_claimDetailProvider(claimId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Details'),
      ),
      body: claimAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(_claimDetailProvider(claimId)),
        ),
        data: (claim) => _ClaimDetailContent(claim: claim),
      ),
    );
  }
}

class _ClaimDetailContent extends StatelessWidget {
  final ClaimModel claim;

  const _ClaimDetailContent({required this.claim});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Claim header card
          _buildHeaderCard(context, dateFormat),
          const SizedBox(height: AppSpacing.md),

          // AI muzzle match score
          if (claim.aiMuzzleMatchScore != null) ...[
            _buildAiMatchCard(),
            const SizedBox(height: AppSpacing.md),
          ],

          // Rejection reason
          if ((claim.status == ClaimStatus.vetRejected ||
                  claim.status == ClaimStatus.repudiated) &&
              claim.rejectionReason != null) ...[
            _buildRejectionCard(),
            const SizedBox(height: AppSpacing.md),
          ],

          // Settlement info
          if (claim.isSettled && claim.settlementAmount != null) ...[
            _buildSettlementCard(currencyFormat),
            const SizedBox(height: AppSpacing.md),
          ],

          // Status timeline
          _buildStatusTimeline(),
          const SizedBox(height: AppSpacing.md),

          // Form data
          _buildFormDataSection(context),
          const SizedBox(height: AppSpacing.md),

          // Evidence gallery
          if (claim.evidenceMedia != null && claim.evidenceMedia!.isNotEmpty)
            EvidenceGallery(media: claim.evidenceMedia!),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateFormat dateFormat) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim number and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.claimNumber.isNotEmpty
                            ? claim.claimNumber
                            : 'Claim #${claim.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claim.animalName ?? 'Animal #${claim.animalId}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ClaimStatusBadge(status: claim.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                ClaimTypeBadge(type: claim.type),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(claim.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (claim.policyNumber != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.policy, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Policy: ${claim.policyNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiMatchCard() {
    final score = claim.aiMuzzleMatchScore!;
    final percentage = (score * 100).round();
    final color = percentage >= 80
        ? AppColors.success
        : percentage >= 50
            ? AppColors.warning
            : AppColors.error;
    final resultLabel = claim.aiMatchResult ?? 'pending';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            // Circular progress indicator
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score,
                    strokeWidth: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Muzzle Match',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        resultLabel == 'verified'
                            ? Icons.check_circle
                            : resultLabel == 'suspicious'
                                ? Icons.warning
                                : Icons.help_outline,
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        resultLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionCard() {
    return Card(
      elevation: 0,
      color: AppColors.error.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claim.status == ClaimStatus.repudiated
                        ? 'Claim Repudiated'
                        : 'Rejection Reason',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    claim.rejectionReason!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(NumberFormat currencyFormat) {
    return Card(
      elevation: 0,
      color: Colors.teal.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.paid, color: Colors.teal, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settlement Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    currencyFormat.format(claim.settlementAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal,
                    ),
                  ),
                  if (claim.settledAt != null)
                    Text(
                      'Settled on ${DateFormat('dd MMM yyyy').format(claim.settledAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final statusOrder = [
      ClaimStatus.submitted,
      ClaimStatus.vetReview,
      ClaimStatus.vetApproved,
      ClaimStatus.uiicProcessing,
      ClaimStatus.settled,
    ];

    final isRejected = claim.status == ClaimStatus.vetRejected ||
        claim.status == ClaimStatus.repudiated;
    final currentIndex = statusOrder.indexOf(claim.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Claim Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(statusOrder.length, (index) {
              final status = statusOrder[index];
              final isCompleted = currentIndex > index;
              final isCurrent = currentIndex == index;
              final isFuture = currentIndex < index;
              final isLast = index == statusOrder.length - 1;

              // Handle rejection display.
              if (isRejected && index >= 2) {
                if (index == 2) {
                  return _buildTimelineStep(
                    label: claim.status.label,
                    icon: claim.status.icon,
                    isRejected: true,
                    isCurrent: true,
                    isLast: true,
                  );
                }
                return const SizedBox.shrink();
              }

              return _buildTimelineStep(
                label: status.label,
                icon: status.icon,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isLast: isLast || (isRejected && index == 1),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required IconData icon,
    bool isCompleted = false,
    bool isCurrent = false,
    bool isRejected = false,
    bool isLast = false,
  }) {
    final Color circleColor;
    final Color textColor;

    if (isRejected) {
      circleColor = AppColors.error;
      textColor = AppColors.error;
    } else if (isCompleted) {
      circleColor = AppColors.success;
      textColor = AppColors.textPrimary;
    } else if (isCurrent) {
      circleColor = AppColors.primary;
      textColor = AppColors.primary;
    } else {
      circleColor = AppColors.divider;
      textColor = AppColors.textTertiary;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRejected ? Icons.close : icon,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 20),
                      color: isCompleted
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent || isRejected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDataSection(BuildContext context) {
    if (claim.formData.isEmpty) return const SizedBox.shrink();

    final formType = claim.type == ClaimType.death ? 'claim_death' : 'claim_injury';

    return Consumer(
      builder: (context, ref, _) {
        final schemaAsync = ref.watch(
          FutureProvider<FormSchema>((ref) async {
            final repo = ref.watch(formSchemaRepositoryProvider);
            return repo.getSchema(formType);
          }),
        );

        return schemaAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (schema) {
            return SizedBox(
              height: 400,
              child: DynamicFormRenderer(
                schema: schema,
                initialData: claim.formData,
                readOnly: true,
                displayMode: FormDisplayMode.singlePage,
              ),
            );
          },
        );
      },
    );
  }
}
