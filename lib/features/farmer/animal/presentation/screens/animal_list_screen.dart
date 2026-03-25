import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../shared/widgets/app_error_widget.dart';
import '../../../../../shared/widgets/empty_state_widget.dart';
import '../../domain/animal_model.dart';
import '../providers/animal_provider.dart';
import '../widgets/animal_card.dart';

/// Screen displaying a searchable, filterable list of registered animals.
class AnimalListScreen extends ConsumerStatefulWidget {
  const AnimalListScreen({super.key});

  @override
  ConsumerState<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends ConsumerState<AnimalListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(animalListProvider.notifier).loadAnimals();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(animalListProvider.notifier).loadAnimals();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(animalListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        title: const Text('My Animals'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(animalListProvider.notifier).setSearchQuery(value);
              },
              decoration: InputDecoration(
                hintText: 'Search by name, tag, or breed...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(animalListProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: AppSpacing.inputPadding,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: state.filterSpecies == null,
                    onTap: () {
                      ref
                          .read(animalListProvider.notifier)
                          .setFilter(null);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: 'Cattle',
                    isSelected: state.filterSpecies == AnimalSpecies.cow,
                    color: AppColors.primary,
                    onTap: () {
                      ref
                          .read(animalListProvider.notifier)
                          .setFilter(AnimalSpecies.cow);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: 'Buffalo',
                    isSelected: state.filterSpecies == AnimalSpecies.buffalo,
                    color: AppColors.primary,
                    onTap: () {
                      ref
                          .read(animalListProvider.notifier)
                          .setFilter(AnimalSpecies.buffalo);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: 'Mule',
                    isSelected: state.filterSpecies == AnimalSpecies.mule,
                    color: AppColors.muleAccent,
                    onTap: () {
                      ref
                          .read(animalListProvider.notifier)
                          .setFilter(AnimalSpecies.mule);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: 'Horse',
                    isSelected: state.filterSpecies == AnimalSpecies.horse,
                    color: AppColors.muleAccent,
                    onTap: () {
                      ref
                          .read(animalListProvider.notifier)
                          .setFilter(AnimalSpecies.horse);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    label: 'Donkey',
                    isSelected: state.filterSpecies == AnimalSpecies.donkey,
                    color: AppColors.muleAccent,
                    onTap: () {
                      ref
                          .read(animalListProvider.notifier)
                          .setFilter(AnimalSpecies.donkey);
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Animal list
          Expanded(
            child: state.animals.when(
              data: (_) {
                final filtered = state.filteredAnimals;
                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.pets_outlined,
                    title: state.searchQuery.isNotEmpty ||
                            state.filterSpecies != null
                        ? 'No animals match your filters'
                        : 'No animals registered',
                    subtitle: state.searchQuery.isNotEmpty ||
                            state.filterSpecies != null
                        ? 'Try adjusting your search or filters.'
                        : 'Register your first animal to get started.',
                    action: state.searchQuery.isEmpty &&
                            state.filterSpecies == null
                        ? TextButton.icon(
                            onPressed: () =>
                                context.push('/farmer/animals/onboard'),
                            icon: const Icon(Icons.add),
                            label: const Text('Register Animal'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          )
                        : null,
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final animal = filtered[index];
                      return AnimalCard(
                        animal: animal,
                        onTap: () {
                          ref.read(selectedAnimalProvider.notifier).state =
                              animal;
                          context.push(
                            '/farmer/animals/${animal.id}',
                            extra: animal,
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () {
                  ref.read(animalListProvider.notifier).loadAnimals();
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/farmer/animals/onboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Selectable filter chip for species filtering.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    return Material(
      color: isSelected ? effectiveColor : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? effectiveColor : AppColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
