import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_labels.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/pharmacy_reporting_report_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Pharmacist Overview: Reporting and Analytics tabs for pharmacy datasets.
///
/// Reporting chrome is shared ([ModuleReportingDomainTabs] +
/// [ModuleReportingShell]); Analytics insights stay pharmacy-specific.
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
    return reportsOwnsDomainReporting(policy, ReportsDomainPack.pharmacy);
  }

  static const String analyticsTabId =
      ModuleReportingDomainTabs.analyticsTabId;
  static const String reportingTabId =
      ModuleReportingDomainTabs.reportingTabId;

  @override
  State<ReportsPharmacyDomainGroups> createState() =>
      _ReportsPharmacyDomainGroupsState();
}

class _ReportsPharmacyDomainGroupsState
    extends State<ReportsPharmacyDomainGroups> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);

  String _selectedTabId = ReportsPharmacyDomainGroups.reportingTabId;
  late final TextEditingController _reportingSearchController;
  late final ValueNotifier<String> _reportingSearchQuery;
  Timer? _searchDebounce;
  AppSearchBarFilterValue _reportingFilters = AppSearchBarFilterValue.empty;
  late final List<PharmacyReportingCategory> _catalog;
  late final int _totalReports;
  late final ModuleReportingCatalogExpansionController _expansionController;
  late ModuleReportingLabels _labels;

  @override
  void initState() {
    super.initState();
    _reportingSearchController = TextEditingController();
    _reportingSearchQuery = ValueNotifier<String>('');
    _catalog = pharmacyReportingCatalogForPolicy(widget.policy);
    _totalReports = _catalog.fold<int>(
      0,
      (int sum, PharmacyReportingCategory category) =>
          sum + category.reports.length,
    );
    _expansionController = ModuleReportingCatalogExpansionController(
      categoryIds: _catalog.map(
        (PharmacyReportingCategory category) => category.id,
      ),
    );
    _labels = pharmacyReportingLabels(widget.l10n);
  }

  @override
  void didUpdateWidget(covariant ReportsPharmacyDomainGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.l10n != widget.l10n) {
      _labels = pharmacyReportingLabels(widget.l10n);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _expansionController.dispose();
    _reportingSearchQuery.dispose();
    _reportingSearchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      if (_reportingSearchQuery.value == value) {
        return;
      }
      _reportingSearchQuery.value = value;
    });
  }

  void _applySearchNow(String value) {
    _searchDebounce?.cancel();
    if (_reportingSearchQuery.value == value) {
      return;
    }
    _reportingSearchQuery.value = value;
  }

  @override
  Widget build(BuildContext context) {
    return ModuleReportingDomainTabs(
      labels: _labels,
      selectedId: _selectedTabId,
      onTabTapped: (String tabId) {
        if (tabId == _selectedTabId) {
          return;
        }
        setState(() => _selectedTabId = tabId);
        widget.onTabChanged?.call(tabId);
      },
      reportingChild: ModuleReportingShell(
        catalog: _catalog,
        labels: _labels,
        searchController: _reportingSearchController,
        searchQuery: _reportingSearchQuery,
        filters: _reportingFilters,
        expansionController: _expansionController,
        totalReports: _totalReports,
        onFiltersChanged: (AppSearchBarFilterValue value) {
          setState(() => _reportingFilters = value);
        },
        onSearchChanged: _scheduleSearch,
        onSearchSubmitted: _applySearchNow,
        onSearchCleared: () {
          _reportingSearchController.clear();
          _applySearchNow('');
        },
        onReportPressed: (ModuleReportingReport report) {
          final ReportsRepository repository = ProviderScope.containerOf(
            context,
          ).read(reportsRepositoryProvider);
          openPharmacyReportingReportDialog(
            context: context,
            report: report,
            policy: widget.policy,
            repository: repository,
          );
        },
      ),
      analyticsChild: _PharmacyAnalyticsTabBody(
        l10n: widget.l10n,
        datasetShortcuts: widget.datasetShortcuts,
        onOpenDataset: widget.onOpenDataset,
      ),
    );
  }
}

class _PharmacyAnalyticsTabBody extends StatelessWidget {
  const _PharmacyAnalyticsTabBody({
    required this.l10n,
    required this.datasetShortcuts,
    required this.onOpenDataset,
  });

  final AppLocalizations l10n;
  final List<ReportsLookupOption> datasetShortcuts;
  final ValueChanged<String> onOpenDataset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ReportsLookupOption> analyticsDatasets = datasetShortcuts
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

    return Column(
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
                  onPressed: () => onOpenDataset(dataset.id),
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
                onPressed: () => onOpenDataset(insight.datasetId),
              ),
          ],
        ),
      ],
    );
  }
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
