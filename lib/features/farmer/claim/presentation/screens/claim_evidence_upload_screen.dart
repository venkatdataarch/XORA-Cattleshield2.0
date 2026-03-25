import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import '../../data/claim_repository.dart';

/// Definition of an upload slot in the evidence upload grid.
class _UploadSlot {
  final String label;
  final IconData icon;
  final String type; // photo, video, document
  final bool required;
  XFile? file;

  _UploadSlot({
    required this.label,
    required this.icon,
    required this.type,
    this.required = false,
    this.file,
  });
}

/// Screen for uploading evidence media for a claim.
///
/// Provides a grid of upload slots for different types of evidence:
/// - Muzzle verification photo (required)
/// - Death scene / Injury photos
/// - Video evidence
/// - Vet records / documents
class ClaimEvidenceUploadScreen extends ConsumerStatefulWidget {
  final String claimId;

  const ClaimEvidenceUploadScreen({
    super.key,
    required this.claimId,
  });

  @override
  ConsumerState<ClaimEvidenceUploadScreen> createState() =>
      _ClaimEvidenceUploadScreenState();
}

class _ClaimEvidenceUploadScreenState
    extends ConsumerState<ClaimEvidenceUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0;

  late final List<_UploadSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = [
      _UploadSlot(
        label: 'Muzzle Photo',
        icon: Icons.camera_alt,
        type: 'photo',
        required: true,
      ),
      _UploadSlot(
        label: 'Scene Photo 1',
        icon: Icons.photo_camera,
        type: 'photo',
      ),
      _UploadSlot(
        label: 'Scene Photo 2',
        icon: Icons.photo_camera,
        type: 'photo',
      ),
      _UploadSlot(
        label: 'Scene Photo 3',
        icon: Icons.photo_camera,
        type: 'photo',
      ),
      _UploadSlot(
        label: 'Video Evidence',
        icon: Icons.videocam,
        type: 'video',
      ),
      _UploadSlot(
        label: 'Vet Records',
        icon: Icons.description,
        type: 'document',
      ),
    ];
  }

  int get _filledSlots => _slots.where((s) => s.file != null).length;

  bool get _hasRequiredPhotos {
    return _slots.where((s) => s.required).every((s) => s.file != null);
  }

  Future<void> _pickFile(_UploadSlot slot) async {
    XFile? file;

    if (slot.type == 'photo') {
      // Show camera/gallery choice.
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;
      file = await _picker.pickImage(source: source, imageQuality: 85);
    } else if (slot.type == 'video') {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;
      file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
    } else {
      // Document - pick image as placeholder (file_picker would be better).
      file = await _picker.pickImage(source: ImageSource.gallery);
    }

    if (file != null) {
      setState(() => slot.file = file);
    }
  }

  void _removeFile(_UploadSlot slot) {
    setState(() => slot.file = null);
  }

  Future<void> _uploadEvidence() async {
    if (!_hasRequiredPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add the required muzzle photo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final formData = FormData();

      for (final slot in _slots) {
        if (slot.file != null) {
          formData.files.add(
            MapEntry(
              'evidence',
              await MultipartFile.fromFile(
                slot.file!.path,
                filename: slot.file!.name,
              ),
            ),
          );
        }
      }

      final repo = ref.read(claimRepositoryProvider);
      final result = await repo.uploadEvidence(widget.claimId, formData);

      result.when(
        success: (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Evidence uploaded successfully'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          }
        },
        failure: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${error.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Evidence'),
      ),
      body: LoadingOverlay(
        isLoading: _isUploading,
        message: 'Uploading evidence...',
        child: Column(
          children: [
            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.info.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Upload photos, videos, and documents as evidence. '
                      'Muzzle photo is required for verification.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Upload slots grid
            Expanded(
              child: GridView.builder(
                padding: AppSpacing.screenPadding,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: _slots.length,
                itemBuilder: (context, index) {
                  return _UploadSlotCard(
                    slot: _slots[index],
                    onTap: () => _pickFile(_slots[index]),
                    onRemove: () => _removeFile(_slots[index]),
                  );
                },
              ),
            ),

            // Submit button
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Text(
                      '$_filledSlots of ${_slots.length} slots filled',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: 'Upload Evidence',
                      icon: Icons.cloud_upload,
                      onPressed: _hasRequiredPhotos ? _uploadEvidence : null,
                      isDisabled: !_hasRequiredPhotos,
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
}

/// Card widget for a single upload slot.
class _UploadSlotCard extends StatelessWidget {
  final _UploadSlot slot;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _UploadSlotCard({
    required this.slot,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = slot.file != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: slot.required && !hasFile
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: slot.required && !hasFile ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: hasFile ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          children: [
            if (hasFile && slot.type == 'photo')
              // Show thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: Image.file(
                  File(slot.file!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            else if (hasFile)
              // Show file indicator
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(slot.icon, size: 36, color: AppColors.success),
                    const SizedBox(height: 8),
                    Text(
                      slot.file!.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              // Show empty state
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        slot.icon,
                        size: 28,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      slot.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (slot.required) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to add',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

            // Remove button
            if (hasFile)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Check indicator
            if (hasFile)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
