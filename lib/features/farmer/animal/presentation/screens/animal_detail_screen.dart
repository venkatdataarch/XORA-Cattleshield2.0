import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../../../shared/widgets/secondary_button.dart';
import '../../../../../shared/widgets/status_badge.dart';
import '../../domain/animal_model.dart';
import '../providers/animal_provider.dart';

/// Full detail screen for a single animal.
///
/// Displays all animal information, photo gallery, health score,
/// and action buttons for proposals and policies.
class AnimalDetailScreen extends ConsumerWidget {
  final String animalId;
  final AnimalModel? initialAnimal;

  const AnimalDetailScreen({
    super.key,
    required this.animalId,
    this.initialAnimal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animal = initialAnimal ?? ref.watch(selectedAnimalProvider);
    final theme = Theme.of(context);

    if (animal == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          title: const Text('Animal Detail'),
        ),
        body: const Center(child: Text('Animal not found.')),
      );
    }

    final accentColor = animal.isCattle ? AppColors.primary : AppColors.muleAccent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Collapsing header with species icon
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: accentColor,
            foregroundColor: AppColors.textOnPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        animal.isCattle ? Icons.pets : Icons.agriculture,
                        size: 56,
                        color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        animal.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      if (animal.uniqueId != null)
                        Text(
                          animal.uniqueId!,
                          style: AppTypography.mono.copyWith(
                            color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // Photo gallery
                  _PhotoGallery(animal: animal),
                  const SizedBox(height: AppSpacing.lg),

                  // Details card
                  _DetailsCard(animal: animal),
                  const SizedBox(height: AppSpacing.lg),

                  // Health score section
                  if (animal.healthScore != null) ...[
                    _HealthScoreSection(animal: animal),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Action buttons
                  _ActionButtons(animal: animal),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal photo gallery for muzzle and body photos.
class _PhotoGallery extends StatelessWidget {
  final AnimalModel animal;

  const _PhotoGallery({required this.animal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPhotos = [
      ...?animal.muzzleImages,
      ...?animal.bodyPhotos,
    ];

    if (allPhotos.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: AppColors.textTertiary,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No photos available',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allPhotos.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  child: Image.network(
                    allPhotos[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Card showing all animal details in a structured layout.
class _DetailsCard extends StatelessWidget {
  final AnimalModel animal;

  const _DetailsCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
          Row(
            children: [
              Text('Animal Details', style: theme.textTheme.titleSmall),
              const Spacer(),
              StatusBadge(
                label: animal.speciesLabel,
                color: animal.isCattle
                    ? AppColors.primary
                    : AppColors.muleAccent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          if (animal.identificationTag != null)
            _DetailRow(
              label: 'Tag Number',
              value: animal.identificationTag!,
              isMono: true,
            ),
          if (animal.speciesBreed != null)
            _DetailRow(label: 'Breed', value: animal.speciesBreed!),
          if (animal.sex != null)
            _DetailRow(label: 'Sex', value: animal.sex!.label),
          if (animal.sexCondition != null)
            _DetailRow(label: 'Condition', value: animal.sexCondition!.label),
          if (animal.ageYears != null)
            _DetailRow(
              label: 'Age',
              value: '${animal.ageYears!.toStringAsFixed(1)} years',
            ),
          if (animal.color != null)
            _DetailRow(label: 'Color', value: animal.color!),
          if (animal.distinguishingMarks != null)
            _DetailRow(label: 'Marks', value: animal.distinguishingMarks!),
          if (animal.milkYieldLtr != null)
            _DetailRow(
              label: 'Milk Yield',
              value: '${animal.milkYieldLtr!.toStringAsFixed(1)} L/day',
            ),
          if (animal.heightCm != null)
            _DetailRow(
              label: 'Height',
              value: '${animal.heightCm!.toStringAsFixed(0)} cm',
            ),
          if (animal.marketValue != null)
            _DetailRow(
              label: 'Market Value',
              value: '\u20B9${animal.marketValue!.toStringAsFixed(0)}',
            ),
          if (animal.sumInsured != null)
            _DetailRow(
              label: 'Sum Insured',
              value: '\u20B9${animal.sumInsured!.toStringAsFixed(0)}',
            ),
          if (animal.muzzleId != null)
            _DetailRow(
              label: 'Muzzle ID',
              value: animal.muzzleId!,
              isMono: true,
            ),
          if (animal.createdAt != null)
            _DetailRow(
              label: 'Registered',
              value: _formatDate(animal.createdAt!),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

/// Single row in the details card.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              style: isMono
                  ? AppTypography.mono.copyWith(fontSize: 13)
                  : theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Health score section with visual gauge.
class _HealthScoreSection extends StatelessWidget {
  final AnimalModel animal;

  const _HealthScoreSection({required this.animal});

  Color get _scoreColor {
    final score = animal.healthScore ?? 0;
    if (score >= 80) return AppColors.riskLow;
    if (score >= 60) return AppColors.riskMedium;
    if (score >= 40) return AppColors.riskHigh;
    return AppColors.riskCritical;
  }

  String get _riskLabel {
    if (animal.healthRiskCategory != null) {
      return animal.healthRiskCategory!;
    }
    final score = animal.healthScore ?? 0;
    if (score >= 80) return 'Low Risk';
    if (score >= 60) return 'Medium Risk';
    if (score >= 40) return 'High Risk';
    return 'Critical Risk';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = animal.healthScore ?? 0;

    return Container(
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
          Text('Health Score', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),

          // Score gauge
          Row(
            children: [
              // Circular gauge
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 8,
                        backgroundColor: _scoreColor.withValues(alpha: 0.15),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.toString(),
                          style: AppTypography.mono.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _scoreColor,
                          ),
                        ),
                        Text(
                          '/100',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // Risk label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(
                      label: _riskLabel,
                      color: _scoreColor,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Based on the latest health assessment.',
                      style: theme.textTheme.bodySmall,
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
}

/// Action buttons for navigating to proposals, policies, etc.
class _ActionButtons extends StatelessWidget {
  final AnimalModel animal;

  const _ActionButtons({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'New Proposal',
          icon: Icons.description_outlined,
          onPressed: () {
            context.push('/farmer/proposals/new', extra: animal);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'View Policies',
          icon: Icons.policy_outlined,
          onPressed: () {
            context.push('/farmer/policies', extra: animal);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'View Proposals',
          icon: Icons.list_alt,
          onPressed: () {
            context.push('/farmer/proposals', extra: animal);
          },
        ),
      ],
    );
  }
}
