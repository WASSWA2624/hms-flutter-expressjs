import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accessAdminStatusFilterKey = 'status';
const String accessAdminRoleScopeFilterKey = 'role_scope';

String accessAdminColumnVisibilityStorageKey(AccessAdminResource resource) {
  return switch (resource) {
    AccessAdminResource.users => 'access_admin_workspace_users_v1',
    AccessAdminResource.demoUsers => 'access_admin_workspace_demo_users_v1',
    AccessAdminResource.roles => 'access_admin_workspace_roles_v1',
    AccessAdminResource.permissions => 'access_admin_workspace_permissions_v2',
    AccessAdminResource.moduleEntitlements =>
      'access_admin_workspace_entitlements_v1',
    AccessAdminResource.registrationFollowUps =>
      'access_admin_workspace_registrations_v1',
    _ => 'access_admin_workspace_${resource.serverValue}_v1',
  };
}

String accessAdminColumnWidthStorageKey(AccessAdminResource resource) {
  return switch (resource) {
    AccessAdminResource.users => 'access_admin_cw_users_v1',
    AccessAdminResource.demoUsers => 'access_admin_cw_demo_users_v1',
    AccessAdminResource.roles => 'access_admin_cw_roles_v1',
    AccessAdminResource.permissions => 'access_admin_cw_permissions_v1',
    AccessAdminResource.moduleEntitlements => 'access_admin_cw_entitlements_v1',
    AccessAdminResource.registrationFollowUps =>
      'access_admin_cw_registrations_v1',
    _ => 'access_admin_cw_${resource.serverValue}_v1',
  };
}

List<AppListTableColumn<AccessAdminItem>> accessAdminDefaultColumns(
  BuildContext context, {
  required AccessAdminResource resource,
  required bool canWrite,
  required Future<void> Function(AccessAdminItem item) onUserStatusToggle,
  required void Function(AccessAdminItem item) onRoleEdit,
  required Future<void> Function(AccessAdminItem item) onRegistrationApprove,
}) {
  final List<AppListTableColumn<AccessAdminItem>> all =
      accessAdminAllColumnsForResource(
        context,
        resource: resource,
        canWrite: canWrite,
        onUserStatusToggle: onUserStatusToggle,
        onRoleEdit: onRoleEdit,
        onRegistrationApprove: onRegistrationApprove,
      );
  final Set<String> defaultIds = switch (resource) {
    AccessAdminResource.users ||
    AccessAdminResource.demoUsers => const <String>{
      'user_id',
      'user_name',
      'user_facility',
      'status',
      'next_action',
    },
    AccessAdminResource.roles => const <String>{
      'role_id',
      'role_name',
      'role_scope',
      'role_users',
      'next_action',
    },
    AccessAdminResource.permissions => const <String>{
      'perm_id',
      'perm_name',
      'perm_description',
      'perm_code',
    },
    AccessAdminResource.moduleEntitlements => const <String>{
      'ent_module',
      'ent_group',
      'ent_plan',
      'ent_active',
      'ent_denial',
    },
    AccessAdminResource.registrationFollowUps => const <String>{
      'reg_id',
      'reg_name',
      'reg_facility',
      'status',
      'next_action',
    },
    _ => all.map((AppListTableColumn<AccessAdminItem> c) => c.id!).toSet(),
  };

  return all
      .where(
        (AppListTableColumn<AccessAdminItem> column) =>
            column.id != null && defaultIds.contains(column.id),
      )
      .toList(growable: false);
}

List<AppListTableColumn<AccessAdminItem>> accessAdminColumnChoices(
  BuildContext context, {
  required AccessAdminResource resource,
  required bool canWrite,
  required Future<void> Function(AccessAdminItem item) onUserStatusToggle,
  required void Function(AccessAdminItem item) onRoleEdit,
  required Future<void> Function(AccessAdminItem item) onRegistrationApprove,
}) {
  return accessAdminAllColumnsForResource(
    context,
    resource: resource,
    canWrite: canWrite,
    onUserStatusToggle: onUserStatusToggle,
    onRoleEdit: onRoleEdit,
    onRegistrationApprove: onRegistrationApprove,
  );
}

