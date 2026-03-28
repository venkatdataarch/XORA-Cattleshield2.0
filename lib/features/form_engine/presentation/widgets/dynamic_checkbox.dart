import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import '../../domain/form_schema_model.dart';

/// Renders a checkbox for [FieldType.checkbox].
class DynamicCheckbox extends StatelessWidget {
  final FormFieldDef fieldDef;
  final bool value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  const DynamicCheckbox({
    super.key,
    required this.fieldDef,
    this.value = false,
    this.errorText,
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(
            fieldDef.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          value: value,
          onChanged: (readOnly || fieldDef.readOnly)
              ? null
              : (v) => onChanged(v ?? false),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
