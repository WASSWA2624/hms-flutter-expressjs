import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_columns.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_filters.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class IcuBoardPanel extends ConsumerWidget {
  const IcuBoardPanel({
    required this.state,
    required this.section,
    required this.writeRequirement,
    required this.searchController,
    required this.columnVisibilityController,
    required this.filterValue,
    required this.onFilterChanged,
    this.readRequirement = icuWorkspaceReadRequirement,
    this.showNextAction,
    super.key,
  });

  final IcuWorkspaceState state;
  final IcuWorkspaceSection section;
  final AccessRequirement writeRequirement;
  final AccessRequirement readRequirement;
  final bool? showNextAction;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<IcuPatientSummary>
  columnVisibilityController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppPage<IcuPatientSummary> displayPage = icuBoardDisplayPage(
      state.board,
      filterValue,
    );
    final bool includeNextAction =
        showNextAction ??
        icuBoardShowsNextActionColumn(policy, section);
    final List<AppListTableColumn<IcuPatientSummary>> columns =
        icuColumnsForSection(
          context,
          section,
          writeRequirement: writeRequirement,
          showNextAction: includeNextAction,
        );

    return AppListTable<IcuPatientSummary>(
      page: displayPage,
      isLoading: state.isRefreshingBoard,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'icu_${section.name}',
      columnWidthStorageKey: 'icu_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
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
      exportInvalidDateMessage: l10n.opdInvalidDateMessage,
      enablePrint: true,
      canPrint: canPrintIcuWorkspace(policy),
      printLabel: l10n.commonPrintActionLabel,
      printFailureMessage: l10n.commonTablePrintFailureMessage,
      loadMatchingItems: () => matchingItemsOrThrow(
        controller.loadMatchingBoardItems(),
      ),
      onPrint: (List<IcuPatientSummary> items) => _printIcuBoardList(
        context,
        ref,
        section: section,
        items: items,
        writeRequirement: writeRequirement,
        includeNextAction: includeNextAction,
        l10n: l10n,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<IcuPatientSummary>(
        fileNameStem: 'icu_${section.name}',
        dateOf: (IcuPatientSummary item) => item.admittedAt,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
        sheetName: _sectionLabel(l10n, section),
      ),
      search: AppListTableSearch<IcuPatientSummary>(
        controller: searchController,
        semanticLabel: l10n.icuSearchHint,
        hintText: l10n.icuSearchHint,
        matcher: (IcuPatientSummary item, String query) =>
            item.matchesSearch(query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        enableDateFilter: true,
        dateFilterLabel: l10n.ipdAdmittedAtColumnLabel,
        dateFromLabel: l10n.opdDateFromLabel,
        dateToLabel: l10n.opdDateToLabel,
        datePickerButtonLabel: l10n.opdDatePickerButtonLabel,
        invalidDateMessage: l10n.opdInvalidDateMessage,
        firstDate: DateTime(DateTime.now().year - 10),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
        currentDate: DateTime.now(),
        filterGroups: icuBoardFilterGroups(l10n),
        filterValue: filterValue,
        hasActiveFilters: filterValue.isActive,
        onFilterChanged: onFilterChanged,
      ),
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<IcuPatientSummary> page) {
        return icuBoardPageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: (IcuPatientSummary summary) {
        unawaited(
          openIcuDetailDialog(
            context,
            ref,
            state,
            summary,
            writeRequirement,
            readRequirement: readRequirement,
            omitNextActionKind: icuBoardNextActionKind(summary, section),
          ),
        );
      },
      rowColorBuilder: _rowColor,
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.icuNoPatientsTitle,
        body: l10n.icuNoPatientsBody,
        icon: Icons.bed_outlined,
      ),
      columns: columns,
      columnChoices: icuColumnChoicesForSection(
        context,
        section,
        writeRequirement: writeRequirement,
        showNextAction: includeNextAction,
      ),
      mobileItemBuilder: (BuildContext context, IcuPatientSummary item) {
        return AppListTableMobileItem(
          title: item.displayTitle,
          caption: item.displayId,
          meta: <AppListTableMobileMeta>[
            ...switch (section) {
              IcuWorkspaceSection.critical => <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: alertStatus(l10n, item).label,
                ),
              ],
              IcuWorkspaceSection.transfers => <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: apiLabel(
                    item.transferStatus ?? l10n.profileUnknownValue,
                  ),
                ),
              ],
              IcuWorkspaceSection.discharge => <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: dateTimeLabel(context, item.admittedAt),
                  icon: AppActionIcons.calendar,
                ),
              ],
              IcuWorkspaceSection.ended => <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: dateTimeLabel(context, item.boardIcuStartAt),
                  icon: AppActionIcons.calendar,
                ),
              ],
              _ => <AppListTableMobileMeta>[
                AppListTableMobileMeta(label: apiLabel(item.sourceLabel)),
              ],
            },
            AppListTableMobileMeta(label: icuStatus(item).label),
          ],
          trailing: includeNextAction
              ? IcuNextActionButton(
                  summary: item,
                  section: section,
                  writeRequirement: writeRequirement,
                )
              : null,
        );
      },
    );
  }

  Color? _rowColor(BuildContext context, IcuPatientSummary item) {
    if (!item.hasCriticalAlert) {
      return null;
    }
    return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.22);
  }
}

