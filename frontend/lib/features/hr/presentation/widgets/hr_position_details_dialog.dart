import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_position_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Position details with collapsible overview and assigned-staff table.
Future<void> showHrStaffPositionDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffPosition position, {
  Future<void> Function(HrStaffPosition position)? onEdit,
  Future<void> Function(HrStaffPosition position)? onSoftDelete,
  Future<void> Function(HrStaffPosition position)? onRestore,
  Future<void> Function(HrStaffPosition position)? onPermanentDelete,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _HrStaffPositionDetailDialog(
      position: position,
      onEdit: onEdit,
      onSoftDelete: onSoftDelete,
      onRestore: onRestore,
      onPermanentDelete: onPermanentDelete,
    ),
  );
}

class _HrStaffPositionDetailDialog extends ConsumerStatefulWidget {
  const _HrStaffPositionDetailDialog({
    required this.position,
    this.onEdit,
    this.onSoftDelete,
    this.onRestore,
    this.onPermanentDelete,
  });

  final HrStaffPosition position;
  final Future<void> Function(HrStaffPosition position)? onEdit;
  final Future<void> Function(HrStaffPosition position)? onSoftDelete;
  final Future<void> Function(HrStaffPosition position)? onRestore;
  final Future<void> Function(HrStaffPosition position)? onPermanentDelete;

  @override
  ConsumerState<_HrStaffPositionDetailDialog> createState() =>
      _HrStaffPositionDetailDialogState();
}

