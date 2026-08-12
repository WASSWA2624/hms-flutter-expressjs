import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_shift_context_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_vitals_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_actions.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_columns.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_filters.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class NursingWorklistPanel extends ConsumerWidget {
  const NursingWorklistPanel({
    required this.state,
    required this.scope,
    required this.searchController,
    required this.filterValue,
    required this.onFilterChanged,
    required this.columnVisibilityController,
    super.key,
  });

  final NursingWorkspaceState state;
  final NursingQueueScope scope;
  final TextEditingController searchController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;
  final AppListTableColumnVisibilityController<NursingWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool showNextAction = nursingBoardShowsNextActionColumn(
      policy,
      scope,
    );
    final bool canExport = canExportNursingWorkspace(policy);
    final bool canPrint = canPrintNursingWorkspace(policy);

    return AppListTable<NursingWorkItem>(
      page: state.worklist,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      columnVisibilityStorageKey: 'nursing_${scope.name}',
      columnWidthStorageKey: 'nursing_cw_${scope.name}',
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<NursingWorkItem> page) {
        return nursingPageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      enableExport: true,
      canExport: canExport,
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
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: () => _printNursingWorklist(
        context,
        ref,
        state: state,
        scope: scope,
        policy: policy,
        l10n: l10n,
      ),
      exportConfig: AppListTableExportConfig<NursingWorkItem>(
        fileNameStem: 'nursing_${scope.name}',
        dateOf: (NursingWorkItem item) => item.dueReferenceAt ?? item.admittedAt,
        sheetName: _scopeLabel(l10n, scope),
      ),
      onRowSelected: (NursingWorkItem item) {
        openNursingPatientDetailDialog(
          context,
          ref,
          item,
          omitNextActionKind: nursingResolveNextActionKind(item, scope),
        );
      },
      search: AppListTableSearch<NursingWorkItem>(
        controller: searchController,
        semanticLabel: l10n.nursingSearchLabel,
        hintText: l10n.nursingSearchHint,
        matcher: nursingWorklistSearchMatcher,
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        searchFieldLabel: l10n.nursingSearchFieldLabel,
        allFieldsLabel: l10n.nursingAllFieldsLabel,
        dateFilterLabel: l10n.nursingDateFilterLabel,
        dateFromLabel: l10n.nursingDateFromLabel,
        dateToLabel: l10n.nursingDateToLabel,
        datePickerButtonLabel: l10n.nursingDatePickerLabel,
        invalidDateMessage: l10n.nursingInvalidDateMessage,
        currentDate: DateTime.now(),
        searchFields: nursingWorklistSearchFields(l10n),
        textFilters: nursingWorklistTextFilters(l10n),
        filterGroups: nursingWorklistFilterGroups(l10n),
        filterValue: filterValue,
        hasActiveFilters: state.query.hasAdvancedFilters,
        onFilterChanged: onFilterChanged,
        // Filters → Settings → Export → Print → Shift context.
        trailingActions: _shiftContextSearchActions(context, policy),
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.nursingNoWorklistTitle,
        body: l10n.nursingNoWorklistBody,
        icon: Icons.assignment_outlined,
      ),
      columnChoices: nursingColumnChoicesForScope(
        l10n,
        scope,
        policy: policy,
      ),
      columns: nursingColumnsForScope(l10n, scope, policy: policy),
      mobileItemBuilder: (BuildContext context, NursingWorkItem item) {
        final String subtitle = nursingJoinDisplay(<String?>[
          item.locationLabel,
          nursingTaskTypeLabel(context, item),
          nursingDueTimeLabel(context, item),
        ]);
        return AppListTableMobileItem(
          title: item.displayTitle,
          caption: nursingJoinDisplay(<String?>[
            item.patientDisplayId,
            item.encounterDisplayId,
            item.displayId,
          ]),
          showAvatar: false,
          meta: <AppListTableMobileMeta>[
            if (scope == NursingQueueScope.urgent ||
                scope == NursingQueueScope.all ||
                scope == NursingQueueScope.assignedWard)
              AppListTableMobileMeta(
                label: nursingPriorityStatus(context, item).label,
              ),
            AppListTableMobileMeta(label: nursingSummaryStatus(item).label),
            if (subtitle.isNotEmpty) AppListTableMobileMeta(label: subtitle),
          ],
          // Same stage write as the desktop next-action column (sole primary).
          // Compact avoids overflow beside title/meta on narrow viewports;
          // tooltip + semanticLabel keep the action labeled for novices/a11y.
          trailing: showNextAction
              ? NursingNextActionCell(
                  item: item,
                  scope: scope,
                  compact: true,
                )
              : null,
        );
      },
    );
  }

  /// Shift context lives after Print in the search bar (not the tab toolbar).
  List<AppSearchBarAction> _shiftContextSearchActions(
    BuildContext context,
    AppAccessPolicy policy,
  ) {
    if (!canReadNursingShiftContext(policy)) {
      return const <AppSearchBarAction>[];
    }
    final String label = context.l10n.nursingShiftContextTitle;
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.assignment_ind_outlined,
        label: label,
        tooltip: label,
        onPressed: () {
          showAppDialog<void>(
            context: context,
            builder: (BuildContext dialogContext) =>
                const NursingShiftContextDialog(),
          );
        },
      ),
    ];
  }
}

