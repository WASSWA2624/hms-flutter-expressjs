import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Facility-scoped staff positions CRUD embedded in the HR workspace.
class HrPositionsPanel extends ConsumerStatefulWidget {
  const HrPositionsPanel({super.key});

  @override
  ConsumerState<HrPositionsPanel> createState() => _HrPositionsPanelState();
}

class _HrPositionsPanelState extends ConsumerState<HrPositionsPanel> {
  static const String _statusFilterKey = 'is_active';
  static const String _recordFilterKey = 'record_state';
  static const String _scopeFilterKey = 'scope';
  static const String _nameTextKey = 'name';
  static const String _descriptionTextKey = 'description';
  static const String _recordCurrent = 'current';
  static const String _recordDeleted = 'deleted';
  static const String _recordAll = 'all';
  static const String _scopeFacility = 'facility';
  static const String _scopeShared = 'shared';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrStaffPosition>
  _columnController = AppListTableColumnVisibilityController<HrStaffPosition>(
    storageKey: 'hr.positions.table.v2',
  );

  AppPage<HrStaffPosition> _page = const AppPage<HrStaffPosition>(
    items: <HrStaffPosition>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  bool _loading = true;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue(
    options: <String, String>{_recordFilterKey: _recordCurrent},
  );

  String? get _tenantId =>
      ref.read(sessionStateProvider).session?.user?.tenantId;
  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId;

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

  bool get _hasActiveFilters {
    final String status = _filterValue.option(_statusFilterKey) ?? '';
    final String record =
        _filterValue.option(_recordFilterKey) ?? _recordCurrent;
    final String scope = _filterValue.option(_scopeFilterKey) ?? '';
    return status.isNotEmpty ||
        record != _recordCurrent ||
        scope.isNotEmpty ||
        (_filterValue.text(_nameTextKey) ?? '').trim().isNotEmpty ||
        (_filterValue.text(_descriptionTextKey) ?? '').trim().isNotEmpty ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _reload() async {
    final String? tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _failure = AppFailure.validation();
      });
      return;
    }

    setState(() {
      _loading = true;
      _failure = null;
    });

    final String? activeFilter = _filterValue.option(_statusFilterKey);
    final bool? isActive = activeFilter == null || activeFilter.isEmpty
        ? null
        : activeFilter == 'true';
    final String recordState =
        _filterValue.option(_recordFilterKey) ?? _recordCurrent;
    final bool includeDeleted =
        recordState == _recordDeleted || recordState == _recordAll;
    final String nameFilter = (_filterValue.text(_nameTextKey) ?? '').trim();
    final String descriptionFilter =
        (_filterValue.text(_descriptionTextKey) ?? '').trim();
    final String search = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : nameFilter;

