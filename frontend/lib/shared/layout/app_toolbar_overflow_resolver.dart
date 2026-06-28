import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/shared/actions/app_global_fault_report_action.dart';
import 'package:hosspi_hms/shared/actions/app_global_fault_report_dialog.dart';
import 'package:hosspi_hms/shared/actions/app_global_housekeeping_request_action.dart';
import 'package:hosspi_hms/shared/actions/app_global_housekeeping_request_dialog.dart';
import 'package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';

typedef AppToolbarOverflowCallback = void Function(
  BuildContext context,
  WidgetRef ref,
);

@immutable
final class AppToolbarOverflowEntry {
  const AppToolbarOverflowEntry({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final AppToolbarOverflowCallback? onSelected;
}

const AccessRequirement _faultReportRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.biomedWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>['biomedical-engineering-suite'],
);

const AccessRequirement _housekeepingRequestRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.operationsWrite,
    AppPermissions.operationsRead,
  ],
  activeModules: <String>['housekeeping-maintenance'],
);

List<AppToolbarOverflowEntry> resolveToolbarOverflowEntries(
  List<Widget> actions,
  WidgetRef ref,
) {
  return actions
      .map((Widget action) => _resolveAction(action, ref))
      .whereType<AppToolbarOverflowEntry>()
      .toList();
}

AppToolbarOverflowEntry? _resolveAction(Widget action, WidgetRef ref) {
  if (action is AppButton) {
    return _resolveAppButton(action);
  }
  if (action is AppWorkspaceRefreshAction) {
    return AppToolbarOverflowEntry(
      icon: Icons.refresh,
      label: action.label,
      enabled: action.onPressed != null && !action.isLoading,
      onSelected: (_, _) => action.onPressed?.call(),
    );
  }
  if (action is AppGlobalFaultReportAction) {
    final bool isAllowed = _faultReportRequirement.isAllowed(
      ref.read(appAccessPolicyProvider),
    );
    return AppToolbarOverflowEntry(
      icon: Icons.report_problem_outlined,
      label: action.label,
      enabled: isAllowed,
      onSelected: (BuildContext context, WidgetRef menuRef) {
        if (!isAllowed) {
          return;
        }
        showAppGlobalFaultReportDialog(
          context: context,
          ref: menuRef,
          onCompleted: action.onCompleted,
        );
      },
    );
  }
  if (action is AppGlobalHousekeepingRequestAction) {
    final bool isAllowed = _housekeepingRequestRequirement.isAllowed(
      ref.read(appAccessPolicyProvider),
    );
    return AppToolbarOverflowEntry(
      icon: Icons.cleaning_services_outlined,
      label: action.label,
      enabled: isAllowed,
      onSelected: (BuildContext context, WidgetRef menuRef) {
        if (!isAllowed) {
          return;
        }
        showAppGlobalHousekeepingRequestDialog(
          context: context,
          ref: menuRef,
          onCompleted: action.onCompleted,
        );
      },
    );
  }
  if (action is AppIconButton) {
    return AppToolbarOverflowEntry(
      icon: action.icon,
      label: action.semanticLabel,
      enabled: action.enabled && !action.isLoading && action.onPressed != null,
      onSelected: (_, _) => action.onPressed?.call(),
    );
  }
  return null;
}

AppToolbarOverflowEntry _resolveAppButton(AppButton action) {
  final String label = action.semanticLabel ?? action.label;
  final bool canPress =
      action.enabled && !action.isLoading && action.onPressed != null;
  final IconData icon = action.leadingIcon ??
      switch (action.variant) {
        AppButtonVariant.primary => Icons.add,
        AppButtonVariant.secondary ||
        AppButtonVariant.tertiary => Icons.touch_app_outlined,
      };

  return AppToolbarOverflowEntry(
    icon: icon,
    label: label,
    enabled: canPress,
    onSelected: (_, _) => action.onPressed?.call(),
  );
}
