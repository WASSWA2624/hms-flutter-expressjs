import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';

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
    required this.onRoster,
    required this.onRequestLeave,
    required this.onCompensation,
    required this.onManagePayroll,
    required this.onAssignRole,
    required this.onModuleAccess,
    this.onOffboardStaff,
    super.key,
  });

  final HrWorkspaceState state;
  final HrStaffDetail detail;
  final HrStaffDetailActionCallback onAssignDepartment;
  final HrStaffDetailProfileActionCallback onAssignPosition;
  final HrStaffDetailActionCallback onRoster;
  final HrStaffDetailActionCallback onRequestLeave;
  final HrStaffDetailProfileActionCallback onCompensation;
  final HrStaffDetailAccessActionCallback onManagePayroll;
  final HrStaffDetailAccessActionCallback onAssignRole;
  final HrStaffDetailModuleAccessCallback onModuleAccess;
  final HrStaffDetailOffboardCallback? onOffboardStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrStaffProfile profile = detail.profile;
    final bool separated = profile.isSeparated;
    final bool enabled = !state.isMutating && !separated;
    final bool hasLinkedUser = (profile.userId ?? profile.userDisplayId ?? '')
        .trim()
        .isNotEmpty;
    final HrStaffRosterActionKind rosterKind = resolveStaffRosterActionKind(
      detail.shiftAssignments,
    );

    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[
      if (!separated) ...<AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.assignDepartment,
          label: staffHasAssignedDepartment(detail)
              ? l10n.hrChangeDepartmentAction
              : l10n.hrAssignDepartmentAction,
          icon: Icons.account_tree_outlined,
          enabled: enabled,
          onPressed: () => onAssignDepartment(context, ref),
        ),
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.assignPosition,
          label: l10n.hrAssignPositionAction,
          icon: Icons.work_outline,
          enabled: enabled,
          onPressed: () => onAssignPosition(context, ref, profile),
        ),
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.nestedRosterWrite,
          label: hrStaffRosterActionLabel(l10n, rosterKind),
          icon: rosterKind == HrStaffRosterActionKind.add
              ? Icons.add_outlined
              : Icons.edit_calendar_outlined,
          enabled: enabled,
          onPressed: () => onRoster(context, ref),
        ),
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.requestLeave,
          label: l10n.hrRequestLeaveAction,
          icon: Icons.event_busy_outlined,
          enabled: enabled,
          onPressed: () => onRequestLeave(context, ref),
        ),
      ],
      AppPermissionActionItem(
        requirement: HrHumanResourcesAtomPermissions.compensation,
        label: l10n.hrCompensationAction,
        icon: Icons.price_change_outlined,
        enabled: enabled,
        tooltip: l10n.hrCompensationActionTooltip,
        onPressed: () => onCompensation(context, ref, profile),
      ),
      AppPermissionActionItem(
        requirement: HrHumanResourcesAtomPermissions.runPayroll,
        label: l10n.hrManagePayrollAction,
        icon: Icons.account_balance_wallet_outlined,
        enabled: enabled,
        tooltip: l10n.hrManagePayrollActionTooltip,
        onPressed: () => onManagePayroll(context, ref, detail),
      ),
      if (!separated && hasLinkedUser) ...<AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.assignRole,
          label: l10n.hrAssignRoleAction,
          icon: Icons.admin_panel_settings_outlined,
          enabled: enabled,
          onPressed: () => onAssignRole(context, ref, detail),
        ),
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.moduleAccess,
          label: l10n.hrModuleAccessAction,
          icon: Icons.apps_outlined,
          enabled: enabled,
          onPressed: () => onModuleAccess(context, detail),
        ),
      ],
      if (!separated && onOffboardStaff != null)
        AppPermissionActionItem(
          requirement: HrHumanResourcesAtomPermissions.offboard,
          label: l10n.hrOffboardStaffAction,
          icon: Icons.person_off_outlined,
          enabled: enabled,
          tooltip: l10n.hrOffboardStaffActionTooltip,
          onPressed: () => onOffboardStaff!(context, ref, detail),
        ),
    ];

    return AppQuickActions(
      title: l10n.hrStaffActionsTitle,
      permissionActions: actions,
    );
  }
}
