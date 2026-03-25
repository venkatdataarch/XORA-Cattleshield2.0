import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/vet_certificate_model.dart';

/// Renders a [VetCertificateModel] as a structured card layout mimicking
/// an official UIIC certificate.
class CertificatePdfViewer extends StatelessWidget {
  final VetCertificateModel certificate;

  const CertificatePdfViewer({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final fd = certificate.formData;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: AppSpacing.cardPadding,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.cardRadius - 1),
                topRight: Radius.circular(AppSpacing.cardRadius - 1),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'UNITED INDIA INSURANCE CO. LTD.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  certificate.typeLabel.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.0,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Certificate info
                _buildSectionTitle(context, 'Certificate Details'),
                _buildTableRow(context, 'Certificate ID', certificate.id),
                _buildTableRow(context, 'Type', certificate.typeLabel),
                _buildTableRow(context, 'Date',
                    dateFormat.format(certificate.createdAt)),
                _buildTableRow(context, 'Vet ID', certificate.vetId),

                const Divider(height: AppSpacing.lg),

                // Animal identity
                _buildSectionTitle(context, 'Animal Identity'),
                _buildTableRow(context, 'Species',
                    fd['species']?.toString() ?? '-'),
                _buildTableRow(
                    context, 'Breed', fd['breed']?.toString() ?? '-'),
                _buildTableRow(context, 'Tag Number',
                    fd['tagNumber']?.toString() ?? '-'),
                _buildTableRow(
                    context, 'Color', fd['color']?.toString() ?? '-'),
                _buildTableRow(context, 'Age',
                    fd['age']?.toString() ?? '-'),
                if (fd['ucid'] != null || fd['muid'] != null)
                  _buildTableRow(
                    context,
                    'Unique ID',
                    fd['ucid']?.toString() ??
                        fd['muid']?.toString() ??
                        '-',
                  ),

                const Divider(height: AppSpacing.lg),

                // Clinical / Post-mortem
                if (certificate.type == CertificateType.claimDeath ||
                    certificate.type == CertificateType.claimInjury) ...[
                  _buildSectionTitle(
                    context,
                    certificate.type == CertificateType.claimDeath
                        ? 'Post-mortem Details'
                        : 'Clinical Examination',
                  ),
                  _buildTableRow(context, 'Cause',
                      fd['causeOfDeath']?.toString() ?? fd['cause']?.toString() ?? '-'),
                  _buildTableRow(context, 'Date of Incident',
                      fd['dateOfIncident']?.toString() ?? '-'),
                  _buildTableRow(context, 'Observations',
                      fd['observations']?.toString() ?? '-'),
                  const Divider(height: AppSpacing.lg),
                ],

                // Vet declaration
                _buildSectionTitle(context, 'Vet Declaration'),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadius),
                  ),
                  child: Text(
                    fd['declaration']?.toString() ??
                        'I hereby certify that I have personally examined the '
                            'above-mentioned animal and the details furnished '
                            'above are true to the best of my knowledge.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Signature block
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (certificate.vetSignatureUrl != null)
                          Image.network(
                            certificate.vetSignatureUrl!,
                            height: 50,
                            errorBuilder: (_, __, ___) => Container(
                              width: 120,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 120,
                            height: 40,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Digitally Signed',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Veterinary Doctor',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          dateFormat.format(certificate.createdAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
