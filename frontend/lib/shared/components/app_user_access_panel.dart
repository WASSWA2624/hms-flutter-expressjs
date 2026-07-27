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
  const AppUserAccessDirectPermission({required this.id, required this.name});

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
              ...directPermissions.map(
                (AppUserAccessDirectPermission permission) => Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.xs),
                  child: _DirectPermissionRow(
                    permission: permission,
                    canWrite: canWrite,
                    isBusy: isBusy,
                    onRemove: onRemoveDirectPermission == null
                        ? null
                        : () => onRemoveDirectPermission!(permission),
                  ),
                ),
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

class _RoleGroupCard extends StatefulWidget {
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
  State<_RoleGroupCard> createState() => _RoleGroupCardState();
}

class _RoleGroupCardState extends State<_RoleGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppUserAccessRoleGroup group = widget.group;
    final bool canRemove =
        widget.canWrite && group.canRemove && widget.onRemove != null;
    final bool hasPermissions = group.permissions.isNotEmpty;

    return AppContentPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(theme.radius.sm),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: InkWell(
                  onTap: hasPermissions
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  borderRadius: BorderRadius.circular(theme.radius.sm),
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
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              l10n.accessAdminUserAccessPermissionCountLabel(
                                group.permissions.length,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (hasPermissions) ...<Widget>[
                            SizedBox(width: theme.spacing.xs),
                            Icon(
                              _expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (canRemove)
                AppButton.tertiary(
                  leadingIcon: Icons.remove_circle_outline,
                  label: l10n.accessAdminUserAccessRemoveRoleAction,
                  color: colorScheme.error,
                  tooltip: l10n.accessAdminUserAccessRemoveRoleAction,
                  onPressed: widget.isBusy ? null : widget.onRemove,
                ),
            ],
          ),
          if (hasPermissions && _expanded) ...<Widget>[
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

class _DirectPermissionRow extends StatelessWidget {
  const _DirectPermissionRow({
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.key_outlined, size: 18, color: colorScheme.secondary),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: theme.textTheme.labelLarge),
                  if (label != permission.name)
                    Text(
                      permission.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (canWrite && onRemove != null)
              AppButton.tertiary(
                leadingIcon: Icons.remove_circle_outline,
                label: l10n.accessAdminUserAccessRemoveDirectPermissionAction,
                color: colorScheme.error,
                tooltip: l10n.accessAdminUserAccessRemoveDirectPermissionAction,
                onPressed: isBusy ? null : onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
