import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../domain/animal_model.dart';

/// Row of selectable chips for choosing an animal species.
///
/// Groups species into Cattle (Cow, Buffalo) and Equine (Mule, Horse, Donkey)
/// with visual grouping labels.
class SpeciesSelector extends StatelessWidget {
  final AnimalSpecies? selected;
  final ValueChanged<AnimalSpecies> onSelected;
  final bool showGroups;

  const SpeciesSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showGroups = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (showGroups) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cattle group
          Text(
            'Cattle',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _SpeciesChip(
                species: AnimalSpecies.cow,
                isSelected: selected == AnimalSpecies.cow,
                onTap: () => onSelected(AnimalSpecies.cow),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SpeciesChip(
                species: AnimalSpecies.buffalo,
                isSelected: selected == AnimalSpecies.buffalo,
                onTap: () => onSelected(AnimalSpecies.buffalo),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Equine group
          Text(
            'Equine',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _SpeciesChip(
                species: AnimalSpecies.mule,
                isSelected: selected == AnimalSpecies.mule,
                onTap: () => onSelected(AnimalSpecies.mule),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SpeciesChip(
                species: AnimalSpecies.horse,
                isSelected: selected == AnimalSpecies.horse,
                onTap: () => onSelected(AnimalSpecies.horse),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SpeciesChip(
                species: AnimalSpecies.donkey,
                isSelected: selected == AnimalSpecies.donkey,
                onTap: () => onSelected(AnimalSpecies.donkey),
              ),
            ],
          ),
        ],
      );
    }

    // Flat layout without group labels
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: AnimalSpecies.values.map((species) {
        return _SpeciesChip(
          species: species,
          isSelected: selected == species,
          onTap: () => onSelected(species),
        );
      }).toList(),
    );
  }
}

/// Individual species chip with icon and label.
class _SpeciesChip extends StatelessWidget {
  final AnimalSpecies species;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpeciesChip({
    required this.species,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (species) {
      case AnimalSpecies.cow:
        return Icons.pets;
      case AnimalSpecies.buffalo:
        return Icons.pets;
      case AnimalSpecies.mule:
        return Icons.agriculture;
      case AnimalSpecies.horse:
        return Icons.agriculture;
      case AnimalSpecies.donkey:
        return Icons.agriculture;
    }
  }

  Color get _accentColor {
    return species.isCattle ? AppColors.primary : AppColors.muleAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _accentColor;

    return Material(
      color: isSelected ? color : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isSelected ? color : AppColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 18,
                color: isSelected ? AppColors.textOnPrimary : color,
              ),
              const SizedBox(width: 6),
              Text(
                species.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
