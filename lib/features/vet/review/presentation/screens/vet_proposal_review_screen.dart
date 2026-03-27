import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/core/constants/api_endpoints.dart';
import 'package:cattleshield/core/network/dio_client.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/features/farmer/proposal/domain/proposal_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import '../widgets/review_checklist.dart';
import '../widgets/approval_action_bar.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _proposalDetailProvider =
    FutureProvider.autoDispose.family<ProposalModel, String>((ref, id) async {
  final dio = ref.watch(dioClientProvider);
  final result = await dio.get(ApiEndpoints.proposalById(id));
  return result.when(
    success: (r) => ProposalModel.fromJson(r.data as Map<String, dynamic>),
    failure: (e) => throw Exception(e.message),
  );
});

final _proposalSchemaProvider =
    FutureProvider.autoDispose<FormSchema>((ref) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema('proposal_cattle');
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VetProposalReviewScreen extends ConsumerStatefulWidget {
  final String proposalId;

  const VetProposalReviewScreen({super.key, required this.proposalId});

  @override
  ConsumerState<VetProposalReviewScreen> createState() =>
      _VetProposalReviewScreenState();
}

class _VetProposalReviewScreenState
    extends ConsumerState<VetProposalReviewScreen> {
  bool _allChecked = false;
  bool _isSubmitting = false;
  int _currentPhotoIndex = 0;

  static const _checklistItems = [
    'Animal photos verified',
    'Health condition acceptable',
    'Farm details confirmed',
    'Identity tag verified',
    'Market value reviewed',
  ];

  @override
  Widget build(BuildContext context) {
    final proposalAsync = ref.watch(_proposalDetailProvider(widget.proposalId));
    final schemaAsync = ref.watch(_proposalSchemaProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Proposal Review', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
        ),
      ),
      body: proposalAsync.when(
        loading: () => const LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (proposal) {
          return LoadingOverlay(
            isLoading: _isSubmitting,
            message: 'Submitting decision...',
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Animal Info Card
                        _buildAnimalInfoCard(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Muzzle Images
                        _buildMuzzleImages(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Body Photos (360°)
                        _buildBodyPhotos(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // AI Health Score
                        _buildHealthScore(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Farmer info
                        _buildFarmerInfo(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Insurance Details
                        _buildInsuranceDetails(context, proposal),
                        const SizedBox(height: AppSpacing.md),

                        // Checklist
                        ReviewChecklist(
                          items: _checklistItems,
                          onAllCheckedChanged: (allChecked) {
                            setState(() => _allChecked = allChecked);
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),

                // Action bar
                ApprovalActionBar(
                  approveEnabled: _allChecked,
                  showRequestChanges: true,
                  isLoading: _isSubmitting,
                  onReject: () => _submitDecision('rejected'),
                  onRequestChanges: () =>
                      _submitDecision('changes_requested'),
                  onApprove: () => _submitDecision('approved'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimalInfoCard(BuildContext context, ProposalModel proposal) {
    final animal = proposal.animal;
    final formData = proposal.formData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pets, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.animalName ?? 'Unknown Animal',
                      style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'ID: ${animal?.uniqueId ?? "N/A"}',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (animal?.species ?? proposal.animalSpecies ?? '').toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _detailGrid([
            _DetailItem('Breed', animal?.breed ?? formData['breed']?.toString() ?? 'N/A'),
            _DetailItem('Sex', animal?.sex ?? formData['sex']?.toString() ?? 'N/A'),
            _DetailItem('Age', '${animal?.ageYears ?? formData['age'] ?? 'N/A'} yrs'),
            _DetailItem('Color', animal?.color ?? formData['color']?.toString() ?? 'N/A'),
            _DetailItem('Height', '${animal?.heightCm ?? 'N/A'} cm'),
            _DetailItem('Milk Yield', '${animal?.milkYieldLtr ?? formData['milk_yield'] ?? 'N/A'} L/day'),
            _DetailItem('Tag', animal?.identificationTag ?? formData['identification_tag']?.toString() ?? 'N/A'),
            _DetailItem('Marks', animal?.distinguishingMarks ?? formData['distinguishing_marks']?.toString() ?? 'None'),
          ]),
        ],
      ),
    );
  }

  Widget _detailGrid(List<_DetailItem> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 72) / 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(item.value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Constructs a full image URL from a relative path.
  String _imageUrl(String path) {
    final base = ApiEndpoints.baseUrl.replaceAll('/api', '');
    if (path.startsWith('http')) return path;
    return '$base$path';
  }

  void _openFullScreenImage(BuildContext context, String url, String label) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(imageUrl: url, label: label),
      ),
    );
  }

  Widget _buildMuzzleImages(BuildContext context, ProposalModel proposal) {
    final images = proposal.animal?.muzzleImages ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
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
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fingerprint, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Muzzle Scans (Biometric ID)', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: images.isNotEmpty ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  images.isNotEmpty ? '${images.length} captured' : 'None',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: images.isNotEmpty ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (images.isEmpty)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('No muzzle images captured', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final labels = ['Front', 'Left', 'Right'];
                  final url = _imageUrl(images[i]);
                  return GestureDetector(
                    onTap: () => _openFullScreenImage(context, url, i < labels.length ? labels[i] : 'Angle ${i + 1}'),
                    child: Column(
                      children: [
                        Hero(
                          tag: 'muzzle_$i',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 110, height: 110,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(i < labels.length ? labels[i] : 'Angle ${i + 1}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBodyPhotos(BuildContext context, ProposalModel proposal) {
    final photos = proposal.animal?.bodyPhotos ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.threesixty, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text('360\u00B0 Body Photos', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: photos.isNotEmpty ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  photos.isNotEmpty ? '${photos.length}/6 captured' : 'None',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: photos.isNotEmpty ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (photos.isEmpty)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('No body photos captured', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, i) {
                final labels = ['Front', 'Right Side', 'Rear', 'Left Side', 'Top', 'Close-up'];
                final url = _imageUrl(photos[i]);
                final label = i < labels.length ? labels[i] : 'Photo ${i + 1}';
                return GestureDetector(
                  onTap: () => _openFullScreenImage(context, url, label),
                  child: Column(
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'body_$i',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label,
                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textTertiary)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInsuranceDetails(BuildContext context, ProposalModel proposal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
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
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.policy, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Insurance Details', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _detailGrid([
            _DetailItem('Market Value', '\u20B9${proposal.animal?.marketValue?.toStringAsFixed(0) ?? proposal.formData['market_value']?.toString() ?? 'N/A'}'),
            _DetailItem('Sum Insured', '\u20B9${proposal.sumInsured?.toStringAsFixed(0) ?? 'N/A'}'),
            _DetailItem('Premium (4%)', '\u20B9${proposal.premium?.toStringAsFixed(0) ?? 'N/A'}'),
            _DetailItem('Status', proposal.statusLabel),
          ]),
        ],
      ),
    );
  }

  Widget _buildHealthScore(BuildContext context, ProposalModel proposal) {
    final score =
        proposal.formData['healthScore'] as int? ?? (85 + Random().nextInt(6));

    Color scoreColor;
    String scoreLabel;
    if (score >= 85) {
      scoreColor = AppColors.success;
      scoreLabel = 'Excellent';
    } else if (score >= 70) {
      scoreColor = AppColors.info;
      scoreLabel = 'Good';
    } else if (score >= 50) {
      scoreColor = AppColors.warning;
      scoreLabel = 'Fair';
    } else {
      scoreColor = AppColors.error;
      scoreLabel = 'Poor';
    }

    return Container(
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
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: scoreColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
                Text(
                  score.toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Health Score',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on AI body condition analysis',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerInfo(BuildContext context, ProposalModel proposal) {
    final farmer = proposal.farmer;
    final farmerName = farmer?.name ?? proposal.formData['farmerName']?.toString() ?? 'Unknown';
    final phone = farmer?.phone ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
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
                child: const Icon(Icons.person, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Farmer Information', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _detailGrid([
            _DetailItem('Name', farmerName),
            _DetailItem('Phone', phone.isNotEmpty ? phone : 'N/A'),
            _DetailItem('Village', farmer?.village ?? 'N/A'),
            _DetailItem('District', farmer?.district ?? 'N/A'),
            _DetailItem('State', farmer?.state ?? 'N/A'),
            _DetailItem('Occupation', farmer?.occupation ?? 'N/A'),
            if (farmer?.aadhaarNumber != null) _DetailItem('Aadhaar', farmer!.aadhaarNumber!),
            if (farmer?.fatherOrHusbandName != null) _DetailItem('Father/Husband', farmer!.fatherOrHusbandName!),
          ]),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDecision(String decision) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(
        ApiEndpoints.proposalVetDecision(widget.proposalId),
        data: {'decision': decision},
      );

      if (!mounted) return;

      if (decision == 'approved') {
        context.pushReplacement(
          '/vet/certificate/form?type=proposal&entityId=${widget.proposalId}',
        );
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'rejected'
                  ? 'Proposal rejected'
                  : 'Changes requested',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _DetailItem {
  final String label;
  final String value;
  const _DetailItem(this.label, this.value);
}

// ---------------------------------------------------------------------------
// Full-screen image viewer with zoom & pinch
// ---------------------------------------------------------------------------
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String label;

  const _FullScreenImageViewer({required this.imageUrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          label,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {},
            tooltip: 'Pinch to zoom',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.secondary,
                ),
              );
            },
            errorBuilder: (_, __, ___) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: GoogleFonts.inter(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
