import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// A tappable card used on the login screen to select a user role.
///
/// Displays an [icon] and [label]. When [isSelected] is true the card
/// shows a green border and tinted background; otherwise it has a neutral
/// grey outline.
class RoleSelectorCard extends StatelessWidget {
  /// The icon displayed at the centre of the card.
  final IconData icon;

  /// The label shown below the icon.
  final String label;

  /// Whether this card is currently selected.
  final bool isSelected;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  const RoleSelectorCard({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? AppColors.primary : AppColors.cardBorder;
    final backgroundColor =
        isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white;
    final iconColor =
        isSelected ? AppColors.primary : AppColors.textSecondary;
    final textColor =
        isSelected ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
