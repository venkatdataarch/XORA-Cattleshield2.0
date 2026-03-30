import 'package:flutter/material.dart';

import '../../domain/form_schema_model.dart';

/// Wraps any form field widget and controls its visibility based on a
/// [ShowCondition] evaluated against the current form data.
///
/// When the condition is `null` the child is always visible.
/// Uses [AnimatedSize] for smooth show/hide transitions.
class ConditionalFieldWrapper extends StatelessWidget {
  final ShowCondition? condition;
  final Map<String, dynamic> formData;
  final Widget child;

  const ConditionalFieldWrapper({
    super.key,
    required this.condition,
    required this.formData,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = condition == null || condition!.evaluate(formData);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: isVisible
          ? child
          : const SizedBox.shrink(),
    );
  }
}
