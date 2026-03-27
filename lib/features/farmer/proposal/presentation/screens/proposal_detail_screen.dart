import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/shared/widgets/secondary_button.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import '../../data/proposal_repository.dart';
import '../../domain/proposal_model.dart';
import '../providers/proposal_provider.dart';
import '../widgets/proposal_status_badge.dart';
import '../widgets/proposal_timeline.dart';

/// Provider to load full proposal detail by ID.
final _proposalDetailProvider =
    FutureProvider.family<ProposalModel, String>((ref, id) async {
  final repo = ref.watch(proposalRepositoryProvider);
  final result = await repo.getProposalById(id);
  return result.when(
    success: (proposal) => proposal,
    failure: (error) => throw Exception(error.message),
  );
});

/// Provider to load the form schema for viewing proposal form data.
final _proposalViewSchemaProvider =
    FutureProvider.family<FormSchema, String>((ref, formType) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema(formType);
});

/// Screen showing full detail of a proposal.
class ProposalDetailScreen extends ConsumerStatefulWidget {
  final String proposalId;

  const ProposalDetailScreen({
    super.key,
    required this.proposalId,
  });

  @override
  ConsumerState<ProposalDetailScreen> createState() =>
      _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends ConsumerState<ProposalDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _submitProposal(ProposalModel proposal) async {
    setState(() => _isSubmitting = true);

    try {
      final result = await ref
          .read(proposalListProvider.notifier)
          .submitProposal(proposal.id);

      if (result != null && mounted) {
        ref.read(selectedProposalProvider.notifier).state = result;
        ref.invalidate(_proposalDetailProvider(widget.proposalId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit proposal'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposalAsync = ref.watch(_proposalDetailProvider(widget.proposalId));

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
                        'Proposal Details',
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
                child: LoadingOverlay(
                  isLoading: _isSubmitting,
                  message: 'Submitting proposal...',
                  child: proposalAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    error: (error, _) => AppErrorWidget(
                      message: error.toString(),
                      onRetry: () =>
                          ref.invalidate(_proposalDetailProvider(widget.proposalId)),
                    ),
                    data: (proposal) => _buildContent(context, proposal),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProposalModel proposal) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final species = proposal.animalSpecies?.toLowerCase() ?? '';
    final formType = (species == 'mule' || species == 'horse' || species == 'donkey')
        ? 'proposal_mule'
        : 'proposal_cattle';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimalInfoCard(context, proposal, dateFormat),
          const SizedBox(height: 16),

          if (proposal.status == ProposalStatus.vetRejected &&
              proposal.rejectionReason != null) ...[
            _buildRejectionCard(proposal),
            const SizedBox(height: 16),
          ],

          if (proposal.uiicReference != null) ...[
            _buildInfoCard(
              icon: Icons.business,
              title: 'UIIC Reference',
              value: proposal.uiicReference!,
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
          ],

          ProposalTimeline(proposal: proposal),
          const SizedBox(height: 16),

          _buildFormDataSection(formType, proposal),
          const SizedBox(height: 16),

          _buildActions(context, proposal),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAnimalInfoCard(
    BuildContext context,
    ProposalModel proposal,
    DateFormat dateFormat,
  ) {
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.animalName ?? 'Animal #${proposal.animalId}',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (proposal.animalSpecies != null)
                      Text(
                        proposal.animalSpecies!,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              ProposalStatusBadge(status: proposal.status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            children: [
              _DetailItem(
                label: 'Created',
                value: dateFormat.format(proposal.createdAt),
              ),
              if (proposal.sumInsured != null)
                _DetailItem(
                  label: 'Sum Insured',
                  value: NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '\u20B9',
                    decimalDigits: 0,
                  ).format(proposal.sumInsured),
                ),
              if (proposal.premium != null)
                _DetailItem(
                  label: 'Premium',
                  value: NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '\u20B9',
                    decimalDigits: 0,
                  ).format(proposal.premium),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionCard(ProposalModel proposal) {
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
                  'Rejection Reason',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  proposal.rejectionReason!,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormDataSection(String formType, ProposalModel proposal) {
    final schemaAsync = ref.watch(_proposalViewSchemaProvider(formType));

    return schemaAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (schema) {
        if (proposal.formData.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 400,
          child: DynamicFormRenderer(
            schema: schema,
            initialData: proposal.formData,
            readOnly: true,
            displayMode: FormDisplayMode.singlePage,
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, ProposalModel proposal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proposal.isEditable) ...[
          SecondaryButton(
            label: 'Edit Proposal',
            icon: Icons.edit,
            onPressed: () {
              ref.read(selectedProposalProvider.notifier).state = proposal;
              context.push(
                '/farmer/proposals/form/${proposal.animalId}?proposalId=${proposal.id}',
              );
            },
          ),
          const SizedBox(height: 10),
        ],

        if (proposal.isSubmittable)
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
              onPressed: () => _submitProposal(proposal),
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              label: Text(
                'Submit Proposal',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

        if (proposal.hasPolicyCreated)
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
                context.push('/farmer/policies');
              },
              icon: const Icon(Icons.verified, color: Colors.white, size: 20),
              label: Text(
                'View Policy',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