List<AppListTableColumn<AccessAdminItem>> accessAdminAllColumnsForResource(
  BuildContext context, {
  required AccessAdminResource resource,
  required bool canWrite,
  required Future<void> Function(AccessAdminItem item) onUserStatusToggle,
  required void Function(AccessAdminItem item) onRoleEdit,
  required Future<void> Function(AccessAdminItem item) onRegistrationApprove,
}) {
  return switch (resource) {
    AccessAdminResource.users || AccessAdminResource.demoUsers => _userColumns(
      context,
      canWrite: canWrite,
      onUserStatusToggle: onUserStatusToggle,
    ),
    AccessAdminResource.roles => _roleColumns(
      context,
      canWrite: canWrite,
      onRoleEdit: onRoleEdit,
    ),
    AccessAdminResource.permissions => accessAdminPermissionColumns(context),
    AccessAdminResource.moduleEntitlements => _entitlementColumns(context),
    AccessAdminResource.registrationFollowUps => _registrationColumns(
      context,
      canWrite: canWrite,
      onRegistrationApprove: onRegistrationApprove,
    ),
    _ => _userColumns(
      context,
      canWrite: canWrite,
      onUserStatusToggle: onUserStatusToggle,
    ),
  };
}

List<AppSearchBarFilterGroup> accessAdminFilterGroups(
  AppLocalizations l10n,
  AccessAdminResource resource,
  AccessAdminLookups lookups,
) {
  return switch (resource) {
    AccessAdminResource.users ||
    AccessAdminResource.demoUsers => <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: accessAdminStatusFilterKey,
        label: l10n.accessAdminStatusLabel,
        allLabel: l10n.accessAdminAllStatusesLabel,
        choices: lookups.userStatuses
            .map(
              (String value) =>
                  AppSearchBarFilterChoice(value: value, label: value),
            )
            .toList(growable: false),
      ),
    ],
    AccessAdminResource.roles => <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: accessAdminRoleScopeFilterKey,
        label: l10n.accessAdminColumnScope,
        allLabel: l10n.accessAdminRoleScopeFilterAll,
        choices: <AppSearchBarFilterChoice>[
          AppSearchBarFilterChoice(
            value: 'tenant',
            label: l10n.accessAdminRoleScopeFilterTenant,
            icon: Icons.domain_outlined,
          ),
          AppSearchBarFilterChoice(
            value: 'facility',
            label: l10n.accessAdminRoleScopeFilterFacility,
            icon: Icons.local_hospital_outlined,
          ),
        ],
      ),
    ],
    _ => const <AppSearchBarFilterGroup>[],
  };
}

AppSearchBarFilterValue accessAdminFilterValue(
  AccessAdminWorkspaceQuery query,
  AccessAdminResource resource,
) {
  final Map<String, String> options = <String, String>{};
  if ((resource == AccessAdminResource.users ||
          resource == AccessAdminResource.demoUsers) &&
      query.status != null) {
    options[accessAdminStatusFilterKey] = query.status!;
  }
  if (resource == AccessAdminResource.roles && query.roleScope != null) {
    options[accessAdminRoleScopeFilterKey] = query.roleScope!;
  }
  return options.isEmpty
      ? AppSearchBarFilterValue.empty
      : AppSearchBarFilterValue(options: options);
}

bool accessAdminHasActiveFilters(
  AccessAdminWorkspaceQuery query,
  AccessAdminResource resource,
) {
  if (resource == AccessAdminResource.users ||
      resource == AccessAdminResource.demoUsers) {
    return query.status != null;
  }
  if (resource == AccessAdminResource.roles) {
    return query.roleScope != null;
  }
  return false;
}

bool accessAdminSearchMatcher(
  BuildContext context,
  AccessAdminResource resource,
  AccessAdminItem item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final AppLocalizations l10n = context.l10n;
  final List<String> haystack = <String>[
    item.title,
    item.effectiveDisplayId,
    item.subtitle ?? '',
    item.email ?? '',
    item.name ?? '',
    item.displayName ?? '',
    item.status ?? '',
    item.facilityName ?? '',
    item.facilityId ?? '',
    item.tenantName ?? '',
    item.phone ?? '',
    item.positionTitle ?? '',
    item.permissionName ?? '',
    item.moduleSlug ?? '',
    item.moduleGroup ?? '',
    item.planLabel ?? '',
    item.entitlementDenialReason ?? '',
    '${item.userCount}',
    '${item.permissionCount}',
    '${item.isActive}',
    '${item.entitlementDenied}',
    accessAdminRoleScopeLabel(context, item),
    accessAdminEntitlementActiveLabel(context, item.isActive),
    ...item.roles.map((AccessAdminRoleRef role) => role.name),
  ];

  final String? permissionCode = item.permissionName ?? item.name;
  if (permissionCode != null && permissionCode.isNotEmpty) {
    haystack.add(l10n.permissionCatalogLabelForCode(permissionCode));
  }

  if (resource == AccessAdminResource.registrationFollowUps) {
    haystack.add(l10n.accessAdminApproveRegistrationAction.toLowerCase());
  }
  if (resource == AccessAdminResource.users ||
      resource == AccessAdminResource.demoUsers) {
    if (item.status == 'ACTIVE') {
      haystack.add(l10n.accessAdminDeactivateAction.toLowerCase());
    } else {
      haystack.add(l10n.accessAdminActivateAction.toLowerCase());
    }
  }

  return haystack.any(
    (String value) =>
        value.trim().isNotEmpty && value.toLowerCase().contains(needle),
  );
}

