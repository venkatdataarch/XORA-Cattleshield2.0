import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import '../../domain/form_schema_model.dart';

/// Renders a group of radio buttons for [FieldType.radio].
class DynamicRadioField extends StatelessWidget {
  final FormFieldDef fieldDef;
  final String? value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const DynamicRadioField({
    super.key,
    required this.fieldDef,
    this.value,
    this.errorText,
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = fieldDef.options ?? [];

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
        const SizedBox(height: 4),

        // Radio options
        ...options.map((option) {
          return RadioListTile<String>(
            title: Text(
              option,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            value: option,
            groupValue: value,
            onChanged: (readOnly || fieldDef.readOnly) ? null : onChanged,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          );
        }),

        // Error text
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
}
