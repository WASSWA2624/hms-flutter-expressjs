import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_list_table.dart';
import 'package:hosspi_hms/shared/components/app_list_table_export.dart';
import 'package:hosspi_hms/shared/components/app_role_assignment_picker.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Opens a searchable multi-select roles table and returns selected role ids.
Future<Set<String>?> showAppRoleSelectionTableDialog({
  required BuildContext context,
  required List<AppRoleAssignmentOption> roles,
  String? title,
  String? description,
  String? searchHint,
  String? confirmLabel,
  String? emptyTitle,
  String? emptyBody,
  String storageKey = 'shared.role_selection.table',
}) {
  return showAppDialog<Set<String>>(
    context: context,
    builder: (BuildContext dialogContext) => _AppRoleSelectionTableDialog(
      roles: roles,
      title: title,
      description: description,
      searchHint: searchHint,
      confirmLabel: confirmLabel,
      emptyTitle: emptyTitle,
      emptyBody: emptyBody,
      storageKey: storageKey,
    ),
  );
}

class _AppRoleSelectionTableDialog extends StatefulWidget {
  const _AppRoleSelectionTableDialog({
    required this.roles,
    required this.storageKey,
    this.title,
    this.description,
    this.searchHint,
    this.confirmLabel,
    this.emptyTitle,
    this.emptyBody,
  });

  final List<AppRoleAssignmentOption> roles;
  final String storageKey;
  final String? title;
  final String? description;
  final String? searchHint;
  final String? confirmLabel;
  final String? emptyTitle;
  final String? emptyBody;

  @override
  State<_AppRoleSelectionTableDialog> createState() =>
      _AppRoleSelectionTableDialogState();
}

