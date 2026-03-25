import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/shared/widgets/secondary_button.dart';
import 'package:cattleshield/shared/widgets/status_badge.dart';
import '../../data/policy_repository.dart';
import '../../domain/policy_model.dart';
import '../providers/policy_provider.dart';

/// Provider to load full policy detail by ID.
final _policyDetailProvider =
    FutureProvider.family<PolicyModel, String>((ref, id) async {
  final repo = ref.watch(policyRepositoryProvider);
  final result = await repo.getPolicyById(id);
  return result.when(
    success: (policy) => policy,
    failure: (error) => throw Exception(error.message),
  );
});

/// Screen showing full detail of a policy.
class PolicyDetailScreen extends ConsumerWidget {
  final String policyId;

  const PolicyDetailScreen({
    super.key,
    required this.policyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(_policyDetailProvider(policyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy Details'),
      ),
      body: policyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(_policyDetailProvider(policyId)),
        ),
        data: (policy) => _PolicyDetailContent(policy: policy),
      ),
    );
  }
}

class _PolicyDetailContent extends ConsumerWidget {
  final PolicyModel policy;

  const _PolicyDetailContent({required this.policy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Policy header card with big policy number
          _buildHeaderCard(context, dateFormat),
          const SizedBox(height: AppSpacing.md),

          // Status + days remaining
          _buildStatusCard(),
          const SizedBox(height: AppSpacing.md),

          // Animal info section
          _buildAnimalInfoCard(),
          const SizedBox(height: AppSpacing.md),

          // Coverage details
          _buildCoverageCard(currencyFormat, dateFormat),
          const SizedBox(height: AppSpacing.md),

          // Linked proposal
          _buildProposalLink(context),
          const SizedBox(height: AppSpacing.md),

          // Action buttons
          _buildActions(context, ref),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateFormat dateFormat) {
    return Card(
      elevation: 0,
      color: AppColors.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Policy number
            const Text(
              'Policy Number',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              policy.policyNumber,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Insured name
            if (policy.insuredName != null)
              Text(
                policy.insuredName!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: policy.statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: policy.statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                policy.status.icon,
                color: policy.statusColor,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label: policy.statusLabel,
                    color: policy.statusColor,
                    icon: policy.status.icon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    policy.isExpired
                        ? 'This policy has expired'
                        : policy.isExpiringSoon
                            ? '${policy.daysRemaining} days until expiry'
                            : '${policy.daysRemaining} days remaining',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: policy.statusColor,
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

  Widget _buildAnimalInfoCard() {
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
              'Insured Animal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  child: const Icon(Icons.pets, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.sm),
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
                      ),
                      if (policy.animalSpecies != null)
                        Text(
                          policy.animalSpecies!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageCard(NumberFormat currencyFormat, DateFormat dateFormat) {
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
              'Coverage Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Sum Insured',
              value: currencyFormat.format(policy.sumInsured),
              icon: Icons.shield,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Premium Paid',
              value: currencyFormat.format(policy.premium),
              icon: Icons.payment,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Policy Start',
              value: dateFormat.format(policy.startDate),
              icon: Icons.event,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Policy End',
              value: dateFormat.format(policy.endDate),
              icon: Icons.event_busy,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Coverage Period',
              value: '${policy.endDate.difference(policy.startDate).inDays} days',
              icon: Icons.date_range,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalLink(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: () {
          context.push('/farmer/proposals/${policy.proposalId}');
        },
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              Icon(
                Icons.description,
                color: AppColors.primary.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Proposal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      'View the original proposal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File Claim button (only for active / expiring policies)
        if (policy.isClaimable)
          PrimaryButton(
            label: 'File a Claim',
            icon: Icons.receipt_long,
            onPressed: () {
              ref.read(selectedPolicyProvider.notifier).state = policy;
              context.push('/farmer/claims/new/${policy.id}');
            },
          ),

        // Renew button (for expiring or expired policies)
        if (policy.isExpiringSoon || policy.isExpired) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Renew Policy',
            icon: Icons.refresh,
            onPressed: () {
              // Navigate to proposal form for renewal.
              context.push(
                '/farmer/proposals/form/${policy.animalId}',
              );
            },
          ),
        ],

        // Download certificate (always available)
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Download Certificate',
          icon: Icons.download,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Certificate download will be available soon'),
                backgroundColor: AppColors.info,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A row displaying a label-value pair with an icon.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
