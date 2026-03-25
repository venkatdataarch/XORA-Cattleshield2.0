import 'field_types.dart';

// =============================================================================
// FormSchema
// =============================================================================

/// Root model representing a complete UIIC insurance form definition.
class FormSchema {
  final String id;

  /// Logical form identifier, e.g. `proposal_cattle`, `claim_death`.
  final String formType;
  final String version;
  final String title;

  /// Animal types this form applies to, e.g. `['cow', 'buffalo']`.
  final List<String> animalTypes;
  final List<FormSection> sections;

  const FormSchema({
    required this.id,
    required this.formType,
    required this.version,
    required this.title,
    this.animalTypes = const [],
    this.sections = const [],
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    return FormSchema(
      id: json['id'] as String? ?? '',
      formType: json['formType'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      title: json['title'] as String? ?? '',
      animalTypes: (json['animalTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => FormSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formType': formType,
      'version': version,
      'title': title,
      'animalTypes': animalTypes,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }
}

// =============================================================================
// FormSection
// =============================================================================

/// A logical grouping of fields rendered as a card with a title.
class FormSection {
  final String id;
  final String title;
  final String? description;
  final List<FormFieldDef> fields;

  /// Optional condition controlling whether this entire section is visible.
  final ShowCondition? showWhen;

  const FormSection({
    required this.id,
    required this.title,
    this.description,
    this.fields = const [],
    this.showWhen,
  });

  factory FormSection.fromJson(Map<String, dynamic> json) {
    return FormSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => FormFieldDef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      showWhen: json['showWhen'] != null
          ? ShowCondition.fromJson(json['showWhen'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'fields': fields.map((f) => f.toJson()).toList(),
      if (showWhen != null) 'showWhen': showWhen!.toJson(),
    };
  }
}

// =============================================================================
// FormFieldDef
// =============================================================================

/// Definition of a single form field as described in the JSON schema.
class FormFieldDef {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? hint;
  final String? defaultValue;

  /// Available choices for [FieldType.dropdown] and [FieldType.radio].
  final List<String>? options;

  /// Controls conditional visibility of this field.
  final ShowCondition? showWhen;
  final ValidationRule? validation;
  final bool readOnly;

  const FormFieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.hint,
    this.defaultValue,
    this.options,
    this.showWhen,
    this.validation,
    this.readOnly = false,
  });

  factory FormFieldDef.fromJson(Map<String, dynamic> json) {
    return FormFieldDef(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: FieldType.fromString(json['type'] as String? ?? 'text'),
      required: json['required'] as bool? ?? false,
      hint: json['hint'] as String?,
      defaultValue: json['defaultValue'] as String?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      showWhen: json['showWhen'] != null
          ? ShowCondition.fromJson(json['showWhen'] as Map<String, dynamic>)
          : null,
      validation: json['validation'] != null
          ? ValidationRule.fromJson(json['validation'] as Map<String, dynamic>)
          : null,
      readOnly: json['readOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'type': type.name,
      'required': required,
      if (hint != null) 'hint': hint,
      if (defaultValue != null) 'defaultValue': defaultValue,
      if (options != null) 'options': options,
      if (showWhen != null) 'showWhen': showWhen!.toJson(),
      if (validation != null) 'validation': validation!.toJson(),
      if (readOnly) 'readOnly': readOnly,
    };
  }
}

// =============================================================================
// ShowCondition
// =============================================================================

/// Determines visibility of a section or field based on the current form data.
class ShowCondition {
  /// The [FormFieldDef.key] of the field whose value is checked.
  final String field;

  /// Exact match: visible when `formData[field] == value`.
  final String? value;

  /// List match: visible when `formData[field]` is contained in [valueIn].
  final List<String>? valueIn;

  /// Negation: visible when `formData[field] != notValue`.
  final String? notValue;

  const ShowCondition({
    required this.field,
    this.value,
    this.valueIn,
    this.notValue,
  });

  factory ShowCondition.fromJson(Map<String, dynamic> json) {
    return ShowCondition(
      field: json['field'] as String? ?? '',
      value: json['value'] as String?,
      valueIn: (json['valueIn'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      notValue: json['notValue'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      if (value != null) 'value': value,
      if (valueIn != null) 'valueIn': valueIn,
      if (notValue != null) 'notValue': notValue,
    };
  }

  /// Evaluates this condition against the current [formData].
  ///
  /// Returns `true` when the field should be visible.
  bool evaluate(Map<String, dynamic> formData) {
    final fieldValue = formData[field]?.toString();

    // If the referenced field has no value yet, hide the dependent element.
    if (fieldValue == null || fieldValue.isEmpty) return false;

    if (value != null && fieldValue != value) return false;
    if (valueIn != null && !valueIn!.contains(fieldValue)) return false;
    if (notValue != null && fieldValue == notValue) return false;

    return true;
  }
}

// =============================================================================
// ValidationRule
// =============================================================================

/// Declarative validation constraints applied to a field value.
class ValidationRule {
  final double? min;
  final double? max;
  final int? minLength;
  final int? maxLength;

  /// Regex pattern the value must match.
  final String? pattern;
  final String? errorMessage;

  const ValidationRule({
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.errorMessage,
  });

  factory ValidationRule.fromJson(Map<String, dynamic> json) {
    return ValidationRule(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
      pattern: json['pattern'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
      if (pattern != null) 'pattern': pattern,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  /// Validates [value] against all constraints.
  ///
  /// Returns an error message if invalid, or `null` if the value passes.
  String? validate(dynamic value) {
    final str = value?.toString() ?? '';

    if (minLength != null && str.length < minLength!) {
      return errorMessage ?? 'Minimum $minLength characters required';
    }
    if (maxLength != null && str.length > maxLength!) {
      return errorMessage ?? 'Maximum $maxLength characters allowed';
    }

    if (pattern != null) {
      final regex = RegExp(pattern!);
      if (!regex.hasMatch(str)) {
        return errorMessage ?? 'Invalid format';
      }
    }

    if (min != null || max != null) {
      final numValue = double.tryParse(str);
      if (numValue == null) {
        return errorMessage ?? 'Must be a valid number';
      }
      if (min != null && numValue < min!) {
        return errorMessage ?? 'Minimum value is $min';
      }
      if (max != null && numValue > max!) {
        return errorMessage ?? 'Maximum value is $max';
      }
    }

    return null;
  }
}