class _HrStaffPositionDetailDialogState
    extends ConsumerState<_HrStaffPositionDetailDialog> {
  static const String _statusFilterKey = 'status';
  static const String _departmentFilterKey = 'department';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrStaffProfile>
  _columnController = AppListTableColumnVisibilityController<HrStaffProfile>(
    storageKey: 'hr.position_detail.assigned_staff.v1',
  );

  List<HrStaffProfile> _staff = const <HrStaffProfile>[];
  bool _loading = true;
  AppFailure? _failure;
  String _searchQuery = '';
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();

  HrStaffPosition get _position => widget.position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadStaff());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  bool _matchesPosition(HrStaffProfile profile) {
    final String expected = _position.name.trim().toLowerCase();
    final String actual = (profile.position ?? '').trim().toLowerCase();
    return expected.isNotEmpty && actual == expected;
  }

  Future<void> _reloadStaff() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final Result<AppPage<HrStaffProfile>> result = await ref
        .read(hrRepositoryProvider)
        .listStaffProfiles(
          HrStaffQuery(
            position: _position.name,
            pageRequest: const AppPageRequest(
              pageSize: AppPageRequest.maxPageSize,
            ),
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<HrStaffProfile> page) {
        final List<HrStaffProfile> matched = page.items
            .where(_matchesPosition)
            .toList(growable: false);
        setState(() {
          _staff = matched;
          _loading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  List<HrStaffProfile> get _visibleStaff {
    final String needle = _searchQuery.trim().toLowerCase();
    final String? statusFilter = _filterValue.option(_statusFilterKey);
    final String? departmentFilter = _filterValue.option(_departmentFilterKey);

    return _staff.where((HrStaffProfile row) {
      if (statusFilter != null && statusFilter.isNotEmpty) {
        if ((row.status ?? '').trim().toLowerCase() !=
            statusFilter.trim().toLowerCase()) {
          return false;
        }
      }
      if (departmentFilter != null && departmentFilter.isNotEmpty) {
        final String dept =
            (row.departmentName ?? row.departmentDisplayId ?? row.departmentId ?? '')
                .trim();
        if (dept != departmentFilter) {
          return false;
        }
      }
      if (needle.isEmpty) {
        return true;
      }
      return row.displayName.toLowerCase().contains(needle) ||
          (row.staffNumber ?? '').toLowerCase().contains(needle) ||
          (row.userEmail ?? '').toLowerCase().contains(needle) ||
          (row.departmentName ?? '').toLowerCase().contains(needle) ||
          row.effectiveId.toLowerCase().contains(needle);
    }).toList(growable: false);
  }

  List<String> get _statusChoices {
    final Set<String> values = <String>{};
    for (final HrStaffProfile row in _staff) {
      final String status = (row.status ?? '').trim();
      if (status.isNotEmpty) {
        values.add(status);
      }
    }
    final List<String> sorted = values.toList()..sort();
    return sorted;
  }

  List<String> get _departmentChoices {
    final Set<String> values = <String>{};
    for (final HrStaffProfile row in _staff) {
      final String dept =
          (row.departmentName ?? row.departmentDisplayId ?? '').trim();
      if (dept.isNotEmpty) {
        values.add(dept);
      }
    }
    final List<String> sorted = values.toList()..sort();
    return sorted;
  }

  Future<void> _assignStaff() async {
    if (!HrHumanResourcesAtomPermissions.assignPosition.isAllowed(
      ref.read(appAccessPolicyProvider),
    )) {
      return;
    }

    final bool? saved = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _HrAssignStaffToPositionDialog(position: _position, assigned: _staff),
    );
    if (saved == true && mounted) {
      showHrMutationSnackBar(context, null);
      await _reloadStaff();
      unawaited(ref.read(hrWorkspaceControllerProvider.notifier).refresh());
    }
  }

  Future<void> _print() async {
    await showHrPositionPrintPreview(
      context: context,
      ref: ref,
      position: _position,
      staff: _staff,
    );
  }

  List<AppInfoSheetItem> _overviewItems(AppLocalizations l10n) {
    final String description = (_position.description ?? '').trim();
    return <AppInfoSheetItem>[
      AppInfoSheetItem(label: l10n.hrPositionLabel, value: _position.name),
      AppInfoSheetItem(
        label: l10n.hrPositionIdLabel,
        value: _position.effectiveId,
        copyable: true,
      ),
      AppInfoSheetItem(
        label: l10n.hrPositionDescriptionLabel,
        value: description.isEmpty ? null : description,
      ),
      AppInfoSheetItem(
        label: l10n.hrPositionScopeLabel,
        value: _position.isShared
            ? l10n.hrPositionScopeShared
            : l10n.hrPositionScopeFacility,
      ),
      AppInfoSheetItem(
        label: l10n.hrStatusLabel,
        value: _position.isDeleted
            ? l10n.tenantFacilityStructureDeletedStatus
            : _position.isActive
            ? l10n.hrPositionActiveStatus
            : l10n.hrPositionInactiveStatus,
      ),
      AppInfoSheetItem(
        label: l10n.hrPositionAssignedStaffSectionTitle,
        value: _loading ? '…' : '${_staff.length}',
      ),
    ];
  }

  List<AppListTableColumn<HrStaffProfile>> _staffColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<HrStaffProfile>>[
      AppListTableColumn<HrStaffProfile>(
        id: 'name',
        label: l10n.hrStaffNameLabel,
        alwaysVisible: true,
        preferredWidth: 200,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text(row.displayName),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            a.displayName.compareTo(b.displayName),
        exportValue: (HrStaffProfile row) => row.displayName,
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'staff_number',
        label: l10n.hrStaffNumberLabel,
        preferredWidth: 140,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text(row.staffNumber ?? row.effectiveId),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.staffNumber ?? a.effectiveId).compareTo(
              b.staffNumber ?? b.effectiveId,
            ),
        exportValue: (HrStaffProfile row) =>
            row.staffNumber ?? row.effectiveId,
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'department',
        label: l10n.hrDepartmentLabel,
        preferredWidth: 160,
        cellBuilder: (BuildContext context, HrStaffProfile row) => Text(
          row.departmentName ?? row.departmentDisplayId ?? '—',
        ),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.departmentName ?? a.departmentDisplayId ?? '').compareTo(
              b.departmentName ?? b.departmentDisplayId ?? '',
            ),
        exportValue: (HrStaffProfile row) =>
            row.departmentName ?? row.departmentDisplayId ?? '',
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'email',
        label: l10n.hrEmailLabel,
        preferredWidth: 200,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text(row.userEmail ?? '—'),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.userEmail ?? '').compareTo(b.userEmail ?? ''),
        exportValue: (HrStaffProfile row) => row.userEmail ?? '',
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'practitioner_type',
        label: l10n.hrPractitionerTypeLabel,
        preferredWidth: 160,
        cellBuilder: (BuildContext context, HrStaffProfile row) {
          final String? type = row.practitionerType;
          if (type == null || type.trim().isEmpty) {
            return const Text('—');
          }
          return Text(
            context.l10n.hrReferencePractitionerTypeLabel(
              type,
              fallback: type,
            ),
          );
        },
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.practitionerType ?? '').compareTo(b.practitionerType ?? ''),
        exportValue: (HrStaffProfile row) => row.practitionerType ?? '',
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'status',
        label: l10n.hrStatusLabel,
        preferredWidth: 120,
        cellBuilder: (BuildContext context, HrStaffProfile row) {
          final String status = (row.status ?? '').trim();
          if (status.isEmpty) {
            return const Text('—');
          }
          final bool separated = row.isSeparated;
          return AppStatusBadge(
            label: status,
            tone: separated
                ? AppWorkspaceStatusTone.error
                : status.toUpperCase() == 'ACTIVE'
                ? AppWorkspaceStatusTone.success
                : AppWorkspaceStatusTone.neutral,
          );
        },
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.status ?? '').compareTo(b.status ?? ''),
        exportValue: (HrStaffProfile row) => row.status ?? '',
      ),
    ];
  }

  AppListTableMobileItem _staffMobileItem(
    BuildContext context,
    HrStaffProfile row,
  ) {
    return AppListTableMobileItem(
      title: row.displayName,
      caption: row.staffNumber ?? row.effectiveId,
      meta: <AppListTableMobileMeta>[
        if ((row.departmentName ?? row.departmentDisplayId ?? '')
            .trim()
            .isNotEmpty)
          AppListTableMobileMeta(
            label: row.departmentName ?? row.departmentDisplayId!,
          ),
        if ((row.status ?? '').trim().isNotEmpty)
          AppListTableMobileMeta(label: row.status!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool canWrite = HrHumanResourcesAtomPermissions.write.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final bool canAssign =
        HrHumanResourcesAtomPermissions.assignPosition.isAllowed(
          ref.watch(appAccessPolicyProvider),
        );
    final bool canMutate = canWrite && !_position.isShared;
    final bool showActionLabels =
        AppBreakpoints.of(context).showsToolbarActionLabels;
    final List<HrStaffProfile> visible = _visibleStaff;

    return AppActionLabelScope(
      showLabels: showActionLabels,
      forceIconOnly: !showActionLabels,
      child: AppDialog(
        title: Text(l10n.hrPositionDetailTitle),
        icon: const Icon(Icons.work_outline),
        scrollable: true,
        pinActionsToBottom: true,
        maxWidth: 980,
        stackActionsWhenCompact: false,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppCollapsibleSection(
              title: l10n.hrPositionPrintDetailsSection,
              titleIcon: Icons.info_outline,
              child: AppInfoSheetGrid(
                emptyValue: l10n.profileUnknownValue,
                spacing: theme.spacing.lg,
                runSpacing: theme.spacing.sm,
                layout: AppInfoSheetLayout.inline,
                items: _overviewItems(l10n),
              ),
            ),
            SizedBox(height: theme.spacing.lg),
            AppCollapsibleSection(
              title: l10n.hrPositionAssignedStaffSectionTitle,
              titleIcon: Icons.groups_outlined,
              contentPadding: EdgeInsets.only(bottom: theme.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_failure != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        theme.spacing.md,
                        theme.spacing.md,
                        theme.spacing.md,
                        0,
                      ),
                      child: AppFormInformationBanner(
                        title: l10n.hrPositionAssignedStaffLoadErrorTitle,
                        message: l10n.failureMessage(_failure!),
                        variant: AppFormInformationVariant.error,
                      ),
                    ),
                  AppListTable<HrStaffProfile>(
                    page: AppPage<HrStaffProfile>(
                      items: visible,
                      request: AppPageRequest(
                        pageSize: visible.isEmpty ? 20 : visible.length,
                      ),
                      totalItemCount: visible.length,
                    ),
                    isLoading: _loading,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    forceCompact: true,
                    padEmptyRows: false,
                    maxVisibleItems: visible.isEmpty ? 1 : visible.length,
                    columnVisibilityController: _columnController,
                    columnVisibilityStorageKey:
                        'hr.position_detail.assigned_staff.v1',
                    columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                    columnVisibilityTitle: l10n.commonTableSettingsTitle,
                    emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                      title: l10n.hrPositionAssignedStaffEmptyTitle,
                      body: l10n.hrPositionAssignedStaffEmptyBody,
                    ),
                    search: AppListTableSearch<HrStaffProfile>(
                      controller: _searchController,
                      semanticLabel: l10n.hrPositionAssignedStaffSearchHint,
                      hintText: l10n.hrPositionAssignedStaffSearchHint,
                      clearLabel: l10n.hrClearFiltersAction,
                      matcher: (HrStaffProfile row, String query) => true,
                      onSubmitted: (String value) =>
                          setState(() => _searchQuery = value),
                      onClear: () => setState(() {
                        _searchQuery = '';
                        _filterValue = const AppSearchBarFilterValue();
                      }),
                      showAdvancedFilterButton: true,
                      advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
                      advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                      advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                      advancedFilterResetLabel: l10n.hrClearFiltersAction,
                      allFieldsLabel: l10n.opdAllFieldsFilterLabel,
                      filterGroups: <AppSearchBarFilterGroup>[
                        if (_statusChoices.isNotEmpty)
                          AppSearchBarFilterGroup(
                            key: _statusFilterKey,
                            label: l10n.hrStatusLabel,
                            allLabel: l10n.opdAllFieldsFilterLabel,
                            choices: <AppSearchBarFilterChoice>[
                              for (final String status in _statusChoices)
                                AppSearchBarFilterChoice(
                                  value: status,
                                  label: status,
                                ),
                            ],
                          ),
                        if (_departmentChoices.isNotEmpty)
                          AppSearchBarFilterGroup(
                            key: _departmentFilterKey,
                            label: l10n.hrDepartmentLabel,
                            allLabel: l10n.opdAllFieldsFilterLabel,
                            choices: <AppSearchBarFilterChoice>[
                              for (final String dept in _departmentChoices)
                                AppSearchBarFilterChoice(
                                  value: dept,
                                  label: dept,
                                ),
                            ],
                          ),
                      ],
                      filterValue: _filterValue,
                      onFilterChanged: (AppSearchBarFilterValue value) {
                        setState(() => _filterValue = value);
                      },
                      trailingActions: <AppSearchBarAction>[
                        if (canAssign &&
                            !_position.isDeleted &&
                            _position.isActive)
                          AppSearchBarAction(
                            icon: Icons.person_add_alt_1_outlined,
                            label: l10n.hrPositionAssignStaffAction,
                            tooltip: l10n.hrPositionAssignStaffAction,
                            enabled: !_loading,
                            onPressed: _loading
                                ? null
                                : () => unawaited(_assignStaff()),
                          ),
                      ],
                    ),
                    columns: _staffColumns(l10n),
                    mobileItemBuilder: _staffMobileItem,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (canMutate && !_position.isDeleted && widget.onEdit != null)
            AppButton.secondary(
              label: l10n.commonEditActionLabel,
              leadingIcon: Icons.edit_outlined,
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onEdit!(_position);
              },
            ),
          if (canMutate && !_position.isDeleted && widget.onSoftDelete != null)
            AppButton.secondary(
              label: l10n.commonDeleteActionLabel,
              leadingIcon: Icons.delete_outline,
              color: colors.error,
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onSoftDelete!(_position);
              },
            ),
          if (canMutate && _position.isDeleted && widget.onRestore != null)
            AppButton.secondary(
              label: l10n.tenantFacilityRestoreStructureAction,
              leadingIcon: Icons.restore_outlined,
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onRestore!(_position);
              },
            ),
          if (canMutate &&
              _position.isDeleted &&
              widget.onPermanentDelete != null)
            AppButton.secondary(
              label: l10n.tenantFacilityPermanentDeleteAction,
              leadingIcon: Icons.delete_forever_outlined,
              color: colors.error,
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onPermanentDelete!(_position);
              },
            ),
          AppButton.primary(
            label: l10n.commonPrintActionLabel,
            leadingIcon: Icons.print_outlined,
            onPressed: () => unawaited(_print()),
          ),
        ],
      ),
    );
  }
}

