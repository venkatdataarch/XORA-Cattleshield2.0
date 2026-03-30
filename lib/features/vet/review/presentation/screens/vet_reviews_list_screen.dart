import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _ReviewItem {
  final String id;
  final String type; // proposal or claim
  final String title;
  final String subtitle;
  final String status;
  final String? reviewedAt;

  const _ReviewItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    this.reviewedAt,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _vetReviewsProvider =
    FutureProvider.autoDispose.family<List<_ReviewItem>, String?>((ref, filter) async {
  final dio = ref.watch(dioClientProvider);
  final queryParams = <String, dynamic>{};
  if (filter != null && filter != 'all') {
    queryParams['status'] = filter;
  }
  final result = await dio.get(ApiEndpoints.vetReviewed, queryParameters: queryParams);
  final items = <_ReviewItem>[];

  result.when(
    success: (r) {
      final data = r.data;
      if (data is Map<String, dynamic>) {
        final proposals = data['proposals'] as List<dynamic>? ?? [];
        for (final p in proposals) {
          if (p is Map<String, dynamic>) {
            items.add(_ReviewItem(
              id: p['id']?.toString() ?? '',
              type: 'proposal',
              title: p['animal_name']?.toString() ?? 'Proposal',
              subtitle:
                  '${p['animal_species'] ?? 'Cattle'} | Sum: ${p['sum_insured'] ?? '-'}',
              status: p['status']?.toString() ?? '',
              reviewedAt: p['reviewed_at']?.toString(),
            ));
          }
        }
        final claims = data['claims'] as List<dynamic>? ?? [];
        for (final c in claims) {
          if (c is Map<String, dynamic>) {
            items.add(_ReviewItem(
              id: c['id']?.toString() ?? '',
              type: 'claim',
              title: c['animal_name']?.toString() ?? c['claim_number']?.toString() ?? 'Claim',
              subtitle:
                  '${c['claim_type'] ?? 'death'} | Policy: ${c['policy_number'] ?? '-'}',
              status: c['status']?.toString() ?? '',
              reviewedAt: c['reviewed_at']?.toString(),
            ));
          }
        }
      }
    },
    failure: (_) {},
  );

  return items;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetReviewsListScreen extends ConsumerStatefulWidget {
  const VetReviewsListScreen({super.key});

  @override
  ConsumerState<VetReviewsListScreen> createState() =>
      _VetReviewsListScreenState();
}

class _VetReviewsListScreenState extends ConsumerState<VetReviewsListScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(_vetReviewsProvider(_filter == 'all' ? null : _filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Gradient AppBar
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF1A5C45)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'My Reviews',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'All proposals & claims you have reviewed',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Approved',
                    isSelected: _filter == 'vet_approved',
                    color: AppColors.success,
                    onTap: () => setState(() => _filter = 'vet_approved'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Rejected',
                    isSelected: _filter == 'vet_rejected',
                    color: AppColors.error,
                    onTap: () => setState(() => _filter = 'vet_rejected'),
                  ),
                ],
              ),
            ),
          ),

          // List
          reviewsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rate_review_outlined,
                            size: 56,
                            color: AppColors.textTertiary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No reviews found',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _ReviewCard(item: items[index], onTap: () {
                        if (items[index].type == 'proposal') {
                          context.push('/vet/reviews/proposals/${items[index].id}');
                        } else {
                          context.push('/vet/reviews/claims/${items[index].id}');
                        }
                      }),
                  childCount: items.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load reviews',
                        style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

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
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _ReviewItem item;
  final VoidCallback onTap;

  const _ReviewCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isApproved = item.status.contains('approved') ||
        item.status == 'policy_created' ||
        item.status == 'uiic_sent' ||
        item.status == 'settled';
    final statusColor = isApproved ? AppColors.success : AppColors.error;
    final statusLabel = _normalizeStatus(item.status);
    final dateFormat = DateFormat('dd MMM yyyy');

    String dateStr = '';
    if (item.reviewedAt != null) {
      final dt = DateTime.tryParse(item.reviewedAt!);
      if (dt != null) dateStr = dateFormat.format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (item.type == 'proposal'
                          ? AppColors.info
                          : AppColors.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.type == 'proposal'
                      ? Icons.description_outlined
                      : Icons.healing_outlined,
                  color: item.type == 'proposal'
                      ? AppColors.info
                      : AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          dateStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
