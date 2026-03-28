import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Premium header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Claim Details',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: claimAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  error: (error, _) => AppErrorWidget(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(_claimDetailProvider(claimId)),
                  ),
                  data: (claim) => _ClaimDetailContent(claim: claim),
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, dateFormat),
          const SizedBox(height: 16),

          if (claim.aiMuzzleMatchScore != null) ...[
            _buildAiMatchCard(),
            const SizedBox(height: 16),
          ],

          if ((claim.status == ClaimStatus.vetRejected ||
                  claim.status == ClaimStatus.repudiated) &&
              claim.rejectionReason != null) ...[
            _buildRejectionCard(),
            const SizedBox(height: 16),
          ],

          if (claim.isSettled && claim.settlementAmount != null) ...[
            _buildSettlementCard(currencyFormat),
            const SizedBox(height: 16),
          ],

          _buildStatusTimeline(),
          const SizedBox(height: 16),

          _buildFormDataSection(context),
          const SizedBox(height: 16),

          if (claim.evidenceMedia != null && claim.evidenceMedia!.isNotEmpty)
            EvidenceGallery(media: claim.evidenceMedia!),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claim.animalName ?? 'Animal #${claim.animalId}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              ClaimStatusBadge(status: claim.status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            children: [
              ClaimTypeBadge(type: claim.type),
              const Spacer(),
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(claim.createdAt),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          if (claim.policyNumber != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.policy, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Policy: ${claim.policyNumber}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
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
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Muzzle Match',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildRejectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claim.status == ClaimStatus.repudiated
                      ? 'Claim Repudiated'
                      : 'Rejection Reason',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  claim.rejectionReason!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.paid, color: Colors.teal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settlement Amount',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  currencyFormat.format(claim.settlementAmount),
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.teal,
                  ),
                ),
                if (claim.settledAt != null)
                  Text(
                    'Settled on ${DateFormat('dd MMM yyyy').format(claim.settledAt!)}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
        ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Claim Status',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(statusOrder.length, (index) {
            final status = statusOrder[index];
            final isCompleted = currentIndex > index;
            final isCurrent = currentIndex == index;
            final isLast = index == statusOrder.length - 1;

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
      circleColor = Colors.grey.shade300;
      textColor = Colors.grey.shade400;
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
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: isCurrent || isRejected
                      ? FontWeight.w700
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
