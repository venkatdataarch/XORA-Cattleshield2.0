import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/claim_model.dart';

/// Grid of evidence thumbnails for a claim.
///
/// Displays photos, videos, and documents with type indicators.
/// Tapping a thumbnail opens it in a full-screen viewer.
class EvidenceGallery extends StatelessWidget {
  final List<EvidenceMedia> media;

  const EvidenceGallery({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'Evidence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${media.length} item${media.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: media.length,
              itemBuilder: (context, index) {
                return _EvidenceThumbnail(
                  evidence: media[index],
                  onTap: () => _openFullScreen(context, media[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, EvidenceMedia evidence) {
    if (evidence.isPhoto || evidence.isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullScreenViewer(evidence: evidence),
        ),
      );
    }
  }
}

/// Individual evidence thumbnail with type icon and AI processed badge.
class _EvidenceThumbnail extends StatelessWidget {
  final EvidenceMedia evidence;
  final VoidCallback? onTap;

  const _EvidenceThumbnail({
    required this.evidence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or placeholder
            if (evidence.isPhoto && evidence.url.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: Image.network(
                  evidence.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                ),
              )
            else
              _buildPlaceholder(),

            // Type icon overlay
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  evidence.typeIcon,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),

            // AI processed badge
            if (evidence.aiProcessed == true)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            evidence.typeIcon,
            size: 28,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 4),
          Text(
            evidence.type.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen viewer for evidence media.
class _FullScreenViewer extends StatelessWidget {
  final EvidenceMedia evidence;

  const _FullScreenViewer({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          evidence.type.toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: evidence.isPhoto
            ? InteractiveViewer(
                child: Image.network(
                  evidence.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.white54,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    evidence.typeIcon,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preview not available for ${evidence.type}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
      ),
    );
  }
}
