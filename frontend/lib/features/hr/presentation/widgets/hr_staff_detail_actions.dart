import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_panel.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';

typedef HrStaffDetailActionCallback = void Function(
  BuildContext context,
  WidgetRef ref,
);

typedef HrStaffDetailProfileActionCallback = void Function(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile profile,
);

typedef HrStaffDetailAccessActionCallback = void Function(
  BuildContext context,
  WidgetRef ref,
  HrStaffDetail detail,
);

typedef HrStaffDetailModuleAccessCallback = void Function(
  BuildContext context,
  HrStaffDetail detail,
);

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool enabled = !state.isMutating;
    final bool hasLinkedUser =
        (detail.profile.userId ?? detail.profile.userDisplayId ?? '')
            .trim()
            .isNotEmpty;

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      AppPermissionActionItem(
        requirement: _hrWriteRequirement,
        label: l10n.hrAssignDepartmentAction,
        icon: Icons.account_tree_outlined,
        enabled: enabled,
        onPressed: () => onAssignDepartment(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _hrWriteRequirement,
        label: l10n.hrAssignPositionAction,
        icon: Icons.work_outline,
        enabled: enabled,
        onPressed: () => onAssignPosition(context, ref, detail.profile),
      ),
      AppPermissionActionItem(
        requirement: _rosterWriteRequirement,
        label: l10n.hrRecordAvailabilityAction,
        icon: Icons.schedule_outlined,
        enabled: enabled,
        onPressed: () => onRecordAvailability(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _rosterWriteRequirement,
        label: l10n.hrAssignShiftAction,
        icon: Icons.calendar_view_week_outlined,
        enabled: enabled,
        onPressed: () => onAssignShift(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _rosterWriteRequirement,
        label: l10n.hrSwapShiftAction,
        icon: Icons.swap_horiz_outlined,
        enabled: enabled,
        onPressed: () => onSwapShift(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _hrWriteRequirement,
        label: l10n.hrRequestLeaveAction,
        icon: Icons.event_busy_outlined,
        enabled: enabled,
        onPressed: () => onRequestLeave(context, ref),
      ),
      AppPermissionActionItem(
        requirement: _payrollRequirement,
        label: l10n.hrCompensationAction,
        icon: Icons.price_change_outlined,
        enabled: enabled,
        onPressed: () => onCompensation(context, ref, detail.profile),
      ),
      AppPermissionActionItem(
        requirement: _payrollRequirement,
        label: l10n.hrRunPayrollAction,
        icon: Icons.payments_outlined,
        enabled: enabled,
        onPressed: () => onRunPayroll(context, ref, detail.profile),
      ),
      if (hasLinkedUser) ...<AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: _hrWriteRequirement,
          label: l10n.hrAssignRoleAction,
          icon: Icons.admin_panel_settings_outlined,
          enabled: enabled,
          onPressed: () => onAssignRole(context, ref, detail),
        ),
        AppPermissionActionItem(
          requirement: _hrWriteRequirement,
          label: l10n.hrModuleAccessAction,
          icon: Icons.apps_outlined,
          enabled: enabled,
          onPressed: () => onModuleAccess(context, detail),
        ),
      ],
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

const AccessRequirement _hrWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  activeModules: <String>['hr-rosters'],
);

const AccessRequirement _rosterWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterWrite,
  ],
  activeModules: <String>['hr-rosters'],
);

const AccessRequirement _payrollRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  anyPermissions: <AppPermission>[AppPermissions.financialApprove],
  activeModules: <String>['hr-rosters'],
);
