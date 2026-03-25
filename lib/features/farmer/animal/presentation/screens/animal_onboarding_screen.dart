import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../shared/widgets/loading_overlay.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../../../shared/widgets/secondary_button.dart';
import '../../domain/animal_model.dart';
import '../providers/animal_provider.dart';
import '../widgets/species_selector.dart';

/// Multi-step animal registration screen with 3 steps:
/// 1. Animal Details (species, breed, tag, sex, etc.)
/// 2. Muzzle Scan (capture muzzle photos)
/// 3. Review & Submit
class AnimalOnboardingScreen extends ConsumerStatefulWidget {
  const AnimalOnboardingScreen({super.key});

  @override
  ConsumerState<AnimalOnboardingScreen> createState() =>
      _AnimalOnboardingScreenState();
}

class _AnimalOnboardingScreenState
    extends ConsumerState<AnimalOnboardingScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 - Animal details
  AnimalSpecies? _selectedSpecies;
  final _tagController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _colorController = TextEditingController();
  final _marksController = TextEditingController();
  final _milkYieldController = TextEditingController();
  final _heightController = TextEditingController();
  final _marketValueController = TextEditingController();
  final _sumInsuredController = TextEditingController();
  AnimalSex? _selectedSex;
  SexCondition? _selectedSexCondition;

  // Step 2 - Muzzle scan
  final List<String> _muzzleImagePaths = [];
  bool _muzzleCaptured = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tagController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _colorController.dispose();
    _marksController.dispose();
    _milkYieldController.dispose();
    _heightController.dispose();
    _marketValueController.dispose();
    _sumInsuredController.dispose();
    super.dispose();
  }

  bool get _isCattle =>
      _selectedSpecies == AnimalSpecies.cow ||
      _selectedSpecies == AnimalSpecies.buffalo;

  bool get _isEquine =>
      _selectedSpecies == AnimalSpecies.mule ||
      _selectedSpecies == AnimalSpecies.horse ||
      _selectedSpecies == AnimalSpecies.donkey;

  bool get _showSexCondition =>
      _isCattle && _selectedSex == AnimalSex.female;

  bool get _canProceedStep1 =>
      _selectedSpecies != null && _breedController.text.isNotEmpty;

  void _goToStep(int step) {
    if (step == 1 && !_canProceedStep1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a species and enter the breed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _currentStep = step);
  }

  Future<void> _onSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      final formData = FormData.fromMap({
        'species': _selectedSpecies!.name,
        if (_tagController.text.isNotEmpty)
          'identificationTag': _tagController.text,
        if (_breedController.text.isNotEmpty)
          'speciesBreed': _breedController.text,
        if (_ageController.text.isNotEmpty)
          'ageYears': double.tryParse(_ageController.text),
        if (_selectedSex != null) 'sex': _selectedSex!.name,
        if (_selectedSexCondition != null)
          'sexCondition': _selectedSexCondition!.name,
        if (_colorController.text.isNotEmpty) 'color': _colorController.text,
        if (_marksController.text.isNotEmpty)
          'distinguishingMarks': _marksController.text,
        if (_milkYieldController.text.isNotEmpty)
          'milkYieldLtr': double.tryParse(_milkYieldController.text),
        if (_heightController.text.isNotEmpty)
          'heightCm': double.tryParse(_heightController.text),
        if (_marketValueController.text.isNotEmpty)
          'marketValue': double.tryParse(_marketValueController.text),
        if (_sumInsuredController.text.isNotEmpty)
          'sumInsured': double.tryParse(_sumInsuredController.text),
      });

      final animal = await ref
          .read(animalListProvider.notifier)
          .registerAnimal(_selectedSpecies!, formData);

      if (!mounted) return;

      if (animal != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${animal.displayName} registered successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please try again.'),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        title: const Text('Register Animal'),
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Registering animal...',
        child: Column(
          children: [
            // Step indicator
            _StepIndicator(
              currentStep: _currentStep,
              steps: const ['Details', 'Muzzle', 'Review'],
            ),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: _buildStepContent(theme),
              ),
            ),

            // Navigation buttons
            _buildNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Details(theme);
      case 1:
        return _buildStep2Muzzle(theme);
      case 2:
        return _buildStep3Review(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Step 1 - Animal Details
  // ---------------------------------------------------------------------------

  Widget _buildStep1Details(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Species selector
          Text('Select Species', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SpeciesSelector(
            selected: _selectedSpecies,
            onSelected: (species) {
              setState(() {
                _selectedSpecies = species;
                // Reset species-specific fields.
                if (!_isCattle) {
                  _selectedSexCondition = null;
                  _milkYieldController.clear();
                }
                if (!_isEquine) {
                  _heightController.clear();
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_selectedSpecies != null) ...[
            // Tag number
            _buildTextField(
              controller: _tagController,
              label: 'Identification Tag Number',
              hint: 'e.g. HF-0042',
              icon: Icons.tag,
            ),
            const SizedBox(height: AppSpacing.md),

            // Breed
            _buildTextField(
              controller: _breedController,
              label: 'Breed',
              hint: _isCattle ? 'e.g. Gir, Holstein Friesian' : 'e.g. Poitou',
              icon: Icons.category,
              isRequired: true,
            ),
            const SizedBox(height: AppSpacing.md),

            // Age
            _buildTextField(
              controller: _ageController,
              label: 'Age (years)',
              hint: 'e.g. 3.5',
              icon: Icons.calendar_today,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),

            // Sex
            Text('Sex', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: AnimalSex.values.map((sex) {
                final isSelected = _selectedSex == sex;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(sex.label),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedSex = sex;
                        if (sex == AnimalSex.male) {
                          _selectedSexCondition = null;
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Sex condition (female cattle only)
            if (_showSexCondition) ...[
              Text('Condition', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<SexCondition>(
                value: _selectedSexCondition,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: AppSpacing.inputPadding,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.buttonRadius),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.buttonRadius),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                items: SexCondition.values.map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedSexCondition = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Color
            _buildTextField(
              controller: _colorController,
              label: 'Color',
              hint: 'e.g. Brown, White with spots',
              icon: Icons.palette,
            ),
            const SizedBox(height: AppSpacing.md),

            // Distinguishing marks
            _buildTextField(
              controller: _marksController,
              label: 'Distinguishing Marks',
              hint: 'e.g. Star on forehead, ear notch',
              icon: Icons.star_outline,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // Milk yield (cattle only)
            if (_isCattle) ...[
              _buildTextField(
                controller: _milkYieldController,
                label: 'Milk Yield (litres/day)',
                hint: 'e.g. 8.5',
                icon: Icons.water_drop,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Height (equine only)
            if (_isEquine) ...[
              _buildTextField(
                controller: _heightController,
                label: 'Height (cm)',
                hint: 'e.g. 140',
                icon: Icons.height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Market value
            _buildTextField(
              controller: _marketValueController,
              label: 'Market Value (\u20B9)',
              hint: 'e.g. 50000',
              icon: Icons.currency_rupee,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            // Sum insured
            _buildTextField(
              controller: _sumInsuredController,
              label: 'Sum Insured (\u20B9)',
              hint: 'e.g. 40000',
              icon: Icons.shield,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 - Muzzle Scan
  // ---------------------------------------------------------------------------

  Widget _buildStep2Muzzle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text('Muzzle Capture', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A muzzle scan uniquely identifies your animal, similar to a fingerprint. '
          'This helps in insurance verification and prevents fraud.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Capture button
        Center(
          child: Column(
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(
                    color: _muzzleCaptured
                        ? AppColors.success
                        : AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                    style: _muzzleCaptured
                        ? BorderStyle.solid
                        : BorderStyle.none,
                  ),
                ),
                child: _muzzleCaptured
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Muzzle Captured',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.primary.withValues(alpha: 0.5),
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Tap to Capture',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: _muzzleCaptured ? 'Retake' : 'Capture Muzzle',
                  icon: Icons.camera_alt,
                  onPressed: () {
                    // Navigate to muzzle scan screen.
                    // On return, update state with captured images.
                    setState(() {
                      _muzzleCaptured = true;
                      _muzzleImagePaths.add('mock_muzzle_image.jpg');
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Captured thumbnails
        if (_muzzleImagePaths.isNotEmpty) ...[
          Text('Captured Images', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _muzzleImagePaths.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(
                    Icons.image,
                    color: AppColors.primary,
                    size: 32,
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Ensure the muzzle is clearly visible with good lighting. '
                  'The image should be sharp and free of obstructions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 - Review & Submit
  // ---------------------------------------------------------------------------

  Widget _buildStep3Review(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('Review Details', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please review the information below before submitting.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Review card
        Container(
          width: double.infinity,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewRow(
                label: 'Species',
                value: _selectedSpecies?.label ?? '-',
                onEdit: () => _goToStep(0),
              ),
              if (_breedController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Breed',
                  value: _breedController.text,
                  onEdit: () => _goToStep(0),
                ),
              if (_tagController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Tag Number',
                  value: _tagController.text,
                  onEdit: () => _goToStep(0),
                ),
              if (_selectedSex != null)
                _ReviewRow(
                  label: 'Sex',
                  value: _selectedSex!.label,
                  onEdit: () => _goToStep(0),
                ),
              if (_selectedSexCondition != null)
                _ReviewRow(
                  label: 'Condition',
                  value: _selectedSexCondition!.label,
                  onEdit: () => _goToStep(0),
                ),
              if (_ageController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Age',
                  value: '${_ageController.text} years',
                  onEdit: () => _goToStep(0),
                ),
              if (_colorController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Color',
                  value: _colorController.text,
                  onEdit: () => _goToStep(0),
                ),
              if (_marksController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Marks',
                  value: _marksController.text,
                  onEdit: () => _goToStep(0),
                ),
              if (_milkYieldController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Milk Yield',
                  value: '${_milkYieldController.text} L/day',
                  onEdit: () => _goToStep(0),
                ),
              if (_heightController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Height',
                  value: '${_heightController.text} cm',
                  onEdit: () => _goToStep(0),
                ),
              if (_marketValueController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Market Value',
                  value: '\u20B9${_marketValueController.text}',
                  onEdit: () => _goToStep(0),
                ),
              if (_sumInsuredController.text.isNotEmpty)
                _ReviewRow(
                  label: 'Sum Insured',
                  value: '\u20B9${_sumInsuredController.text}',
                  onEdit: () => _goToStep(0),
                ),
              _ReviewRow(
                label: 'Muzzle Scan',
                value: _muzzleCaptured ? 'Completed' : 'Not captured',
                valueColor: _muzzleCaptured
                    ? AppColors.success
                    : AppColors.warning,
                onEdit: () => _goToStep(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: SecondaryButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  onPressed: () => _goToStep(_currentStep - 1),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _currentStep < 2
                  ? PrimaryButton(
                      label: 'Next',
                      icon: Icons.arrow_forward,
                      onPressed: () => _goToStep(_currentStep + 1),
                    )
                  : PrimaryButton(
                      label: 'Submit',
                      icon: Icons.check,
                      isLoading: _isSubmitting,
                      onPressed: _canProceedStep1 ? _onSubmit : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
            prefixIcon: icon != null
                ? Icon(icon, color: AppColors.textTertiary, size: 20)
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: AppSpacing.inputPadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Step indicator showing progress across the registration steps.
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const _StepIndicator({required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? AppColors.primary
                    : AppColors.cardBorder,
              ),
            );
          }

          // Step circle
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == currentStep;
          final isCompleted = stepIndex < currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive || isCompleted
                      ? AppColors.primary
                      : AppColors.surface,
                  border: Border.all(
                    color: isActive || isCompleted
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.textOnPrimary,
                        )
                      : Text(
                          '${stepIndex + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? AppColors.textOnPrimary
                                : AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isActive || isCompleted
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Row in the review step showing a label, value, and edit button.
class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onEdit;

  const _ReviewRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: const Icon(
                Icons.edit,
                size: 16,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
