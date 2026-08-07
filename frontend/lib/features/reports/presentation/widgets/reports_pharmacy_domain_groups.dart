import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/pharmacy_reporting_catalog_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Pharmacist Overview: Analytics and Reporting tabs for pharmacy datasets.
class ReportsPharmacyDomainGroups extends StatefulWidget {
  const ReportsPharmacyDomainGroups({
    required this.l10n,
    required this.policy,
    required this.datasetShortcuts,
    required this.onOpenDataset,
    this.onTabChanged,
    super.key,
  });

  final AppLocalizations l10n;
  final AppAccessPolicy policy;
  final List<ReportsLookupOption> datasetShortcuts;
  final ValueChanged<String> onOpenDataset;
  final ValueChanged<String>? onTabChanged;

  static bool shouldShow(AppAccessPolicy policy) {
    return reportsDomainPacks(policy).contains(ReportsDomainPack.pharmacy);
  }

  static const String analyticsTabId = 'analytics';
  static const String reportingTabId = 'reporting';

  @override
  State<ReportsPharmacyDomainGroups> createState() =>
      _ReportsPharmacyDomainGroupsState();
}

class _ReportsPharmacyDomainGroupsState
    extends State<ReportsPharmacyDomainGroups> {
  static const String _categoryFilterKey = 'category';
  static const String _subcategoryFilterKey = 'subcategory';
  static const String _contentKindFilterKey = 'content_kind';

  String _selectedTabId = ReportsPharmacyDomainGroups.analyticsTabId;
  late final TextEditingController _reportingSearchController;
  AppSearchBarFilterValue _reportingFilters = AppSearchBarFilterValue.empty;
  late final List<PharmacyReportingCategory> _catalog;

  @override
  void initState() {
    super.initState();
    _reportingSearchController = TextEditingController();
    _catalog = pharmacyReportingCatalog();
  }

  @override
  void dispose() {
    _reportingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = widget.l10n;
    final List<ReportsLookupOption> analyticsDatasets = widget.datasetShortcuts
        .where(
          (ReportsLookupOption option) =>
              option.id == 'pharmacy_drug_consumption' ||
              option.id == 'pharmacy_dispense_throughput' ||
              option.id == 'inventory_stock_risk',
        )
        .toList(growable: false);
    final List<_PharmacyInsightAction> insights = <_PharmacyInsightAction>[
      _PharmacyInsightAction(
        datasetId: 'pharmacy_drug_consumption',
        label: l10n.reportsPharmacyAnalyticsTopConsumedLabel,
        icon: Icons.medication_outlined,
      ),
      _PharmacyInsightAction(
        datasetId: 'inventory_stock_risk',
        label: l10n.reportsPharmacyAnalyticsStockRiskLabel,
        icon: Icons.inventory_2_outlined,
      ),
      _PharmacyInsightAction(
        datasetId: 'inventory_stock_risk',
        label: l10n.reportsPharmacyAnalyticsExpiryLabel,
        icon: Icons.event_busy_outlined,
      ),
      _PharmacyInsightAction(
        datasetId: 'inventory_stock_risk',
        label: l10n.reportsPharmacyAnalyticsStockingLabel,
        icon: Icons.local_shipping_outlined,
      ),
      _PharmacyInsightAction(
        datasetId: 'pharmacy_drug_consumption',
        label: l10n.reportsPharmacyAnalyticsSourceMixLabel,
        icon: Icons.storefront_outlined,
      ),
      _PharmacyInsightAction(
        datasetId: 'pharmacy_drug_consumption',
        label: l10n.reportsPharmacyAnalyticsMarginLabel,
        icon: Icons.payments_outlined,
      ),
    ];

    final List<PharmacyReportingCategory> filteredCatalog =
        filterPharmacyReportingCatalog(
          catalog: _catalog,
          searchQuery: _reportingSearchController.text,
          categoryIds: _reportingFilters.optionsFor(_categoryFilterKey),
          reportIds: _reportingFilters.optionsFor(_subcategoryFilterKey),
          contentKinds: _reportingFilters.optionsFor(_contentKindFilterKey),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          variant: AppTabStripVariant.nested,
          tabs: <AppTabItem>[
            AppTabItem(
              id: ReportsPharmacyDomainGroups.analyticsTabId,
              label: l10n.reportsPharmacyAnalyticsTitle,
              icon: Icons.insights_outlined,
            ),
            AppTabItem(
              id: ReportsPharmacyDomainGroups.reportingTabId,
              label: l10n.reportsPharmacyReportingTitle,
              icon: Icons.description_outlined,
            ),
          ],
          selectedId: _selectedTabId,
          onTabTapped: (String tabId) {
            setState(() => _selectedTabId = tabId);
            widget.onTabChanged?.call(tabId);
          },
        ),
        SizedBox(height: theme.spacing.md),
        if (_selectedTabId == ReportsPharmacyDomainGroups.analyticsTabId)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (analyticsDatasets.isEmpty)
                AppMutedText(l10n.reportsPharmacyAnalyticsEmpty)
              else
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  children: <Widget>[
                    for (final ReportsLookupOption dataset in analyticsDatasets)
                      ActionChip(
                        avatar: const Icon(Icons.bar_chart_outlined, size: 18),
                        label: Text(dataset.label),
                        onPressed: () => widget.onOpenDataset(dataset.id),
                      ),
                  ],
                ),
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final _PharmacyInsightAction insight in insights)
                    ActionChip(
                      avatar: Icon(insight.icon, size: 18),
                      label: Text(insight.label),
                      onPressed: () => widget.onOpenDataset(insight.datasetId),
                    ),
                ],
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppSearchBar(
                controller: _reportingSearchController,
                semanticLabel: l10n.reportsPharmacyReportingSearchLabel,
                hintText: l10n.reportsPharmacyReportingSearchHint,
                clearLabel: l10n.reportsClearSearchLabel,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => setState(() {}),
                onClear: () {
                  _reportingSearchController.clear();
                  setState(() {});
                },
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
                advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                dateFilterLabel: l10n.reportsDateFilterLabel,
                dateFromLabel: l10n.reportsDateFromLabel,
                dateToLabel: l10n.reportsDateToLabel,
                datePickerButtonLabel: l10n.reportsDatePickerLabel,
                invalidDateMessage: l10n.reportsInvalidDateMessage,
                filterGroups: <AppSearchBarFilterGroup>[
                  AppSearchBarFilterGroup(
                    key: _categoryFilterKey,
                    label: l10n.reportsPharmacyReportingCategoryFilterLabel,
                    allLabel: l10n.reportsPharmacyReportingCategoryAllLabel,
                    allowMultiple: true,
                    choices: <AppSearchBarFilterChoice>[
                      for (final PharmacyReportingCategory category in _catalog)
                        AppSearchBarFilterChoice(
                          value: category.id,
                          label: pharmacyReportingCategoryLabel(
                            l10n,
                            category.id,
                          ),
                          icon: category.icon,
                        ),
                    ],
                  ),
                  AppSearchBarFilterGroup(
                    key: _subcategoryFilterKey,
                    label: l10n.reportsPharmacyReportingSubcategoryFilterLabel,
                    allLabel: l10n.reportsPharmacyReportingSubcategoryAllLabel,
                    allowMultiple: true,
                    choices: _subcategoryFilterChoices(
                      l10n: l10n,
                      catalog: _catalog,
                      selectedCategoryIds: _reportingFilters.optionsFor(
                        _categoryFilterKey,
                      ),
                    ),
                  ),
                  AppSearchBarFilterGroup(
                    key: _contentKindFilterKey,
                    label: l10n.reportsPharmacyReportingContentKindFilterLabel,
                    allLabel: l10n.reportsPharmacyReportingContentKindAllLabel,
                    allowMultiple: true,
                    choices: <AppSearchBarFilterChoice>[
                      AppSearchBarFilterChoice(
                        value: PharmacyReportingContentKind.table.name,
                        label: l10n.reportsPharmacyReportingContentKindTable,
                        icon: Icons.table_chart_outlined,
                      ),
                      AppSearchBarFilterChoice(
                        value: PharmacyReportingContentKind.chart.name,
                        label: l10n.reportsPharmacyReportingContentKindChart,
                        icon: Icons.bar_chart_outlined,
                      ),
                    ],
                  ),
                ],
                filterValue: _reportingFilters,
                hasActiveFilters: _reportingFilters.isActive,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _reportingFilters = value);
                },
              ),
              SizedBox(height: theme.spacing.md),
              PharmacyReportingCatalogPanel(
                l10n: l10n,
                policy: widget.policy,
                categories: filteredCatalog,
              ),
            ],
          ),
      ],
    );
  }
}

List<AppSearchBarFilterChoice> _subcategoryFilterChoices({
  required AppLocalizations l10n,
  required List<PharmacyReportingCategory> catalog,
  required Set<String> selectedCategoryIds,
}) {
  final List<AppSearchBarFilterChoice> choices = <AppSearchBarFilterChoice>[];
  for (final PharmacyReportingCategory category in catalog) {
    if (selectedCategoryIds.isNotEmpty &&
        !selectedCategoryIds.contains(category.id)) {
      continue;
    }
    for (final PharmacyReportingReport report in category.reports) {
      choices.add(
        AppSearchBarFilterChoice(
          value: report.id,
          label: report.label,
          icon: report.contentKind == PharmacyReportingContentKind.chart
              ? Icons.bar_chart_outlined
              : Icons.description_outlined,
        ),
      );
    }
  }
  return choices;
}

final class _PharmacyInsightAction {
  const _PharmacyInsightAction({
    required this.datasetId,
    required this.label,
    required this.icon,
  });

  final String datasetId;
  final String label;
  final IconData icon;
}
