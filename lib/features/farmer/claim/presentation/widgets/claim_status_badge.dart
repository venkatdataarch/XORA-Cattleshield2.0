import 'package:flutter/material.dart';

import 'package:cattleshield/shared/widgets/status_badge.dart';
import '../../domain/claim_model.dart';

/// A status badge tailored for claim statuses with appropriate colors and icons.
class ClaimStatusBadge extends StatelessWidget {
  final ClaimStatus status;

  const ClaimStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: status.label,
      color: status.color,
      icon: status.icon,
    );
  }
}

/// A badge for claim type (death, injury, disease).
class ClaimTypeBadge extends StatelessWidget {
  final ClaimType type;

  const ClaimTypeBadge({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: type.label,
      color: type.color,
      icon: type.icon,
    );
  }
}
