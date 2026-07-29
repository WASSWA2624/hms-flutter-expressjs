import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/physiotherapy_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

/// @nodoc — prefer [physiotherapyNextActionReadRequirement].
const AccessRequirement therapyNextActionReadRequirement =
    physiotherapyNextActionReadRequirement;

/// @nodoc — prefer [physiotherapyNextActionWriteRequirement].
const AccessRequirement therapyNextActionWriteRequirement =
    physiotherapyNextActionWriteRequirement;

enum TherapyNextActionKind {
  acceptReferral,
  recordAssessment,
  scheduleSession,
  recordSession,
  scheduleFollowUp,
  markAttendance,
  printInstructions,
}

TherapyNextActionKind therapyResolveNextActionKind(TherapyWorkItem item) {
  return therapyResolveNextActionKindFromStatus(item.status);
}

TherapyNextActionKind therapyResolveNextActionKindFromStatus(String status) {
  return switch (status.toUpperCase()) {
    'REFERRAL' => TherapyNextActionKind.acceptReferral,
    'ACCEPTED' => TherapyNextActionKind.recordAssessment,
    'ASSESSMENT' => TherapyNextActionKind.scheduleSession,
    'TODAY' || 'IN_TREATMENT' => TherapyNextActionKind.recordSession,
    'ACTIVE_PLAN' || 'FOLLOW_UP_DUE' => TherapyNextActionKind.scheduleFollowUp,
    'MISSED' => TherapyNextActionKind.markAttendance,
    'COMPLETED' => TherapyNextActionKind.printInstructions,
    _ => TherapyNextActionKind.acceptReferral,
  };
}

String therapyNextActionLabel(AppLocalizations l10n, String status) {
  return therapyNextActionLabelForKind(
    l10n,
    therapyResolveNextActionKindFromStatus(status),
  );
}

String therapyNextActionLabelForKind(
  AppLocalizations l10n,
  TherapyNextActionKind kind,
) {
  return switch (kind) {
    TherapyNextActionKind.acceptReferral =>
      l10n.physiotherapyAcceptReferralAction,
    TherapyNextActionKind.recordAssessment =>
      l10n.physiotherapyRecordAssessmentAction,
    TherapyNextActionKind.scheduleSession =>
      l10n.physiotherapyScheduleSessionAction,
    TherapyNextActionKind.recordSession =>
      l10n.physiotherapyRecordSessionAction,
    TherapyNextActionKind.scheduleFollowUp =>
      l10n.physiotherapyScheduleFollowUpAction,
    TherapyNextActionKind.markAttendance =>
      l10n.physiotherapyMarkAttendanceAction,
    TherapyNextActionKind.printInstructions =>
      l10n.physiotherapyPrintInstructionsAction,
  };
}

IconData therapyNextActionIcon(String status) {
  return therapyNextActionIconForKind(
    therapyResolveNextActionKindFromStatus(status),
  );
}

IconData therapyNextActionIconForKind(TherapyNextActionKind kind) {
  return switch (kind) {
    TherapyNextActionKind.acceptReferral => Icons.assignment_turned_in_outlined,
    TherapyNextActionKind.recordAssessment => Icons.assignment_outlined,
    TherapyNextActionKind.scheduleSession => Icons.event_available_outlined,
    TherapyNextActionKind.recordSession => Icons.directions_walk_outlined,
    TherapyNextActionKind.scheduleFollowUp => Icons.notification_add_outlined,
    TherapyNextActionKind.markAttendance => Icons.fact_check_outlined,
    TherapyNextActionKind.printInstructions => Icons.print_outlined,
  };
}

AccessRequirement therapyNextActionRequirement(String status) {
  return therapyNextActionRequirementForKind(
    therapyResolveNextActionKindFromStatus(status),
  );
}

AccessRequirement therapyNextActionRequirementForKind(
  TherapyNextActionKind kind,
) {
  // REFERRAL row next-action is Accept referral (Referrals atom map — write ∩).
  // TODAY / IN_TREATMENT row next-action is Record session (Today atom map).
  // ACTIVE_PLAN / FOLLOW_UP_DUE row next-action is Schedule follow-up
  // (Active plans / Follow-up due atom maps — write ∩; identical constants).
  // COMPLETED row next-action is Print instructions (Completed atom map).
  // MISSED row next-action is Mark attendance (Missed atom map — write ∩).
  return switch (kind) {
    TherapyNextActionKind.acceptReferral =>
      PhysiotherapyReferralsAtomPermissions.acceptReferral,
    TherapyNextActionKind.recordSession =>
      PhysiotherapyTodayAtomPermissions.recordSession,
    TherapyNextActionKind.scheduleFollowUp =>
      PhysiotherapyActivePlansAtomPermissions.scheduleFollowUp,
    TherapyNextActionKind.printInstructions =>
      PhysiotherapyCompletedAtomPermissions.printInstructions,
    TherapyNextActionKind.markAttendance =>
      PhysiotherapyMissedAtomPermissions.markAttendance,
    _ => physiotherapyNextActionWriteRequirement,
  };
}

bool therapyNextActionEnabled({
  required TherapyWorkItem item,
  required bool isSaving,
}) {
  if (isSaving) {
    return false;
  }
  return switch (therapyResolveNextActionKind(item)) {
    TherapyNextActionKind.scheduleSession => item.apiPatientId != null,
    TherapyNextActionKind.markAttendance => item.hasAppointment,
    _ => true,
  };
}

class TherapyNextActionButton extends ConsumerWidget {
  const TherapyNextActionButton({
    required this.item,
    required this.onPressed,
    this.compact = true,
    super.key,
  });

  final TherapyWorkItem item;
  final Future<void> Function() onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isSaving =
        ref
            .watch(physiotherapyWorkspaceControllerProvider)
            .asData
            ?.value
            .when(
              success: (PhysiotherapyWorkspaceState state) => state.isSaving,
              failure: (_) => false,
            ) ??
        false;
    final TherapyNextActionKind kind = therapyResolveNextActionKind(item);
    final String label = therapyNextActionLabelForKind(l10n, kind);
    final IconData icon = therapyNextActionIconForKind(kind);
    final AccessRequirement requirement =
        therapyNextActionRequirementForKind(kind);
    final bool actionEnabled = therapyNextActionEnabled(
      item: item,
      isSaving: isSaving,
    );

    if (!actionEnabled) {
      return const SizedBox.shrink();
    }

    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool _) {
        final Color primaryColor = theme.colorScheme.primary;

        return Semantics(
          button: true,
          enabled: true,
          label: label,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                unawaited(onPressed());
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.xs,
                    vertical: compact ? 2 : 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: compact ? 14 : 16, color: primaryColor),
                      SizedBox(width: theme.spacing.xs),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (compact
                                      ? theme.textTheme.labelSmall
                                      : theme.textTheme.bodySmall)
                                  ?.copyWith(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: primaryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
