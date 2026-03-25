import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/form_schema_model.dart';

/// Renders a numeric input for [FieldType.number] and [FieldType.currency].
class DynamicNumberField extends StatelessWidget {
  final FormFieldDef fieldDef;
  final String? value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const DynamicNumberField({
    super.key,
    required this.fieldDef,
    this.value,
    this.errorText,
    this.readOnly = false,
    required this.onChanged,
  });

  bool get _isCurrency => fieldDef.type.name == 'currency';

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      readOnly: readOnly || fieldDef.readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: fieldDef.label,
        hintText: fieldDef.hint,
        errorText: errorText,
        filled: readOnly || fieldDef.readOnly,
        fillColor: (readOnly || fieldDef.readOnly)
            ? AppColors.background
            : null,
        prefixText: _isCurrency ? '\u20B9 ' : null,
        prefixStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
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
