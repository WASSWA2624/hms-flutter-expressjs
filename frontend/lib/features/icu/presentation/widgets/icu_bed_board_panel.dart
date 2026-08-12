import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String _wardFilterKey = 'ward';
const String _statusFilterKey = 'status';

/// ICU-ward scoped bed board (icu-flow §7, ipd-flow §14.2). Read view over the
/// shared bed catalog filtered to ICU wards; bed CRUD remains in Facility/IPD.
class IcuBedBoardPanel extends ConsumerStatefulWidget {
  const IcuBedBoardPanel({required this.state, super.key});

  final IcuWorkspaceState state;

  @override
  ConsumerState<IcuBedBoardPanel> createState() => _IcuBedBoardPanelState();
}

class _IcuBedBoardPanelState extends ConsumerState<IcuBedBoardPanel> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<IcuBed>
  _columnVisibilityController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<IcuBed>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!IcuBedBoardAtomPermissions.tab.isAllowed(policy)) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final IcuBedBoard board = widget.state.bedBoard;
    final List<IcuBed> beds = board.visibleBeds;
    final AppSearchBarFilterValue filterValue = AppSearchBarFilterValue(
      options: <String, String>{
        if (board.selectedWardId != null) _wardFilterKey: board.selectedWardId!,
        if (board.selectedStatus != null)
          _statusFilterKey: board.selectedStatus!,
      },
    );
    final ({
      List<AppListTableColumn<IcuBed>> defaults,
      List<AppListTableColumn<IcuBed>> choices,
    }) columns = _icuBedBoardColumns(context, policy: policy);
    final bool canOpenIpd =
        IcuBedBoardAtomPermissions.openIpd.isAllowed(policy);

    return AppListTable<IcuBed>(
      items: beds,
      isLoading: widget.state.isRefreshingBeds,
      itemKeyBuilder: (IcuBed bed) => ValueKey<String>(bed.id),
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: 'icu_bed_board',
      columnWidthStorageKey: 'icu_bed_board_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      columns: columns.defaults,
      columnChoices: columns.choices,
      enableExport: true,
      canExport: canExportIcuWorkspace(policy),
      exportLabel: l10n.commonTableExportActionLabel,
      exportDialogTitle: l10n.commonTableExportDialogTitle,
      exportCancelLabel: l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: l10n.commonTableExportSuccessMessage,
      exportFailureMessage: l10n.commonTableExportFailureMessage,
      enablePrint: true,
      canPrint: canPrintIcuWorkspace(policy),
      printLabel: l10n.commonPrintActionLabel,
      onPrint: () => _printIcuBedBoardList(
        context,
        ref,
        beds: beds,
        columns: <AppListTableColumn<IcuBed>>[
          ...columns.defaults,
          ...columns.choices,
        ],
        l10n: l10n,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<IcuBed>(
        fileNameStem: 'icu_bed_board',
        sheetName: l10n.icuViewBedBoard,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      search: AppListTableSearch<IcuBed>(
        controller: _searchController,
        semanticLabel: l10n.ipdBedBoardSearchLabel,
        hintText: l10n.ipdBedBoardSearchHint,
        matcher: (IcuBed bed, String query) => bed.matchesSearch(query),
        onChanged: controller.applyBedSearch,
        onSubmitted: controller.applyBedSearch,
        onClear: () => controller.applyBedSearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        enableDateFilter: false,
        allFieldsLabel: l10n.ipdAllWardsOption,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _wardFilterKey,
            label: l10n.ipdWardFilterLabel,
            allLabel: l10n.ipdAllWardsOption,
            choices: <AppSearchBarFilterChoice>[
              for (final IcuBedWard ward in board.wards)
                AppSearchBarFilterChoice(
                  value: ward.id,
                  label: ward.displayTitle,
                  icon: Icons.local_hospital_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.ipdBedStatusFilterLabel,
            allLabel: l10n.ipdScopeAll,
            choices: <AppSearchBarFilterChoice>[
              for (final String status in _icuBedStatuses)
                AppSearchBarFilterChoice(
                  value: status,
                  label: apiLabel(status),
                  icon: Icons.filter_list,
                ),
            ],
          ),
        ],
        filterValue: filterValue,
        hasActiveFilters:
            board.selectedWardId != null || board.selectedStatus != null,
        onFilterChanged: (AppSearchBarFilterValue value) {
          final String? nextWard = value.option(_wardFilterKey);
          final String? nextStatus = value.option(_statusFilterKey);
          if (nextWard != board.selectedWardId) {
            controller.selectBedWard(nextWard);
          }
          if (nextStatus != board.selectedStatus) {
            controller.selectBedStatus(nextStatus);
          }
        },
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.icuBedNoBedsTitle,
        body: l10n.icuBedNoBedsBody,
        icon: Icons.bed_outlined,
      ),
      mobileItemBuilder: (BuildContext context, IcuBed bed) {
        return AppListTableMobileItem(
          title: bed.label ?? bed.id,
          caption: bed.isOccupied
              ? (bed.occupantName ?? l10n.profileUnknownValue)
              : l10n.icuBedVacantLabel,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(label: bed.locationLabel),
            AppListTableMobileMeta(label: apiLabel(bed.status ?? '')),
          ],
          trailing: bed.isOccupied && canOpenIpd
              ? AppButton(
                  iconOnly: true,
                  leadingIcon: Icons.open_in_new_outlined,
                  label: l10n.icuActionOpenIpd,
                  semanticLabel: l10n.icuActionOpenIpd,
                  tooltip: l10n.icuActionOpenIpd,
                  onPressed: () => _openIpd(context, bed),
                )
              : null,
        );
      },
    );
  }
}

