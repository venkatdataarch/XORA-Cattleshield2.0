import 'package:flutter/material.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import 'package:cattleshield/shared/widgets/primary_button.dart';
import '../domain/field_types.dart';
import '../domain/form_schema_model.dart';
import 'widgets/conditional_field_wrapper.dart';
import 'widgets/dynamic_checkbox.dart';
import 'widgets/dynamic_date_picker.dart';
import 'widgets/dynamic_dropdown.dart';
import 'widgets/dynamic_number_field.dart';
import 'widgets/dynamic_photo_field.dart';
import 'widgets/dynamic_radio_field.dart';
import 'widgets/dynamic_text_field.dart';

/// Display mode for the form engine.
enum FormDisplayMode {
  /// All sections rendered in a single scrollable view.
  singlePage,

  /// One section per page with forward / back navigation.
  multiPage,
}

/// The core dynamic form renderer.
///
/// Given a [FormSchema] and optional initial data, it renders every section
/// and field according to the schema, manages form state reactively, evaluates
/// conditional visibility, validates inputs and calls submission callbacks.
class DynamicFormRenderer extends StatefulWidget {
  final FormSchema schema;

  /// Pre-populated form data keyed by [FormFieldDef.key].
  final Map<String, dynamic> initialData;

  /// When `true`, all fields are rendered as read-only.
  final bool readOnly;

  final FormDisplayMode displayMode;

  /// Called when the user taps "Submit" and all validations pass.
  final ValueChanged<Map<String, dynamic>>? onSubmit;

  /// Called when the user taps "Save Draft".
  final ValueChanged<Map<String, dynamic>>? onSaveDraft;

  const DynamicFormRenderer({
    super.key,
    required this.schema,
    this.initialData = const {},
    this.readOnly = false,
    this.displayMode = FormDisplayMode.multiPage,
    this.onSubmit,
    this.onSaveDraft,
  });

  @override
  State<DynamicFormRenderer> createState() => _DynamicFormRendererState();
}

class _DynamicFormRendererState extends State<DynamicFormRenderer> {
  late Map<String, dynamic> _formData;
  final Map<String, String> _errors = {};

  // Multi-page state
  late PageController _pageController;
  int _currentPage = 0;

  /// Visible sections after evaluating section-level [ShowCondition]s.
  List<FormSection> get _visibleSections {
    return widget.schema.sections
        .where((s) =>
            s.showWhen == null || s.showWhen!.evaluate(_formData))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData);
    _pageController = PageController();

