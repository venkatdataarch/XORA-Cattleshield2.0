import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pets, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'My Animals',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(animalListProvider.notifier).setSearchQuery(value);
                    },
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search by name, tag, or breed...',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey.shade400),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(animalListProvider.notifier)
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
              const SizedBox(height: 12),

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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/farmer/animals/onboard'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.add),
        ),
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
