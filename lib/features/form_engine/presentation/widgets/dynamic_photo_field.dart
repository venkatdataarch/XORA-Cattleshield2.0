import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/form_schema_model.dart';

/// Renders an image capture / gallery picker for [FieldType.photo].
class DynamicPhotoField extends StatelessWidget {
  final FormFieldDef fieldDef;

  /// The current value is a local file path or empty string.
  final String? value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const DynamicPhotoField({
    super.key,
    required this.fieldDef,
    this.value,
    this.errorText,
    this.readOnly = false,
    required this.onChanged,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    if (readOnly || fieldDef.readOnly) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (picked != null) {
      onChanged(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              fieldDef.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (fieldDef.required)
              const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),

        // Image preview or placeholder
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null ? AppColors.error : AppColors.cardBorder,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            color: AppColors.background,
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: Image.file(
                    File(value!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  ),
                )
              : _placeholder(),
        ),
        const SizedBox(height: 8),

        // Action buttons
        if (!readOnly && !fieldDef.readOnly)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),

        // Error
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 40, color: AppColors.textTertiary),
          SizedBox(height: 8),
          Text(
            'No photo selected',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
