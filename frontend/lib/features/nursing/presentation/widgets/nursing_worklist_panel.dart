import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_cell.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
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
        openNursingPatientDetailDialog(context, ref, item);
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
        return _NursingMobileListItem(item: item, scope: scope);
      },
    );
  }
}

class _NursingMobileListItem extends ConsumerWidget {
  const _NursingMobileListItem({required this.item, required this.scope});

  final NursingWorkItem item;
  final NursingQueueScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = nursingJoinDisplay(<String?>[
      item.locationLabel,
      nursingTaskTypeLabel(context, item),
      nursingDueTimeLabel(context, item),
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NursingPatientCell(item: item),
          SizedBox(height: theme.spacing.xs),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (scope == NursingQueueScope.urgent ||
                  scope == NursingQueueScope.all ||
                  scope == NursingQueueScope.assignedWard)
                AppWorkspaceStatusBadge(
                  status: nursingPriorityStatus(context, item),
                ),
              AppWorkspaceStatusBadge(status: nursingSummaryStatus(item)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: NursingNextActionCell(item: item, scope: scope),
          ),
        ],
      ),
    );
  }
}

Future<void> openNursingPatientDetailDialog(
  BuildContext context,
  WidgetRef ref,
  NursingPatientSummary summary,
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
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => const NursingPatientDetailDialog(),
  );
}
