import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_permission_assignment_picker.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

/// Read-only, searchable permission list grouped by module for detail views.
class AppPermissionGroupedView extends StatefulWidget {
  const AppPermissionGroupedView({
    required this.permissions,
    this.emptyTitle,
    this.emptyMessage,
    this.initiallyExpandAll = false,
    this.showSearch = true,
    super.key,
  });

  final List<AppPermissionAssignmentOption> permissions;
  final String? emptyTitle;
  final String? emptyMessage;
  final bool initiallyExpandAll;
  final bool showSearch;

  @override
  State<AppPermissionGroupedView> createState() =>
      _AppPermissionGroupedViewState();
}

class _AppPermissionGroupedViewState extends State<AppPermissionGroupedView> {
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
  void didUpdateWidget(covariant AppPermissionGroupedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.permissions != widget.permissions) {
      _expandedGroupKeys = _initialExpandedGroups();
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

  Set<String> _initialExpandedGroups() {
    final Map<String, List<AppPermissionAssignmentOption>> grouped = _groupAll(
      widget.permissions,
    );
    if (grouped.isEmpty) {
      return <String>{};
    }
    if (widget.initiallyExpandAll || grouped.length <= 4) {
      return grouped.keys.toSet();
    }
    final List<String> keys = grouped.keys.toList(growable: false)..sort();
    return <String>{keys.first};
  }

  Map<String, List<AppPermissionAssignmentOption>> _groupAll(
    List<AppPermissionAssignmentOption> permissions,
  ) {
    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        <String, List<AppPermissionAssignmentOption>>{};
    for (final AppPermissionAssignmentOption permission in permissions) {
      grouped
          .putIfAbsent(
            permission.modulePrefix,
            () => <AppPermissionAssignmentOption>[],
          )
          .add(permission);
    }
    for (final List<AppPermissionAssignmentOption> entries in grouped.values) {
      entries.sort(
        (AppPermissionAssignmentOption a, AppPermissionAssignmentOption b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
    }
    return grouped;
  }

  List<AppPermissionAssignmentOption> get _filteredPermissions {
    if (_searchQuery.isEmpty) {
      return widget.permissions;
    }
    return widget.permissions
        .where((AppPermissionAssignmentOption permission) {
          final String haystack =
              '${permission.label} ${permission.code} ${permission.groupLabel} ${permission.actionLabel}'
                  .toLowerCase();
          return haystack.contains(_searchQuery);
        })
        .toList(growable: false);
  }

  Map<String, List<AppPermissionAssignmentOption>> _groupedPermissions() {
    return _groupAll(_filteredPermissions);
  }

  void _toggleGroup(String groupKey) {
    setState(() {
      if (_expandedGroupKeys.contains(groupKey)) {
        _expandedGroupKeys.remove(groupKey);
      } else {
        _expandedGroupKeys.add(groupKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (widget.permissions.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
        child: Text(
          widget.emptyMessage ?? l10n.accessAdminRoleDetailNoPermissionsMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final Map<String, List<AppPermissionAssignmentOption>> grouped =
        _groupedPermissions();
    final List<String> groupKeys = grouped.keys.toList(growable: false)..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showSearch) ...<Widget>[
          AppTextField(
            controller: _searchController,
            labelText: l10n.hrPermissionAssignmentSearchLabel,
            prefixIcon: const Icon(Icons.search),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        if (groupKeys.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
            child: Text(
              l10n.hrPermissionAssignmentNoSearchResultsLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= AppBreakpoints.lg;
              if (!wide) {
                return Column(
                  children: <Widget>[
                    for (final String groupKey in groupKeys)
                      _PermissionGroupCard(
                        groupKey: groupKey,
                        permissions:
                            grouped[groupKey] ??
                            const <AppPermissionAssignmentOption>[],
                        expanded: _expandedGroupKeys.contains(groupKey),
                        onToggle: () => _toggleGroup(groupKey),
                      ),
                  ],
                );
              }

              final int splitIndex = (groupKeys.length / 2).ceil();
              final List<String> leftKeys = groupKeys.sublist(0, splitIndex);
              final List<String> rightKeys = groupKeys.sublist(splitIndex);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        for (final String groupKey in leftKeys)
                          _PermissionGroupCard(
                            groupKey: groupKey,
                            permissions:
                                grouped[groupKey] ??
                                const <AppPermissionAssignmentOption>[],
                            expanded: _expandedGroupKeys.contains(groupKey),
                            onToggle: () => _toggleGroup(groupKey),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        for (final String groupKey in rightKeys)
                          _PermissionGroupCard(
                            groupKey: groupKey,
                            permissions:
                                grouped[groupKey] ??
                                const <AppPermissionAssignmentOption>[],
                            expanded: _expandedGroupKeys.contains(groupKey),
                            onToggle: () => _toggleGroup(groupKey),
                          ),
                      ],
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

class _PermissionGroupCard extends StatelessWidget {
  const _PermissionGroupCard({
    required this.groupKey,
    required this.permissions,
    required this.expanded,
    required this.onToggle,
  });

  final String groupKey;
  final List<AppPermissionAssignmentOption> permissions;
  final bool expanded;
  final VoidCallback onToggle;

  static List<AppPermissionAssignmentOption> _uniquePermissions(
    List<AppPermissionAssignmentOption> permissions,
  ) {
    final Set<String> seen = <String>{};
    final List<AppPermissionAssignmentOption> unique =
        <AppPermissionAssignmentOption>[];
    for (final AppPermissionAssignmentOption permission in permissions) {
      final String code = permission.code.trim().toLowerCase();
      final String id = permission.id.trim().toLowerCase();
      final String key = code.isNotEmpty
          ? 'code:$code'
          : (id.isNotEmpty ? 'id:$id' : permission.label.toLowerCase());
      if (!seen.add(key)) {
        continue;
      }
      unique.add(permission);
    }
    return unique;
  }

  static String _chipLabel(
    AppPermissionAssignmentOption permission, {
    required List<AppPermissionAssignmentOption> permissions,
  }) {
    final String action = permission.actionLabel.trim();
    final int sameActionCount = permissions
        .where(
          (AppPermissionAssignmentOption other) =>
              other.actionLabel.trim().toLowerCase() == action.toLowerCase(),
        )
        .length;
    if (sameActionCount <= 1 || action.isEmpty) {
      return action.isEmpty ? permission.label : action;
    }
    // Disambiguate colliding action labels (e.g. two "Read" codes).
    final int separator = permission.code.indexOf(':');
    if (separator > 0 && separator + 1 < permission.code.length) {
      return permission.code.substring(separator + 1);
    }
    return permission.label;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (permissions.isEmpty) {
      return const SizedBox.shrink();
    }

    final String groupLabel = permissions.first.groupLabel;
    final List<AppPermissionAssignmentOption> uniquePermissions =
        _uniquePermissions(permissions);

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(theme.radius.sm),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      size: 18,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(groupLabel, style: theme.textTheme.titleSmall),
                        Text(
                          l10n.hrAccessPermissionCountLabel(
                            uniquePermissions.length,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md,
                0,
                theme.spacing.md,
                theme.spacing.md,
              ),
              child: Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final AppPermissionAssignmentOption permission
                      in uniquePermissions)
                    _PermissionActionChip(
                      permission: permission,
                      label: _chipLabel(
                        permission,
                        permissions: uniquePermissions,
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

class _PermissionActionChip extends StatelessWidget {
  const _PermissionActionChip({
    required this.permission,
    required this.label,
  });

  final AppPermissionAssignmentOption permission;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Tooltip(
      message: permission.code,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(theme.radius.sm),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle, size: 16, color: colors.primary),
            SizedBox(width: theme.spacing.xs),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