/// Labeled next-action for mobile worklist rows (mirrors desktop `next_action`).
///
/// Returns null when unauthorized or the resource has no write next-action so
/// the row stays read/select-only.
Widget? accessAdminMobileNextAction(
  BuildContext context, {
  required AccessAdminResource resource,
  required AccessAdminItem item,
  required bool canWrite,
  required Future<void> Function(AccessAdminItem item)? onUserStatusToggle,
  required void Function(AccessAdminItem item)? onRoleEdit,
  required Future<void> Function(AccessAdminItem item)? onRegistrationApprove,
}) {
  if (!canWrite) {
    return null;
  }

  return switch (resource) {
    AccessAdminResource.users ||
    AccessAdminResource.demoUsers => AppButton.tertiary(
      label: item.status == 'ACTIVE'
          ? context.l10n.accessAdminDeactivateAction
          : context.l10n.accessAdminActivateAction,
      onPressed: onUserStatusToggle == null
          ? null
          : () => onUserStatusToggle(item),
    ),
    AccessAdminResource.roles when !item.isSystemCritical => AppButton.tertiary(
      label: context.l10n.accessAdminEditRoleAction,
      leadingIcon: Icons.edit_outlined,
      onPressed: onRoleEdit == null ? null : () => onRoleEdit(item),
    ),
    AccessAdminResource.registrationFollowUps => AppButton.tertiary(
      label: context.l10n.accessAdminApproveRegistrationAction,
      onPressed: onRegistrationApprove == null
          ? null
          : () => onRegistrationApprove(item),
    ),
    _ => null,
  };
}

List<AppListTableColumn<AccessAdminItem>> _userColumns(
  BuildContext context, {
  required bool canWrite,
  required Future<void> Function(AccessAdminItem item) onUserStatusToggle,
}) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<AccessAdminItem>>[
    AppListTableColumn<AccessAdminItem>(
      id: 'user_id',
      label: l10n.accessAdminColumnId,
      alwaysVisible: true,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.effectiveDisplayId,
            right.effectiveDisplayId,
          ),
      cellBuilder: (_, AccessAdminItem item) => Text(item.effectiveDisplayId),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_name',
      label: l10n.accessAdminColumnName,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.title, right.title),
      cellBuilder: (_, AccessAdminItem item) {
        final String? email = item.email?.trim();
        if (email != null && email.isNotEmpty && email != item.title) {
          return AppListItemText(title: item.title, subtitle: email);
        }
        return Text(item.title);
      },
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_facility',
      label: l10n.accessAdminColumnFacility,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.facilityName ?? left.facilityId,
            right.facilityName ?? right.facilityId,
          ),
      cellBuilder: (_, AccessAdminItem item) =>
          Text(item.facilityName ?? item.facilityId ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'status',
      label: l10n.accessAdminColumnStatus,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.status, right.status),
      cellBuilder: (BuildContext context, AccessAdminItem item) {
        if (item.status == null) {
          return const Text('—');
        }
        return AppWorkspaceStatusBadge(
          status: accessAdminItemStatus(context, item.status),
        );
      },
    ),
    // Omit the column entirely when unauthorized (no empty/disabled cell).
    if (canWrite)
      _userNextActionColumn(
        context,
        onUserStatusToggle: onUserStatusToggle,
      ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_details',
      label: l10n.accessAdminColumnDetails,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.subtitle, right.subtitle),
      cellBuilder: (_, AccessAdminItem item) => Text(item.subtitle ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_roles',
      label: l10n.accessAdminColumnRoles,
      cellBuilder: (_, AccessAdminItem item) => Text(
        item.roles.map((AccessAdminRoleRef role) => role.name).join(', '),
      ),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_email',
      label: l10n.accessAdminEmailLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.email, right.email),
      cellBuilder: (_, AccessAdminItem item) => Text(item.email ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_phone',
      label: l10n.accessAdminPhoneLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.phone, right.phone),
      cellBuilder: (_, AccessAdminItem item) => Text(item.phone ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'user_tenant',
      label: l10n.settingsWorkspaceTenantLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.tenantName, right.tenantName),
      cellBuilder: (_, AccessAdminItem item) => Text(item.tenantName ?? '—'),
    ),
  ];
}

