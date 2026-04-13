/// Supported field types for the dynamic form engine.
///
/// Each value maps to a specific renderer widget in the presentation layer.
enum FieldType {
  text,
  textarea,
  number,
  currency,
  date,
  dropdown,
  radio,
  checkbox,
  photo,
  signature,
  section_header;

  /// Parses a JSON string (e.g. `"text"`, `"section_header"`) into [FieldType].
  static FieldType fromString(String value) {
    return FieldType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FieldType.text,
    );
  }
}
