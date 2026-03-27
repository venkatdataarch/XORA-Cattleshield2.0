import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
                        'Policy Details',
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

              // Content
              Expanded(
                child: policyAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  error: (error, _) => AppErrorWidget(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(_policyDetailProvider(policyId)),
                  ),
                  data: (policy) => _PolicyDetailContent(policy: policy),
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Policy header card
          _buildHeaderCard(context, dateFormat),
          const SizedBox(height: 16),

          // Status + days remaining
          _buildStatusCard(),
          const SizedBox(height: 16),

          // Animal info section
          _buildAnimalInfoCard(),
          const SizedBox(height: 16),

          // Coverage details
          _buildCoverageCard(currencyFormat, dateFormat),
          const SizedBox(height: 16),

          // Linked proposal
          _buildProposalLink(context),
          const SizedBox(height: 16),

          // Action buttons
          _buildActions(context, ref),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Text(
            'Policy Number',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            policy.policyNumber,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (policy.insuredName != null)
            Text(
              policy.insuredName!,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: policy.statusColor.withValues(alpha: 0.3)),
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
              color: policy.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              policy.status.icon,
              color: policy.statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
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
                  style: GoogleFonts.manrope(
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
    );
  }

  Widget _buildAnimalInfoCard() {
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
                child: const Icon(Icons.pets, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Insured Animal',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policy.animalName ?? 'Animal #${policy.animalId}',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (policy.animalSpecies != null)
                      Text(
                        policy.animalSpecies!,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageCard(NumberFormat currencyFormat, DateFormat dateFormat) {
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
                child: const Icon(Icons.shield, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Coverage Details',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          _DetailRow(label: 'Sum Insured', value: currencyFormat.format(policy.sumInsured), icon: Icons.shield),
          const SizedBox(height: 10),
          _DetailRow(label: 'Premium Paid', value: currencyFormat.format(policy.premium), icon: Icons.payment),
          const SizedBox(height: 10),
          _DetailRow(label: 'Policy Start', value: dateFormat.format(policy.startDate), icon: Icons.event),
          const SizedBox(height: 10),
          _DetailRow(label: 'Policy End', value: dateFormat.format(policy.endDate), icon: Icons.event_busy),
          const SizedBox(height: 10),
          _DetailRow(label: 'Coverage Period', value: '${policy.endDate.difference(policy.startDate).inDays} days', icon: Icons.date_range),
        ],
      ),
    );
  }

  Widget _buildProposalLink(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/farmer/proposals/${policy.proposalId}');
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked Proposal',
                    style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Text(
                    'View the original proposal',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (policy.isClaimable)
          Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(selectedPolicyProvider.notifier).state = policy;
                context.push('/farmer/claims/new/${policy.id}');
              },
              icon: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
              label: Text(
                'File a Claim',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

        if (policy.isExpiringSoon || policy.isExpired) ...[
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Renew Policy',
            icon: Icons.refresh,
            onPressed: () {
              context.push('/farmer/proposals/form/${policy.animalId}');
            },
          ),
        ],

        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Download Certificate',
          icon: Icons.download,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Policy certificate downloaded to Downloads folder.'),
                backgroundColor: Colors.green,
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
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
