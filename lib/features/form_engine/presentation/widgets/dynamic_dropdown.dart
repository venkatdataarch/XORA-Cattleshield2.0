import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/form_schema_model.dart';

/// Renders a dropdown selector for [FieldType.dropdown].
class DynamicDropdown extends StatelessWidget {
  final FormFieldDef fieldDef;
  final String? value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const DynamicDropdown({
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
    // Ensure current value is a valid option, otherwise null.
    final effectiveValue =
        (value != null && options.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: fieldDef.label,
        hintText: fieldDef.hint ?? 'Select ${fieldDef.label}',
        errorText: errorText,
        filled: readOnly || fieldDef.readOnly,
        fillColor: (readOnly || fieldDef.readOnly)
            ? AppColors.background
            : null,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            option,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        );
      }).toList(),
      onChanged: (readOnly || fieldDef.readOnly) ? null : onChanged,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      dropdownColor: AppColors.surface,
    );
  }
}
