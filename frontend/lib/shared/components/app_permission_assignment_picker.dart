import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
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

  String get groupLabel {
    final int separator = label.indexOf(' — ');
    if (separator > 0) {
      return label.substring(0, separator);
    }
    return modulePrefix;
  }
}

/// Reusable permission multi-select with search, grouped checkboxes, and bulk actions.
class AppPermissionAssignmentPicker extends StatefulWidget {
  const AppPermissionAssignmentPicker({
    required this.permissions,
    required this.selectedPermissionIds,
    required this.onSelectionChanged,
    this.groupByModule = true,
    this.enabled = true,
    super.key,
  });

  final List<AppPermissionAssignmentOption> permissions;
  final Set<String> selectedPermissionIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final bool groupByModule;
  final bool enabled;

  @override
  State<AppPermissionAssignmentPicker> createState() =>
      _AppPermissionAssignmentPickerState();
}

class _AppPermissionAssignmentPickerState
    extends State<AppPermissionAssignmentPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Set<String> _expandedGroupKeys;

  @override
  void initState() {
    super.initState();
    _expandedGroupKeys = _initialExpandedGroups();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant AppPermissionAssignmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPermissionIds != widget.selectedPermissionIds) {
      _expandedGroupKeys.addAll(_groupsWithSelection());
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Set<String> _groupsWithSelection() {
    final Set<String> keys = <String>{};
    for (final AppPermissionAssignmentOption permission in widget.permissions) {
      if (widget.selectedPermissionIds.contains(permission.id)) {
        keys.add(_groupKey(permission));
      }
    }
    return keys;
  }

  Set<String> _initialExpandedGroups() {
    final Set<String> keys = _groupsWithSelection();
    if (keys.isEmpty && widget.permissions.isNotEmpty) {
      keys.add(_groupKey(widget.permissions.first));
    }
    return keys;
  }

  String _groupKey(AppPermissionAssignmentOption permission) {
    return widget.groupByModule ? permission.modulePrefix : '';
  }

  bool _matchesSearch(AppPermissionAssignmentOption permission) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final String haystack =
        '${permission.code} ${permission.label} ${permission.description ?? ''} ${permission.groupLabel}'
            .toLowerCase();
    return haystack.contains(_searchQuery);
  }

  List<AppPermissionAssignmentOption> get _filteredPermissions {
    return widget.permissions
        .where(_matchesSearch)
        .toList(growable: false);
  }

  Map<String, List<AppPermissionAssignmentOption>> _groupedPermissions() {
    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        <String, List<AppPermissionAssignmentOption>>{};
    for (final AppPermissionAssignmentOption permission
        in _filteredPermissions) {
      grouped
          .putIfAbsent(_groupKey(permission), () => <AppPermissionAssignmentOption>[])
          .add(permission);
    }
    for (final List<AppPermissionAssignmentOption> group in grouped.values) {
      group.sort(
        (AppPermissionAssignmentOption a, AppPermissionAssignmentOption b) =>
            a.label.compareTo(b.label),
      );
    }
    return grouped;
  }

  void _updateSelection(Set<String> next) {
    widget.onSelectionChanged(next);
  }

  void _togglePermission(String permissionId, bool selected) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    if (selected) {
      next.add(permissionId);
    } else {
      next.remove(permissionId);
    }
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

  void _selectGroup(List<AppPermissionAssignmentOption> groupPermissions) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    for (final AppPermissionAssignmentOption permission in groupPermissions) {
      next.add(permission.id);
    }
    _updateSelection(next);
  }

  void _clearGroup(List<AppPermissionAssignmentOption> groupPermissions) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    for (final AppPermissionAssignmentOption permission in groupPermissions) {
      next.remove(permission.id);
    }
    _updateSelection(next);
  }

  int _selectedCountInGroup(List<AppPermissionAssignmentOption> groupPermissions) {
    return groupPermissions
        .where(
          (AppPermissionAssignmentOption permission) =>
              widget.selectedPermissionIds.contains(permission.id),
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        _groupedPermissions();
    final List<String> groupKeys = grouped.keys.toList(growable: false)..sort();
    final int selectedCount = widget.selectedPermissionIds.length;
    final int totalCount = widget.permissions.length;
    final bool canChange = widget.enabled;

    return AppFormSection(
      children: <Widget>[
        AppTextField(
          controller: _searchController,
          enabled: canChange,
          labelText: l10n.hrPermissionAssignmentSearchLabel,
          prefixIcon: const Icon(Icons.search),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
          child: Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                l10n.hrPermissionAssignmentSelectedCount(selectedCount, totalCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppButton.secondary(
                label: l10n.hrAccessSelectAllPermissionsAction,
                onPressed: canChange && widget.permissions.isNotEmpty
                    ? _selectAll
                    : null,
              ),
              AppButton.secondary(
                label: l10n.hrAccessClearPermissionsAction,
                onPressed: canChange && selectedCount > 0 ? _clearAll : null,
              ),
            ],
          ),
        ),
        if (selectedCount == 0)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Text(
              l10n.hrPermissionAssignmentEmptySelectedLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (groupKeys.isEmpty)
          Text(
            l10n.hrPermissionAssignmentNoSearchResultsLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ResponsiveBuilder(
            builder: (BuildContext context, AppBreakpoint breakpoint) {
              final bool twoColumns = !breakpoint.isMobile;
              if (!twoColumns) {
                return _PermissionGroupColumn(
                  groupKeys: groupKeys,
                  grouped: grouped,
                  expandedGroupKeys: _expandedGroupKeys,
                  selectedPermissionIds: widget.selectedPermissionIds,
                  enabled: canChange,
                  onExpansionChanged: (String groupKey, bool expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedGroupKeys.add(groupKey);
                      } else {
                        _expandedGroupKeys.remove(groupKey);
                      }
                    });
                  },
                  onTogglePermission: _togglePermission,
                  onSelectGroup: _selectGroup,
                  onClearGroup: _clearGroup,
                  selectedCountInGroup: _selectedCountInGroup,
                );
              }

              final int splitIndex = (groupKeys.length / 2).ceil();
              final List<String> leftKeys = groupKeys
                  .take(splitIndex)
                  .toList(growable: false);
              final List<String> rightKeys = groupKeys
                  .skip(splitIndex)
                  .toList(growable: false);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _PermissionGroupColumn(
                      groupKeys: leftKeys,
                      grouped: grouped,
                      expandedGroupKeys: _expandedGroupKeys,
                      selectedPermissionIds: widget.selectedPermissionIds,
                      enabled: canChange,
                      onExpansionChanged: (String groupKey, bool expanded) {
                        setState(() {
                          if (expanded) {
                            _expandedGroupKeys.add(groupKey);
                          } else {
                            _expandedGroupKeys.remove(groupKey);
                          }
                        });
                      },
                      onTogglePermission: _togglePermission,
                      onSelectGroup: _selectGroup,
                      onClearGroup: _clearGroup,
                      selectedCountInGroup: _selectedCountInGroup,
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: _PermissionGroupColumn(
                      groupKeys: rightKeys,
                      grouped: grouped,
                      expandedGroupKeys: _expandedGroupKeys,
                      selectedPermissionIds: widget.selectedPermissionIds,
                      enabled: canChange,
                      onExpansionChanged: (String groupKey, bool expanded) {
                        setState(() {
                          if (expanded) {
                            _expandedGroupKeys.add(groupKey);
                          } else {
                            _expandedGroupKeys.remove(groupKey);
                          }
                        });
                      },
                      onTogglePermission: _togglePermission,
                      onSelectGroup: _selectGroup,
                      onClearGroup: _clearGroup,
                      selectedCountInGroup: _selectedCountInGroup,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _PermissionGroupColumn extends StatelessWidget {
  const _PermissionGroupColumn({
    required this.groupKeys,
    required this.grouped,
    required this.expandedGroupKeys,
    required this.selectedPermissionIds,
    required this.enabled,
    required this.onExpansionChanged,
    required this.onTogglePermission,
    required this.onSelectGroup,
    required this.onClearGroup,
    required this.selectedCountInGroup,
  });

  final List<String> groupKeys;
  final Map<String, List<AppPermissionAssignmentOption>> grouped;
  final Set<String> expandedGroupKeys;
  final Set<String> selectedPermissionIds;
  final bool enabled;
  final void Function(String groupKey, bool expanded) onExpansionChanged;
  final void Function(String permissionId, bool selected) onTogglePermission;
  final void Function(List<AppPermissionAssignmentOption> permissions)
  onSelectGroup;
  final void Function(List<AppPermissionAssignmentOption> permissions)
  onClearGroup;
  final int Function(List<AppPermissionAssignmentOption> permissions)
  selectedCountInGroup;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String groupKey in groupKeys)
          _PermissionGroupSection(
            permissions: grouped[groupKey] ?? const <AppPermissionAssignmentOption>[],
            expanded: expandedGroupKeys.contains(groupKey),
            selectedPermissionIds: selectedPermissionIds,
            enabled: enabled,
            onExpansionChanged: (bool expanded) =>
                onExpansionChanged(groupKey, expanded),
            onTogglePermission: onTogglePermission,
            onSelectGroup: onSelectGroup,
            onClearGroup: onClearGroup,
            selectedCountInGroup: selectedCountInGroup,
          ),
        SizedBox(height: theme.spacing.xs),
      ],
    );
  }
}

class _PermissionGroupSection extends StatelessWidget {
  const _PermissionGroupSection({
    required this.permissions,
    required this.expanded,
    required this.selectedPermissionIds,
    required this.enabled,
    required this.onExpansionChanged,
    required this.onTogglePermission,
    required this.onSelectGroup,
    required this.onClearGroup,
    required this.selectedCountInGroup,
  });

  final List<AppPermissionAssignmentOption> permissions;
  final bool expanded;
  final Set<String> selectedPermissionIds;
  final bool enabled;
  final ValueChanged<bool> onExpansionChanged;
  final void Function(String permissionId, bool selected) onTogglePermission;
  final void Function(List<AppPermissionAssignmentOption> permissions)
  onSelectGroup;
  final void Function(List<AppPermissionAssignmentOption> permissions)
  onClearGroup;
  final int Function(List<AppPermissionAssignmentOption> permissions)
  selectedCountInGroup;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    if (permissions.isEmpty) {
      return const SizedBox.shrink();
    }

    final String groupLabel = permissions.first.groupLabel;
    final int selectedInGroup = selectedCountInGroup(permissions);
    final bool allSelected = selectedInGroup == permissions.length;
    final bool noneSelected = selectedInGroup == 0;

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey<bool>(expanded),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.xs,
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          theme.spacing.sm,
          0,
          theme.spacing.md,
          theme.spacing.sm,
        ),
        title: Text(
          groupLabel,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          l10n.hrPermissionAssignmentSelectedCount(
            selectedInGroup,
            permissions.length,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: theme.spacing.xs,
              children: <Widget>[
                TextButton(
                  onPressed: enabled && !allSelected
                      ? () => onSelectGroup(permissions)
                      : null,
                  child: Text(l10n.hrPermissionAssignmentSelectGroupAction),
                ),
                TextButton(
                  onPressed: enabled && !noneSelected
                      ? () => onClearGroup(permissions)
                      : null,
                  child: Text(l10n.hrPermissionAssignmentClearGroupAction),
                ),
              ],
            ),
          ),
          for (final AppPermissionAssignmentOption permission in permissions)
            CheckboxListTile(
              value: selectedPermissionIds.contains(permission.id),
              onChanged: enabled
                  ? (bool? value) =>
                        onTogglePermission(permission.id, value ?? false)
                  : null,
              title: Text(permission.label),
              subtitle: permission.code == permission.label
                  ? null
                  : Text(
                      permission.code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              dense: true,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            ),
        ],
      ),
    );
  }
}
