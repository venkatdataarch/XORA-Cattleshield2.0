import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/features/auth/presentation/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Provider for vet stats
// ---------------------------------------------------------------------------

final _vetStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.vetStats);
  return result.when(
    success: (r) {
      final data = r.data;
      if (data is Map<String, dynamic>) {
        return {
          'approved': (data['approved_count'] as num?)?.toInt() ?? 0,
          'rejected': (data['rejected_count'] as num?)?.toInt() ?? 0,
          'total': (data['total_reviewed'] as num?)?.toInt() ?? 0,
        };
      }
      return {'approved': 0, 'rejected': 0, 'total': 0};
    },
    failure: (_) => {'approved': 0, 'rejected': 0, 'total': 0},
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetProfileScreen extends ConsumerWidget {
  const VetProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final statsAsync = ref.watch(_vetStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Gradient AppBar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (user?.name.isNotEmpty == true)
                                ? user!.name[0].toUpperCase()
                                : 'V',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.name ?? 'Veterinarian',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Veterinarian',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  statsAsync.when(
                    data: (stats) => Row(
                      children: [
                        _StatCard(
                          label: 'Approved',
                          value: stats['approved']?.toString() ?? '0',
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Rejected',
                          value: stats['rejected']?.toString() ?? '0',
                          color: AppColors.error,
                          icon: Icons.cancel_outlined,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Total',
                          value: stats['total']?.toString() ?? '0',
                          color: AppColors.info,
                          icon: Icons.assessment_outlined,
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(
                      height: 90,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),

                  // Contact Info
                  _SectionCard(
                    title: 'Contact Information',
                    children: [
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user?.phone ?? '-',
                      ),
                      if (user?.email != null)
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user!.email!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Professional Details
                  _SectionCard(
                    title: 'Professional Details',
                    children: [
                      _InfoRow(
                        icon: Icons.school_outlined,
                        label: 'Qualification',
                        value: user?.qualification ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Reg. Number',
                        value: user?.regNumber ?? '-',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Assignment
                  _SectionCard(
                    title: 'Assignment',
                    children: [
                      if (user?.state != null)
                        _InfoRow(
                          icon: Icons.flag_outlined,
                          label: 'State',
                          value: user!.state!,
                        ),
                      if (user?.district != null)
                        _InfoRow(
                          icon: Icons.map_outlined,
                          label: 'District',
                          value: user!.district!,
                        ),
                      if (user?.village != null)
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Village',
                          value: user!.village!,
                        ),
                      if (user?.state == null &&
                          user?.district == null &&
                          user?.village == null)
                        _InfoRow(
                          icon: Icons.location_off_outlined,
                          label: 'Location',
                          value: 'Not assigned',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context, ref),
                      icon: const Icon(Icons.logout, size: 20),
                      label: Text(
                        'Logout',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
