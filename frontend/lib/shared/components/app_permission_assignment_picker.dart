import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/permission_read_dependency.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';

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

  /// Action portion of [label] (e.g. "Read" from "Billing — Read").
  String get actionLabel {
    final int separator = label.indexOf(' — ');
    if (separator > 0 && separator + 3 < label.length) {
      return label.substring(separator + 3).trim();
    }
    final int codeSeparator = code.indexOf(':');
    if (codeSeparator > 0 && codeSeparator + 1 < code.length) {
      return code.substring(codeSeparator + 1);
    }
    return label;
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
      if (_searchQuery.isNotEmpty) {
        _expandedGroupKeys.addAll(_groupedPermissions().keys);
      }
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
    return widget.permissions.where(_matchesSearch).toList(growable: false);
  }

  List<AppPermissionAssignmentOption> get _scopePermissions {
    return _searchQuery.isEmpty ? widget.permissions : _filteredPermissions;
  }

  Map<String, List<AppPermissionAssignmentOption>> _groupedPermissions() {
    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        <String, List<AppPermissionAssignmentOption>>{};
    for (final AppPermissionAssignmentOption permission
        in _filteredPermissions) {
      grouped
          .putIfAbsent(
            _groupKey(permission),
            () => <AppPermissionAssignmentOption>[],
          )
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

  Map<String, String> get _idByCode {
    return <String, String>{
      for (final AppPermissionAssignmentOption permission in widget.permissions)
        permission.code: permission.id,
    };
  }

  Map<String, String> get _codeById {
    return <String, String>{
      for (final AppPermissionAssignmentOption permission in widget.permissions)
        permission.id: permission.code,
    };
  }

  Set<String> get _catalogCodes {
    return widget.permissions
        .map((AppPermissionAssignmentOption permission) => permission.code)
        .toSet();
  }

  Set<String> _selectionCodes(Set<String> ids) {
    final Map<String, String> codeById = _codeById;
    return ids
        .map((String id) => codeById[id])
        .whereType<String>()
        .toSet();
  }

  Set<String> _idsForCodes(Set<String> codes) {
    final Map<String, String> idByCode = _idByCode;
    return codes
        .map((String code) => idByCode[code])
        .whereType<String>()
        .toSet();
  }

  Set<String> _withRequiredReads(Set<String> ids) {
    final Set<String> codes = _selectionCodes(ids);
    final Set<String> expandedCodes = expandPermissionCodesWithRequiredReads(
      codes,
      catalogCodes: _catalogCodes,
    );
    return <String>{...ids, ..._idsForCodes(expandedCodes)};
  }

  void _togglePermission(String permissionId, bool selected) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    final String? code = _codeById[permissionId];
    if (selected) {
      next.add(permissionId);
      _updateSelection(_withRequiredReads(next));
      return;
    }

    if (code != null &&
        !canDeselectPermissionCode(
          code,
          selectedCodes: _selectionCodes(next),
          catalogCodes: _catalogCodes,
        )) {
      return;
    }
    next.remove(permissionId);
    _updateSelection(next);
  }

  void _selectInScope() {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    for (final AppPermissionAssignmentOption permission in _scopePermissions) {
      next.add(permission.id);
    }
    _updateSelection(_withRequiredReads(next));
  }

  void _clearInScope() {
    if (_searchQuery.isEmpty) {
      _updateSelection(<String>{});
      return;
    }

    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    for (final AppPermissionAssignmentOption permission in _scopePermissions) {
      if (!canDeselectPermissionCode(
        permission.code,
        selectedCodes: _selectionCodes(next),
        catalogCodes: _catalogCodes,
      )) {
        continue;
      }
      next.remove(permission.id);
    }
    _updateSelection(next);
  }

  void _selectGroup(List<AppPermissionAssignmentOption> groupPermissions) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    for (final AppPermissionAssignmentOption permission in groupPermissions) {
      next.add(permission.id);
    }
    _updateSelection(_withRequiredReads(next));
  }

  void _clearGroup(List<AppPermissionAssignmentOption> groupPermissions) {
    final Set<String> next = Set<String>.from(widget.selectedPermissionIds);
    // Clear non-read actions first so reads become free to remove.
    final List<AppPermissionAssignmentOption> ordered =
        List<AppPermissionAssignmentOption>.from(groupPermissions)..sort((
          AppPermissionAssignmentOption a,
          AppPermissionAssignmentOption b,
        ) {
          final bool aRead = a.code.endsWith(':read');
          final bool bRead = b.code.endsWith(':read');
          if (aRead == bRead) {
            return 0;
          }
          return aRead ? 1 : -1;
        });
    for (final AppPermissionAssignmentOption permission in ordered) {
      if (!canDeselectPermissionCode(
        permission.code,
        selectedCodes: _selectionCodes(next),
        catalogCodes: _catalogCodes,
      )) {
        continue;
      }
      next.remove(permission.id);
    }
    _updateSelection(next);
  }

  void _toggleGroup(List<AppPermissionAssignmentOption> groupPermissions) {
    if (_selectedCountInGroup(groupPermissions) == groupPermissions.length) {
      _clearGroup(groupPermissions);
    } else {
      _selectGroup(groupPermissions);
    }
  }

  int _selectedCountInGroup(
    List<AppPermissionAssignmentOption> groupPermissions,
  ) {
    return groupPermissions
        .where(
          (AppPermissionAssignmentOption permission) =>
              widget.selectedPermissionIds.contains(permission.id),
        )
        .length;
  }

  int _selectedCountInScope(
    List<AppPermissionAssignmentOption> scopePermissions,
  ) {
    return scopePermissions
        .where(
          (AppPermissionAssignmentOption permission) =>
              widget.selectedPermissionIds.contains(permission.id),
        )
        .length;
  }

  void _handleExpansionChanged(String groupKey, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedGroupKeys.add(groupKey);
      } else {
        _expandedGroupKeys.remove(groupKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int selectedCount = widget.selectedPermissionIds.length;
    final int totalCount = widget.permissions.length;
    final bool canChange = widget.enabled;
    final bool isFiltering = _searchQuery.isNotEmpty;
    final List<AppPermissionAssignmentOption> scopePermissions =
        _scopePermissions;
    final int selectedInScope = _selectedCountInScope(scopePermissions);
    final int scopeTotal = scopePermissions.length;
    final bool allInScopeSelected =
        scopeTotal > 0 && selectedInScope == scopeTotal;
    final bool noneInScopeSelected = selectedInScope == 0;
    final bool noneSelected = selectedCount == 0;

    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        _groupedPermissions();
    final List<String> groupKeys = grouped.keys.toList(growable: false)..sort();

    final Widget selectAllTile = CheckboxListTile(
      key: const ValueKey<String>('permission-select-all'),
      value: allInScopeSelected
          ? true
          : noneInScopeSelected
          ? false
          : null,
      tristate: true,
      enabled: canChange && scopeTotal > 0,
      onChanged: canChange && scopeTotal > 0
          ? (bool? value) {
              if (value == false) {
                _clearInScope();
              } else {
                _selectInScope();
              }
            }
          : null,
      title: Text(
        isFiltering
            ? l10n.hrPermissionAssignmentSelectAllMatchingAction
            : l10n.hrAccessSelectAllPermissionsAction,
      ),
      subtitle: Text(
        isFiltering
            ? l10n.hrPermissionAssignmentSelectedCount(
                selectedInScope,
                scopeTotal,
              )
            : l10n.hrPermissionAssignmentSelectedCount(
                selectedCount,
                totalCount,
              ),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );

    final Widget clearAllTile = CheckboxListTile(
      value: noneInScopeSelected,
      enabled: canChange && !noneInScopeSelected,
      onChanged: canChange && !noneInScopeSelected
          ? (_) => _clearInScope()
          : null,
      title: Text(
        isFiltering
            ? l10n.hrPermissionAssignmentClearMatchingAction
            : l10n.hrAccessClearPermissionsAction,
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );

    return AppFormSection(
      children: <Widget>[
        AppTextField(
          controller: _searchController,
          enabled: canChange,
          labelText: l10n.hrPermissionAssignmentSearchLabel,
          prefixIcon: const Icon(Icons.search),
        ),
        AppResponsiveFieldRow.two(
          breakpoint: AppBreakpoints.md,
          gap: AppResponsiveFieldRowGap.standard,
          left: selectAllTile,
          right: clearAllTile,
        ),
        if (noneSelected)
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
                  onExpansionChanged: _handleExpansionChanged,
                  onTogglePermission: _togglePermission,
                  onToggleGroup: _toggleGroup,
                  selectedCountInGroup: _selectedCountInGroup,
                  canDeselectPermission: (AppPermissionAssignmentOption permission) {
                    return canDeselectPermissionCode(
                      permission.code,
                      selectedCodes: _selectionCodes(
                        widget.selectedPermissionIds,
                      ),
                      catalogCodes: _catalogCodes,
                    );
                  },
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
                      onExpansionChanged: _handleExpansionChanged,
                      onTogglePermission: _togglePermission,
                      onToggleGroup: _toggleGroup,
                      selectedCountInGroup: _selectedCountInGroup,
                      canDeselectPermission:
                          (AppPermissionAssignmentOption permission) {
                        return canDeselectPermissionCode(
                          permission.code,
                          selectedCodes: _selectionCodes(
                            widget.selectedPermissionIds,
                          ),
                          catalogCodes: _catalogCodes,
                        );
                      },
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
                      onExpansionChanged: _handleExpansionChanged,
                      onTogglePermission: _togglePermission,
                      onToggleGroup: _toggleGroup,
                      selectedCountInGroup: _selectedCountInGroup,
                      canDeselectPermission:
                          (AppPermissionAssignmentOption permission) {
                        return canDeselectPermissionCode(
                          permission.code,
                          selectedCodes: _selectionCodes(
                            widget.selectedPermissionIds,
                          ),
                          catalogCodes: _catalogCodes,
                        );
                      },
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
    required this.onToggleGroup,
    required this.selectedCountInGroup,
    required this.canDeselectPermission,
  });

  final List<String> groupKeys;
  final Map<String, List<AppPermissionAssignmentOption>> grouped;
  final Set<String> expandedGroupKeys;
  final Set<String> selectedPermissionIds;
  final bool enabled;
  final void Function(String groupKey, bool expanded) onExpansionChanged;
  final void Function(String permissionId, bool selected) onTogglePermission;
  final void Function(List<AppPermissionAssignmentOption> permissions)
  onToggleGroup;
  final int Function(List<AppPermissionAssignmentOption> permissions)
  selectedCountInGroup;
  final bool Function(AppPermissionAssignmentOption permission)
  canDeselectPermission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String groupKey in groupKeys)
          _PermissionGroupSection(
            groupKey: groupKey,
            permissions:
                grouped[groupKey] ?? const <AppPermissionAssignmentOption>[],
            expanded: expandedGroupKeys.contains(groupKey),
            selectedPermissionIds: selectedPermissionIds,
            enabled: enabled,
            onExpansionChanged: (bool expanded) =>
                onExpansionChanged(groupKey, expanded),
            onTogglePermission: onTogglePermission,
            onToggleGroup: onToggleGroup,
            selectedCountInGroup: selectedCountInGroup,
            canDeselectPermission: canDeselectPermission,
          ),
        SizedBox(height: theme.spacing.xs),
      ],
    );
  }
}

