import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Pharmacist Overview: Analytics and Reporting tabs for pharmacy datasets.
class ReportsPharmacyDomainGroups extends StatefulWidget {
  const ReportsPharmacyDomainGroups({
    required this.l10n,
    required this.datasetShortcuts,
    required this.onOpenDataset,
    super.key,
  });

  final AppLocalizations l10n;
  final List<ReportsLookupOption> datasetShortcuts;
  final ValueChanged<String> onOpenDataset;

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

  String _selectedTabId = ReportsPharmacyDomainGroups.analyticsTabId;
  late final TextEditingController _reportingSearchController;
  AppSearchBarFilterValue _reportingFilters = AppSearchBarFilterValue.empty;

  @override
  void initState() {
    super.initState();
    _reportingSearchController = TextEditingController();
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
          AppSearchBar(
            controller: _reportingSearchController,
            semanticLabel: l10n.reportsPharmacyReportingSearchLabel,
            hintText: l10n.reportsPharmacyReportingSearchHint,
            clearLabel: l10n.reportsClearSearchLabel,
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
                choices: _pharmacyReportingCategoryChoices(l10n),
              ),
            ],
            filterValue: _reportingFilters,
            hasActiveFilters: _reportingFilters.isActive,
            onFilterChanged: (AppSearchBarFilterValue value) {
              setState(() => _reportingFilters = value);
            },
          ),
      ],
    );
  }
}

List<AppSearchBarFilterChoice> _pharmacyReportingCategoryChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: 'sales_revenue',
      label: l10n.reportsPharmacyReportingCategorySales,
      icon: Icons.point_of_sale_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'inventory_stock',
      label: l10n.reportsPharmacyReportingCategoryInventory,
      icon: Icons.inventory_2_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'medicines_products',
      label: l10n.reportsPharmacyReportingCategoryMedicines,
      icon: Icons.medication_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'purchasing_suppliers',
      label: l10n.reportsPharmacyReportingCategoryPurchasing,
      icon: Icons.local_shipping_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'dispensing',
      label: l10n.reportsPharmacyReportingCategoryDispensing,
      icon: Icons.medical_services_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'patients_customers',
      label: l10n.reportsPharmacyReportingCategoryCustomers,
      icon: Icons.people_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'expiry_loss',
      label: l10n.reportsPharmacyReportingCategoryExpiry,
      icon: Icons.event_busy_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'financial',
      label: l10n.reportsPharmacyReportingCategoryFinancial,
      icon: Icons.payments_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'staff_activity',
      label: l10n.reportsPharmacyReportingCategoryStaff,
      icon: Icons.badge_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'branch',
      label: l10n.reportsPharmacyReportingCategoryBranch,
      icon: Icons.storefront_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'stock_transfers',
      label: l10n.reportsPharmacyReportingCategoryTransfers,
      icon: Icons.swap_horiz_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'prescription_clinical',
      label: l10n.reportsPharmacyReportingCategoryPrescription,
      icon: Icons.description_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'controlled_medicines',
      label: l10n.reportsPharmacyReportingCategoryControlled,
      icon: Icons.lock_outline,
    ),
    AppSearchBarFilterChoice(
      value: 'supplier_procurement',
      label: l10n.reportsPharmacyReportingCategoryProcurement,
      icon: Icons.handshake_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'operational_kpis',
      label: l10n.reportsPharmacyReportingCategoryKpis,
      icon: Icons.speed_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'audit_compliance',
      label: l10n.reportsPharmacyReportingCategoryAudit,
      icon: Icons.fact_check_outlined,
    ),
    AppSearchBarFilterChoice(
      value: 'management_executive',
      label: l10n.reportsPharmacyReportingCategoryManagement,
      icon: Icons.analytics_outlined,
    ),
  ];
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
