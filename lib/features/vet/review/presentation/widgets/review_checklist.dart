import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';

/// A configurable checklist that the vet must complete before approving.
///
/// All items must be checked before [allChecked] returns `true`, which is
/// typically used to gate the Approve button.
class ReviewChecklist extends StatefulWidget {
  final List<String> items;
  final ValueChanged<bool>? onAllCheckedChanged;

  const ReviewChecklist({
    super.key,
    required this.items,
    this.onAllCheckedChanged,
  });

  @override
  State<ReviewChecklist> createState() => _ReviewChecklistState();
}

class _ReviewChecklistState extends State<ReviewChecklist> {
  late List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.items.length, false);
  }

  @override
  void didUpdateWidget(ReviewChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _checked = List.filled(widget.items.length, false);
    }
  }

  bool get _allChecked => _checked.every((v) => v);

  void _toggle(int index, bool? value) {
    setState(() {
      _checked[index] = value ?? false;
    });
    widget.onAllCheckedChanged?.call(_allChecked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Review Checklist',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_checked.where((v) => v).length}/${_checked.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _allChecked
                            ? AppColors.success
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(widget.items.length, (i) {
            return CheckboxListTile(
              value: _checked[i],
              onChanged: (val) => _toggle(i, val),
              title: Text(
                widget.items[i],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration:
                          _checked[i] ? TextDecoration.lineThrough : null,
                      color: _checked[i]
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
              ),
              activeColor: AppColors.success,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
            );
          }),
        ],
      ),
    );
  }
}
