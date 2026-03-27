import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/features/vet/certificate/domain/vet_certificate_model.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _vetCertificatesProvider =
    FutureProvider.autoDispose<List<VetCertificateModel>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.vetCertificates);
  final certs = <VetCertificateModel>[];

  result.when(
    success: (r) {
      final data = r.data;
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            certs.add(VetCertificateModel.fromJson(item));
          }
        }
      } else if (data is Map<String, dynamic>) {
        final list = data['data'] as List<dynamic>? ?? [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            certs.add(VetCertificateModel.fromJson(item));
          }
        }
      }
    },
    failure: (_) {},
  );

  return certs;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetCertificatesListScreen extends ConsumerWidget {
  const VetCertificatesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(_vetCertificatesProvider);

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
                          'Certificates',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'All certificates you have generated',
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

          // List
          certsAsync.when(
            data: (certs) {
              if (certs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined,
                            size: 56,
                            color: AppColors.textTertiary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No certificates yet',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Certificates will appear here after you approve proposals or claims',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _CertificateCard(
                    cert: certs[index],
                    onTap: () {
                      context.push('/vet/certificates/${certs[index].id}/preview');
                    },
                  ),
                  childCount: certs.length,
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
                    Text('Failed to load certificates',
                        style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(_vetCertificatesProvider),
                      child: const Text('Retry'),
                    ),
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
// Certificate Card
// ---------------------------------------------------------------------------

class _CertificateCard extends StatelessWidget {
  final VetCertificateModel cert;
  final VoidCallback onTap;

  const _CertificateCard({required this.cert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final dateStr = dateFormat.format(cert.createdAt);

    // Determine icon and color based on type
    final IconData icon;
    final Color color;
    switch (cert.type) {
      case CertificateType.proposal:
        icon = Icons.verified_outlined;
        color = AppColors.success;
        break;
      case CertificateType.claimDeath:
        icon = Icons.dangerous_outlined;
        color = AppColors.error;
        break;
      case CertificateType.claimInjury:
        icon = Icons.healing_outlined;
        color = AppColors.warning;
        break;
    }

    // Try to extract animal info from formData
    final formData = cert.formData;
    final animalName = formData['animalName']?.toString() ??
        formData['animal_name']?.toString() ??
        '';
    final species = formData['species']?.toString() ??
        formData['animalSpecies']?.toString() ??
        '';

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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.typeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (animalName.isNotEmpty || species.isNotEmpty)
                      Text(
                        [animalName, species]
                            .where((s) => s.isNotEmpty)
                            .join(' | '),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // View icon
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
