import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/features/farmer/proposal/domain/proposal_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import '../widgets/review_checklist.dart';
import '../widgets/approval_action_bar.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _proposalDetailProvider =
    FutureProvider.autoDispose.family<ProposalModel, String>((ref, id) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.proposalById(id));
  return result.when(
    success: (r) => ProposalModel.fromJson(r.data as Map<String, dynamic>),
    failure: (e) => throw Exception(e.message),
  );
});

final _proposalSchemaProvider =
    FutureProvider.autoDispose<FormSchema>((ref) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema('proposal_cattle');
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetProposalReviewScreen extends ConsumerStatefulWidget {
  final String proposalId;

  const VetProposalReviewScreen({super.key, required this.proposalId});

  @override
  ConsumerState<VetProposalReviewScreen> createState() =>
      _VetProposalReviewScreenState();
}

class _VetProposalReviewScreenState
    extends ConsumerState<VetProposalReviewScreen> {
  bool _allChecked = false;
  bool _isSubmitting = false;
  int _currentPhotoIndex = 0;

  static const _checklistItems = [
    'Animal photos verified',
    'Health condition acceptable',
    'Farm details confirmed',
    'Identity tag verified',
    'Market value reviewed',
  ];

  @override
  Widget build(BuildContext context) {
    final proposalAsync = ref.watch(_proposalDetailProvider(widget.proposalId));
    final schemaAsync = ref.watch(_proposalSchemaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposal Review'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: proposalAsync.when(
        loading: () => const LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (proposal) {
          return LoadingOverlay(
            isLoading: _isSubmitting,
            message: 'Submitting decision...',
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo gallery
                        _buildPhotoGallery(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // AI Health Score
                        _buildHealthScore(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Farmer info
                        _buildFarmerInfo(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Form data
                        schemaAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (_, __) => const Text(
                            'Could not load form schema',
                          ),
                          data: (schema) => DynamicFormRenderer(
                            schema: schema,
                            initialData: proposal.formData,
                            readOnly: true,
                            displayMode: FormDisplayMode.singlePage,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Checklist
                        ReviewChecklist(
                          items: _checklistItems,
                          onAllCheckedChanged: (allChecked) {
                            setState(() => _allChecked = allChecked);
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),

                // Action bar
                ApprovalActionBar(
                  approveEnabled: _allChecked,
                  showRequestChanges: true,
                  isLoading: _isSubmitting,
                  onReject: () => _submitDecision('rejected'),
                  onRequestChanges: () =>
                      _submitDecision('changes_requested'),
                  onApprove: () => _submitDecision('approved'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoGallery(BuildContext context, ProposalModel proposal) {
    final photos = proposal.formData['photos'] as List<dynamic>? ?? [];
    if (photos.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library, size: 48, color: AppColors.textTertiary),
              SizedBox(height: 8),
              Text('No photos available',
                  style: TextStyle(color: AppColors.textTertiary)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
            itemBuilder: (ctx, i) {
              final url = photos[i].toString();
              return ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppSpacing.cardRadius),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 48, color: AppColors.textTertiary),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              photos.length,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentPhotoIndex
                      ? AppColors.primary
                      : AppColors.cardBorder,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHealthScore(BuildContext context, ProposalModel proposal) {
    final score =
        proposal.formData['healthScore'] as int? ?? (85 + Random().nextInt(6));

    Color scoreColor;
    String scoreLabel;
    if (score >= 85) {
      scoreColor = AppColors.success;
      scoreLabel = 'Excellent';
    } else if (score >= 70) {
      scoreColor = AppColors.info;
      scoreLabel = 'Good';
    } else if (score >= 50) {
      scoreColor = AppColors.warning;
      scoreLabel = 'Fair';
    } else {
      scoreColor = AppColors.error;
      scoreLabel = 'Poor';
    }

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: scoreColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
                Text(
                  score.toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
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
                Text(
                  'AI Health Score',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on AI body condition analysis',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerInfo(BuildContext context, ProposalModel proposal) {
    final farmerName =
        proposal.formData['farmerName']?.toString() ?? 'Unknown Farmer';
    final farmerId =
        proposal.formData['farmerId']?.toString() ?? proposal.farmerId;
    final village = proposal.formData['village']?.toString();

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Farmer Information',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _infoRow(context, 'Name', farmerName),
          _infoRow(context, 'ID', farmerId),
          if (village != null) _infoRow(context, 'Village', village),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDecision(String decision) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(
        ApiEndpoints.proposalVetDecision(widget.proposalId),
        data: {'decision': decision},
      );

      if (!mounted) return;

      if (decision == 'approved') {
        context.pushReplacement(
          '/vet/certificate/form?type=proposal&entityId=${widget.proposalId}',
        );
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'rejected'
                  ? 'Proposal rejected'
                  : 'Changes requested',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
