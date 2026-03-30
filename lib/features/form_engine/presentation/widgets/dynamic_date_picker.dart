import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/form_schema_model.dart';

/// Renders a tappable date selector for [FieldType.date].
class DynamicDatePicker extends StatelessWidget {
  final FormFieldDef fieldDef;
  final String? value;
  final String? errorText;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const DynamicDatePicker({
    super.key,
    required this.fieldDef,
    this.value,
    this.errorText,
    this.readOnly = false,
    required this.onChanged,
  });

  static final DateFormat _displayFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');

  String _formatForDisplay(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = _isoFormat.parse(isoDate);
      return _displayFormat.format(date);
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    if (readOnly || fieldDef.readOnly) return;

    DateTime initialDate = DateTime.now();
    if (value != null && value!.isNotEmpty) {
      try {
        initialDate = _isoFormat.parse(value!);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: AppColors.textOnPrimary,
                  surface: AppColors.surface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onChanged(_isoFormat.format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickDate(context),
      child: AbsorbPointer(
        child: TextFormField(
          key: ValueKey('${fieldDef.key}_$value'),
          initialValue: _formatForDisplay(value),
          readOnly: true,
          decoration: InputDecoration(
            labelText: fieldDef.label,
            hintText: fieldDef.hint ?? 'dd/mm/yyyy',
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
            suffixIcon: const Icon(
              Icons.calendar_today,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixText: fieldDef.required ? '*' : null,
            suffixStyle: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
