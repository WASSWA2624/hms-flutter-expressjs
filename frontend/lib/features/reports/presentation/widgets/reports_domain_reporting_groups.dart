import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/domain_reporting_catalogs.dart';
import 'package:hosspi_hms/features/reports/presentation/domain_reporting_labels.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/domain_reporting_data_provider.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Overview Reporting/Analytics chrome for a non-pharmacy owned domain pack.
class ReportsDomainReportingGroups extends StatefulWidget {
  const ReportsDomainReportingGroups({
    required this.l10n,
    required this.policy,
    required this.pack,
    required this.datasetShortcuts,
    required this.onOpenDataset,
    this.onTabChanged,
    super.key,
  });

  final AppLocalizations l10n;
  final AppAccessPolicy policy;
  final ReportsDomainPack pack;
  final List<ReportsLookupOption> datasetShortcuts;
  final ValueChanged<String> onOpenDataset;
  final ValueChanged<String>? onTabChanged;

  static bool shouldShow(AppAccessPolicy policy) {
    return reportsNonPharmacyOwnedPacks(policy).isNotEmpty;
  }

  static const String analyticsTabId = ModuleReportingDomainTabs.analyticsTabId;
  static const String reportingTabId = ModuleReportingDomainTabs.reportingTabId;

  @override
  State<ReportsDomainReportingGroups> createState() =>
      _ReportsDomainReportingGroupsState();
}

class _ReportsDomainReportingGroupsState
    extends State<ReportsDomainReportingGroups> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);

  String _selectedTabId = ReportsDomainReportingGroups.reportingTabId;
  late final TextEditingController _reportingSearchController;
  late final ValueNotifier<String> _reportingSearchQuery;
  Timer? _searchDebounce;
  AppSearchBarFilterValue _reportingFilters = AppSearchBarFilterValue.empty;
  late List<ModuleReportingCategory> _catalog;
  late int _totalReports;
  late ModuleReportingCatalogExpansionController _expansionController;
  late ModuleReportingLabels _labels;

  @override
  void initState() {
    super.initState();
    _reportingSearchController = TextEditingController();
    _reportingSearchQuery = ValueNotifier<String>('');
    _bindPack(widget.pack);
  }

  @override
  void didUpdateWidget(covariant ReportsDomainReportingGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pack != widget.pack || oldWidget.l10n != widget.l10n) {
      _expansionController.dispose();
      _bindPack(widget.pack);
    }
  }

  void _bindPack(ReportsDomainPack pack) {
    _catalog = reportsDomainCatalog(pack);
    _totalReports = _catalog.fold<int>(
      0,
      (int sum, ModuleReportingCategory category) =>
          sum + category.reports.length,
    );
    _expansionController = ModuleReportingCatalogExpansionController(
      categoryIds: _catalog.map(
        (ModuleReportingCategory category) => category.id,
      ),
    );
    _labels = domainReportingLabels(widget.l10n, pack);
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
          final bool canExport = canExportEvidence(widget.policy);
          openModuleReportingReportDialog(
            context: context,
            report: report,
            labels: _labels,
            canExport: canExport,
            dataProvider: DomainReportingDataProvider(repository),
          );
        },
      ),
      analyticsChild: _DomainAnalyticsTabBody(
        pack: widget.pack,
        datasetShortcuts: widget.datasetShortcuts,
        onOpenDataset: widget.onOpenDataset,
      ),
    );
  }
}

class _DomainAnalyticsTabBody extends StatelessWidget {
  const _DomainAnalyticsTabBody({
    required this.pack,
    required this.datasetShortcuts,
    required this.onOpenDataset,
  });

  final ReportsDomainPack pack;
  final List<ReportsLookupOption> datasetShortcuts;
  final ValueChanged<String> onOpenDataset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<String> preferredIds =
        reportsDomainPrimaryDatasets[pack] ?? const <String>[];
    final List<ReportsLookupOption> analyticsDatasets = datasetShortcuts
        .where(
          (ReportsLookupOption option) => preferredIds.contains(option.id),
        )
        .toList(growable: false);
    final List<({String datasetId, String label, IconData icon})> insights =
        reportsDomainAnalyticsInsights(pack);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (analyticsDatasets.isEmpty && insights.isEmpty)
          AppMutedText(l10n.reportsOverviewEmptyBody)
        else ...<Widget>[
          if (analyticsDatasets.isNotEmpty)
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
          if (insights.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final ({String datasetId, String label, IconData icon})
                    insight in insights)
                  ActionChip(
                    avatar: Icon(insight.icon, size: 18),
                    label: Text(insight.label),
                    onPressed: () => onOpenDataset(insight.datasetId),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Hosts owned non-pharmacy domain Reporting, with a pack switcher when needed.
class ReportsOwnedDomainReportingHost extends StatefulWidget {
  const ReportsOwnedDomainReportingHost({
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

  @override
  State<ReportsOwnedDomainReportingHost> createState() =>
      _ReportsOwnedDomainReportingHostState();
}

class _ReportsOwnedDomainReportingHostState
    extends State<ReportsOwnedDomainReportingHost> {
  late ReportsDomainPack _selectedPack;

  @override
  void initState() {
    super.initState();
    _selectedPack = reportsNonPharmacyOwnedPacks(widget.policy).first;
  }

  @override
  void didUpdateWidget(covariant ReportsOwnedDomainReportingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<ReportsDomainPack> packs =
        reportsNonPharmacyOwnedPacks(widget.policy);
    if (!packs.contains(_selectedPack) && packs.isNotEmpty) {
      _selectedPack = packs.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ReportsDomainPack> packs =
        reportsNonPharmacyOwnedPacks(widget.policy);
    if (packs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (packs.length > 1) ...<Widget>[
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              for (final ReportsDomainPack pack in packs)
                ChoiceChip(
                  label: Text(reportsDomainPackTitle(pack)),
                  selected: pack == _selectedPack,
                  onSelected: (bool selected) {
                    if (!selected || pack == _selectedPack) {
                      return;
                    }
                    setState(() => _selectedPack = pack);
                  },
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
        ],
        ReportsDomainReportingGroups(
          key: ValueKey<ReportsDomainPack>(_selectedPack),
          l10n: widget.l10n,
          policy: widget.policy,
          pack: _selectedPack,
          datasetShortcuts: widget.datasetShortcuts,
          onOpenDataset: widget.onOpenDataset,
          onTabChanged: widget.onTabChanged,
        ),
      ],
    );
  }
}
