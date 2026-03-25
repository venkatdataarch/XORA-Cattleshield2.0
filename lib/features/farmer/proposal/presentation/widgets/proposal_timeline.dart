import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cattleshield/core/constants/app_colors.dart';
import 'package:cattleshield/core/constants/app_spacing.dart';
import '../../domain/proposal_model.dart';

/// A step in the proposal lifecycle timeline.
class _TimelineStep {
  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final bool isRejected;
  final DateTime? date;

  const _TimelineStep({
    required this.label,
    required this.icon,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isRejected = false,
    this.date,
  });
}

/// Vertical timeline widget showing proposal lifecycle.
///
/// Displays each stage with a circle icon, label, and date (if reached).
/// The current step is highlighted, future steps are greyed out, and
/// rejected steps show a red X.
class ProposalTimeline extends StatelessWidget {
  final ProposalModel proposal;

  const ProposalTimeline({
    super.key,
    required this.proposal,
  });

  List<_TimelineStep> _buildSteps() {
    final status = proposal.status;
    final isRejected = status == ProposalStatus.vetRejected;

    // Define the order index for each status.
    final statusOrder = {
      ProposalStatus.draft: 0,
      ProposalStatus.submitted: 1,
      ProposalStatus.vetReview: 2,
      ProposalStatus.vetApproved: 3,
      ProposalStatus.vetRejected: 3,
      ProposalStatus.uiicSent: 4,
      ProposalStatus.policyCreated: 5,
    };

    final currentIndex = statusOrder[status] ?? 0;

    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Draft Created',
        icon: Icons.edit_note,
        isCompleted: currentIndex > 0,
        isCurrent: currentIndex == 0,
        date: proposal.createdAt,
      ),
      _TimelineStep(
        label: 'Submitted',
        icon: Icons.send,
        isCompleted: currentIndex > 1,
        isCurrent: currentIndex == 1,
        date: proposal.submittedAt,
      ),
      _TimelineStep(
        label: 'Vet Review',
        icon: Icons.medical_services,
        isCompleted: currentIndex > 2,
        isCurrent: currentIndex == 2,
        date: proposal.vetReviewedAt,
      ),
    ];

    if (isRejected) {
      steps.add(
        _TimelineStep(
          label: 'Vet Rejected',
          icon: Icons.cancel,
          isCurrent: true,
          isRejected: true,
          date: proposal.vetReviewedAt,
        ),
      );
    } else {
      steps.addAll([
        _TimelineStep(
          label: 'Vet Approved',
          icon: Icons.check_circle,
          isCompleted: currentIndex > 3,
          isCurrent: currentIndex == 3,
          date: currentIndex >= 3 ? proposal.vetReviewedAt : null,
        ),
        _TimelineStep(
          label: 'Sent to UIIC',
          icon: Icons.business,
          isCompleted: currentIndex > 4,
          isCurrent: currentIndex == 4,
          date: proposal.uiicSentAt,
        ),
        _TimelineStep(
          label: 'Policy Created',
          icon: Icons.verified,
          isCompleted: currentIndex >= 5,
          isCurrent: currentIndex == 5,
        ),
      ]);
    }

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proposal Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(steps.length, (index) {
              final step = steps[index];
              final isLast = index == steps.length - 1;
              return _buildTimelineItem(context, step, isLast);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    _TimelineStep step,
    bool isLast,
  ) {
    final Color circleColor;
    final Color iconColor;
    final Color textColor;

    if (step.isRejected) {
      circleColor = AppColors.error;
      iconColor = Colors.white;
      textColor = AppColors.error;
    } else if (step.isCompleted) {
      circleColor = AppColors.success;
      iconColor = Colors.white;
      textColor = AppColors.textPrimary;
    } else if (step.isCurrent) {
      circleColor = AppColors.primary;
      iconColor = Colors.white;
      textColor = AppColors.primary;
    } else {
      circleColor = AppColors.divider;
      iconColor = AppColors.textTertiary;
      textColor = AppColors.textTertiary;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and circle
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.isRejected ? Icons.close : step.icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 24),
                      color: step.isCompleted
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: step.isCurrent || step.isRejected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(step.date!),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
