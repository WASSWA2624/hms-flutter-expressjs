import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_columns.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_filters.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_patient_cell.dart';
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
    super.key,
  });

  final IcuWorkspaceState state;
  final IcuWorkspaceSection section;
  final AccessRequirement writeRequirement;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<IcuPatientSummary>
  columnVisibilityController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppPage<IcuPatientSummary> displayPage = icuBoardDisplayPage(
      state.board,
      filterValue,
    );

    return AppListTable<IcuPatientSummary>(
      page: displayPage,
      isLoading: state.isRefreshingBoard,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'icu_board',
      columnWidthStorageKey: 'icu_cw_board',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.icuTableSettingsTitle,
      search: AppListTableSearch<IcuPatientSummary>(
        controller: searchController,
        semanticLabel: l10n.icuSearchHint,
        hintText: l10n.icuSearchHint,
        matcher: (IcuPatientSummary item, String query) =>
            item.matchesSearch(query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.icuAdvancedFiltersLabel,
        advancedFilterTitle: l10n.icuAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.icuApplyFiltersLabel,
        advancedFilterResetLabel: l10n.icuResetFiltersLabel,
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
          openIcuDetailDialog(context, ref, state, summary, writeRequirement),
        );
      },
      rowColorBuilder: _rowColor,
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.icuNoPatientsTitle,
        body: l10n.icuNoPatientsBody,
        icon: Icons.bed_outlined,
      ),
      columns: icuColumnsForSection(
        l10n,
        section,
        writeRequirement: writeRequirement,
      ),
      columnChoices: icuColumnChoicesForSection(
        l10n,
        section,
        writeRequirement: writeRequirement,
      ),
      mobileItemBuilder: (BuildContext context, IcuPatientSummary item) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IcuPatientCell(item: item),
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  ...icuMobilePriorityFields(context, item, section),
                  AppWorkspaceStatusBadge(status: icuStatus(item)),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              icuNextActionColumn(
                l10n,
                section,
                writeRequirement: writeRequirement,
              ).cellBuilder(context, item),
            ],
          ),
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
