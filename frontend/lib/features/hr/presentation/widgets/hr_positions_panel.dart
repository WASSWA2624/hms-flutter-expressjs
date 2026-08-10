import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Facility-scoped staff positions CRUD embedded in the HR workspace.
class HrPositionsPanel extends ConsumerStatefulWidget {
  const HrPositionsPanel({super.key});

  @override
  ConsumerState<HrPositionsPanel> createState() => _HrPositionsPanelState();
}

class _HrPositionsPanelState extends ConsumerState<HrPositionsPanel> {
  static const String _statusFilterKey = 'is_active';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrStaffPosition>
  _columnController = AppListTableColumnVisibilityController<HrStaffPosition>(
    storageKey: 'hr.positions.table',
  );

  List<HrStaffPosition> _items = const <HrStaffPosition>[];
  bool _loading = true;
  bool _includeDeleted = false;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();

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

    final Result<AppPage<HrStaffPosition>> result = await ref
        .read(hrRepositoryProvider)
        .listStaffPositions(
          HrStaffPositionQuery(
            tenantId: tenantId,
            facilityId: _facilityId,
            search: _searchController.text.trim(),
            isActive: isActive,
            includeDeleted: _includeDeleted,
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
        setState(() {
          _items = page.items;
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
      existing: _items,
      editing: editing,
    );
    if (saved != null && mounted) {
      showHrMutationSnackBar(context, null);
      await _reload();
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = HrHumanResourcesAtomPermissions.write.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );

    return AppListTable<HrStaffPosition>(
      items: _items,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      columnVisibilityController: _columnController,
      onRowSelected: (HrStaffPosition item) => unawaited(_openDetail(item)),
      search: AppListTableSearch<HrStaffPosition>(
        controller: _searchController,
        semanticLabel: l10n.hrPositionsSearchHint,
        hintText: l10n.hrPositionsSearchHint,
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
          unawaited(_reload());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.hrClearFiltersAction,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.hrStatusLabel,
            allLabel: l10n.opdAllFieldsFilterLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: l10n.hrPositionActiveStatus,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: l10n.hrPositionInactiveStatus,
              ),
            ],
          ),
        ],
        filterValue: _filterValue,
        hasActiveFilters:
            (_filterValue.option(_statusFilterKey) ?? '').isNotEmpty,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _filterValue = value);
          unawaited(_reload());
        },
        trailingActions: <AppSearchBarAction>[
          AppSearchBarAction(
            label: _includeDeleted
                ? l10n.hrPositionsActiveOnlyFilter
                : l10n.hrPositionsIncludeDeletedFilter,
            icon: _includeDeleted
                ? Icons.visibility_off_outlined
                : Icons.delete_outline,
            active: _includeDeleted,
            onPressed: () {
              setState(() => _includeDeleted = !_includeDeleted);
              unawaited(_reload());
            },
          ),
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
          cellBuilder: (_, HrStaffPosition item) => Text(item.name),
          sortComparator: (HrStaffPosition a, HrStaffPosition b) =>
              a.name.compareTo(b.name),
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'id',
          label: l10n.hrPositionIdLabel,
          cellBuilder: (_, HrStaffPosition item) => Text(item.effectiveId),
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'description',
          label: l10n.hrPositionDescriptionLabel,
          cellBuilder: (_, HrStaffPosition item) => Text(
            (item.description ?? '').trim().isEmpty
                ? '—'
                : item.description!,
          ),
        ),
        AppListTableColumn<HrStaffPosition>(
          id: 'status',
          label: l10n.hrStatusLabel,
          cellBuilder: (_, HrStaffPosition item) => Text(
            item.isDeleted
                ? l10n.tenantFacilityStructureDeletedStatus
                : item.isActive
                ? l10n.hrPositionActiveStatus
                : l10n.hrPositionInactiveStatus,
          ),
        ),
        if (canWrite)
          AppListTableColumn<HrStaffPosition>(
            id: 'actions',
            label: l10n.hrPositionsActionsColumnLabel,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, HrStaffPosition item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!item.isDeleted) ...<Widget>[
                    AppButton.tertiary(
                      leadingIcon: Icons.edit_outlined,
                      label: l10n.commonEditActionLabel,
                      onPressed: () => unawaited(_createOrEdit(editing: item)),
                    ),
                    AppButton.tertiary(
                      leadingIcon: Icons.delete_outline,
                      label: l10n.commonDeleteActionLabel,
                      onPressed: () => unawaited(_softDelete(item)),
                    ),
                  ] else ...<Widget>[
                    AppButton.tertiary(
                      leadingIcon: Icons.restore_outlined,
                      label: l10n.tenantFacilityRestoreStructureAction,
                      onPressed: () => unawaited(_restore(item)),
                    ),
                    AppButton.tertiary(
                      leadingIcon: Icons.delete_forever_outlined,
                      label: l10n.tenantFacilityPermanentDeleteAction,
                      onPressed: () => unawaited(_permanentDelete(item)),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
      mobileItemBuilder: (BuildContext context, HrStaffPosition item) {
        return AppListTableMobileItem(
          title: item.name,
          caption: item.effectiveId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: item.isDeleted
                  ? l10n.tenantFacilityStructureDeletedStatus
                  : item.isActive
                  ? l10n.hrPositionActiveStatus
                  : l10n.hrPositionInactiveStatus,
            ),
          ],
        );
      },
    );
  }
}
