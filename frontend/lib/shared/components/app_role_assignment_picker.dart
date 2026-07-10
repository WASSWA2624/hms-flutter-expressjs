import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';

@immutable
final class AppRoleAssignmentOption {
  const AppRoleAssignmentOption({
    required this.id,
    required this.label,
    this.description,
    this.permissionCount = 0,
    this.isSystemCritical = false,
  });

  final String id;
  final String label;
  final String? description;
  final int permissionCount;
  final bool isSystemCritical;
}

typedef AppRolePermissionsLoader = Future<Set<String>> Function(String roleId);

/// Reusable role picker with search, per-role summary, and effective-permissions preview.
class AppRoleAssignmentPicker extends StatefulWidget {
  const AppRoleAssignmentPicker({
    required this.roles,
    required this.selectedRoleIds,
    required this.onSelectionChanged,
    this.loadRolePermissions,
    this.emptyWarning,
    super.key,
  });

  final List<AppRoleAssignmentOption> roles;
  final Set<String> selectedRoleIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final AppRolePermissionsLoader? loadRolePermissions;
  final String? emptyWarning;

  @override
  State<AppRoleAssignmentPicker> createState() =>
      _AppRoleAssignmentPickerState();
}

class _AppRoleAssignmentPickerState extends State<AppRoleAssignmentPicker> {
  final Set<String> _previewPermissions = <String>{};
  bool _loadingPermissions = false;
  int _roleSelectGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPermissionPreview());
  }

  @override
  void didUpdateWidget(covariant AppRoleAssignmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoleIds != widget.selectedRoleIds) {
      unawaited(_refreshPermissionPreview());
    }
  }

  List<AppRoleAssignmentOption> get _availableRoles {
    return widget.roles
        .where(
          (AppRoleAssignmentOption role) =>
              !widget.selectedRoleIds.contains(role.id),
        )
        .toList(growable: false);
  }

  AppRoleAssignmentOption? _roleById(String roleId) {
    for (final AppRoleAssignmentOption role in widget.roles) {
      if (role.id == roleId) {
        return role;
      }
    }
    return null;
  }

  void _updateSelection(Set<String> next) {
    widget.onSelectionChanged(next);
    unawaited(_refreshPermissionPreview());
  }

  void _addRole(String? roleId) {
    if (roleId == null || roleId.isEmpty) {
      return;
    }
    final Set<String> next = Set<String>.from(widget.selectedRoleIds)
      ..add(roleId);
    setState(() => _roleSelectGeneration += 1);
    _updateSelection(next);
  }

  void _removeRole(String roleId) {
    final Set<String> next = Set<String>.from(widget.selectedRoleIds)
      ..remove(roleId);
    _updateSelection(next);
  }

  Future<void> _refreshPermissionPreview() async {
    final AppRolePermissionsLoader? loader = widget.loadRolePermissions;
    if (loader == null || widget.selectedRoleIds.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewPermissions.clear();
        _loadingPermissions = false;
      });
      return;
    }

    setState(() => _loadingPermissions = true);
    final Set<String> permissions = <String>{};
    for (final String roleId in widget.selectedRoleIds) {
      final Set<String> rolePermissions = await loader(roleId);
      permissions.addAll(rolePermissions);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _previewPermissions
        ..clear()
        ..addAll(permissions);
      _loadingPermissions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppFormSection(
      children: <Widget>[
        if (widget.emptyWarning != null && widget.selectedRoleIds.isEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.warning_amber_outlined,
                color: theme.colorScheme.error,
                size: 20,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  widget.emptyWarning!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        AppSelectField<String>.searchable(
          key: ValueKey<int>(_roleSelectGeneration),
          labelText: l10n.hrRoleAssignmentAddRoleLabel,
          options: <AppSelectOption<String>>[
            for (final AppRoleAssignmentOption role in _availableRoles)
              AppSelectOption<String>(
                value: role.id,
                label: role.permissionCount > 0
                    ? '${role.label} · ${l10n.hrAccessPermissionCountLabel(role.permissionCount)}'
                    : role.label,
                searchText:
                    '${role.label} ${role.description ?? ''} ${role.permissionCount}',
              ),
          ],
          onChanged: _addRole,
        ),
        if (widget.selectedRoleIds.isEmpty)
          Text(
            l10n.hrRoleAssignmentEmptySelectedLabel,
            style: theme.textTheme.bodySmall,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final String roleId in widget.selectedRoleIds)
                _SelectedRoleTile(
                  role: _roleById(roleId),
                  roleId: roleId,
                  onRemove: () => _removeRole(roleId),
                ),
            ],
          ),
        Text(
          l10n.hrEffectivePermissionsTitle,
          style: theme.textTheme.titleSmall,
        ),
        if (_loadingPermissions)
          const LinearProgressIndicator(minHeight: 2)
        else if (_previewPermissions.isEmpty)
          Text(
            l10n.hrStaffOnboardingPermissionsPreviewEmpty,
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _previewPermissions
                .take(32)
                .map(
                  (String permission) => Chip(
                    label: Text(
                      l10n.permissionCatalogLabelForCode(permission),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _SelectedRoleTile extends StatelessWidget {
  const _SelectedRoleTile({
    required this.roleId,
    required this.onRemove,
    this.role,
  });

  final AppRoleAssignmentOption? role;
  final String roleId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppRoleAssignmentOption? resolved = role;

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      child: ListTile(
        title: Row(
          children: <Widget>[
            Expanded(child: Text(resolved?.label ?? roleId)),
            if (resolved?.isSystemCritical == true)
              Padding(
                padding: EdgeInsets.only(left: theme.spacing.sm),
                child: Chip(
                  label: Text(l10n.hrAccessSystemCriticalRoleBadge),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text(
          l10n.hrAccessRoleSummary(resolved?.permissionCount ?? 0, 0),
        ),
        trailing: IconButton(
          tooltip: l10n.hrRoleAssignmentRemoveRoleAction,
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