String _scopeLabel(AppLocalizations l10n, NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.all => l10n.nursingScopeAllLabel,
    NursingQueueScope.assignedWard => l10n.nursingScopeAssignedWardLabel,
    NursingQueueScope.urgent => l10n.nursingScopeUrgentLabel,
    NursingQueueScope.medicationDue => l10n.nursingScopeMedicationDueLabel,
    NursingQueueScope.handoverPending => l10n.nursingScopeHandoverPendingLabel,
    NursingQueueScope.transferPending => l10n.nursingScopeTransferPendingLabel,
    NursingQueueScope.dischargePending =>
      l10n.nursingScopeDischargePendingLabel,
  };
}

Future<void> _printNursingWorklist(
  BuildContext context,
  WidgetRef ref, {
  required NursingWorkspaceState state,
  required NursingQueueScope scope,
  required AppAccessPolicy policy,
  required AppLocalizations l10n,
}) async {
  final List<AppListTableColumn<NursingWorkItem>> columns =
      <AppListTableColumn<NursingWorkItem>>[
        ...nursingColumnsForScope(l10n, scope, policy: policy),
        ...nursingColumnChoicesForScope(l10n, scope, policy: policy),
      ].where(
        (AppListTableColumn<NursingWorkItem> column) => column.includesInExport,
      ).toList(growable: false);
  final List<NursingWorkspacePrintColumn> printColumns =
      <NursingWorkspacePrintColumn>[
        for (final AppListTableColumn<NursingWorkItem> column in columns)
          NursingWorkspacePrintColumn(id: column.key, label: column.label),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final NursingWorkItem item in state.worklist.items)
      <String, String>{
        for (final AppListTableColumn<NursingWorkItem> column in columns)
          column.key: _nursingWorklistPrintCellValue(context, item, column.key),
      },
  ];
  await printNursingWorkspaceList(
    ref: ref,
    context: context,
    title: _scopeLabel(l10n, scope),
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.nursingNoWorklistTitle,
  );
}

String _nursingWorklistPrintCellValue(
  BuildContext context,
  NursingWorkItem item,
  String columnId,
) {
  return switch (columnId) {
    'patient' => item.displayTitle,
    'location' => item.locationLabel ?? context.l10n.profileUnknownValue,
    'task_type' => nursingTaskTypeLabel(context, item),
    'priority' => nursingPriorityStatus(context, item).label,
    'status' => nursingSummaryStatus(item).label,
    'admission' => nursingAdmissionLabel(context, item),
    'due_time' => nursingDueTimeLabel(context, item),
    // Product exception (tables.mdc): no assignee API field — synthetic summary.
    'responsible_nurse' => nursingResponsibleNurseLabel(context, item),
    'observations' => nursingLastObservationLabel(context, item),
    'medication_due_count' => '${item.medicationDueCount}',
    'transfer_status' => nursingApiLabel(
      item.transferStatus ?? context.l10n.profileUnknownValue,
    ),
    'discharge_status' => nursingApiLabel(
      item.dischargeStatus ?? context.l10n.profileUnknownValue,
    ),
    _ => '',
  };
}

Future<void> openNursingPatientDetailDialog(
  BuildContext context,
  WidgetRef ref,
  NursingPatientSummary summary, {
  NursingNextActionKind? omitNextActionKind,
}) async {
  final NursingWorkspaceController controller = ref.read(
    nursingWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    nursingShowFailureIfNeeded(context, failure);
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => NursingPatientDetailDialog(
      omitNextActionKind: omitNextActionKind,
    ),
  );
}

/// Panel deep links open the mutation dialog directly (no empty detail shell).
Future<void> openNursingFocusedAction(
  BuildContext context,
  WidgetRef ref,
  NursingPatientSummary summary,
  NursingDetailPanel panel,
) async {
  final NursingWorkspaceController controller = ref.read(
    nursingWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    nursingShowFailureIfNeeded(context, failure);
    return;
  }

  final NursingPatientDetail? detail = nursingSelectedDetailFromState(
    ref.read(nursingWorkspaceControllerProvider),
  );
  if (detail == null || !context.mounted) {
    return;
  }

  switch (panel) {
    case NursingDetailPanel.vitals:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NursingVitalsDialog(),
        ),
      );
    case NursingDetailPanel.medication:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NursingMedicationDialog(detail: detail),
        ),
      );
    case NursingDetailPanel.handover:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NursingHandoverDialog(),
        ),
      );
    case NursingDetailPanel.transfer:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NursingTransferDialog(detail: detail),
        ),
      );
    case NursingDetailPanel.discharge:
      await nursingShowActionResult(
        context,
        showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NursingDischargeClearanceDialog(detail: detail),
        ),
      );
    case NursingDetailPanel.checklist:
      break;
  }
}
