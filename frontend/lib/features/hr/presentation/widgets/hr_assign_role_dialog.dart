import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Staff-detail roles manager: table of assigned roles + nested add/edit form.
Future<void> showHrAssignRoleDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffDetail detail,
) async {
  if (!HrHumanResourcesAtomPermissions.assignRole.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  final String userId = (detail.profile.userId ?? detail.profile.userDisplayId ?? '')
      .trim();
  if (userId.isEmpty) {
    showHrMutationSnackBar(context, AppFailure.validation());
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _HrAssignRolesDialog(detail: detail),
  );
}

class _HrAssignRolesDialog extends ConsumerStatefulWidget {
  const _HrAssignRolesDialog({required this.detail});

  final HrStaffDetail detail;

  @override
  ConsumerState<_HrAssignRolesDialog> createState() =>
      _HrAssignRolesDialogState();
}

class _HrAssignRolesDialogState extends ConsumerState<_HrAssignRolesDialog> {
  static const String _facilityFilterKey = 'facility';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrUserRole> _columnController =
      AppListTableColumnVisibilityController<HrUserRole>(
        storageKey: 'hr.assign_roles.table',
      );

  late List<HrUserRole> _roles;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  bool _busy = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _roles = List<HrUserRole>.from(
      widget.detail.accessSummary?.userRoles ?? const <HrUserRole>[],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadRoles());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  Set<String> get _usedRoleIds => _roles
      .map((HrUserRole role) => (role.roleId ?? '').trim())
      .where((String id) => id.isNotEmpty)
      .toSet();

  Future<void> _reloadRoles() async {
    final String userId =
        (widget.detail.profile.userId ?? widget.detail.profile.userDisplayId ?? '')
            .trim();
    if (userId.isEmpty) {
      return;
    }
    setState(() => _loading = true);
    final Result<List<HrUserRole>> result = await ref
        .read(hrRepositoryProvider)
        .listUserRoles(
          userId: userId,
          tenantId: widget.detail.profile.tenantId,
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<HrUserRole> roles) {
        setState(() {
          _roles = roles;
          _loading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() => _loading = false);
        showHrMutationSnackBar(context, failure);
      },
    );
  }

  Future<void> _openRoleForm({HrUserRole? editing}) async {
    if (_busy) {
      return;
    }
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    final List<HrOption> catalog =
        state?.referenceData.roles ?? const <HrOption>[];
    final List<HrOption> facilities =
        state?.referenceData.facilities ?? const <HrOption>[];

    final _HrRoleFormResult? result = await showAppDialog<_HrRoleFormResult>(
      context: context,
      builder: (BuildContext dialogContext) => _HrRoleFormDialog(
        catalog: catalog,
        facilities: facilities,
        usedRoleIds: _usedRoleIds,
        editing: editing,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    AppFailure? failure;
    if (editing != null) {
      final String previousRoleId = (editing.roleId ?? '').trim();
      final String previousFacility = (editing.facilityId ?? '').trim();
      final bool unchanged =
          previousRoleId == result.roleId &&
          previousFacility == (result.facilityId ?? '').trim();
      if (!unchanged) {
        failure = await controller.revokeUserRole(editing);
        failure ??= await controller.assignUserRole(
          roleId: result.roleId,
          facilityId: result.facilityId,
        );
      }
    } else {
      failure = await controller.assignUserRole(
        roleId: result.roleId,
        facilityId: result.facilityId,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (failure != null) {
      showHrMutationSnackBar(context, failure);
      return;
    }
    showHrMutationSnackBar(context, null);
    await _reloadRoles();
  }

  Future<void> _deleteRole(HrUserRole role) async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String label = l10n.hrReferenceRoleLabel(
      role.roleName,
      fallback: role.roleName ?? role.roleId,
    );
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.hrRemoveStaffRoleTitle,
        body: l10n.hrRemoveStaffRoleBody(label),
        highlightedText: label,
        submitLabel: l10n.commonDeleteActionLabel,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async => null,
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final AppFailure? failure = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .revokeUserRole(role);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (failure != null) {
      showHrMutationSnackBar(context, failure);
      return;
    }
    showHrMutationSnackBar(context, null);
    await _reloadRoles();
  }

  bool _matchesFilters(HrUserRole role) {
    final String? facility = _filterValue.option(_facilityFilterKey);
    if (facility != null && facility.isNotEmpty) {
      final String roleFacility =
          (role.facilityId ?? role.facilityDisplayId ?? '').trim();
      if (roleFacility != facility) {
        return false;
      }
    }
    return true;
  }

  List<HrUserRole> get _visibleRoles =>
      _roles.where(_matchesFilters).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canWrite = HrHumanResourcesAtomPermissions.assignRole.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    final List<HrOption> facilities =
        state?.referenceData.facilities ?? const <HrOption>[];

    return AppDialog(
      title: Text(l10n.hrAssignRoleDialogTitle),
      icon: const Icon(Icons.admin_panel_settings_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 980,
      content: AppListTable<HrUserRole>(
        items: _visibleRoles,
        isLoading: _loading || _busy,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: _columnController,
        columnVisibilityStorageKey: 'hr.assign_roles.table',
        columnWidthStorageKey: 'hr.assign_roles.table.widths',
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
        exportConfig: AppListTableExportConfig<HrUserRole>(
          fileNameStem: 'staff_roles',
          sheetName: l10n.hrAssignRoleDialogTitle,
        ),
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.hrNoRolesLabel,
          body: l10n.hrStaffRolesEmptyBody,
        ),
        search: AppListTableSearch<HrUserRole>(
          controller: _searchController,
          semanticLabel: l10n.hrStaffRolesSearchHint,
          hintText: l10n.hrStaffRolesSearchHint,
          matcher: (HrUserRole item, String query) {
            final String needle = query.trim().toLowerCase();
            if (needle.isEmpty) {
              return true;
            }
            final String name = l10n
                .hrReferenceRoleLabel(
                  item.roleName,
                  fallback: item.roleName ?? item.roleId,
                )
                .toLowerCase();
            return name.contains(needle) ||
                (item.roleId ?? '').toLowerCase().contains(needle) ||
                (item.facilityName ?? '').toLowerCase().contains(needle) ||
                (item.facilityDisplayId ?? '').toLowerCase().contains(needle);
          },
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
          advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.hrClearFiltersAction,
          allFieldsLabel: l10n.opdAllFieldsFilterLabel,
          filterGroups: <AppSearchBarFilterGroup>[
            if (facilities.isNotEmpty)
              AppSearchBarFilterGroup(
                key: _facilityFilterKey,
                label: l10n.hrRosterOverviewFacilityLabel,
                allLabel: l10n.opdAllFieldsFilterLabel,
                choices: facilities
                    .map(
                      (HrOption option) => AppSearchBarFilterChoice(
                        value: option.value,
                        label: option.label,
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
          filterValue: _filterValue,
          hasActiveFilters:
              (_filterValue.option(_facilityFilterKey) ?? '').isNotEmpty,
          onFilterChanged: (AppSearchBarFilterValue value) {
            setState(() => _filterValue = value);
          },
          trailingActions: <AppSearchBarAction>[
            if (canWrite)
              AppSearchBarAction(
                label: l10n.hrAddRoleAction,
                icon: Icons.add_outlined,
                enabled: !_busy && !_loading,
                onPressed: () => unawaited(_openRoleForm()),
              ),
          ],
        ),
        columns: <AppListTableColumn<HrUserRole>>[
          AppListTableColumn<HrUserRole>(
            id: 'role',
            label: l10n.hrRolePositionColumnLabel,
            alwaysVisible: true,
            cellBuilder: (_, HrUserRole item) => Text(
              l10n.hrReferenceRoleLabel(
                item.roleName,
                fallback: item.roleName ?? item.roleId,
              ),
            ),
            sortComparator: (HrUserRole a, HrUserRole b) =>
                (a.roleName ?? a.roleId ?? '').compareTo(
                  b.roleName ?? b.roleId ?? '',
                ),
            exportValue: (HrUserRole item) => l10n.hrReferenceRoleLabel(
              item.roleName,
              fallback: item.roleName ?? item.roleId,
            ),
          ),
          AppListTableColumn<HrUserRole>(
            id: 'role_id',
            label: l10n.hrRoleIdColumnLabel,
            cellBuilder: (_, HrUserRole item) =>
                Text((item.roleId ?? item.effectiveId).trim().isEmpty
                    ? '—'
                    : (item.roleId ?? item.effectiveId)),
            exportValue: (HrUserRole item) => item.roleId ?? item.effectiveId,
          ),
          AppListTableColumn<HrUserRole>(
            id: 'facility',
            label: l10n.hrRosterOverviewFacilityLabel,
            cellBuilder: (_, HrUserRole item) => Text(
              (item.facilityName ?? item.facilityDisplayId ?? '')
                      .trim()
                      .isEmpty
                  ? l10n.hrRoleFacilityAllLabel
                  : (item.facilityName ?? item.facilityDisplayId)!,
            ),
            exportValue: (HrUserRole item) =>
                item.facilityName ?? item.facilityDisplayId ?? '',
          ),
          AppListTableColumn<HrUserRole>(
            id: 'actions',
            label: l10n.hrPositionsActionsColumnLabel,
            alwaysVisible: true,
            preferredWidth: 200,
            cellBuilder: (BuildContext context, HrUserRole item) {
              if (!canWrite) {
                return const SizedBox.shrink();
              }
              final double gap = theme.spacing.xs;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AppButton.tertiary(
                    leadingIcon: Icons.edit_outlined,
                    label: l10n.commonEditActionLabel,
                    tooltip: l10n.commonEditActionLabel,
                    dense: true,
                    enabled: !_busy,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_openRoleForm(editing: item)),
                  ),
                  AppButton.tertiary(
                    leadingIcon: Icons.delete_outline,
                    label: l10n.commonDeleteActionLabel,
                    tooltip: l10n.commonDeleteActionLabel,
                    dense: true,
                    color: theme.colorScheme.error,
                    enabled: !_busy,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_deleteRole(item)),
                  ),
                ],
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, HrUserRole item) {
          return AppListTableMobileItem(
            title: l10n.hrReferenceRoleLabel(
              item.roleName,
              fallback: item.roleName ?? item.roleId,
            ),
            caption: item.facilityName ??
                item.facilityDisplayId ??
                l10n.hrRoleFacilityAllLabel,
            trailing: canWrite
                ? IconButton(
                    tooltip: l10n.commonEditActionLabel,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_openRoleForm(editing: item)),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          );
        },
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _HrRoleFormResult {
  const _HrRoleFormResult({required this.roleId, this.facilityId});

  final String roleId;
  final String? facilityId;
}

class _HrRoleFormDialog extends StatefulWidget {
  const _HrRoleFormDialog({
    required this.catalog,
    required this.facilities,
    required this.usedRoleIds,
    this.editing,
  });

  final List<HrOption> catalog;
  final List<HrOption> facilities;
  final Set<String> usedRoleIds;
  final HrUserRole? editing;

  @override
  State<_HrRoleFormDialog> createState() => _HrRoleFormDialogState();
}

class _HrRoleFormDialogState extends State<_HrRoleFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _roleId;
  String? _facilityId;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final HrUserRole? editing = widget.editing;
    if (editing != null) {
      _roleId = editing.roleId;
      _facilityId = editing.facilityId ?? editing.facilityDisplayId;
    }
  }

  List<AppSelectOption<String>> _roleOptions(AppLocalizations l10n) {
    return <AppSelectOption<String>>[
      for (final HrOption option in widget.catalog)
        if (option.value == _roleId ||
            !widget.usedRoleIds.contains(option.value))
          AppSelectOption<String>(
            value: option.value,
            label: l10n.hrLocalizedOptionLabel(option),
          ),
    ];
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? roleId = _roleId?.trim();
    if (roleId == null || roleId.isEmpty) {
      return;
    }
    if (widget.usedRoleIds.contains(roleId) &&
        widget.editing?.roleId != roleId) {
      return;
    }
    Navigator.of(context).pop(
      _HrRoleFormResult(
        roleId: roleId,
        facilityId: (_facilityId ?? '').trim().isEmpty ? null : _facilityId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<AppSelectOption<String>> roleOptions = _roleOptions(l10n);

    return AppDialog(
      title: Text(
        _isEdit ? l10n.hrEditRoleDialogTitle : l10n.hrAddRoleDialogTitle,
      ),
      icon: const Icon(Icons.admin_panel_settings_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 640,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          description: l10n.hrAddRoleFormHint,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final double gap = theme.spacing.md;
                final Widget roleField = AppSelectField<String>.searchable(
                  value: _roleId,
                  labelText: l10n.hrRolePositionColumnLabel,
                  isRequired: true,
                  options: roleOptions,
                  validator: AppValidators.requiredValue(
                    l10n.hrFieldRequiredLabel(l10n.hrRolePositionColumnLabel),
                  ),
                  onChanged: (String? value) => setState(() => _roleId = value),
                );
                final Widget facilityField = AppSelectField<String>.searchable(
                  value: _facilityId,
                  labelText: l10n.hrRosterOverviewFacilityLabel,
                  options: hrSelectOptions(widget.facilities),
                  onChanged: (String? value) =>
                      setState(() => _facilityId = value),
                );
                if (width >= 560) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: roleField),
                      SizedBox(width: gap),
                      Expanded(child: facilityField),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    roleField,
                    SizedBox(height: theme.appTokens.formGapCompact),
                    facilityField,
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: _isEdit
              ? l10n.commonSaveActionLabel
              : l10n.hrAddRoleAction,
          leadingIcon: _isEdit ? Icons.save_outlined : Icons.add,
          onPressed: _submit,
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
