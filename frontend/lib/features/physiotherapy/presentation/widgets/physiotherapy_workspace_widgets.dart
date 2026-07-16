import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

const AccessRequirement therapyNextActionReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.patientRead,
    AppPermissions.billingRead,
  ],
);

const AccessRequirement therapyNextActionWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.patientWrite,
  ],
);

String therapyNextActionLabel(AppLocalizations l10n, String status) {
  return switch (status.toUpperCase()) {
    'REFERRAL' => l10n.physiotherapyAcceptReferralAction,
    'ACCEPTED' => l10n.physiotherapyRecordAssessmentAction,
    'ASSESSMENT' => l10n.physiotherapyScheduleSessionAction,
    'TODAY' => l10n.physiotherapyRecordSessionAction,
    'IN_TREATMENT' => l10n.physiotherapyRecordSessionAction,
    'ACTIVE_PLAN' => l10n.physiotherapyScheduleFollowUpAction,
    'FOLLOW_UP_DUE' => l10n.physiotherapyScheduleFollowUpAction,
    'MISSED' => l10n.physiotherapyMarkAttendanceAction,
    'COMPLETED' => l10n.physiotherapyPrintInstructionsAction,
    _ => l10n.physiotherapyAcceptReferralAction,
  };
}

IconData therapyNextActionIcon(String status) {
  return switch (status.toUpperCase()) {
    'REFERRAL' => Icons.assignment_turned_in_outlined,
    'ACCEPTED' => Icons.assignment_outlined,
    'ASSESSMENT' => Icons.event_available_outlined,
    'TODAY' || 'IN_TREATMENT' => Icons.directions_walk_outlined,
    'ACTIVE_PLAN' || 'FOLLOW_UP_DUE' => Icons.notification_add_outlined,
    'MISSED' => Icons.fact_check_outlined,
    'COMPLETED' => Icons.print_outlined,
    _ => Icons.assignment_turned_in_outlined,
  };
}

AccessRequirement therapyNextActionRequirement(String status) {
  return status.toUpperCase() == 'COMPLETED'
      ? therapyNextActionReadRequirement
      : therapyNextActionWriteRequirement;
}

bool therapyNextActionEnabled({
  required TherapyWorkItem item,
  required bool isSaving,
}) {
  if (isSaving) {
    return false;
  }
  return switch (item.status.toUpperCase()) {
    'ASSESSMENT' => item.apiPatientId != null,
    'MISSED' => item.hasAppointment,
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
    final String label = therapyNextActionLabel(l10n, item.status);
    final IconData icon = therapyNextActionIcon(item.status);
    final AccessRequirement requirement = therapyNextActionRequirement(
      item.status,
    );
    final bool actionEnabled = therapyNextActionEnabled(
      item: item,
      isSaving: isSaving,
    );

    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        final bool enabled = isAllowed && actionEnabled;
        final Color primaryColor = enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.38);

        return Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled
                  ? () {
                      unawaited(onPressed());
                    }
                  : null,
              child: MouseRegion(
                cursor: enabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
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
                                    fontWeight: FontWeight.w600,
                                    decoration: enabled
                                        ? TextDecoration.underline
                                        : null,
                                    decorationColor: primaryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                        ),
                      ),
                      if (!enabled) ...<Widget>[
                        SizedBox(width: theme.spacing.xs),
                        Icon(
                          Icons.lock_outlined,
                          size: compact ? 10 : 12,
                          color: primaryColor.withValues(alpha: 0.5),
                        ),
                      ],
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