List<AppListTableColumn<AccessAdminItem>> _roleColumns(
  BuildContext context, {
  required bool canWrite,
  required void Function(AccessAdminItem item) onRoleEdit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<AccessAdminItem>>[
    AppListTableColumn<AccessAdminItem>(
      id: 'role_id',
      label: l10n.accessAdminColumnId,
      alwaysVisible: true,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.effectiveDisplayId,
            right.effectiveDisplayId,
          ),
      cellBuilder: (_, AccessAdminItem item) => Text(item.effectiveDisplayId),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'role_name',
      label: l10n.accessAdminColumnName,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.title, right.title),
      cellBuilder: (_, AccessAdminItem item) => Text(item.title),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'role_tenant',
      label: l10n.settingsWorkspaceTenantLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.tenantName, right.tenantName),
      cellBuilder: (_, AccessAdminItem item) => Text(
        (item.tenantName ?? '').trim().isNotEmpty
            ? item.tenantName!.trim()
            : '—',
      ),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'role_scope',
      label: l10n.accessAdminColumnScope,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            accessAdminRoleScopeLabel(context, left),
            accessAdminRoleScopeLabel(context, right),
          ),
      cellBuilder: (BuildContext context, AccessAdminItem item) =>
          AccessAdminRoleScopeBadge(item: item),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'role_users',
      label: l10n.accessAdminRoleDetailUsersLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          left.userCount.compareTo(right.userCount),
      cellBuilder: (_, AccessAdminItem item) => Text('${item.userCount}'),
    ),
    // Omit the column entirely when unauthorized (no empty/disabled cell).
    if (canWrite)
      _roleNextActionColumn(context, onRoleEdit: onRoleEdit),
    AppListTableColumn<AccessAdminItem>(
      id: 'role_details',
      label: l10n.accessAdminColumnDetails,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.subtitle, right.subtitle),
      cellBuilder: (_, AccessAdminItem item) => Text(item.subtitle ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'role_permissions',
      label: l10n.accessAdminRolePermissionsLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          left.permissionCount.compareTo(right.permissionCount),
      cellBuilder: (_, AccessAdminItem item) =>
          Text(l10n.hrAccessPermissionCountLabel(item.permissionCount)),
    ),
  ];
}

List<AppListTableColumn<AccessAdminItem>> accessAdminPermissionColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<AccessAdminItem>>[
    AppListTableColumn<AccessAdminItem>(
      id: 'perm_id',
      label: l10n.accessAdminPermissionIdColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.effectiveDisplayId,
            right.effectiveDisplayId,
          ),
      cellBuilder: (_, AccessAdminItem item) => Text(item.effectiveDisplayId),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'perm_name',
      label: l10n.accessAdminPermissionNameColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.title, right.title),
      cellBuilder: (_, AccessAdminItem item) => Text(item.title),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'perm_tenant',
      label: l10n.settingsWorkspaceTenantLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.tenantName, right.tenantName),
      cellBuilder: (_, AccessAdminItem item) => Text(
        (item.tenantName ?? '').trim().isNotEmpty
            ? item.tenantName!.trim()
            : '—',
      ),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'perm_description',
      label: l10n.accessAdminPermissionDescriptionColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            accessAdminPermissionDescription(l10n, left),
            accessAdminPermissionDescription(l10n, right),
          ),
      cellBuilder: (BuildContext context, AccessAdminItem item) =>
          Text(accessAdminPermissionDescription(context.l10n, item)),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'perm_code',
      label: l10n.accessAdminPermissionCodeColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            accessAdminPermissionMachineCode(left),
            accessAdminPermissionMachineCode(right),
          ),
      cellBuilder: (_, AccessAdminItem item) {
        final String? code = accessAdminPermissionMachineCode(item);
        if (code == null) {
          return const Text('—');
        }
        return Text(code);
      },
    ),
  ];
}

