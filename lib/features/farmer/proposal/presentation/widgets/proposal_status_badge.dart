import 'package:flutter/material.dart';

import 'package:cattleshield/shared/widgets/status_badge.dart';
import '../../domain/proposal_model.dart';

/// A status badge tailored for proposal statuses with appropriate colors and icons.
class ProposalStatusBadge extends StatelessWidget {
  final ProposalStatus status;

  const ProposalStatusBadge({
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
