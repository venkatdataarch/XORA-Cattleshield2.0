import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/farmer/policy/presentation/providers/policy_provider.dart';
import '../../domain/claim_model.dart';
import '../providers/claim_provider.dart';

/// Provider to load the form schema for a claim based on claim type.
final _claimFormSchemaProvider =
    FutureProvider.family<FormSchema, String>((ref, formType) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema(formType);
});

/// Screen for creating a new insurance claim.
///
/// Flow:
/// 1. User selects claim type (Death / Injury / Disease)
/// 2. Loads appropriate form schema
/// 3. User fills out the form
/// 4. Submit creates the claim
class ClaimFormScreen extends ConsumerStatefulWidget {
  final String policyId;

  const ClaimFormScreen({
    super.key,
    required this.policyId,
  });

  @override
  ConsumerState<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

class _ClaimFormScreenState extends ConsumerState<ClaimFormScreen> {
  ClaimType? _selectedType;
  bool _isSubmitting = false;

  String get _formType {
    switch (_selectedType) {
      case ClaimType.death:
        return 'claim_death';
      case ClaimType.injury:
      case ClaimType.disease:
        return 'claim_injury';
      case null:
        return '';
    }
  }

  /// Build initial form data with pre-filled policy details.
  Map<String, dynamic> _buildInitialData() {
    final data = <String, dynamic>{};
    final policy = ref.read(selectedPolicyProvider);

    if (policy != null) {
      data['policyNumber'] = policy.policyNumber;
      data['policyId'] = policy.id;
      data['animalId'] = policy.animalId;
      data['insuredName'] = policy.insuredName ?? '';
      data['sumInsured'] = policy.sumInsured.toString();
    }

    if (_selectedType != null) {
      data['claimType'] = _selectedType!.label;
    }

    return data;
  }

  Future<void> _handleSubmit(Map<String, dynamic> formData) async {
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(claimListProvider.notifier).createClaim(
            widget.policyId,
            _selectedType!,
            formData,
          );

      if (result != null && mounted) {
        ref.read(selectedClaimProvider.notifier).state = result;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/farmer/claims/${result.id}');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit claim. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedType != null
              ? 'File ${_selectedType!.label} Claim'
              : 'File a Claim',
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Submitting claim...',
        child: _selectedType == null
            ? _buildTypeSelection()
            : _buildClaimForm(),
      ),
    );
  }

  /// Step 1: Claim type selection.
  Widget _buildTypeSelection() {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What type of claim?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Select the type of claim you want to file for this policy.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...ClaimType.values.map((type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ClaimTypeCard(
                type: type,
                onTap: () => setState(() => _selectedType = type),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Step 2: Dynamic form for the selected claim type.
  Widget _buildClaimForm() {
    final schemaAsync = ref.watch(_claimFormSchemaProvider(_formType));

    return schemaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorWidget(
        message: 'Failed to load form: $error',
        onRetry: () => ref.invalidate(_claimFormSchemaProvider(_formType)),
      ),
      data: (schema) {
        final initialData = _buildInitialData();

        return Column(
          children: [
            // Type selection indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _selectedType!.color.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(_selectedType!.icon, size: 18, color: _selectedType!.color),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedType!.label} Claim',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedType!.color,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedType = null),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: DynamicFormRenderer(
                schema: schema,
                initialData: initialData,
                displayMode: FormDisplayMode.multiPage,
                onSubmit: _handleSubmit,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Card for selecting a claim type.
class _ClaimTypeCard extends StatelessWidget {
  final ClaimType type;
  final VoidCallback onTap;

  const _ClaimTypeCard({
    required this.type,
    required this.onTap,
  });

  String get _description {
    switch (type) {
      case ClaimType.death:
        return 'File a claim for the death of the insured animal.';
      case ClaimType.injury:
        return 'File a claim for injury to the insured animal.';
      case ClaimType.disease:
        return 'File a claim for disease affecting the insured animal.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: type.color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Icon(type.icon, color: type.color, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: type.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: type.color),
            ],
          ),
        ),
      ),
    );
  }
}