/// Pick facility staff and assign them to [position].
class _HrAssignStaffToPositionDialog extends ConsumerStatefulWidget {
  const _HrAssignStaffToPositionDialog({
    required this.position,
    required this.assigned,
  });

  final HrStaffPosition position;
  final List<HrStaffProfile> assigned;

  @override
  ConsumerState<_HrAssignStaffToPositionDialog> createState() =>
      _HrAssignStaffToPositionDialogState();
}

class _HrAssignStaffToPositionDialogState
    extends ConsumerState<_HrAssignStaffToPositionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrStaffProfile>
  _columnController = AppListTableColumnVisibilityController<HrStaffProfile>(
    storageKey: 'hr.position_detail.assign_staff.v1',
  );

  List<HrStaffProfile> _candidates = const <HrStaffProfile>[];
  final Set<String> _selectedIds = <String>{};
  bool _loading = true;
  bool _saving = false;
  AppFailure? _failure;

  Set<String> get _assignedIds => <String>{
    for (final HrStaffProfile row in widget.assigned) row.effectiveId,
    for (final HrStaffProfile row in widget.assigned) row.id,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final Result<AppPage<HrStaffProfile>> result = await ref
        .read(hrRepositoryProvider)
        .listStaffProfiles(
          const HrStaffQuery(
            pageRequest: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<HrStaffProfile> page) {
        final String positionName = widget.position.name.trim().toLowerCase();
        final List<HrStaffProfile> candidates = page.items.where((
          HrStaffProfile row,
        ) {
          if (row.isSeparated) {
            return false;
          }
          if (_assignedIds.contains(row.effectiveId) ||
              _assignedIds.contains(row.id)) {
            return false;
          }
          final String current = (row.position ?? '').trim().toLowerCase();
          return current != positionName;
        }).toList(growable: false);
        setState(() {
          _candidates = candidates;
          _loading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  Future<void> _assign() async {
    if (_selectedIds.isEmpty) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }

    setState(() => _saving = true);
    final HrRepository repository = ref.read(hrRepositoryProvider);
    AppFailure? firstFailure;

    for (final String id in _selectedIds) {
      HrStaffProfile? profile;
      for (final HrStaffProfile row in _candidates) {
        if (row.effectiveId == id || row.id == id) {
          profile = row;
          break;
        }
      }
      if (profile == null) {
        continue;
      }
      final Result<HrStaffProfile> result = await repository.updateStaffProfile(
        profile.effectiveId,
        <String, Object?>{'position': widget.position.name},
      );
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure value) => value,
      );
      if (failure != null) {
        firstFailure = failure;
        break;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (firstFailure != null) {
      showHrMutationSnackBar(context, firstFailure);
      return;
    }
    Navigator.of(context).pop(true);
  }

  List<AppListTableColumn<HrStaffProfile>> _columns(AppLocalizations l10n) {
    final List<HrStaffProfile> visible = _candidates;
    final bool allSelected =
        visible.isNotEmpty &&
        visible.every(
          (HrStaffProfile row) =>
              _selectedIds.contains(row.effectiveId) ||
              _selectedIds.contains(row.id),
        );
    final bool noneSelected = visible.every(
      (HrStaffProfile row) =>
          !_selectedIds.contains(row.effectiveId) &&
          !_selectedIds.contains(row.id),
    );

    return <AppListTableColumn<HrStaffProfile>>[
      AppListTableColumn<HrStaffProfile>(
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
              onChanged: _saving || visible.isEmpty
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          for (final HrStaffProfile row in visible) {
                            _selectedIds.add(row.effectiveId);
                          }
                        } else {
                          for (final HrStaffProfile row in visible) {
                            _selectedIds.remove(row.effectiveId);
                            _selectedIds.remove(row.id);
                          }
                        }
                      });
                    },
            ),
          );
        },
        cellBuilder: (BuildContext context, HrStaffProfile row) {
          final bool selected =
              _selectedIds.contains(row.effectiveId) ||
              _selectedIds.contains(row.id);
          return Center(
            child: Checkbox(
              value: selected,
              onChanged: _saving
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(row.effectiveId);
                        } else {
                          _selectedIds.remove(row.effectiveId);
                          _selectedIds.remove(row.id);
                        }
                      });
                    },
            ),
          );
        },
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'name',
        label: l10n.hrStaffNameLabel,
        alwaysVisible: true,
        preferredWidth: 200,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text(row.displayName),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            a.displayName.compareTo(b.displayName),
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'staff_number',
        label: l10n.hrStaffNumberLabel,
        preferredWidth: 140,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text(row.staffNumber ?? row.effectiveId),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.staffNumber ?? a.effectiveId).compareTo(
              b.staffNumber ?? b.effectiveId,
            ),
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'department',
        label: l10n.hrDepartmentLabel,
        preferredWidth: 160,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text(row.departmentName ?? row.departmentDisplayId ?? '—'),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.departmentName ?? a.departmentDisplayId ?? '').compareTo(
              b.departmentName ?? b.departmentDisplayId ?? '',
            ),
      ),
      AppListTableColumn<HrStaffProfile>(
        id: 'current_position',
        label: l10n.hrPositionLabel,
        preferredWidth: 180,
        cellBuilder: (BuildContext context, HrStaffProfile row) =>
            Text((row.position ?? '').trim().isEmpty ? '—' : row.position!),
        sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
            (a.position ?? '').compareTo(b.position ?? ''),
      ),
    ];
  }

  AppListTableMobileItem _mobileItem(BuildContext context, HrStaffProfile row) {
    final bool selected =
        _selectedIds.contains(row.effectiveId) || _selectedIds.contains(row.id);
    return AppListTableMobileItem(
      title: row.displayName,
      caption: row.staffNumber ?? row.effectiveId,
      leading: Checkbox(
        value: selected,
        onChanged: _saving
            ? null
            : (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(row.effectiveId);
                  } else {
                    _selectedIds.remove(row.effectiveId);
                    _selectedIds.remove(row.id);
                  }
                });
              },
      ),
      meta: <AppListTableMobileMeta>[
        if ((row.departmentName ?? row.departmentDisplayId ?? '')
            .trim()
            .isNotEmpty)
          AppListTableMobileMeta(
            label: row.departmentName ?? row.departmentDisplayId!,
          ),
        if ((row.position ?? '').trim().isNotEmpty)
          AppListTableMobileMeta(label: row.position!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.hrPositionAssignStaffDialogTitle),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: Theme.of(context).spacing.md),
              child: AppFormInformationBanner(
                title: l10n.hrPositionAssignedStaffLoadErrorTitle,
                message: l10n.failureMessage(_failure!),
                variant: AppFormInformationVariant.error,
              ),
            ),
          AppListTable<HrStaffProfile>(
            items: _candidates,
            isLoading: _loading,
            columnVisibilityController: _columnController,
            columnVisibilityStorageKey: 'hr.position_detail.assign_staff.v1',
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            onRowSelected: _saving
                ? null
                : (HrStaffProfile row) {
                    setState(() {
                      if (_selectedIds.contains(row.effectiveId) ||
                          _selectedIds.contains(row.id)) {
                        _selectedIds.remove(row.effectiveId);
                        _selectedIds.remove(row.id);
                      } else {
                        _selectedIds.add(row.effectiveId);
                      }
                    });
                  },
            emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
              title: l10n.hrPositionAssignStaffEmptyTitle,
              body: l10n.hrPositionAssignStaffEmptyBody,
            ),
            search: AppListTableSearch<HrStaffProfile>(
              controller: _searchController,
              semanticLabel: l10n.hrSearchLabel,
              hintText: l10n.hrSearchHint,
              clearLabel: l10n.hrClearFiltersAction,
              matcher: (HrStaffProfile row, String query) {
                final String needle = query.trim().toLowerCase();
                if (needle.isEmpty) {
                  return true;
                }
                return row.displayName.toLowerCase().contains(needle) ||
                    (row.staffNumber ?? '').toLowerCase().contains(needle) ||
                    (row.userEmail ?? '').toLowerCase().contains(needle) ||
                    (row.position ?? '').toLowerCase().contains(needle) ||
                    row.effectiveId.toLowerCase().contains(needle);
              },
            ),
            columns: _columns(l10n),
            mobileItemBuilder: _mobileItem,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.hrPositionAssignStaffAction,
          leadingIcon: Icons.person_add_alt_1_outlined,
          onPressed: _saving || _selectedIds.isEmpty
              ? null
              : () => unawaited(_assign()),
        ),
      ],
    );
  }
}
