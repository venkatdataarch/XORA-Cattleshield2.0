import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/loading_overlay.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import 'package:cattleshield/features/form_engine/presentation/dynamic_form_renderer.dart';
import 'package:cattleshield/features/form_engine/domain/form_schema_model.dart';
import 'package:cattleshield/features/form_engine/data/form_schema_repository.dart';
import '../../data/certificate_repository.dart';
import '../../domain/vet_certificate_model.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _certSchemaProvider =
    FutureProvider.autoDispose.family<FormSchema, String>(
        (ref, schemaKey) async {
  final repo = ref.watch(formSchemaRepositoryProvider);
  return repo.getSchema(schemaKey);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CertificateFormScreen extends ConsumerStatefulWidget {
  final String typeString;
  final String entityId;

  const CertificateFormScreen({
    super.key,
    required this.typeString,
    required this.entityId,
  });

  @override
  ConsumerState<CertificateFormScreen> createState() =>
      _CertificateFormScreenState();
}

class _CertificateFormScreenState extends ConsumerState<CertificateFormScreen> {
  late final CertificateType _certType;
  bool _isSubmitting = false;
  List<Offset> _signaturePoints = [];
  bool _signatureCompleted = false;

  @override
  void initState() {
    super.initState();
    _certType = CertificateType.fromString(widget.typeString);
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(_certSchemaProvider(_certType.schemaKey));

    return Scaffold(
      appBar: AppBar(
        title: Text(_certType.label),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Submitting certificate...',
        child: schemaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading form: $err')),
          data: (schema) => Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Certificate type header
                      Container(
                        padding: AppSpacing.cardPadding,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.cardRadius),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description,
                                color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _certType.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                  Text(
                                    'Entity ID: ${widget.entityId}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Dynamic form
                      DynamicFormRenderer(
                        schema: schema,
                        displayMode: FormDisplayMode.multiPage,
                        onSubmit: (formData) =>
                            _handleSubmit(formData),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Digital Signature Pad
                      _buildSignaturePad(context),
                      const SizedBox(height: AppSpacing.lg),

                      // Submit button
                      PrimaryButton(
                        label: 'Submit Certificate',
                        icon: Icons.send,
                        isLoading: _isSubmitting,
                        isDisabled: !_signatureCompleted,
                        onPressed: _signatureCompleted
                            ? () => _handleSubmit({})
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturePad(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.draw, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Digital Signature',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (_signaturePoints.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _signaturePoints = [];
                        _signatureCompleted = false;
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: _signatureCompleted
                    ? AppColors.success
                    : AppColors.cardBorder,
              ),
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final renderBox = context.findRenderObject() as RenderBox;
                  _signaturePoints.add(details.localPosition);
                });
              },
              onPanEnd: (_) {
                setState(() {
                  _signaturePoints.add(Offset.zero);
                  _signatureCompleted = _signaturePoints.length > 10;
                });
              },
              child: CustomPaint(
                painter: _SignaturePainter(points: _signaturePoints),
                size: Size.infinite,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              _signatureCompleted
                  ? 'Signature captured'
                  : 'Draw your signature above',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _signatureCompleted
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit(Map<String, dynamic> formData) async {
    if (!_signatureCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your signature')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(certificateRepositoryProvider);
      final result = await repo.createCertificate(
        _certType,
        widget.entityId,
        formData,
      );

      if (!mounted) return;

      result.when(
        success: (cert) {
          context.pushReplacement(
            '/vet/certificate/${cert.id}/preview',
          );
        },
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

/// Custom painter that draws the signature stroke.
class _SignaturePainter extends CustomPainter {
  final List<Offset> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
