import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';

@immutable
final class AppPermissionAssignmentOption {
  const AppPermissionAssignmentOption({
    required this.id,
    required this.code,
    required this.label,
    this.description,
  });

  final String id;
  final String code;
  final String label;
  final String? description;

  String get modulePrefix {
    final int separator = code.indexOf(':');
    if (separator <= 0) {
      return code;
    }
    return code.substring(0, separator);
  }
}

/// Reusable permission multi-select with search, select-all, and module grouping.
class AppPermissionAssignmentPicker extends StatefulWidget {
  const AppPermissionAssignmentPicker({
    required this.permissions,
    required this.selectedPermissionIds,
    required this.onSelectionChanged,
    this.groupByModule = true,
    super.key,
  });

  final List<AppPermissionAssignmentOption> permissions;
  final Set<String> selectedPermissionIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final bool groupByModule;

  @override
  State<AppPermissionAssignmentPicker> createState() =>
      _AppPermissionAssignmentPickerState();
}

class _AppPermissionAssignmentPickerState
    extends State<AppPermissionAssignmentPicker> {
  int _permissionSelectGeneration = 0;

  List<AppPermissionAssignmentOption> get _availablePermissions {
    return widget.permissions
        .where(
          (AppPermissionAssignmentOption permission) =>
              !widget.selectedPermissionIds.contains(permission.id),
        )
        .toList(growable: false);
  }

  AppPermissionAssignmentOption? _permissionById(String permissionId) {
    for (final AppPermissionAssignmentOption permission in widget.permissions) {
      if (permission.id == permissionId) {
        return permission;
      }
    }
    return null;
  }

  void _updateSelection(Set<String> next) {
    widget.onSelectionChanged(next);
  }

  void _addPermission(String? permissionId) {
    if (permissionId == null || permissionId.isEmpty) {
      return;
    }
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds)
      ..add(permissionId);
    setState(() => _permissionSelectGeneration += 1);
    _updateSelection(next);
  }

  void _removePermission(String permissionId) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds)
      ..remove(permissionId);
    _updateSelection(next);
  }

  void _selectAll() {
    _updateSelection(
      widget.permissions.map((AppPermissionAssignmentOption p) => p.id).toSet(),
    );
  }

  void _clearAll() {
    _updateSelection(<String>{});
  }

  Map<String, List<AppPermissionAssignmentOption>> _groupedAvailable() {
    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        <String, List<AppPermissionAssignmentOption>>{};
    for (final AppPermissionAssignmentOption permission
        in _availablePermissions) {
      final String key = widget.groupByModule
          ? permission.modulePrefix
          : '';
      grouped.putIfAbsent(key, () => <AppPermissionAssignmentOption>[]).add(
        permission,
      );
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        _groupedAvailable();
    final List<String> groupKeys = grouped.keys.toList(growable: false)
      ..sort();

    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>.searchable(
          key: ValueKey<int>(_permissionSelectGeneration),
          labelText: l10n.hrPermissionAssignmentAddPermissionLabel,
          options: <AppSelectOption<String>>[
            for (final AppPermissionAssignmentOption permission
                in _availablePermissions)
              AppSelectOption<String>(
                value: permission.id,
                label: permission.label,
                searchText:
                    '${permission.code} ${permission.label} ${permission.description ?? ''}',
              ),
          ],
          onChanged: _addPermission,
        ),
        Padding(
          padding: EdgeInsets.only(bottom: theme.spacing.sm),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              AppButton.secondary(
                label: l10n.hrAccessSelectAllPermissionsAction,
                onPressed: widget.permissions.isEmpty ? null : _selectAll,
              ),
              AppButton.secondary(
                label: l10n.hrAccessClearPermissionsAction,
                onPressed: widget.selectedPermissionIds.isEmpty
                    ? null
                    : _clearAll,
              ),
            ],
          ),
        ),
        if (widget.selectedPermissionIds.isEmpty)
          Text(
            l10n.hrPermissionAssignmentEmptySelectedLabel,
            style: theme.textTheme.bodySmall,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final String permissionId in widget.selectedPermissionIds)
                _SelectedPermissionTile(
                  permission: _permissionById(permissionId),
                  permissionId: permissionId,
                  onRemove: () => _removePermission(permissionId),
                ),
            ],
          ),
        if (_availablePermissions.isNotEmpty && widget.groupByModule) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(
            l10n.hrPermissionAssignmentAvailableByModuleLabel,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.xs),
          for (final String groupKey in groupKeys)
            if (groupKey.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.xs),
                child: Text(
                  groupKey,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _SelectedPermissionTile extends StatelessWidget {
  const _SelectedPermissionTile({
    required this.permissionId,
    required this.onRemove,
    this.permission,
  });

  final AppPermissionAssignmentOption? permission;
  final String permissionId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppPermissionAssignmentOption? resolved = permission;

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      child: ListTile(
        title: Text(resolved?.label ?? permissionId),
        subtitle: Text(resolved?.code ?? ''),
        trailing: IconButton(
          tooltip: l10n.hrPermissionAssignmentRemovePermissionAction,
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