/// Machine permission code (`domain:action`), never the localized display name.
String? accessAdminPermissionMachineCode(AccessAdminItem item) {
  final String? code = (item.permissionName ?? item.name)?.trim();
  if (code == null || code.isEmpty) {
    return null;
  }
  return code;
}

/// Permission description from the API, falling back to catalog metadata.
String accessAdminPermissionDescription(
  AppLocalizations l10n,
  AccessAdminItem item,
) {
  final String? subtitle = item.subtitle?.trim();
  if (subtitle != null && subtitle.isNotEmpty) {
    return subtitle;
  }
  final String? code = accessAdminPermissionMachineCode(item);
  if (code == null) {
    return '—';
  }
  final String catalog = l10n.permissionCatalogDescriptionForCode(code).trim();
  if (catalog.isEmpty) {
    return '—';
  }
  return catalog;
}

List<AppListTableColumn<AccessAdminItem>> _entitlementColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<AccessAdminItem>>[
    AppListTableColumn<AccessAdminItem>(
      id: 'ent_module',
      label: l10n.accessAdminColumnName,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.title, right.title),
      cellBuilder: (_, AccessAdminItem item) => Text(item.title),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'ent_group',
      label: l10n.accessAdminColumnDetails,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.moduleGroup ?? left.subtitle,
            right.moduleGroup ?? right.subtitle,
          ),
      cellBuilder: (_, AccessAdminItem item) =>
          Text(item.moduleGroup ?? item.subtitle ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'ent_plan',
      label: l10n.accessAdminEntitlementPlanColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.planLabel, right.planLabel),
      cellBuilder: (_, AccessAdminItem item) => Text(item.planLabel ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'ent_active',
      label: l10n.accessAdminColumnStatus,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          left.isActive == right.isActive ? 0 : (left.isActive ? -1 : 1),
      cellBuilder: (BuildContext context, AccessAdminItem item) {
        return AppWorkspaceStatusBadge(
          status: accessAdminEntitlementActiveStatus(context, item.isActive),
        );
      },
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'ent_denial',
      label: l10n.accessAdminEntitlementDenialColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.entitlementDenialReason,
            right.entitlementDenialReason,
          ),
      cellBuilder: (_, AccessAdminItem item) {
        if (!item.entitlementDenied) {
          return const Text('—');
        }
        return Text(item.entitlementDenialReason ?? '—');
      },
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'ent_module_slug',
      label: l10n.accessAdminModuleSlugColumnLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.moduleSlug, right.moduleSlug),
      cellBuilder: (_, AccessAdminItem item) => Text(item.moduleSlug ?? '—'),
    ),
  ];
}

List<AppListTableColumn<AccessAdminItem>> _registrationColumns(
  BuildContext context, {
  required bool canWrite,
  required Future<void> Function(AccessAdminItem item) onRegistrationApprove,
}) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<AccessAdminItem>>[
    AppListTableColumn<AccessAdminItem>(
      id: 'reg_id',
      label: l10n.accessAdminColumnId,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(
            left.effectiveDisplayId,
            right.effectiveDisplayId,
          ),
      cellBuilder: (_, AccessAdminItem item) => Text(item.effectiveDisplayId),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'reg_name',
      label: l10n.accessAdminColumnName,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.title, right.title),
      cellBuilder: (_, AccessAdminItem item) => Text(item.title),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'reg_facility',
      label: l10n.accessAdminColumnDetails,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.subtitle, right.subtitle),
      cellBuilder: (_, AccessAdminItem item) => Text(item.subtitle ?? '—'),
    ),
    AppListTableColumn<AccessAdminItem>(
      id: 'status',
      label: l10n.accessAdminColumnStatus,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.status, right.status),
      cellBuilder: (BuildContext context, AccessAdminItem item) {
        if (item.status == null) {
          return const Text('—');
        }
        return AppWorkspaceStatusBadge(
          status: accessAdminItemStatus(context, item.status),
        );
      },
    ),
    // Omit the column entirely when unauthorized (no empty/disabled cell).
    if (canWrite)
      _registrationNextActionColumn(
        context,
        onRegistrationApprove: onRegistrationApprove,
      ),
    AppListTableColumn<AccessAdminItem>(
      id: 'reg_email',
      label: l10n.accessAdminEmailLabel,
      sortComparator: (AccessAdminItem left, AccessAdminItem right) =>
          appListTableCompareText(left.email, right.email),
      cellBuilder: (_, AccessAdminItem item) => Text(item.email ?? '—'),
    ),
  ];
}