class _PermissionGroupSection extends StatelessWidget {
  const _PermissionGroupSection({
    required this.groupKey,
    required this.permissions,
    required this.expanded,
    required this.selectedPermissionIds,
    required this.enabled,
    required this.onExpansionChanged,
    required this.onTogglePermission,
    required this.onToggleGroup,
    required this.selectedCountInGroup,
    required this.canDeselectPermission,
  });

  final String groupKey;
  final List<AppPermissionAssignmentOption> permissions;
  final bool expanded;
  final Set<String> selectedPermissionIds;
  final bool enabled;
  final ValueChanged<bool> onExpansionChanged;
  final void Function(String permissionId, bool selected) onTogglePermission;
  final void Function(List<AppPermissionAssignmentOption> permissions)
  onToggleGroup;
  final int Function(List<AppPermissionAssignmentOption> permissions)
  selectedCountInGroup;
  final bool Function(AppPermissionAssignmentOption permission)
  canDeselectPermission;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.xs,
              theme.spacing.xs,
              theme.spacing.sm,
              theme.spacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  key: ValueKey<String>('group-$groupKey'),
                  tristate: true,
                  value: allSelected
                      ? true
                      : noneSelected
                      ? false
                      : null,
                  onChanged: enabled ? (_) => onToggleGroup(permissions) : null,
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                    onTap: () => onExpansionChanged(!expanded),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.xs,
                        vertical: theme.spacing.xs,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  groupLabel,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  l10n.hrPermissionAssignmentSelectedCount(
                                    selectedInGroup,
                                    permissions.length,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.sm,
                0,
                theme.spacing.md,
                theme.spacing.sm,
              ),
              child: Column(
                children: <Widget>[
                  for (final AppPermissionAssignmentOption permission
                      in permissions)
                    CheckboxListTile(
                      key: ValueKey<String>('permission-${permission.id}'),
                      value: selectedPermissionIds.contains(permission.id),
                      onChanged: enabled
                          ? (bool? value) {
                              final bool nextSelected = value ?? false;
                              if (!nextSelected &&
                                  !canDeselectPermission(permission)) {
                                return;
                              }
                              onTogglePermission(permission.id, nextSelected);
                            }
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.sm,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
