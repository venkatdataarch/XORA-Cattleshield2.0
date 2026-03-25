import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/farmer/animal/domain/animal_model.dart';
import 'package:cattleshield/features/farmer/animal/presentation/providers/animal_provider.dart';
import '../../domain/proposal_model.dart';
import '../providers/proposal_provider.dart';

/// Provider to load the form schema for a proposal based on animal species.
final _proposalFormSchemaProvider =
    FutureProvider.family<FormSchema, String>((ref, animalId) async {
  final animal = ref.watch(selectedAnimalProvider);
  final repo = ref.watch(formSchemaRepositoryProvider);

  // Determine form type based on species.
  String formType;
  if (animal != null && animal.species.isEquine) {
    formType = 'proposal_mule';
  } else {
    formType = 'proposal_cattle';
  }

  return repo.getSchema(formType);
});

/// Screen for creating or editing an insurance proposal.
///
/// Receives [animalId] from route params. Optionally receives [proposalId]
/// for editing an existing draft proposal.
class ProposalFormScreen extends ConsumerStatefulWidget {
  final String animalId;
  final String? proposalId;

  const ProposalFormScreen({
    super.key,
    required this.animalId,
    this.proposalId,
  });

  @override
  ConsumerState<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends ConsumerState<ProposalFormScreen> {
  bool _isSubmitting = false;
  bool _isSavingDraft = false;

  /// Build initial form data with pre-filled animal details.
  Map<String, dynamic> _buildInitialData(AnimalModel? animal, ProposalModel? existing) {
    final data = <String, dynamic>{};

    // Pre-fill from existing proposal if editing.
    if (existing != null) {
      data.addAll(existing.formData);
    }

    // Pre-fill animal details.
    if (animal != null) {
      data['animalId'] = animal.id;
      data['species'] = animal.species.label;
      data['speciesBreed'] = animal.speciesBreed ?? '';
      data['identificationTag'] = animal.identificationTag ?? '';
      data['sex'] = animal.sex?.label ?? '';
      data['ageYears'] = animal.ageYears?.toString() ?? '';
      data['color'] = animal.color ?? '';
      data['distinguishingMarks'] = animal.distinguishingMarks ?? '';
      data['sumInsured'] = animal.sumInsured?.toString() ?? '';
      data['marketValue'] = animal.marketValue?.toString() ?? '';

      if (animal.uniqueId != null) {
        data['uniqueId'] = animal.uniqueId;
      }
    }

    return data;
  }

  Future<void> _handleSubmit(Map<String, dynamic> formData) async {
    setState(() => _isSubmitting = true);

    try {
      ProposalModel? result;

      if (widget.proposalId != null) {
        // Update existing proposal and submit.
        result = await ref.read(proposalListProvider.notifier).updateProposal(
              widget.proposalId!,
              formData,
              status: ProposalStatus.submitted,
            );
      } else {
        // Create new proposal as submitted.
        result = await ref.read(proposalListProvider.notifier).createProposal(
              widget.animalId,
              formData,
            );
      }

      if (result != null && mounted) {
        ref.read(selectedProposalProvider.notifier).state = result;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/farmer/proposals/${result.id}');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit proposal. Please try again.'),
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

  Future<void> _handleSaveDraft(Map<String, dynamic> formData) async {
    setState(() => _isSavingDraft = true);

    try {
      ProposalModel? result;

      if (widget.proposalId != null) {
        result = await ref.read(proposalListProvider.notifier).updateProposal(
              widget.proposalId!,
              formData,
            );
      } else {
        result = await ref.read(proposalListProvider.notifier).createProposal(
              widget.animalId,
              formData,
            );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save draft. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(_proposalFormSchemaProvider(widget.animalId));
    final animal = ref.watch(selectedAnimalProvider);
    final existingProposal = widget.proposalId != null
        ? ref.watch(selectedProposalProvider)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.proposalId != null ? 'Edit Proposal' : 'New Proposal',
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting || _isSavingDraft,
        message: _isSubmitting ? 'Submitting proposal...' : 'Saving draft...',
        child: schemaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorWidget(
            message: 'Failed to load form: $error',
            onRetry: () => ref.invalidate(_proposalFormSchemaProvider(widget.animalId)),
          ),
          data: (schema) {
            final initialData = _buildInitialData(animal, existingProposal);

            return DynamicFormRenderer(
              schema: schema,
              initialData: initialData,
              displayMode: FormDisplayMode.multiPage,
              onSubmit: _handleSubmit,
              onSaveDraft: _handleSaveDraft,
            );
          },
        ),
      ),
    );
  }
}