const List<String> _icuBedStatuses = <String>[
  'AVAILABLE',
  'OCCUPIED',
  'CLEANING',
  'MAINTENANCE',
  'BLOCKED',
];

({
  List<AppListTableColumn<IcuBed>> defaults,
  List<AppListTableColumn<IcuBed>> choices,
})
_icuBedBoardColumns(
  BuildContext context, {
  required AppAccessPolicy policy,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool canOpenIpd = IcuBedBoardAtomPermissions.openIpd.isAllowed(policy);
  final AppListTableColumn<IcuBed> bed = AppListTableColumn<IcuBed>(
    id: 'bed',
    label: l10n.ipdBedColumnLabel,
    sortComparator: (IcuBed a, IcuBed b) =>
        appListTableCompareText(a.label ?? a.id, b.label ?? b.id),
    exportValue: (IcuBed item) => item.label ?? item.id,
    cellBuilder: (BuildContext context, IcuBed bed) {
      return Text(
        bed.label ?? bed.id,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
  final AppListTableColumn<IcuBed> location = AppListTableColumn<IcuBed>(
    id: 'location',
    label: l10n.ipdWardColumnLabel,
    sortComparator: (IcuBed a, IcuBed b) =>
        appListTableCompareText(a.locationLabel, b.locationLabel),
    exportValue: (IcuBed item) => item.locationLabel,
    cellBuilder: (BuildContext context, IcuBed bed) {
      return Text(bed.locationLabel);
    },
  );
  final AppListTableColumn<IcuBed> occupant = AppListTableColumn<IcuBed>(
    id: 'occupant',
    label: l10n.ipdCurrentPatientColumnLabel,
    exportValue: (IcuBed item) => item.isOccupied
        ? (item.occupantName ?? l10n.profileUnknownValue)
        : l10n.icuBedVacantLabel,
    cellBuilder: (BuildContext context, IcuBed bed) {
      if (!bed.isOccupied) {
        return Text(context.l10n.icuBedVacantLabel);
      }
      return Text(
        bed.occupantName ?? context.l10n.profileUnknownValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
  final AppListTableColumn<IcuBed> status = AppListTableColumn<IcuBed>(
    id: 'status',
    label: l10n.opdStatusColumnLabel,
    alwaysVisible: true,
    exportValue: (IcuBed item) => apiLabel(item.status ?? ''),
    cellBuilder: (BuildContext context, IcuBed bed) {
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: apiLabel(bed.status ?? ''),
          tone: bedStatusTone(bed.status),
        ),
      );
    },
  );
  final AppListTableColumn<IcuBed> admissionId = AppListTableColumn<IcuBed>(
    id: 'admission_id',
    label: l10n.icuAdmissionLabel,
    exportValue: (IcuBed item) =>
        item.occupantDisplayId ?? l10n.profileUnknownValue,
    cellBuilder: (BuildContext context, IcuBed bed) {
      return Text(
        bed.occupantDisplayId ?? context.l10n.profileUnknownValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
  final AppListTableColumn<IcuBed>? nextAction = canOpenIpd
      ? AppListTableColumn<IcuBed>(
          id: 'next_action',
          label: l10n.icuNextActionColumnLabel,
          alwaysVisible: true,
          exportable: false,
          cellBuilder: (BuildContext context, IcuBed bed) {
            if (!bed.isOccupied) {
              return const SizedBox.shrink();
            }
            return AppButton(
              iconOnly: true,
              leadingIcon: Icons.open_in_new_outlined,
              label: l10n.icuActionOpenIpd,
              semanticLabel: l10n.icuActionOpenIpd,
              tooltip: l10n.icuActionOpenIpd,
              onPressed: () => _openIpd(context, bed),
            );
          },
        )
      : null;

  // Prefer ~5 defaults: when next-action is present, admission id is optional.
  final List<AppListTableColumn<IcuBed>> defaults =
      <AppListTableColumn<IcuBed>>[
        bed,
        location,
        occupant,
        status,
        if (nextAction != null) nextAction else admissionId,
      ];
  final Set<String> defaultIds = defaults
      .map((AppListTableColumn<IcuBed> column) => column.key)
      .toSet();
  final List<AppListTableColumn<IcuBed>> choices =
      <AppListTableColumn<IcuBed>>[
        if (!defaultIds.contains(admissionId.key)) admissionId,
      ];
  return (defaults: defaults, choices: choices);
}

void _openIpd(BuildContext context, IcuBed bed) {
  final String? admissionId = bed.occupantAdmissionId?.trim();
  final String location = admissionId == null || admissionId.isEmpty
      ? AppRoutes.ipd.path
      : AppRoutes.ipd.location(
          queryParameters: <String, String>{'id': admissionId},
        );
  context.go(location);
}

Future<void> _printIcuBedBoardList(
  BuildContext context,
  WidgetRef ref, {
  required List<IcuBed> beds,
  required List<AppListTableColumn<IcuBed>> columns,
  required AppLocalizations l10n,
}) async {
  final List<AppListTableColumn<IcuBed>> exportColumns = columns
      .where((AppListTableColumn<IcuBed> column) => column.includesInExport)
      .toList(growable: false);
  final List<IcuWorkspacePrintColumn> printColumns =
      <IcuWorkspacePrintColumn>[
        for (final AppListTableColumn<IcuBed> column in exportColumns)
          IcuWorkspacePrintColumn(id: column.key, label: column.label),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final IcuBed bed in beds)
      <String, String>{
        for (final AppListTableColumn<IcuBed> column in exportColumns)
          column.key: _icuBedBoardPrintCellValue(context, bed, column.key),
      },
  ];
  await printIcuWorkspaceList(
    ref: ref,
    context: context,
    title: l10n.icuViewBedBoard,
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.icuBedNoBedsTitle,
  );
}

String _icuBedBoardPrintCellValue(
  BuildContext context,
  IcuBed bed,
  String columnId,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (columnId) {
    'bed' => bed.label ?? bed.id,
    'location' => bed.locationLabel,
    'occupant' => bed.isOccupied
        ? (bed.occupantName ?? l10n.profileUnknownValue)
        : l10n.icuBedVacantLabel,
    'admission_id' => bed.occupantDisplayId ?? l10n.profileUnknownValue,
    'status' => apiLabel(bed.status ?? ''),
    _ => '',
  };
}
