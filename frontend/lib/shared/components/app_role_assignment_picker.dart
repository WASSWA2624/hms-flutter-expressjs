import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
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

enum _RoleLogicalGroup {
  administration,
  clinical,
  diagnostics,
  frontOffice,
  operations,
  custom,
}

/// Role picker: searchable checkbox grid with expandable permission packs.
///
/// Roles expand with the parent page by default (no nested list scroll).
/// Layout is 1 column on mobile, 2 on tablet, and 3 on desktop widths.
class AppRoleAssignmentPicker extends StatefulWidget {
  const AppRoleAssignmentPicker({
    required this.roles,
    required this.selectedRoleIds,
    required this.onSelectionChanged,
    this.loadRolePermissions,
    this.emptyWarning,
    /// When null, roles expand with the parent (no nested scroll).
    /// When set, the role list is capped and scrolls internally.
    this.maxListHeight,
    super.key,
  });

  final List<AppRoleAssignmentOption> roles;
  final Set<String> selectedRoleIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final AppRolePermissionsLoader? loadRolePermissions;
  final String? emptyWarning;
  final double? maxListHeight;

  @override
  State<AppRoleAssignmentPicker> createState() =>
      _AppRoleAssignmentPickerState();
}

class _AppRoleAssignmentPickerState extends State<AppRoleAssignmentPicker> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Set<String>> _permissionsByRole = <String, Set<String>>{};
  final Set<String> _loadingRoleIds = <String>{};
  final Set<String> _expandedRoleIds = <String>{};
  final Set<String> _previewPermissions = <String>{};
  bool _loadingPreview = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    unawaited(_refreshPermissionPreview());
  }

  @override
  void didUpdateWidget(covariant AppRoleAssignmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoleIds != widget.selectedRoleIds) {
      unawaited(_refreshPermissionPreview());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppRoleAssignmentOption> get _filteredRoles {
    final String query = _searchQuery;
    final List<AppRoleAssignmentOption> roles = widget.roles;
    if (query.isEmpty) {
      return roles;
    }
    return roles
        .where((AppRoleAssignmentOption role) {
          final String haystack =
              '${role.label} ${role.description ?? ''} ${role.permissionCount}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Map<_RoleLogicalGroup, List<AppRoleAssignmentOption>> _groupedRoles(
    List<AppRoleAssignmentOption> roles,
  ) {
    final Map<_RoleLogicalGroup, List<AppRoleAssignmentOption>> grouped =
        <_RoleLogicalGroup, List<AppRoleAssignmentOption>>{
          for (final _RoleLogicalGroup group in _RoleLogicalGroup.values)
            group: <AppRoleAssignmentOption>[],
        };

    for (final AppRoleAssignmentOption role in roles) {
      grouped[_classifyRole(role)]!.add(role);
    }

    for (final List<AppRoleAssignmentOption> groupRoles in grouped.values) {
      groupRoles.sort(
        (AppRoleAssignmentOption a, AppRoleAssignmentOption b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
    }

    return grouped;
  }

  void _toggleRole(String roleId, bool? selected) {
    final Set<String> next = Set<String>.from(widget.selectedRoleIds);
    if (selected == true) {
      next.add(roleId);
    } else {
      next.remove(roleId);
    }
    widget.onSelectionChanged(next);
    unawaited(_refreshPermissionPreview());
  }

  Future<void> _ensureRolePermissionsLoaded(String roleId) async {
    final AppRolePermissionsLoader? loader = widget.loadRolePermissions;
    if (loader == null ||
        _permissionsByRole.containsKey(roleId) ||
        _loadingRoleIds.contains(roleId)) {
      return;
    }
    setState(() => _loadingRoleIds.add(roleId));
    final Set<String> permissions = await loader(roleId);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingRoleIds.remove(roleId);
      _permissionsByRole[roleId] = permissions;
    });
  }

  Future<void> _onExpansionChanged(String roleId, bool expanded) async {
    setState(() {
      if (expanded) {
        _expandedRoleIds.add(roleId);
      } else {
        _expandedRoleIds.remove(roleId);
      }
    });
    if (expanded) {
      await _ensureRolePermissionsLoaded(roleId);
    }
  }

  Future<void> _refreshPermissionPreview() async {
    final AppRolePermissionsLoader? loader = widget.loadRolePermissions;
    if (loader == null || widget.selectedRoleIds.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewPermissions.clear();
        _loadingPreview = false;
      });
      return;
    }

    setState(() => _loadingPreview = true);
    final Set<String> permissions = <String>{};
    for (final String roleId in widget.selectedRoleIds) {
      if (!_permissionsByRole.containsKey(roleId)) {
        await _ensureRolePermissionsLoaded(roleId);
      }
      permissions.addAll(_permissionsByRole[roleId] ?? <String>{});
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _previewPermissions
        ..clear()
        ..addAll(permissions);
      _loadingPreview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<AppRoleAssignmentOption> filtered = _filteredRoles;

    return AppFormSection(
      children: <Widget>[
        if (widget.emptyWarning != null && widget.selectedRoleIds.isEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.warning_amber_outlined,
                color: colors.error,
                size: 20,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  widget.emptyWarning!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ],
          ),
        AppTextField(
          controller: _searchController,
          labelText: l10n.hrRoleAssignmentSearchLabel,
          prefixIcon: const Icon(Icons.search),
          textInputAction: TextInputAction.search,
        ),
        SizedBox(height: theme.spacing.sm),
        Text(
          l10n.hrPermissionAssignmentSelectedCount(
            widget.selectedRoleIds.length,
            widget.roles.length,
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        if (widget.roles.isEmpty)
          Text(
            l10n.hrRoleAssignmentEmptySelectedLabel,
            style: theme.textTheme.bodySmall,
          )
        else if (filtered.isEmpty)
          Text(
            l10n.accessAdminEmptyBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          )
        else
          _buildRoleList(
            l10n: l10n,
            theme: theme,
            colors: colors,
            filtered: filtered,
          ),
        SizedBox(height: theme.spacing.md),
        Text(
          l10n.hrEffectivePermissionsTitle,
          style: theme.textTheme.titleSmall,
        ),
        SizedBox(height: theme.spacing.xs),
        if (_loadingPreview)
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
                .take(48)
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

  Widget _buildRoleList({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colors,
    required List<AppRoleAssignmentOption> filtered,
  }) {
    final Map<_RoleLogicalGroup, List<AppRoleAssignmentOption>> grouped =
        _groupedRoles(filtered);

    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _columnCount(constraints.maxWidth);
        final double gap = theme.spacing.sm;
        final double itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final _RoleLogicalGroup group in _RoleLogicalGroup.values)
              if ((grouped[group] ?? const <AppRoleAssignmentOption>[])
                  .isNotEmpty) ...<Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    top: theme.spacing.sm,
                    bottom: theme.spacing.xs,
                  ),
                  child: Text(
                    _groupLabel(l10n, group),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: grouped[group]!
                      .map(
                        (AppRoleAssignmentOption role) => SizedBox(
                          width: itemWidth,
                          child: _buildRoleTile(
                            l10n: l10n,
                            theme: theme,
                            colors: colors,
                            role: role,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
          ],
        );
      },
    );

    final double? maxHeight = widget.maxListHeight;
    if (maxHeight == null) {
      return content;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(child: content),
    );
  }

  Widget _buildRoleTile({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colors,
    required AppRoleAssignmentOption role,
  }) {
    final bool selected = widget.selectedRoleIds.contains(role.id);
    final bool expanded = _expandedRoleIds.contains(role.id);
    final bool loadingPermissions = _loadingRoleIds.contains(role.id);
    final Set<String> permissions =
        _permissionsByRole[role.id] ?? const <String>{};

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.35)
          : colors.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: 0.45)
              : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('role-browse-${role.id}'),
          initiallyExpanded: expanded,
          tilePadding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          childrenPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          onExpansionChanged: (bool value) {
            unawaited(_onExpansionChanged(role.id, value));
          },
          leading: Checkbox(
            value: selected,
            visualDensity: VisualDensity.compact,
            onChanged: (bool? value) => _toggleRole(role.id, value),
          ),
          title: Text(
            role.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            l10n.hrAccessPermissionCountLabel(
              role.permissionCount > 0
                  ? role.permissionCount
                  : permissions.length,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (role.isSystemCritical)
                Padding(
                  padding: EdgeInsets.only(right: theme.spacing.xs),
                  child: Chip(
                    label: Text(l10n.hrAccessSystemCriticalRoleBadge),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md,
                0,
                theme.spacing.md,
                theme.spacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: loadingPermissions
                    ? const LinearProgressIndicator(minHeight: 2)
                    : permissions.isEmpty
                    ? Text(
                        l10n.hrStaffOnboardingPermissionsPreviewEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : Wrap(
                        spacing: theme.spacing.xs,
                        runSpacing: theme.spacing.xs,
                        children: permissions
                            .map(
                              (String permission) => Chip(
                                avatar: Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                                label: Text(
                                  l10n.permissionCatalogLabelForCode(
                                    permission,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                                labelStyle: theme.textTheme.labelSmall,
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _columnCount(double maxWidth) {
  if (maxWidth >= AppBreakpoints.lg) {
    return 3;
  }
  if (maxWidth >= AppBreakpoints.md) {
    return 2;
  }
  return 1;
}

_RoleLogicalGroup _classifyRole(AppRoleAssignmentOption role) {
  final String haystack =
      '${role.label} ${role.description ?? ''}'.toUpperCase();
  final String normalized = haystack.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

  if (_containsAny(normalized, const <String>[
    'SUPER_ADMIN',
    'TENANT_ADMIN',
    'FACILITY_ADMIN',
    'SYSTEM_ADMIN',
  ])) {
    return _RoleLogicalGroup.administration;
  }

  if (_containsAny(normalized, const <String>[
    'LAB_TECH',
    'LABORATORY',
    'RADIOLOGY',
    'PHARMAC',
    'IMAGING',
  ])) {
    return _RoleLogicalGroup.diagnostics;
  }

  if (_containsAny(normalized, const <String>[
    'DOCTOR',
    'PHYSICIAN',
    'NURSE',
    'CLINICAL',
    'WARD_MANAGER',
    'UNIT_MANAGER',
    'ICU_MANAGER',
    'THEATRE_MANAGER',
    'THEATER_MANAGER',
    'PATIENT',
  ])) {
    return _RoleLogicalGroup.clinical;
  }

  if (_containsAny(normalized, const <String>[
    'RECEPTION',
    'BILLING',
    'FRONT_DESK',
    'CASHIER',
  ])) {
    return _RoleLogicalGroup.frontOffice;
  }

  if (_containsAny(normalized, const <String>[
    'OPERATION',
    'HUMAN_RESOURCE',
    '_HR_',
    'HR_',
    '_HR',
    'BIOMED',
    'HOUSE_KEEP',
    'HOUSEKEEP',
    'AMBULANCE',
    'MORTUARY',
  ])) {
    return _RoleLogicalGroup.operations;
  }

  // Exact / boundary HR match without swallowing other words.
  if (normalized == 'HR' ||
      normalized.startsWith('HR_') ||
      normalized.endsWith('_HR')) {
    return _RoleLogicalGroup.operations;
  }

  return _RoleLogicalGroup.custom;
}

bool _containsAny(String haystack, List<String> tokens) {
  for (final String token in tokens) {
    if (haystack.contains(token)) {
      return true;
    }
  }
  return false;
}

String _groupLabel(AppLocalizations l10n, _RoleLogicalGroup group) {
  return switch (group) {
    _RoleLogicalGroup.administration =>
      l10n.hrRoleAssignmentGroupAdministrationLabel,
    _RoleLogicalGroup.clinical => l10n.hrRoleAssignmentGroupClinicalLabel,
    _RoleLogicalGroup.diagnostics =>
      l10n.hrRoleAssignmentGroupDiagnosticsLabel,
    _RoleLogicalGroup.frontOffice =>
      l10n.hrRoleAssignmentGroupFrontOfficeLabel,
    _RoleLogicalGroup.operations => l10n.hrRoleAssignmentGroupOperationsLabel,
    _RoleLogicalGroup.custom => l10n.hrRoleAssignmentGroupCustomLabel,
  };
}
