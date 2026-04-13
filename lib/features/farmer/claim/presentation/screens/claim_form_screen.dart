import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/app_error_widget.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/farmer/policy/presentation/providers/policy_provider.dart';
import '../../domain/claim_model.dart';
import '../providers/claim_provider.dart';

/// Provider to load the form schema for a claim based on claim type.
final _claimFormSchemaProvider =
    FutureProvider.family<FormSchema, String>((ref, formType) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema(formType);
});

/// Screen for creating a new insurance claim.
class ClaimFormScreen extends ConsumerStatefulWidget {
  final String policyId;

  const ClaimFormScreen({
    super.key,
    required this.policyId,
  });

  @override
  ConsumerState<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

/// Document category for claim evidence
enum DocCategory {
  vetPrescription('Vet Prescription', Icons.medical_services, Color(0xFF1565C0)),
  treatmentBills('Treatment Bills', Icons.receipt_long, Color(0xFFE65100)),
  medicineReceipts('Medicine Receipts', Icons.local_pharmacy, Color(0xFF2E7D32)),
  postMortemReport('Post-mortem Report', Icons.assignment, Color(0xFF6A1B9A)),
  otherDocuments('Other Documents', Icons.folder, Color(0xFF546E7A));

  final String label;
  final IconData icon;
  final Color color;
  const DocCategory(this.label, this.icon, this.color);
}

/// Uploaded document with metadata
class ClaimDocument {
  final String path;
  final DocCategory category;
  final String timestamp;

  ClaimDocument({required this.path, required this.category, required this.timestamp});
}

class _ClaimFormScreenState extends ConsumerState<ClaimFormScreen> {
  // Death claim only — no type selection needed
  final ClaimType _selectedType = ClaimType.death;
  bool _isSubmitting = false;
  int _currentStep = 0; // 0=form, 1=video, 2=documents, 3=review
  Map<String, dynamic> _savedFormData = {};
  final List<ClaimDocument> _uploadedDocs = [];
  final List<String> _videoPaths = []; // Death scene + muzzle close-up videos
  final _picker = ImagePicker();

  String get _formType => 'claim_death';

  Map<String, dynamic> _buildInitialData() {
    final data = <String, dynamic>{};
    final policy = ref.read(selectedPolicyProvider);

    if (policy != null) {
      data['policyNumber'] = policy.policyNumber;
      data['policyId'] = policy.id;
      data['animalId'] = policy.animalId;
      data['insuredName'] = policy.insuredName ?? '';
      data['sumInsured'] = policy.sumInsured.toString();
    }

    if (_selectedType != null) {
      data['claimType'] = _selectedType!.label;
    }

    return data;
  }

  /// Called when dynamic form is filled — moves to video capture
  Future<void> _handleFormComplete(Map<String, dynamic> formData) async {
    setState(() {
      _savedFormData = formData;
      _currentStep = 1; // Move to video capture step
    });
  }

