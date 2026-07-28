import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_vitals_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_actions.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_columns.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_filters.dart';
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

    return AppListTable<NursingWorkItem>(
      page: state.worklist,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityStorageKey: 'nursing_${scope.name}',
      columnWidthStorageKey: 'nursing_cw_${scope.name}',
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<NursingWorkItem> page) {
        return nursingPageLabel(context, page);
      },
      onPageChanged: controller.changePage,
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
        advancedFilterButtonLabel: l10n.nursingAdvancedFiltersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.nursingApplyFiltersLabel,
        advancedFilterResetLabel: l10n.nursingResetFiltersLabel,
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
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.nursingNoWorklistTitle,
        body: l10n.nursingNoWorklistBody,
        icon: Icons.assignment_outlined,
      ),
      columnChoices: nursingColumnChoicesForScope(l10n, scope),
      columns: nursingColumnsForScope(l10n, scope),
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
            if (subtitle.isNotEmpty)
              AppListTableMobileMeta(label: subtitle),
          ],
        );
      },
    );
  }
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