String icuBoardPageLabel(
  BuildContext context,
  AppPage<IcuPatientSummary> page,
) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

String _sectionLabel(AppLocalizations l10n, IcuWorkspaceSection section) {
  return switch (section) {
    IcuWorkspaceSection.active => l10n.icuActiveIcuLabel,
    IcuWorkspaceSection.critical => l10n.icuCriticalAlertsLabel,
    IcuWorkspaceSection.transfers => l10n.icuTransfersLabel,
    IcuWorkspaceSection.discharge => l10n.icuDischargeReadyLabel,
    IcuWorkspaceSection.ended => l10n.icuEndedStaysLabel,
    IcuWorkspaceSection.all => l10n.icuAllIcuLabel,
    IcuWorkspaceSection.beds => l10n.icuViewBedBoard,
    IcuWorkspaceSection.followUps => l10n.opdFollowUpsTitle,
  };
}

Future<void> _printIcuBoardList(
  BuildContext context,
  WidgetRef ref, {
  required IcuWorkspaceSection section,
  required List<IcuPatientSummary> items,
  required AccessRequirement writeRequirement,
  required bool includeNextAction,
  required AppLocalizations l10n,
}) async {
  final List<AppListTableColumn<IcuPatientSummary>> columns =
      <AppListTableColumn<IcuPatientSummary>>[
        ...icuColumnsForSection(
          context,
          section,
          writeRequirement: writeRequirement,
          showNextAction: includeNextAction,
        ),
        ...icuColumnChoicesForSection(
          context,
          section,
          writeRequirement: writeRequirement,
          showNextAction: includeNextAction,
        ),
      ].where(
        (AppListTableColumn<IcuPatientSummary> column) =>
            column.includesInExport,
      ).toList(growable: false);
  final List<IcuWorkspacePrintColumn> printColumns =
      <IcuWorkspacePrintColumn>[
        for (final AppListTableColumn<IcuPatientSummary> column in columns)
          IcuWorkspacePrintColumn(id: column.key, label: column.label),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final IcuPatientSummary item in items)
      <String, String>{
        for (final AppListTableColumn<IcuPatientSummary> column in columns)
          column.key: _icuBoardPrintCellValue(context, item, column.key),
      },
  ];
  await printIcuWorkspaceList(
    ref: ref,
    context: context,
    title: _sectionLabel(l10n, section),
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.icuNoPatientsTitle,
  );
}

String _icuBoardPrintCellValue(
  BuildContext context,
  IcuPatientSummary item,
  String columnId,
) {
  return icuBoardExportCellValue(context, item, columnId);
}