class _AppRoleSelectionTableDialogState
    extends State<_AppRoleSelectionTableDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final AppListTableColumnVisibilityController<AppRoleAssignmentOption>
  _columnController =
      AppListTableColumnVisibilityController<AppRoleAssignmentOption>(
        storageKey: widget.storageKey,
      );
  final Set<String> _selectedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  void _toggle(AppRoleAssignmentOption role, {required bool selected}) {
    setState(() {
      if (selected) {
        _selectedIds.add(role.id);
      } else {
        _selectedIds.remove(role.id);
      }
    });
  }

  List<AppListTableColumn<AppRoleAssignmentOption>> _columns(
    AppLocalizations l10n,
  ) {
    final List<AppRoleAssignmentOption> rows = widget.roles;
    final bool allSelected =
        rows.isNotEmpty &&
        rows.every((AppRoleAssignmentOption row) => _selectedIds.contains(row.id));
    final bool noneSelected = rows.every(
      (AppRoleAssignmentOption row) => !_selectedIds.contains(row.id),
    );

    return <AppListTableColumn<AppRoleAssignmentOption>>[
      AppListTableColumn<AppRoleAssignmentOption>(
        id: 'select',
        label: l10n.hrSelectPositionColumnLabel,
        alwaysVisible: true,
        fixedWidth: 44,
        exportable: false,
        headerBuilder: (BuildContext context) {
          return Center(
            child: Checkbox(
              tristate: true,
              value: allSelected
                  ? true
                  : noneSelected
                  ? false
                  : null,
              onChanged: rows.isEmpty
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          for (final AppRoleAssignmentOption row in rows) {
                            _selectedIds.add(row.id);
                          }
                        } else {
                          for (final AppRoleAssignmentOption row in rows) {
                            _selectedIds.remove(row.id);
                          }
                        }
                      });
                    },
            ),
          );
        },
        cellBuilder: (BuildContext context, AppRoleAssignmentOption row) {
          final bool selected = _selectedIds.contains(row.id);
          return Center(
            child: Checkbox(
              value: selected,
              onChanged: (bool? value) =>
                  _toggle(row, selected: value == true),
            ),
          );
        },
      ),
      AppListTableColumn<AppRoleAssignmentOption>(
        id: 'role',
        label: l10n.hrRolePositionColumnLabel,
        alwaysVisible: true,
        cellBuilder: (_, AppRoleAssignmentOption item) => Text(item.label),
        sortComparator: (AppRoleAssignmentOption a, AppRoleAssignmentOption b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        exportValue: (AppRoleAssignmentOption item) => item.label,
      ),
      AppListTableColumn<AppRoleAssignmentOption>(
        id: 'role_id',
        label: l10n.hrRoleIdColumnLabel,
        cellBuilder: (_, AppRoleAssignmentOption item) => Text(item.id),
        sortComparator: (AppRoleAssignmentOption a, AppRoleAssignmentOption b) =>
            a.id.toLowerCase().compareTo(b.id.toLowerCase()),
        exportValue: (AppRoleAssignmentOption item) => item.id,
      ),
      if (rows.any((AppRoleAssignmentOption row) => row.permissionCount > 0))
        AppListTableColumn<AppRoleAssignmentOption>(
          id: 'permissions',
          label: l10n.hrAccessPanelPermissions,
          cellBuilder: (_, AppRoleAssignmentOption item) =>
              Text(l10n.hrAccessPermissionCountLabel(item.permissionCount)),
          sortComparator:
              (AppRoleAssignmentOption a, AppRoleAssignmentOption b) =>
                  a.permissionCount.compareTo(b.permissionCount),
          exportValue: (AppRoleAssignmentOption item) =>
              '${item.permissionCount}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.title ?? l10n.hrAddRoleDialogTitle;
    final String searchHint =
        widget.searchHint ?? l10n.hrStaffRolesSearchHint;
    final String confirmLabel = widget.confirmLabel ?? l10n.hrAddRoleAction;
    final String emptyTitle =
        widget.emptyTitle ?? l10n.hrNoRolesLabel;
    final String emptyBody =
        widget.emptyBody ?? l10n.hrStaffRolesEmptyBody;

    return AppDialog(
      title: Text(title),
      icon: const Icon(Icons.admin_panel_settings_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if ((widget.description ?? '').trim().isNotEmpty) ...<Widget>[
            Text(
              widget.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          AppListTable<AppRoleAssignmentOption>(
            items: widget.roles,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            columnVisibilityController: _columnController,
            columnVisibilityStorageKey: widget.storageKey,
            columnWidthStorageKey: '${widget.storageKey}.widths',
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            columnVisibilityTitle: l10n.commonTableSettingsTitle,
            columnVisibilityApplyLabel: l10n.opdApplyFiltersAction,
            columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
            columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
            exportLabel: l10n.commonTableExportActionLabel,
            exportDialogTitle: l10n.commonTableExportDialogTitle,
            exportCancelLabel: l10n.commonCancelActionLabel,
            exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
            exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
            exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
            exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
            exportSuccessMessage: l10n.commonTableExportSuccessMessage,
            exportFailureMessage: l10n.commonTableExportFailureMessage,
            exportConfig: AppListTableExportConfig<AppRoleAssignmentOption>(
              fileNameStem: 'selectable_roles',
              sheetName: title,
            ),
            onRowSelected: (AppRoleAssignmentOption row) {
              _toggle(row, selected: !_selectedIds.contains(row.id));
            },
            emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
              title: emptyTitle,
              body: emptyBody,
            ),
            search: AppListTableSearch<AppRoleAssignmentOption>(
              controller: _searchController,
              semanticLabel: searchHint,
              hintText: searchHint,
              matcher: (AppRoleAssignmentOption item, String query) {
                final String needle = query.trim().toLowerCase();
                if (needle.isEmpty) {
                  return true;
                }
                final String haystack =
                    '${item.label} ${item.id} ${item.description ?? ''} ${item.permissionCount}'
                        .toLowerCase();
                return haystack.contains(needle);
              },
            ),
            columns: _columns(l10n),
            mobileItemBuilder:
                (BuildContext context, AppRoleAssignmentOption item) {
              final bool selected = _selectedIds.contains(item.id);
              return AppListTableMobileItem(
                title: item.label,
                caption: item.id,
                leading: Checkbox(
                  value: selected,
                  onChanged: (bool? value) =>
                      _toggle(item, selected: value == true),
                ),
                meta: <AppListTableMobileMeta>[
                  if (item.permissionCount > 0)
                    AppListTableMobileMeta(
                      label: l10n.hrAccessPermissionCountLabel(
                        item.permissionCount,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: confirmLabel,
          leadingIcon: Icons.add,
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<String>.from(_selectedIds)),
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