  /// Record a video (death scene or muzzle close-up)
  Future<void> _recordVideo(String type) async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: type == 'death_scene'
            ? const Duration(seconds: 60)
            : const Duration(seconds: 15),
      );
      if (video != null && mounted) {
        setState(() {
          _videoPaths.add(video.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == "death_scene" ? "Death scene" : "Muzzle close-up"} video recorded'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video recording failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Upload a document photo
  Future<void> _pickDocument(DocCategory category) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
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

    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (xFile != null) {
      setState(() {
        _uploadedDocs.add(ClaimDocument(
          path: xFile.path,
          category: category,
          timestamp: DateTime.now().toLocal().toIso8601String(),
        ));
      });
    }
  }

  /// Remove a document
  void _removeDocument(int index) {
    setState(() => _uploadedDocs.removeAt(index));
  }

  /// Final submission with form data + documents
  Future<void> _handleFinalSubmit() async {
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Add document references to form data
      final submitData = Map<String, dynamic>.from(_savedFormData);
      submitData['documents'] = _uploadedDocs.map((doc) => {
        'category': doc.category.label,
        'path': doc.path,
        'timestamp': doc.timestamp,
      }).toList();

      final result = await ref.read(claimListProvider.notifier).createClaim(
            widget.policyId,
            _selectedType!,
            submitData,
          );

      if (result != null && mounted) {
        ref.read(selectedClaimProvider.notifier).state = result;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/farmer/claims/${result.id}');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit claim. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'File Death Claim',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Step indicator (4 steps: Details → Video → Documents → Submit)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _StepDot(label: 'Details', active: _currentStep == 0, done: _currentStep > 0),
                    _StepLine(done: _currentStep > 0),
                    _StepDot(label: 'Video', active: _currentStep == 1, done: _currentStep > 1),
                    _StepLine(done: _currentStep > 1),
                    _StepDot(label: 'Documents', active: _currentStep == 2, done: _currentStep > 2),
                    _StepLine(done: _currentStep > 2),
                    _StepDot(label: 'Submit', active: _currentStep == 3, done: false),
                  ],
                ),
              ),

              Expanded(
                child: LoadingOverlay(
                  isLoading: _isSubmitting,
                  message: 'Submitting claim...',
                  child: _currentStep == 0
                      ? _buildClaimForm()
                      : _currentStep == 1
                          ? _buildVideoCapture()
                          : _currentStep == 2
                              ? _buildDocumentUpload()
                              : _buildReviewAndSubmit(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Type selection removed — death claims only

  Widget _policyInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimForm() {
    final schemaAsync = ref.watch(_claimFormSchemaProvider(_formType));
    final policy = ref.read(selectedPolicyProvider);

    return schemaAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
      error: (error, _) => AppErrorWidget(
        message: 'Failed to load form: $error',
        onRetry: () => ref.invalidate(_claimFormSchemaProvider(_formType)),
      ),
      data: (schema) {
        final initialData = _buildInitialData();

        return Column(
          children: [
            // Auto-populated policy info banner
            if (policy != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppColors.secondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Policy details auto-filled',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _policyInfoRow('Policy', policy.policyNumber),
                    _policyInfoRow('Animal', policy.animalName ?? 'N/A'),
                    _policyInfoRow('Sum Insured', '\u20B9${policy.sumInsured.toStringAsFixed(0)}'),
                  ],
                ),
              ),

            // Type selection indicator
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _selectedType!.color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _selectedType!.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(_selectedType!.icon, size: 18, color: _selectedType!.color),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedType!.label} Claim',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _selectedType!.color,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DynamicFormRenderer(
                schema: schema,
                initialData: initialData,
                displayMode: FormDisplayMode.multiPage,
                onSubmit: _handleFormComplete,
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Step 2: Video Evidence Capture ────────────────────────────────
  Widget _buildVideoCapture() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Video Evidence',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record video evidence of the deceased animal. This is mandatory for claim processing.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),

          // Video 1: Death scene (mandatory)
          _VideoRecordCard(
            title: 'Death Scene Video',
            subtitle: 'Record full carcass, surroundings, ear tag (30-60 sec)',
            icon: Icons.videocam,
            color: const Color(0xFFC62828),
            duration: '30-60 sec',
            isRecorded: _videoPaths.isNotEmpty,
            isMandatory: true,
            onRecord: () => _recordVideo('death_scene'),
            onRetake: _videoPaths.isNotEmpty ? () {
              setState(() {
                if (_videoPaths.isNotEmpty) _videoPaths.removeAt(0);
              });
            } : null,
          ),
          const SizedBox(height: 16),

          // Video 2: Muzzle close-up (mandatory)
          _VideoRecordCard(
            title: 'Muzzle Close-up Video',
            subtitle: 'Record close-up of muzzle/nose area for ID (10-15 sec)',
            icon: Icons.zoom_in,
            color: const Color(0xFFE65100),
            duration: '10-15 sec',
            isRecorded: _videoPaths.length >= 2,
            isMandatory: true,
            onRecord: () => _recordVideo('muzzle_closeup'),
            onRetake: _videoPaths.length >= 2 ? () {
              setState(() {
                if (_videoPaths.length >= 2) _videoPaths.removeAt(1);
              });
            } : null,
          ),
          const SizedBox(height: 16),

          // Video 3: Farmer declaration (optional)
          _VideoRecordCard(
            title: 'Farmer Declaration Video',
            subtitle: 'State your name, animal ID, and cause of death (15-30 sec)',
            icon: Icons.person_pin,
            color: const Color(0xFF1565C0),
            duration: '15-30 sec',
            isRecorded: _videoPaths.length >= 3,
            isMandatory: false,
            onRecord: () => _recordVideo('farmer_declaration'),
            onRetake: _videoPaths.length >= 3 ? () {
              setState(() {
                if (_videoPaths.length >= 3) _videoPaths.removeAt(2);
              });
            } : null,
          ),

          const SizedBox(height: 16),

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'GPS location and IST timestamp are automatically embedded in all videos.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade800),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _videoPaths.length >= 2
                  ? () => setState(() => _currentStep = 2)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Text(
                _videoPaths.length >= 2
                    ? 'Continue to Documents'
                    : 'Record both mandatory videos to continue',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Step 3: Document Upload ──────────────────────────────────────
  Widget _buildDocumentUpload() {
    final categories = _selectedType == ClaimType.death
        ? DocCategory.values
        : DocCategory.values.where((c) => c != DocCategory.postMortemReport).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Upload Supporting Documents',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload prescriptions, bills, and reports to support your claim.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Document categories
          ...categories.map((cat) {
            final docsInCategory = _uploadedDocs.where((d) => d.category == cat).toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Category header
                  InkWell(
                    onTap: () => _pickDocument(cat),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                ),
                                if (docsInCategory.isNotEmpty)
                                  Text(
                                    '${docsInCategory.length} file(s) uploaded',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.green[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add_a_photo, color: cat.color, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Uploaded files
                  if (docsInCategory.isNotEmpty) ...[
                    Divider(height: 1, color: Colors.grey[200]),
                    ...docsInCategory.map((doc) {
                      final globalIndex = _uploadedDocs.indexOf(doc);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(doc.path),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.path.split('/').last,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatTimestamp(doc.timestamp),
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                              onPressed: () => _removeDocument(globalIndex),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // Navigation buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 1),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF1A5C45)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _currentStep = 3),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Review & Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      final d = DateTime.parse(ts);
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  // ─── Step 4: Review & Submit ──────────────────────────────────────
  Widget _buildReviewAndSubmit() {
    final policy = ref.read(selectedPolicyProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Review Your Claim',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Policy details (auto-populated)
          if (policy != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Policy Details',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Auto-filled',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _policyInfoRow('Policy No.', policy.policyNumber),
                  _policyInfoRow('Animal', policy.animalName ?? 'N/A'),
                  _policyInfoRow('Insured Name', policy.insuredName ?? 'N/A'),
                  _policyInfoRow('Sum Insured', '\u20B9${policy.sumInsured.toStringAsFixed(0)}'),
                  _policyInfoRow('Coverage', '${policy.startDate.day}/${policy.startDate.month}/${policy.startDate.year} — ${policy.endDate.day}/${policy.endDate.month}/${policy.endDate.year}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Claim type
          _ReviewCard(
            icon: _selectedType!.icon,
            color: _selectedType!.color,
            title: 'Claim Type',
            value: _selectedType!.label,
          ),

          // Documents summary
          _ReviewCard(
            icon: Icons.description,
            color: const Color(0xFF1565C0),
            title: 'Documents Uploaded',
            value: '${_uploadedDocs.length} document(s)',
            subtitle: _uploadedDocs.isEmpty
                ? 'No documents attached'
                : _uploadedDocs.map((d) => d.category.label).toSet().join(', '),
          ),

          if (_uploadedDocs.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _uploadedDocs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final doc = _uploadedDocs[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.file(
                          File(doc.path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            color: Colors.black54,
                            child: Text(
                              doc.category.label,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Submit button
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 2), // Back to documents
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _handleFinalSubmit,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Submit Claim'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Step Indicator Widgets ───────────────────────────────────────
class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _StepDot({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.secondary
                : active
                    ? AppColors.primary
                    : Colors.grey[300],
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? AppColors.primary : Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: done ? AppColors.secondary : Colors.grey[300],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? subtitle;

  const _ReviewCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card widget for video recording with status indicator.
class _VideoRecordCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String duration;
  final bool isRecorded;
  final bool isMandatory;
  final VoidCallback onRecord;
  final VoidCallback? onRetake;

  const _VideoRecordCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.duration,
    required this.isRecorded,
    required this.isMandatory,
    required this.onRecord,
    this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecorded
              ? AppColors.success.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.2),
          width: isRecorded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isRecorded ? AppColors.success : color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRecorded ? Icons.check_circle : icon,
                  color: isRecorded ? AppColors.success : color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isMandatory)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Required',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Optional',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Duration badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Record / Retake buttons
              if (isRecorded && onRetake != null)
                TextButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    'Retake',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                ),
              if (!isRecorded)
                ElevatedButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.videocam, size: 18),
                  label: Text(
                    'Record',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              if (isRecorded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Recorded',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
