import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
                        _selectedType != null
                            ? 'File ${_selectedType!.label} Claim'
                            : 'File a Claim',
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
                  message: 'Submitting claim...',
                  child: _selectedType == null
                      ? _buildTypeSelection()
                      : _buildClaimForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'What type of claim?',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the type of claim you want to file for this policy.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ...ClaimType.values.map((type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildClaimForm() {
    final schemaAsync = ref.watch(_claimFormSchemaProvider(_formType));

    return schemaAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
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
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _selectedType!.color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _selectedType!.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(_selectedType!.icon, size: 18, color: _selectedType!.color),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedType!.label} Claim',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _selectedType!.color,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedType = null),
                    child: Text('Change', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: type.color.withValues(alpha: 0.2)),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(type.icon, color: type.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: type.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _description,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: type.color),
          ],
        ),
      ),
    );
  }
}
