import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../farmer/proposal/domain/proposal_model.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _adminPendingProvider =
    FutureProvider.autoDispose<List<ProposalModel>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.adminPending);
  return result.when(
    success: (response) {
      final data = response.data;
      List<dynamic> items = [];
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        items = (data['data'] as List<dynamic>?) ??
            (data['proposals'] as List<dynamic>?) ??
            [];
      }
      return items
          .map((e) => ProposalModel.fromJson(e as Map<String, dynamic>))
          .toList();
    },
    failure: (e) => throw Exception(e.message),
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdminProposalReviewScreen extends ConsumerWidget {
  const AdminProposalReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_adminPendingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_adminPendingProvider);
          await ref.read(_adminPendingProvider.future).catchError((_) => <ProposalModel>[]);
        },
        child: pendingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Failed to load pending approvals',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('$err',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(_adminPendingProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (proposals) {
            if (proposals.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64,
                              color: AppColors.success.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text('No pending approvals',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('All proposals have been reviewed',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: proposals.length,
              itemBuilder: (context, index) {
                final proposal = proposals[index];
                return _ProposalCard(
                  proposal: proposal,
                  onTap: () => _showDetailSheet(context, ref, proposal),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showDetailSheet(
      BuildContext context, WidgetRef ref, ProposalModel proposal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProposalDetailSheet(proposal: proposal, parentRef: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Proposal Card
// ---------------------------------------------------------------------------

class _ProposalCard extends StatelessWidget {
  final ProposalModel proposal;
  final VoidCallback onTap;

  const _ProposalCard({required this.proposal, required this.onTap});

  String _imageUrl(String path) {
    final base = ApiEndpoints.baseUrl.replaceAll('/api', '');
    if (path.startsWith('http')) return path;
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final animal = proposal.animal;
    final muzzleImages = animal?.muzzleImages ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Muzzle thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: muzzleImages.isNotEmpty
                    ? Image.network(
                        _imageUrl(muzzleImages.first),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.animalName ?? animal?.breed ?? 'Unknown Animal',
                      style: GoogleFonts.manrope(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(animal?.species ?? proposal.animalSpecies ?? '').toUpperCase()} | ${animal?.identificationTag ?? 'No tag'}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: proposal.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            proposal.statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: proposal.statusColor,
                            ),
                          ),
                        ),
                        if (proposal.sumInsured != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '\u20B9${proposal.sumInsured!.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.pets, color: Colors.grey),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail bottom sheet with approve/reject
// ---------------------------------------------------------------------------

class _ProposalDetailSheet extends ConsumerStatefulWidget {
  final ProposalModel proposal;
  final WidgetRef parentRef;

  const _ProposalDetailSheet({
    required this.proposal,
    required this.parentRef,
  });

  @override
  ConsumerState<_ProposalDetailSheet> createState() =>
      _ProposalDetailSheetState();
}

class _ProposalDetailSheetState extends ConsumerState<_ProposalDetailSheet> {
  bool _isSubmitting = false;

  String _imageUrl(String path) {
    final base = ApiEndpoints.baseUrl.replaceAll('/api', '');
    if (path.startsWith('http')) return path;
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final animal = proposal.animal;
    final muzzleImages = animal?.muzzleImages ?? [];
    final healthScore = animal?.healthScore ??
        (proposal.formData['healthScore'] as int?);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Proposal Review',
                style: GoogleFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animal info
                    _sectionTitle('Animal Details'),
                    _infoRow('Name', proposal.animalName ?? 'N/A'),
                    _infoRow('Species',
                        animal?.species ?? proposal.animalSpecies ?? 'N/A'),
                    _infoRow('Breed', animal?.breed ?? 'N/A'),
                    _infoRow('Sex', animal?.sex ?? 'N/A'),
                    _infoRow('Age',
                        '${animal?.ageYears?.toStringAsFixed(1) ?? 'N/A'} yrs'),
                    _infoRow('Color', animal?.color ?? 'N/A'),
                    _infoRow('Tag', animal?.identificationTag ?? 'N/A'),
                    _infoRow(
                        'Market Value',
                        animal?.marketValue != null
                            ? '\u20B9${animal!.marketValue!.toStringAsFixed(0)}'
                            : 'N/A'),
                    const SizedBox(height: 16),

                    // Muzzle images
                    if (muzzleImages.isNotEmpty) ...[
                      _sectionTitle('Muzzle Images'),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: muzzleImages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _imageUrl(muzzleImages[i]),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image,
                                      color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Health score
                    if (healthScore != null) ...[
                      _sectionTitle('AI Health Score (CHI)'),
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: healthScore / 100,
                                  strokeWidth: 5,
                                  backgroundColor:
                                      AppColors.success.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation(
                                    healthScore >= 70
                                        ? AppColors.success
                                        : healthScore >= 50
                                            ? AppColors.warning
                                            : AppColors.error,
                                  ),
                                ),
                                Text(
                                  healthScore.toString(),
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: healthScore >= 70
                                        ? AppColors.success
                                        : healthScore >= 50
                                            ? AppColors.warning
                                            : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            healthScore >= 85
                                ? 'Excellent'
                                : healthScore >= 70
                                    ? 'Good'
                                    : healthScore >= 50
                                        ? 'Fair'
                                        : 'Poor',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Insurance details
                    _sectionTitle('Insurance Details'),
                    _infoRow(
                        'Sum Insured',
                        proposal.sumInsured != null
                            ? '\u20B9${proposal.sumInsured!.toStringAsFixed(0)}'
                            : 'N/A'),
                    _infoRow(
                        'Premium',
                        proposal.premium != null
                            ? '\u20B9${proposal.premium!.toStringAsFixed(0)}'
                            : 'N/A'),

                    // Vet remarks
                    if (proposal.rejectionReason != null &&
                        proposal.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Vet Remarks'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          proposal.rejectionReason!,
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ],

                    // Farmer info
                    if (proposal.farmer != null) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Farmer Details'),
                      _infoRow('Name', proposal.farmer!.name),
                      _infoRow('Phone', proposal.farmer!.phone),
                      _infoRow('Village', proposal.farmer!.village ?? 'N/A'),
                      _infoRow('District', proposal.farmer!.district ?? 'N/A'),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _showRejectDialog(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSubmitting ? null : () => _submitDecision('approve'),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Approve & Create Policy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _submitDecision('reject', reason: controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDecision(String decision, {String? reason}) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(
        ApiEndpoints.proposalAdminDecision(widget.proposal.id),
        data: {
          'decision': decision,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );

      if (!mounted) return;

      // Refresh the pending list
      widget.parentRef.invalidate(_adminPendingProvider);

      Navigator.of(context).pop(); // close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decision == 'approve'
              ? 'Proposal approved - policy will be created'
              : 'Proposal rejected'),
          backgroundColor:
              decision == 'approve' ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