AppListTableColumn<AccessAdminItem> _userNextActionColumn(
  BuildContext context, {
  required Future<void> Function(AccessAdminItem item) onUserStatusToggle,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<AccessAdminItem>(
    id: 'next_action',
    label: l10n.accessAdminManageUserAction,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, AccessAdminItem item) {
      final String label = item.status == 'ACTIVE'
          ? l10n.accessAdminDeactivateAction
          : l10n.accessAdminActivateAction;
      return AppButton.tertiary(
        label: label,
        onPressed: () => onUserStatusToggle(item),
      );
    },
  );
}

AppListTableColumn<AccessAdminItem> _roleNextActionColumn(
  BuildContext context, {
  required void Function(AccessAdminItem item) onRoleEdit,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<AccessAdminItem>(
    id: 'next_action',
    label: l10n.accessAdminEditRoleAction,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, AccessAdminItem item) {
      if (item.isSystemCritical) {
        return const SizedBox.shrink();
      }
      return AppButton.tertiary(
        label: l10n.accessAdminEditRoleAction,
        leadingIcon: Icons.edit_outlined,
        onPressed: () => onRoleEdit(item),
      );
    },
  );
}

AppListTableColumn<AccessAdminItem> _registrationNextActionColumn(
  BuildContext context, {
  required Future<void> Function(AccessAdminItem item) onRegistrationApprove,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<AccessAdminItem>(
    id: 'next_action',
    label: l10n.accessAdminApproveRegistrationAction,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, AccessAdminItem item) {
      return AppButton.tertiary(
        label: l10n.accessAdminApproveRegistrationAction,
        onPressed: () => onRegistrationApprove(item),
      );
    },
  );
}

AppWorkspaceStatus accessAdminItemStatus(BuildContext context, String? status) {
  final String normalized = (status ?? '').trim();
  if (normalized.isEmpty) {
    return const AppWorkspaceStatus(
      label: '—',
      tone: AppWorkspaceStatusTone.neutral,
    );
  }
  final AppWorkspaceStatusTone tone = switch (normalized.toUpperCase()) {
    'ACTIVE' => AppWorkspaceStatusTone.success,
    'INACTIVE' => AppWorkspaceStatusTone.neutral,
    'PENDING' => AppWorkspaceStatusTone.warning,
    'REJECTED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
  return AppWorkspaceStatus(label: normalized, tone: tone);
}

AppWorkspaceStatus accessAdminEntitlementActiveStatus(
  BuildContext context,
  bool isActive,
) {
  return AppWorkspaceStatus(
    label: accessAdminEntitlementActiveLabel(context, isActive),
    tone: isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral,
  );
}

String accessAdminEntitlementActiveLabel(BuildContext context, bool isActive) {
  final AppLocalizations l10n = context.l10n;
  return isActive
      ? l10n.tenantFacilityStatusActive
      : l10n.tenantFacilityStatusInactive;
}

String accessAdminRoleScopeLabel(BuildContext context, AccessAdminItem item) {
  final AppLocalizations l10n = context.l10n;
  if (item.isFacilityScopedRole) {
    final String? facility = item.facilityName?.trim();
    return facility != null && facility.isNotEmpty
        ? '${l10n.accessAdminRoleScopeFacilityBadge} · $facility'
        : l10n.accessAdminRoleScopeFacilityBadge;
  }
  if (item.isPlatformScopedRole) {
    return l10n.accessAdminRoleScopePlatformLabel;
  }
  return l10n.accessAdminRoleScopeTenantBadge;
}

class AccessAdminRoleScopeBadge extends StatelessWidget {
  const AccessAdminRoleScopeBadge({required this.item, super.key});

  final AccessAdminItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isFacility = item.isFacilityScopedRole;
    final bool isPlatform = item.isPlatformScopedRole;
    final String label = accessAdminRoleScopeLabel(context, item);
    final Color accent = isFacility
        ? colors.tertiary
        : isPlatform
        ? colors.secondary
        : colors.primary;
    final Color container = isFacility
        ? colors.tertiaryContainer
        : isPlatform
        ? colors.secondaryContainer
        : colors.primaryContainer;

    return Chip(
      avatar: Icon(
        isFacility
            ? Icons.local_hospital_outlined
            : isPlatform
            ? Icons.public_outlined
            : Icons.domain_outlined,
        size: 16,
        color: accent,
      ),
      label: Text(label, style: theme.textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      backgroundColor: container,
      side: theme.borders.side(color: accent.withValues(alpha: 0.28)),
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
    );
  }
}
