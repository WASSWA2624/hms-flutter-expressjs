import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_catalog_panel.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_filters_dialog.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

/// Search bar + filters + catalog panel for a module Reporting tab.
class ModuleReportingShell extends StatelessWidget {
  const ModuleReportingShell({
    required this.catalog,
    required this.labels,
    required this.searchController,
    required this.searchQuery,
    required this.filters,
    required this.expansionController,
    required this.totalReports,
    required this.onFiltersChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
    required this.onReportPressed,
    this.forceExpandedWhenSearching = true,
    super.key,
  });

  final List<ModuleReportingCategory> catalog;
  final ModuleReportingLabels labels;
  final TextEditingController searchController;
  final ValueNotifier<String> searchQuery;
  final AppSearchBarFilterValue filters;
  final ModuleReportingCatalogExpansionController expansionController;
  final int totalReports;
  final ValueChanged<AppSearchBarFilterValue> onFiltersChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchCleared;
  final ValueChanged<ModuleReportingReport> onReportPressed;
  final bool forceExpandedWhenSearching;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListenableBuilder(
          listenable: expansionController,
          builder: (BuildContext context, Widget? _) {
            final bool allExpanded = expansionController.allExpanded;
            return AppSearchBar(
              controller: searchController,
              semanticLabel: labels.searchSemanticLabel,
              hintText: labels.searchHint,
              clearLabel: labels.clearSearchLabel,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              onClear: onSearchCleared,
              showAdvancedFilterButton: true,
              advancedFilterButtonLabel: labels.filtersActionLabel,
              enableDateFilter: false,
              hasActiveFilters: moduleReportingFiltersAreActive(
                filters,
                totalCategories: catalog.length,
                totalReports: totalReports,
              ),
              onAdvancedFilterPressed: () {
                unawaited(
                  openModuleReportingFiltersDialog(
                    context: context,
                    catalog: catalog,
                    initialValue: filters,
                    onApply: onFiltersChanged,
                    labels: labels,
                  ),
                );
              },
              trailingActions: <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: allExpanded
                      ? Icons.unfold_less_outlined
                      : Icons.unfold_more_outlined,
                  label: allExpanded
                      ? labels.collapseAllAction
                      : labels.expandAllAction,
                  tooltip: allExpanded
                      ? labels.collapseAllAction
                      : labels.expandAllAction,
                  active: !allExpanded,
                  onPressed: expansionController.toggleExpandCollapseAll,
                ),
              ],
            );
          },
        ),
        SizedBox(height: theme.spacing.md),
        ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (BuildContext context, String query, Widget? _) {
            final bool forceExpanded = forceExpandedWhenSearching &&
                query.trim().isNotEmpty;
            return ModuleReportingCatalogPanel(
              categories: filterModuleReportingCatalog(
                catalog: catalog,
                searchQuery: query,
                categoryIds: filters.optionsFor(
                  ModuleReportingFilterKeys.category,
                ),
                reportIds: filters.optionsFor(
                  ModuleReportingFilterKeys.subcategory,
                ),
                contentKinds: filters.optionsFor(
                  ModuleReportingFilterKeys.contentKind,
                ),
              ),
              expansionController: expansionController,
              categoryTitle: (ModuleReportingCategory category) =>
                  labels.categoryTitle(category.id),
              emptyLabel: labels.catalogEmpty,
              forceExpanded: forceExpanded,
              onReportPressed: onReportPressed,
            );
          },
        ),
      ],
    );
  }
}
