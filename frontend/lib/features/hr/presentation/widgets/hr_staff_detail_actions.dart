import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_panel.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/components.dart';

typedef HrStaffDetailActionCallback =
    void Function(BuildContext context, WidgetRef ref);

typedef HrStaffDetailProfileActionCallback =
    void Function(BuildContext context, WidgetRef ref, HrStaffProfile profile);

typedef HrStaffDetailAccessActionCallback =
    void Function(BuildContext context, WidgetRef ref, HrStaffDetail detail);

typedef HrStaffDetailModuleAccessCallback =
    void Function(BuildContext context, HrStaffDetail detail);

typedef HrStaffDetailOffboardCallback =
    void Function(BuildContext context, WidgetRef ref, HrStaffDetail detail);

/// Unified staff mutation actions for the staff detail dialog.
class HrStaffDetailActions extends ConsumerWidget {
  const HrStaffDetailActions({
    required this.state,
    required this.detail,
    required this.onAssignDepartment,
    required this.onAssignPosition,
    required this.onRecordAvailability,
    required this.onAssignShift,
    required this.onSwapShift,
    required this.onRequestLeave,
    required this.onCompensation,
    required this.onRunPayroll,
    required this.onAssignRole,
    required this.onModuleAccess,
    this.onOffboardStaff,
    super.key,
  });

  final HrWorkspaceState state;
  final HrStaffDetail detail;
  final HrStaffDetailActionCallback onAssignDepartment;
  final HrStaffDetailProfileActionCallback onAssignPosition;
  final HrStaffDetailActionCallback onRecordAvailability;
  final HrStaffDetailActionCallback onAssignShift;
  final HrStaffDetailActionCallback onSwapShift;
  final HrStaffDetailActionCallback onRequestLeave;
  final HrStaffDetailProfileActionCallback onCompensation;
  final HrStaffDetailProfileActionCallback onRunPayroll;
  final HrStaffDetailAccessActionCallback onAssignRole;
  final HrStaffDetailModuleAccessCallback onModuleAccess;
  final HrStaffDetailOffboardCallback? onOffboardStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrStaffProfile profile = detail.profile;
    final bool separated = profile.isSeparated;
    final bool enabled = !state.isMutating && !separated;
    final bool hasCompensation = <HrStaffCompensation>[
      ...detail.compensations,
      ...profile.compensations,
    ].any((HrStaffCompensation row) => row.isActive);
    final bool hasLinkedUser =
        (profile.userId ?? profile.userDisplayId ?? '').trim().isNotEmpty;

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      if (!separated) ...<AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: hrWriteRequirement,
          label: l10n.hrAssignDepartmentAction,
          icon: Icons.account_tree_outlined,
          enabled: enabled,
          onPressed: () => onAssignDepartment(context, ref),
        ),
        AppPermissionActionItem(
          requirement: hrWriteRequirement,
          label: l10n.hrAssignPositionAction,
          icon: Icons.work_outline,
          enabled: enabled,
          onPressed: () => onAssignPosition(context, ref, profile),
        ),
        AppPermissionActionItem(
          requirement: hrRosterWriteRequirement,
          label: l10n.hrRecordAvailabilityAction,
          icon: Icons.schedule_outlined,
          enabled: enabled,
          onPressed: () => onRecordAvailability(context, ref),
        ),
        AppPermissionActionItem(
          requirement: hrRosterWriteRequirement,
          label: l10n.hrAssignShiftAction,
          icon: Icons.calendar_view_week_outlined,
          enabled: enabled,
          onPressed: () => onAssignShift(context, ref),
        ),
        AppPermissionActionItem(
          requirement: hrRosterWriteRequirement,
          label: l10n.hrSwapShiftAction,
          icon: Icons.swap_horiz_outlined,
          enabled: enabled,
          onPressed: () => onSwapShift(context, ref),
        ),
        AppPermissionActionItem(
          requirement: hrWriteRequirement,
          label: l10n.hrRequestLeaveAction,
          icon: Icons.event_busy_outlined,
          enabled: enabled,
          onPressed: () => onRequestLeave(context, ref),
        ),
      ],
      AppPermissionActionItem(
        requirement: hrWriteRequirement,
        label: l10n.hrCompensationAction,
        icon: Icons.price_change_outlined,
        enabled: enabled,
        tooltip: l10n.hrCompensationActionTooltip,
        onPressed: separated
            ? null
            : () => onCompensation(context, ref, profile),
      ),
      AppPermissionActionItem(
        requirement: hrPayrollRequirement,
        label: l10n.hrRunPayrollAction,
        icon: Icons.payments_outlined,
        enabled: enabled && hasCompensation,
        tooltip: hasCompensation
            ? l10n.hrRunPayrollActionTooltip
            : l10n.hrPayrollMissingCompensationTooltip,
        onPressed: separated || !hasCompensation
            ? null
            : () => onRunPayroll(context, ref, profile),
      ),
      if (!separated && hasLinkedUser) ...<AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: hrWriteRequirement,
          label: l10n.hrAssignRoleAction,
          icon: Icons.admin_panel_settings_outlined,
          enabled: enabled,
          onPressed: () => onAssignRole(context, ref, detail),
        ),
        AppPermissionActionItem(
          requirement: hrWriteRequirement,
          label: l10n.hrModuleAccessAction,
          icon: Icons.apps_outlined,
          enabled: enabled,
          onPressed: () => onModuleAccess(context, detail),
        ),
      ],
      if (!separated && onOffboardStaff != null)
        AppPermissionActionItem(
          requirement: hrWriteRequirement,
          label: l10n.hrOffboardStaffAction,
          icon: Icons.person_off_outlined,
          enabled: enabled,
          tooltip: l10n.hrOffboardStaffActionTooltip,
          onPressed: () => onOffboardStaff!(context, ref, detail),
        ),
    ];

    return AppSectionPanel(
      title: l10n.hrStaffActionsTitle,
      children: <Widget>[
        AppPermissionActionList(
          actions: actions,
          spacing: Theme.of(context).spacing.xs,
          runSpacing: Theme.of(context).spacing.xs,
        ),
      ],
    );
  }
}
