import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

    if (animal == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.background, Colors.white],
            ),
          ),
          child: Center(
            child: Text(
              'Animal not found.',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

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
        child: CustomScrollView(
          slivers: [
            // Gradient header
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                animal.isCattle ? Icons.pets : Icons.agriculture,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              animal.displayName,
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (animal.uniqueId != null)
                              Text(
                                animal.uniqueId!,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo gallery
                    _PhotoGallery(animal: animal),
                    const SizedBox(height: 20),

                    // Details card
                    _DetailsCard(animal: animal),
                    const SizedBox(height: 20),

                    // Health score section
                    if (animal.healthScore != null) ...[
                      _HealthScoreSection(animal: animal),
                      const SizedBox(height: 20),
                    ],

                    // Action buttons
                    _ActionButtons(animal: animal),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final allPhotos = [
      ...?animal.muzzleImages,
      ...?animal.bodyPhotos,
    ];

    if (allPhotos.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No photos available',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_library, color: AppColors.secondary, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Photos',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allPhotos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    allPhotos[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image,
                      color: Colors.grey.shade400,
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
    return Container(
      width: double.infinity,
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
                child: const Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Animal Details',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: animal.speciesLabel,
                color: animal.isCattle
                    ? AppColors.primary
                    : AppColors.muleAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),

          if (animal.identificationTag != null)
            _DetailRow(label: 'Tag Number', value: animal.identificationTag!, isMono: true),
          if (animal.speciesBreed != null)
            _DetailRow(label: 'Breed', value: animal.speciesBreed!),
          if (animal.sex != null)
            _DetailRow(label: 'Sex', value: animal.sex!.label),
          if (animal.sexCondition != null)
            _DetailRow(label: 'Condition', value: animal.sexCondition!.label),
          if (animal.ageYears != null)
            _DetailRow(label: 'Age', value: '${animal.ageYears!.toStringAsFixed(1)} years'),
          if (animal.color != null)
            _DetailRow(label: 'Color', value: animal.color!),
          if (animal.distinguishingMarks != null)
            _DetailRow(label: 'Marks', value: animal.distinguishingMarks!),
          if (animal.milkYieldLtr != null)
            _DetailRow(label: 'Milk Yield', value: '${animal.milkYieldLtr!.toStringAsFixed(1)} L/day'),
          if (animal.heightCm != null)
            _DetailRow(label: 'Height', value: '${animal.heightCm!.toStringAsFixed(0)} cm'),
          if (animal.marketValue != null)
            _DetailRow(label: 'Market Value', value: '\u20B9${animal.marketValue!.toStringAsFixed(0)}'),
          if (animal.sumInsured != null)
            _DetailRow(label: 'Sum Insured', value: '\u20B9${animal.sumInsured!.toStringAsFixed(0)}'),
          if (animal.muzzleId != null)
            _DetailRow(label: 'Muzzle ID', value: animal.muzzleId!, isMono: true),
          if (animal.createdAt != null)
            _DetailRow(label: 'Registered', value: _formatDate(animal.createdAt!)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isMono
                  ? AppTypography.mono.copyWith(fontSize: 13)
                  : GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
    final score = animal.healthScore ?? 0;

    return Container(
      width: double.infinity,
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
                  color: _scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.monitor_heart, color: _scoreColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Health Score',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Score gauge
          Row(
            children: [
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
                        valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.toString(),
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _scoreColor,
                          ),
                        ),
                        Text(
                          '/100',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(
                      label: _riskLabel,
                      color: _scoreColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Based on the latest health assessment.',
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
        // Gradient primary button
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
              context.push('/farmer/proposals/new', extra: animal);
            },
            icon: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
            label: Text(
              'New Proposal',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'View Policies',
          icon: Icons.policy_outlined,
          onPressed: () {
            context.push('/farmer/policies', extra: animal);
          },
        ),
        const SizedBox(height: 10),
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
