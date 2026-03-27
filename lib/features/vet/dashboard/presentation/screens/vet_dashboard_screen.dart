import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/shared/widgets/empty_state_widget.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/features/farmer/proposal/domain/proposal_model.dart';
import 'package:cattleshield/features/farmer/claim/domain/claim_model.dart';
import 'package:cattleshield/features/auth/presentation/providers/auth_provider.dart';
import '../widgets/vet_stats_card.dart';
import '../widgets/pending_reviews_list.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Dashboard data: stats + pending items + approved animals.
final vetDashboardProvider =
    FutureProvider.autoDispose<_VetDashboardData>((ref) async {
  final dio = ref.watch(dioClientProvider);

  // Fetch pending items
  final pendingResult = await dio.get(ApiEndpoints.vetPending);
  final List<PendingReviewItem> pendingItems = [];
  int pendingCount = 0;
  int approvedCount = 0;
  int totalReviewed = 0;

  pendingResult.when(
    success: (response) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Parse stats
        pendingCount = data['pendingCount'] as int? ?? 0;
        approvedCount = data['approvedCount'] as int? ?? 0;
        totalReviewed = data['totalReviewed'] as int? ?? 0;

        // Parse proposals
        final proposals = data['proposals'] as List<dynamic>? ?? [];
        for (final p in proposals) {
          if (p is Map<String, dynamic>) {
            pendingItems.add(
              PendingReviewItem.fromProposal(ProposalModel.fromJson(p)),
            );
          }
        }

        // Parse claims
        final claims = data['claims'] as List<dynamic>? ?? [];
        for (final c in claims) {
          if (c is Map<String, dynamic>) {
            pendingItems.add(
              PendingReviewItem.fromClaim(ClaimModel.fromJson(c)),
            );
          }
        }
      }
    },
    failure: (_) {},
  );

  // Fetch approved livestock
  final approvedResult = await dio.get(
    ApiEndpoints.vetCertificates,
    queryParameters: {'status': 'approved'},
  );
  final List<_ApprovedAnimal> approvedAnimals = [];

  approvedResult.when(
    success: (response) {
      final data = response.data;
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            approvedAnimals.add(_ApprovedAnimal.fromJson(item));
          }
        }
      } else if (data is Map<String, dynamic>) {
        final list = data['data'] as List<dynamic>? ?? [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            approvedAnimals.add(_ApprovedAnimal.fromJson(item));
          }
        }
      }
    },
    failure: (_) {},
  );

  return _VetDashboardData(
    pendingCount: pendingCount,
    approvedCount: approvedCount,
    totalReviewed: totalReviewed,
    pendingItems: pendingItems,
    approvedAnimals: approvedAnimals,
  );
});

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _VetDashboardData {
  final int pendingCount;
  final int approvedCount;
  final int totalReviewed;
  final List<PendingReviewItem> pendingItems;
  final List<_ApprovedAnimal> approvedAnimals;

  const _VetDashboardData({
    required this.pendingCount,
    required this.approvedCount,
    required this.totalReviewed,
    required this.pendingItems,
    required this.approvedAnimals,
  });
}

class _ApprovedAnimal {
  final String id;
  final String name;
  final String species;
  final String? tag;
  final String? certId;
  final DateTime? approvedAt;

  const _ApprovedAnimal({
    required this.id,
    required this.name,
    required this.species,
    this.tag,
    this.certId,
    this.approvedAt,
  });

  factory _ApprovedAnimal.fromJson(Map<String, dynamic> json) {
    return _ApprovedAnimal(
      id: json['id']?.toString() ?? json['animalId']?.toString() ?? '',
      name: json['animalName']?.toString() ?? json['name']?.toString() ?? '',
      species: json['species']?.toString() ?? 'Cattle',
      tag: json['tag']?.toString() ?? json['identificationTag']?.toString(),
      certId: json['certificateId']?.toString() ?? json['certId']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetDashboardScreen extends ConsumerWidget {
  const VetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(vetDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashboardAsync.when(
        loading: () => const LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Failed to load dashboard',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.invalidate(vetDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(vetDashboardProvider),
          child: CustomScrollView(
            slivers: [
              // Green header
              SliverToBoxAdapter(child: _buildHeader(context)),
              // Stats row
              SliverToBoxAdapter(child: _buildStatsRow(context, data)),
              // Pending section
              SliverToBoxAdapter(
                child: _buildPendingSection(context, ref, data),
              ),
              // Approved section
              SliverToBoxAdapter(
                child: _buildApprovedSection(context, data),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medical_services,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vet Dashboard',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review & approve livestock insurance',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Logout button
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Logout', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                  content: Text('Are you sure you want to logout?', style: GoogleFonts.inter()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ProviderScope.containerOf(context).read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, _VetDashboardData data) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          VetStatsCard(
            icon: Icons.pending_actions,
            count: data.pendingCount,
            label: 'Pending\nApprovals',
            accentColor: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          VetStatsCard(
            icon: Icons.verified,
            count: data.approvedCount,
            label: 'Approved\nLivestock',
            accentColor: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          VetStatsCard(
            icon: Icons.fact_check,
            count: data.totalReviewed,
            label: 'Total\nReviewed',
            accentColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection(
    BuildContext context,
    WidgetRef ref,
    _VetDashboardData data,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending for Approval',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PendingReviewsList(
            items: data.pendingItems,
            onScreenImages: (item) {
              // Navigate to image screening
              if (item.isProposal) {
                context.push('/vet/reviews/proposals/${item.id}');
              } else {
                context.push('/vet/reviews/claims/${item.id}');
              }
            },
            onAnalyse: (item) {
              if (item.isProposal) {
                context.push('/vet/reviews/proposals/${item.id}');
              } else {
                context.push('/vet/reviews/claims/${item.id}');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedSection(
    BuildContext context,
    _VetDashboardData data,
  ) {
    if (data.approvedAnimals.isEmpty) return const SizedBox.shrink();

    final dateFormat = DateFormat('dd MMM yyyy');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Approved Livestock',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.approvedAnimals.map(
            (animal) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                title: Text(
                  animal.name.isNotEmpty ? animal.name : animal.species,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${animal.species}${animal.tag != null ? ' - ${animal.tag}' : ''}${animal.approvedAt != null ? ' | ${dateFormat.format(animal.approvedAt!)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                trailing: OutlinedButton(
                  onPressed: () {
                    if (animal.certId != null) {
                      context.push(
                        '/vet/certificate/${animal.certId}/preview',
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
                  child: const Text('View Cert'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