    final Result<AppPage<HrStaffPosition>> result = await ref
        .read(hrRepositoryProvider)
        .listStaffPositions(
          HrStaffPositionQuery(
            tenantId: tenantId,
            facilityId: _facilityId,
            search: search,
            isActive: isActive,
            includeDeleted: includeDeleted,
            pageRequest: const AppPageRequest(
              pageSize: AppPageRequest.maxPageSize,
            ),
          ),
        );

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<HrStaffPosition> page) {
        final List<HrStaffPosition> filtered = _applyLocalFilters(
          page.items,
          recordState: recordState,
          descriptionFilter: descriptionFilter,
          nameFilter: nameFilter,
          searchUsedForNameOnly:
              _searchController.text.trim().isEmpty && nameFilter.isNotEmpty,
        );
        setState(() {
          _page = AppPage<HrStaffPosition>(
            items: filtered,
            request: page.request,
            totalItemCount: filtered.length,
          );
          _loading = false;
        });
        if (recordState == _recordCurrent &&
            activeFilter == null &&
            (_filterValue.option(_scopeFilterKey) ?? '').isEmpty &&
            nameFilter.isEmpty &&
            descriptionFilter.isEmpty &&
            _searchController.text.trim().isEmpty) {
          ref
              .read(hrWorkspaceControllerProvider.notifier)
              .setPositionsTotalCount(page.totalItemCount ?? filtered.length);
        } else {
          unawaited(
            ref
                .read(hrWorkspaceControllerProvider.notifier)
                .refreshPositionsTotalCount(),
          );
        }
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  List<HrStaffPosition> _applyLocalFilters(
    List<HrStaffPosition> items, {
    required String recordState,
    required String descriptionFilter,
    required String nameFilter,
    required bool searchUsedForNameOnly,
  }) {
    final String? scope = _filterValue.option(_scopeFilterKey);
    final String descriptionNeedle = descriptionFilter.toLowerCase();
    final String nameNeedle = nameFilter.toLowerCase();

    return items.where((HrStaffPosition item) {
      if (recordState == _recordCurrent && item.isDeleted) {
        return false;
      }
      if (recordState == _recordDeleted && !item.isDeleted) {
        return false;
      }
      if (scope == _scopeFacility) {
        final String facilityId = (_facilityId ?? '').trim();
        if (facilityId.isEmpty ||
            (item.facilityId ?? '').trim() != facilityId) {
          return false;
        }
      } else if (scope == _scopeShared) {
        if ((item.facilityId ?? '').trim().isNotEmpty) {
          return false;
        }
      }
      if (descriptionNeedle.isNotEmpty) {
        if (!(item.description ?? '').toLowerCase().contains(
          descriptionNeedle,
        )) {
          return false;
        }
      }
      if (searchUsedForNameOnly && nameNeedle.isNotEmpty) {
        if (!item.name.toLowerCase().contains(nameNeedle)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _createOrEdit({HrStaffPosition? editing}) async {
    final String? tenantId = _tenantId;
    final String? facilityId = _facilityId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        facilityId == null ||
        facilityId.isEmpty) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }

    final HrStaffPosition? saved = await showHrCreateStaffPositionDialog(
      context,
      ref,
      tenantId: tenantId,
      facilityId: facilityId,
      existing: _page.items,
      editing: editing,
    );
    if (saved != null && mounted) {
      showHrMutationSnackBar(context, null);
      await _reload();
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .refreshPositionsTotalCount();
    }
  }

  Future<void> _softDelete(HrStaffPosition position) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.hrDeletePositionTitle,
        body: l10n.hrDeletePositionBody(position.name),
        highlightedText: position.name,
        submitLabel: l10n.commonDeleteActionLabel,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(hrRepositoryProvider)
              .deleteStaffPosition(position.effectiveId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      showHrMutationSnackBar(context, null);
      await _reload();
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .refreshPositionsTotalCount();
    }
  }

  Future<void> _restore(HrStaffPosition position) async {
    final Result<HrStaffPosition> result = await ref
        .read(hrRepositoryProvider)
        .restoreStaffPosition(position.effectiveId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        showHrMutationSnackBar(context, null);
        unawaited(_reload());
        unawaited(
          ref
              .read(hrWorkspaceControllerProvider.notifier)
              .refreshPositionsTotalCount(),
        );
      },
      failure: (AppFailure failure) => showHrMutationSnackBar(context, failure),
    );
  }

  Future<void> _permanentDelete(HrStaffPosition position) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilityPermanentDeleteConfirmationTitle,
        body: l10n.hrPermanentDeletePositionBody(position.name),
        highlightedText: position.name,
        submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_forever_outlined),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(hrRepositoryProvider)
              .permanentDeleteStaffPosition(position.effectiveId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      showHrMutationSnackBar(context, null);
      await _reload();
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .refreshPositionsTotalCount();
    }
  }

  Future<void> _openDetail(HrStaffPosition position) async {
    await showHrStaffPositionDetailDialog(
      context,
      ref,
      position,
      onEdit: (HrStaffPosition item) => _createOrEdit(editing: item),
      onSoftDelete: _softDelete,
      onRestore: _restore,
      onPermanentDelete: _permanentDelete,
    );
  }

  String _scopeLabel(AppLocalizations l10n, HrStaffPosition item) {
    return (item.facilityId ?? '').trim().isEmpty
        ? l10n.hrPositionScopeShared
        : l10n.hrPositionScopeFacility;
  }

  AppStatusBadge _statusBadge(AppLocalizations l10n, HrStaffPosition item) {
    if (item.isDeleted) {
      return AppStatusBadge(
        label: l10n.tenantFacilityStructureDeletedStatus,
        tone: AppWorkspaceStatusTone.error,
        icon: Icons.delete_outline,
      );
    }
    if (item.isActive) {
      return AppStatusBadge(
        label: l10n.hrPositionActiveStatus,
        tone: AppWorkspaceStatusTone.success,
        icon: Icons.check_circle_outline,
      );
    }
    return AppStatusBadge(
      label: l10n.hrPositionInactiveStatus,
      icon: Icons.pause_circle_outline,
    );
  }

  Widget _actionsCell(BuildContext context, HrStaffPosition item) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (!item.isDeleted) ...<Widget>[
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: l10n.commonEditActionLabel,
              tooltip: l10n.commonEditActionLabel,
              dense: true,
              onPressed: () => unawaited(_createOrEdit(editing: item)),
            ),
            AppButton.tertiary(
              leadingIcon: Icons.delete_outline,
              label: l10n.commonDeleteActionLabel,
              tooltip: l10n.commonDeleteActionLabel,
              dense: true,
              color: colors.error,
              onPressed: () => unawaited(_softDelete(item)),
            ),
          ] else ...<Widget>[
            AppButton.tertiary(
              leadingIcon: Icons.restore_outlined,
              label: l10n.tenantFacilityRestoreStructureAction,
              tooltip: l10n.tenantFacilityRestoreStructureAction,
              dense: true,
              onPressed: () => unawaited(_restore(item)),
            ),
            AppButton.tertiary(
              leadingIcon: Icons.delete_forever_outlined,
              label: l10n.tenantFacilityPermanentDeleteAction,
              tooltip: l10n.tenantFacilityPermanentDeleteAction,
              dense: true,
              color: colors.error,
              onPressed: () => unawaited(_permanentDelete(item)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = HrHumanResourcesAtomPermissions.write.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );

    return AppListTable<HrStaffPosition>(
      page: _page,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: 'hr.positions.table.v2',
      columnWidthStorageKey: 'hr.positions.table.widths.v2',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      onRowSelected: (HrStaffPosition item) => unawaited(_openDetail(item)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.hrNoPositionsTitle,
        body: l10n.hrNoPositionsBody,
      ),
      search: AppListTableSearch<HrStaffPosition>(
        controller: _searchController,
        semanticLabel: l10n.hrPositionsSearchHint,
        hintText: l10n.hrPositionsSearchHint,
        clearLabel: l10n.hrClearFiltersAction,
        matcher: (HrStaffPosition item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return item.name.toLowerCase().contains(needle) ||
              item.effectiveId.toLowerCase().contains(needle) ||
              (item.description ?? '').toLowerCase().contains(needle);
        },
        onSubmitted: (_) => unawaited(_reload()),
        onClear: () {
          _searchController.clear();
          setState(() => _filterValue = const AppSearchBarFilterValue(
            options: <String, String>{_recordFilterKey: _recordCurrent},
          ));
          unawaited(_reload());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.hrClearFiltersAction,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        searchFields: <AppSearchBarFieldChoice>[
          AppSearchBarFieldChoice(
            field: 'name',
            label: l10n.hrPositionLabel,
            icon: Icons.badge_outlined,
          ),
          AppSearchBarFieldChoice(
            field: 'id',
            label: l10n.hrPositionIdLabel,
            icon: Icons.tag_outlined,
          ),
          AppSearchBarFieldChoice(
            field: 'description',
            label: l10n.hrPositionDescriptionLabel,
            icon: Icons.notes_outlined,
          ),
        ],
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _nameTextKey,
            label: l10n.hrPositionNameFilterLabel,
            hintText: l10n.hrPositionLabel,
            icon: Icons.badge_outlined,
          ),
          AppSearchBarTextFilter(
            key: _descriptionTextKey,
            label: l10n.hrPositionDescriptionFilterLabel,
            hintText: l10n.hrPositionDescriptionLabel,
            icon: Icons.notes_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.hrStatusLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: l10n.hrPositionActiveStatus,
                icon: Icons.check_circle_outline,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: l10n.hrPositionInactiveStatus,
                icon: Icons.pause_circle_outline,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _recordFilterKey,
            label: l10n.hrPositionRecordStateLabel,
            allLabel: l10n.hrPositionRecordAll,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: _recordCurrent,
                label: l10n.hrPositionRecordCurrent,
                icon: Icons.inventory_2_outlined,
              ),
              AppSearchBarFilterChoice(
                value: _recordDeleted,
                label: l10n.hrPositionRecordDeleted,
                icon: Icons.delete_outline,
              ),
              AppSearchBarFilterChoice(
                value: _recordAll,
                label: l10n.hrPositionRecordAll,
                icon: Icons.list_alt_outlined,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _scopeFilterKey,
            label: l10n.hrPositionScopeLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: _scopeFacility,
                label: l10n.hrPositionScopeFacility,
                icon: Icons.apartment_outlined,
              ),
              AppSearchBarFilterChoice(
                value: _scopeShared,
                label: l10n.hrPositionScopeShared,
                icon: Icons.public_outlined,
              ),
            ],
          ),
        ],
        filterValue: _filterValue,
        hasActiveFilters: _hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          final String record =
              value.option(_recordFilterKey) ?? _recordCurrent;
          setState(
            () => _filterValue = value.copyWith(
              options: <String, String>{
                ...value.options,
                _recordFilterKey: record,
              },
            ),
          );
          unawaited(_reload());
        },
        trailingActions: <AppSearchBarAction>[
          if (canWrite)
            AppSearchBarAction(
              label: l10n.hrCreatePositionAction,
              icon: Icons.add_outlined,
              onPressed: () => unawaited(_createOrEdit()),
            ),
        ],
      ),
      columns: <AppListTableColumn<HrStaffPosition>>[
        AppListTableColumn<HrStaffPosition>(
          id: 'name',
          label: l10n.hrPositionLabel,
          alwaysVisible: true,
          preferredWidth: 220,
          cellBuilder: (_, HrStaffPosition item) => Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          sortComparator: (HrStaffPosition a, HrStaffPosition b) =>
              a.name.compareTo(b.name),
          exportValue: (HrStaffPosition item) => item.name,
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'id',
          label: l10n.hrPositionIdLabel,
          preferredWidth: 140,
          cellBuilder: (_, HrStaffPosition item) => AppCopyableIdentifier(
            value: item.effectiveId,
          ),
          sortComparator: (HrStaffPosition a, HrStaffPosition b) =>
              a.effectiveId.compareTo(b.effectiveId),
          exportValue: (HrStaffPosition item) => item.effectiveId,
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'description',
          label: l10n.hrPositionDescriptionLabel,
          preferredWidth: 280,
          cellBuilder: (_, HrStaffPosition item) => Text(
            (item.description ?? '').trim().isEmpty
                ? '—'
                : item.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          exportValue: (HrStaffPosition item) => item.description ?? '',
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'scope',
          label: l10n.hrPositionScopeLabel,
          preferredWidth: 140,
          cellBuilder: (_, HrStaffPosition item) =>
              Text(_scopeLabel(l10n, item)),
          sortComparator: (HrStaffPosition a, HrStaffPosition b) =>
              _scopeLabel(l10n, a).compareTo(_scopeLabel(l10n, b)),
          exportValue: (HrStaffPosition item) => _scopeLabel(l10n, item),
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'status',
          label: l10n.hrStatusLabel,
          preferredWidth: 140,
          cellBuilder: (_, HrStaffPosition item) =>
              _statusBadge(l10n, item),
          sortComparator: (HrStaffPosition a, HrStaffPosition b) {
            final int deletedCmp = (a.isDeleted ? 1 : 0).compareTo(
              b.isDeleted ? 1 : 0,
            );
            if (deletedCmp != 0) {
              return deletedCmp;
            }
            return (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
          },
          exportValue: (HrStaffPosition item) {
            if (item.isDeleted) {
              return l10n.tenantFacilityStructureDeletedStatus;
            }
            return item.isActive
                ? l10n.hrPositionActiveStatus
                : l10n.hrPositionInactiveStatus;
          },
        ),
        if (canWrite)
          AppListTableColumn<HrStaffPosition>(
            id: 'actions',
            label: l10n.hrPositionsActionsColumnLabel,
            alwaysVisible: true,
            preferredWidth: 220,
            cellBuilder: _actionsCell,
          ),
      ],
      mobileItemBuilder: (BuildContext context, HrStaffPosition item) {
        return AppListTableMobileItem(
          title: item.name,
          caption: item.effectiveId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(label: _scopeLabel(l10n, item)),
            AppListTableMobileMeta(
              label: item.isDeleted
                  ? l10n.tenantFacilityStructureDeletedStatus
                  : item.isActive
                  ? l10n.hrPositionActiveStatus
                  : l10n.hrPositionInactiveStatus,
            ),
          ],
          trailing: canWrite ? _actionsCell(context, item) : null,
        );
      },
    );
  }
}