    // Apply default values for fields that have no initial value.
    for (final section in widget.schema.sections) {
      for (final field in section.fields) {
        if (!_formData.containsKey(field.key) &&
            field.defaultValue != null) {
          _formData[field.key] = field.defaultValue;
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Form data management
  // ---------------------------------------------------------------------------

  void _updateField(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
      // Clear error on change
      _errors.remove(key);
    });
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Validates all visible & required fields.
  /// Returns `true` when the form is valid.
  bool _validateAll() {
    _errors.clear();
    for (final section in _visibleSections) {
      for (final field in section.fields) {
        _validateField(field);
      }
    }
    setState(() {});
    return _errors.isEmpty;
  }

  /// Validates fields within a single section (for multi-page next).
  bool _validateSection(FormSection section) {
    // Remove existing errors for this section's fields only.
    for (final field in section.fields) {
      _errors.remove(field.key);
    }

    for (final field in section.fields) {
      _validateField(field);
    }
    setState(() {});

    // Check if any of this section's fields have errors.
    return !section.fields.any((f) => _errors.containsKey(f.key));
  }

  void _validateField(FormFieldDef field) {
    // Skip hidden fields.
    if (field.showWhen != null && !field.showWhen!.evaluate(_formData)) {
      return;
    }

    final value = _formData[field.key];
    final strValue = value?.toString() ?? '';

    // Required check
    if (field.required && strValue.trim().isEmpty) {
      _errors[field.key] = '${field.label} is required';
      return;
    }

    // Skip further validation if empty and not required.
    if (strValue.trim().isEmpty) return;

    // Custom validation rule
    if (field.validation != null) {
      final error = field.validation!.validate(value);
      if (error != null) {
        _errors[field.key] = error;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _onSubmit() {
    if (_validateAll()) {
      widget.onSubmit?.call(Map<String, dynamic>.from(_formData));
    } else if (widget.displayMode == FormDisplayMode.multiPage) {
      // Navigate to the first page with errors.
      final sections = _visibleSections;
      for (int i = 0; i < sections.length; i++) {
        final hasError =
            sections[i].fields.any((f) => _errors.containsKey(f.key));
        if (hasError) {
          _goToPage(i);
          break;
        }
      }
    }
  }

  void _onSaveDraft() {
    widget.onSaveDraft?.call(Map<String, dynamic>.from(_formData));
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    final sections = _visibleSections;
    if (_currentPage < sections.length - 1) {
      if (_validateSection(sections[_currentPage])) {
        _goToPage(_currentPage + 1);
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections;

    return Column(
      children: [
        // Progress indicator
        if (!widget.readOnly && sections.length > 1)
          _buildProgressIndicator(sections),

        // Form content
        Expanded(
          child: widget.displayMode == FormDisplayMode.multiPage
              ? _buildMultiPage(sections)
              : _buildSinglePage(sections),
        ),

        // Bottom actions
        if (!widget.readOnly) _buildActions(sections),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Progress indicator
  // ---------------------------------------------------------------------------

  Widget _buildProgressIndicator(List<FormSection> sections) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Column(
        children: [
          // Section label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.displayMode == FormDisplayMode.multiPage
                    ? 'Section ${_currentPage + 1} of ${sections.length}'
                    : '${sections.length} sections',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.displayMode == FormDisplayMode.multiPage)
                Text(
                  sections[_currentPage].title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.displayMode == FormDisplayMode.multiPage
                  ? (_currentPage + 1) / sections.length
                  : 1.0,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Multi-page mode
  // ---------------------------------------------------------------------------

  Widget _buildMultiPage(List<FormSection> sections) {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: _buildSectionCard(sections[index]),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Single-page mode
  // ---------------------------------------------------------------------------

  Widget _buildSinglePage(List<FormSection> sections) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: sections.map((section) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildSectionCard(section),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section card
  // ---------------------------------------------------------------------------

  Widget _buildSectionCard(FormSection section) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            if (section.description != null) ...[
              const SizedBox(height: 4),
              Text(
                section.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),

            // Fields
            ...section.fields.map((field) {
              return ConditionalFieldWrapper(
                condition: field.showWhen,
                formData: _formData,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildField(field),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field renderer dispatcher
  // ---------------------------------------------------------------------------

  Widget _buildField(FormFieldDef field) {
    final value = _formData[field.key];
    final error = _errors[field.key];
    final isReadOnly = widget.readOnly || field.readOnly;

    switch (field.type) {
      case FieldType.text:
      case FieldType.textarea:
        return DynamicTextField(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.number:
      case FieldType.currency:
        return DynamicNumberField(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.date:
        return DynamicDatePicker(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.dropdown:
        return DynamicDropdown(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.radio:
        return DynamicRadioField(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.checkbox:
        return DynamicCheckbox(
          fieldDef: field,
          value: value == true || value == 'true',
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.photo:
        return DynamicPhotoField(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.signature:
        // Signature uses the same photo widget for now.
        return DynamicPhotoField(
          fieldDef: field,
          value: value?.toString(),
          errorText: error,
          readOnly: isReadOnly,
          onChanged: (v) => _updateField(field.key, v),
        );

      case FieldType.section_header:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            field.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Bottom actions
  // ---------------------------------------------------------------------------

  Widget _buildActions(List<FormSection> sections) {
    final isMultiPage =
        widget.displayMode == FormDisplayMode.multiPage;
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage >= sections.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMultiPage)
              Row(
                children: [
                  // Back button
                  if (!isFirstPage)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previousPage,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppSpacing.buttonRadius),
                          ),
                        ),
                      ),
                    ),
                  if (!isFirstPage) const SizedBox(width: 12),

                  // Next / Submit button
                  Expanded(
                    child: isLastPage
                        ? PrimaryButton(
                            label: 'Submit',
                            icon: Icons.check,
                            onPressed: _onSubmit,
                          )
                        : PrimaryButton(
                            label: 'Next',
                            icon: Icons.arrow_forward,
                            onPressed: _nextPage,
                          ),
                  ),
                ],
              )
            else
              PrimaryButton(
                label: 'Submit',
                icon: Icons.check,
                onPressed: _onSubmit,
              ),

            // Save draft
            if (widget.onSaveDraft != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _onSaveDraft,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Draft'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
