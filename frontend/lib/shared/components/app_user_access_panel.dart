import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Role assignment shown in [AppUserAccessPanel], including inherited permissions.
@immutable
final class AppUserAccessRoleGroup {
  const AppUserAccessRoleGroup({
    required this.roleId,
    required this.roleName,
    this.userRoleId,
    this.permissions = const <String>[],
    this.isSystemCritical = false,
  });

  final String roleId;
  final String roleName;
  final String? userRoleId;
  final List<String> permissions;
  final bool isSystemCritical;

  bool get canRemove =>
      userRoleId != null && userRoleId!.trim().isNotEmpty && !isSystemCritical;
}

/// Direct (individually assigned) permission shown in [AppUserAccessPanel].
@immutable
final class AppUserAccessDirectPermission {
  const AppUserAccessDirectPermission({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

/// Shared read/manage panel for user roles and direct permissions.
///
/// Role-inherited permissions are display-only. Removing access for those
/// requires removing the parent role. Direct permissions may be removed
/// individually when [canWrite] is true.
class AppUserAccessPanel extends StatelessWidget {
  const AppUserAccessPanel({
    required this.roleGroups,
    required this.directPermissions,
    this.canWrite = false,
    this.isBusy = false,
    this.onAddRole,
    this.onRemoveRole,
    this.onAddDirectPermission,
    this.onRemoveDirectPermission,
    super.key,
  });

  final List<AppUserAccessRoleGroup> roleGroups;
  final List<AppUserAccessDirectPermission> directPermissions;
  final bool canWrite;
  final bool isBusy;
  final VoidCallback? onAddRole;
  final ValueChanged<AppUserAccessRoleGroup>? onRemoveRole;
  final VoidCallback? onAddDirectPermission;
  final ValueChanged<AppUserAccessDirectPermission>? onRemoveDirectPermission;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionPanel(
          title: l10n.accessAdminAssignedRolesLabel,
          description: l10n.accessAdminUserDetailRolesSectionDescription,
          leadingIcon: Icons.groups_outlined,
          trailing: _HeaderActions(
            count: roleGroups.length,
            canWrite: canWrite,
            isBusy: isBusy,
            addLabel: l10n.accessAdminUserAccessAddRoleAction,
            addIcon: Icons.person_add_alt_1_outlined,
            onAdd: onAddRole,
          ),
          children: <Widget>[
            if (roleGroups.isEmpty)
              Text(
                l10n.accessAdminUserDetailNoRolesMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...roleGroups.map(
                (AppUserAccessRoleGroup group) => Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.sm),
                  child: _RoleGroupCard(
                    group: group,
                    canWrite: canWrite,
                    isBusy: isBusy,
                    onRemove: onRemoveRole == null
                        ? null
                        : () => onRemoveRole!(group),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.hrAccessDirectPermissionsLabel,
          description: l10n.accessAdminUserAccessDirectPermissionsDescription,
          leadingIcon: Icons.key_outlined,
          trailing: _HeaderActions(
            count: directPermissions.length,
            canWrite: canWrite,
            isBusy: isBusy,
            addLabel: l10n.accessAdminUserAccessAddDirectPermissionAction,
            addIcon: Icons.add_outlined,
            onAdd: onAddDirectPermission,
          ),
          children: <Widget>[
            if (directPermissions.isEmpty)
              Text(
                l10n.accessAdminUserAccessNoDirectPermissionsMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: directPermissions
                    .map(
                      (AppUserAccessDirectPermission permission) =>
                          _DirectPermissionChip(
                            permission: permission,
                            canWrite: canWrite,
                            isBusy: isBusy,
                            onRemove: onRemoveDirectPermission == null
                                ? null
                                : () => onRemoveDirectPermission!(permission),
                          ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.count,
    required this.canWrite,
    required this.isBusy,
    required this.addLabel,
    required this.addIcon,
    this.onAdd,
  });

  final int count;
  final bool canWrite;
  final bool isBusy;
  final String addLabel;
  final IconData addIcon;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Wrap(
      spacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Chip(
          avatar: Icon(
            Icons.format_list_numbered_outlined,
            size: 16,
            color: colorScheme.primary,
          ),
          label: Text('$count'),
          backgroundColor: colorScheme.primaryContainer,
          visualDensity: VisualDensity.compact,
          labelStyle: theme.textTheme.labelSmall,
        ),
        if (canWrite && onAdd != null)
          AppButton.secondary(
            leadingIcon: addIcon,
            label: addLabel,
            onPressed: isBusy ? null : onAdd,
          ),
      ],
    );
  }
}

class _RoleGroupCard extends StatelessWidget {
  const _RoleGroupCard({
    required this.group,
    required this.canWrite,
    required this.isBusy,
    this.onRemove,
  });

  final AppUserAccessRoleGroup group;
  final bool canWrite;
  final bool isBusy;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppContentPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.shield_outlined, color: colorScheme.primary, size: 20),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.roleName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      l10n.accessAdminUserAccessPermissionCountLabel(
                        group.permissions.length,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (canWrite && group.canRemove && onRemove != null)
                IconButton(
                  tooltip: l10n.accessAdminUserAccessRemoveRoleAction,
                  onPressed: isBusy ? null : onRemove,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: colorScheme.error,
                  ),
                ),
            ],
          ),
          if (group.permissions.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              l10n.accessAdminUserAccessRolePermissionsHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: group.permissions
                  .map(
                    (String permission) => Chip(
                      avatar: Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        l10n.permissionCatalogLabelForCode(permission),
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectPermissionChip extends StatelessWidget {
  const _DirectPermissionChip({
    required this.permission,
    required this.canWrite,
    required this.isBusy,
    this.onRemove,
  });

  final AppUserAccessDirectPermission permission;
  final bool canWrite;
  final bool isBusy;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String label = l10n.permissionCatalogLabelForCode(permission.name);

    if (canWrite && onRemove != null) {
      return InputChip(
        avatar: Icon(
          Icons.key_outlined,
          size: 16,
          color: colorScheme.secondary,
        ),
        label: Text(label, overflow: TextOverflow.ellipsis),
        backgroundColor: colorScheme.secondaryContainer,
        visualDensity: VisualDensity.compact,
        labelStyle: theme.textTheme.labelSmall,
        deleteIcon: Icon(
          Icons.close,
          size: 16,
          color: colorScheme.error,
        ),
        onDeleted: isBusy ? null : onRemove,
        tooltip: l10n.accessAdminUserAccessRemoveDirectPermissionAction,
      );
    }

    return Chip(
      avatar: Icon(
        Icons.key_outlined,
        size: 16,
        color: colorScheme.secondary,
      ),
      label: Text(label, overflow: TextOverflow.ellipsis),
      backgroundColor: colorScheme.secondaryContainer,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.labelSmall,
    );
  }
}
