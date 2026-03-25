import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(
        title: const Text('Proposal Details'),
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Submitting proposal...',
        child: proposalAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(_proposalDetailProvider(widget.proposalId)),
          ),
          data: (proposal) => _buildContent(context, proposal),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProposalModel proposal) {
    final dateFormat = DateFormat('dd MMM yyyy');

    // Determine form type for schema loading.
    final species = proposal.animalSpecies?.toLowerCase() ?? '';
    final formType = (species == 'mule' || species == 'horse' || species == 'donkey')
        ? 'proposal_mule'
        : 'proposal_cattle';

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animal info card
          _buildAnimalInfoCard(context, proposal, dateFormat),
          const SizedBox(height: AppSpacing.md),

          // Rejection reason (if rejected)
          if (proposal.status == ProposalStatus.vetRejected &&
              proposal.rejectionReason != null) ...[
            _buildRejectionCard(proposal),
            const SizedBox(height: AppSpacing.md),
          ],

          // UIIC reference (if sent)
          if (proposal.uiicReference != null) ...[
            _buildInfoCard(
              icon: Icons.business,
              title: 'UIIC Reference',
              value: proposal.uiicReference!,
              color: Colors.purple,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Timeline
          ProposalTimeline(proposal: proposal),
          const SizedBox(height: AppSpacing.md),

          // Form data in read-only mode
          _buildFormDataSection(formType, proposal),
          const SizedBox(height: AppSpacing.md),

          // Action buttons
          _buildActions(context, proposal),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildAnimalInfoCard(
    BuildContext context,
    ProposalModel proposal,
    DateFormat dateFormat,
  ) {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  child: Icon(
                    Icons.pets,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.animalName ?? 'Animal #${proposal.animalId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (proposal.animalSpecies != null)
                        Text(
                          proposal.animalSpecies!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                ProposalStatusBadge(status: proposal.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
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
      ),
    );
  }

  Widget _buildRejectionCard(ProposalModel proposal) {
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
                  const Text(
                    'Rejection Reason',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    proposal.rejectionReason!,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
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
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormDataSection(String formType, ProposalModel proposal) {
    final schemaAsync = ref.watch(_proposalViewSchemaProvider(formType));

    return schemaAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
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
        // Edit button (only for drafts)
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
          const SizedBox(height: AppSpacing.sm),
        ],

        // Submit button (only for drafts)
        if (proposal.isSubmittable)
          PrimaryButton(
            label: 'Submit Proposal',
            icon: Icons.send,
            onPressed: () => _submitProposal(proposal),
          ),

        // View Policy link (if policy created)
        if (proposal.hasPolicyCreated)
          PrimaryButton(
            label: 'View Policy',
            icon: Icons.verified,
            onPressed: () {
              context.push('/farmer/policies');
            },
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
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
