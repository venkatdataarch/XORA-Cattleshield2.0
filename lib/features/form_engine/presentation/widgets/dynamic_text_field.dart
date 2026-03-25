import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/form_schema_model.dart';

/// Renders a text input for [FieldType.text] and [FieldType.textarea].
class DynamicTextField extends StatelessWidget {
  final FormFieldDef fieldDef;
  final String? value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const DynamicTextField({
    super.key,
    required this.fieldDef,
    this.value,
    this.errorText,
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isTextarea = fieldDef.type.name == 'textarea';

    return TextFormField(
      initialValue: value,
      readOnly: readOnly || fieldDef.readOnly,
      maxLines: isTextarea ? 4 : 1,
      minLines: isTextarea ? 3 : 1,
      keyboardType:
          isTextarea ? TextInputType.multiline : TextInputType.text,
      textInputAction:
          isTextarea ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: fieldDef.label,
        hintText: fieldDef.hint,
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
        suffixText: fieldDef.required ? '*' : null,
        suffixStyle: const TextStyle(color: AppColors.error),
      ),
      onChanged: onChanged,
    );
  }
}
