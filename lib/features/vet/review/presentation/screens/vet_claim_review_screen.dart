import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/status_badge.dart';
import 'package:cattleshield/features/farmer/claim/domain/claim_model.dart';
import 'package:cattleshield/features/farmer/claim/presentation/widgets/evidence_gallery.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import '../widgets/review_checklist.dart';
import '../widgets/approval_action_bar.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _claimDetailProvider =
    FutureProvider.autoDispose.family<ClaimModel, String>((ref, id) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.claimById(id));
  return result.when(
    success: (r) => ClaimModel.fromJson(r.data as Map<String, dynamic>),
    failure: (e) => throw Exception(e.message),
  );
});

final _claimSchemaProvider =
    FutureProvider.autoDispose.family<FormSchema, String>(
        (ref, schemaType) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema(schemaType);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetClaimReviewScreen extends ConsumerStatefulWidget {
  final String claimId;

  const VetClaimReviewScreen({super.key, required this.claimId});

  @override
  ConsumerState<VetClaimReviewScreen> createState() =>
      _VetClaimReviewScreenState();
}

class _VetClaimReviewScreenState extends ConsumerState<VetClaimReviewScreen> {
  bool _allChecked = false;
  bool _isSubmitting = false;

  static const _checklistItems = [
    'Muzzle identity verified',
    'Cause of death reviewed',
    'Evidence photos verified',
    'Policy details confirmed',
    'Claim amount reviewed',
  ];

  @override
  Widget build(BuildContext context) {
    final claimAsync = ref.watch(_claimDetailProvider(widget.claimId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Claim Review', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
        ),
      ),
      body: claimAsync.when(
        loading: () => const LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (claim) {
          final schemaType = claim.type == ClaimType.death
              ? 'claim_death'
              : 'claim_injury';
          final schemaAsync = ref.watch(_claimSchemaProvider(schemaType));

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
                        // Photo comparison
                        _buildPhotoComparison(context, claim),
                        const SizedBox(height: AppSpacing.md),

                        // AI Muzzle Match
                        _buildMuzzleMatchScore(context, claim),
                        const SizedBox(height: AppSpacing.md),

                        // Evidence gallery
                        if (claim.evidenceMedia != null &&
                            claim.evidenceMedia!.isNotEmpty) ...[
                          Text(
                            'Evidence',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          EvidenceGallery(
                            media: claim.evidenceMedia!,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

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
                            initialData: claim.formData,
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

                // Action bar (no request-changes for claims)
                ApprovalActionBar(
                  approveEnabled: _allChecked,
                  showRequestChanges: false,
                  isLoading: _isSubmitting,
                  onReject: (reason) => _submitDecision('rejected', reason: reason),
                  onApprove: () => _submitDecision('approved'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoComparison(BuildContext context, ClaimModel claim) {
    final originalPhotos =
        claim.formData['originalPhotos'] as List<dynamic>? ?? [];
    final claimPhotos =
        claim.formData['claimPhotos'] as List<dynamic>? ?? [];

    // Calculate elapsed time since death for post-mortem display
    final deathTimeStr = claim.formData['death_date']?.toString() ??
        claim.formData['date_of_death']?.toString();
    String elapsedDisplay = '';
    if (deathTimeStr != null) {
      final deathTime = DateTime.tryParse(deathTimeStr);
      if (deathTime != null) {
        final elapsed = DateTime.now().difference(deathTime);
        if (elapsed.inHours > 0) {
          elapsedDisplay = '${elapsed.inHours}h ${elapsed.inMinutes % 60}m since death';
        } else {
          elapsedDisplay = '${elapsed.inMinutes}m since death';
        }
      }
    }

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
          // Header with post-mortem timer
          Row(
            children: [
              Expanded(
                child: Text(
                  'Muzzle Comparison (Side-by-Side)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (elapsedDisplay.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        elapsedDisplay,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Side-by-side comparison (Scope 5c — 10 marks)
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Text(
                        'ENROLLMENT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    _buildPhotoBox(
                      originalPhotos.isNotEmpty
                          ? originalPhotos.first.toString()
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live animal at enrollment',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // VS divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.compare_arrows, size: 20, color: Colors.grey),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Text(
                        'CLAIM (POST-MORTEM)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                    _buildPhotoBox(
                      claimPhotos.isNotEmpty
                          ? claimPhotos.first.toString()
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deceased animal at claim',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
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

  Widget _buildPhotoBox(String? url) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.background,
                  child: const Icon(Icons.broken_image,
                      color: AppColors.textTertiary),
                ),
              )
            : Container(
                color: AppColors.background,
                child: const Center(
                  child: Icon(Icons.image_not_supported,
                      size: 36, color: AppColors.textTertiary),
                ),
              ),
      ),
    );
  }

  Widget _buildMuzzleMatchScore(BuildContext context, ClaimModel claim) {
    final score = claim.aiMuzzleMatchScore ?? 0.0;
    Color matchColor;
    String matchLabel;
    IconData matchIcon;

    if (score >= 85) {
      matchColor = AppColors.success;
      matchLabel = 'Verified';
      matchIcon = Icons.check_circle;
    } else if (score >= 60) {
      matchColor = AppColors.warning;
      matchLabel = 'Uncertain';
      matchIcon = Icons.warning_amber_rounded;
    } else {
      matchColor = AppColors.error;
      matchLabel = 'Failed';
      matchIcon = Icons.cancel;
    }

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: matchColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'AI Muzzle Match',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: matchColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(matchColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.toStringAsFixed(0)}%',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: matchColor,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          StatusBadge(
            label: matchLabel,
            color: matchColor,
            icon: matchIcon,
          ),
          if (score < 85) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Vet override requires adding a justification note.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitDecision(String decision, {String? reason}) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(
        ApiEndpoints.claimVetDecision(widget.claimId),
        data: {
          'decision': decision,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );

      if (!mounted) return;

      if (decision == 'approved') {
        // Determine certificate type based on claim type
        final claim =
            ref.read(_claimDetailProvider(widget.claimId)).valueOrNull;
        final certType = claim?.type == ClaimType.injury
            ? 'claimInjury'
            : 'claimDeath';
        context.pushReplacement(
          '/vet/certificate/form?type=$certType&entityId=${widget.claimId}',
        );
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim rejected')),
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
