import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_role_tailoring.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Pharmacist Overview: Analytics and Reporting tabs for pharmacy datasets.
class ReportsPharmacyDomainGroups extends StatefulWidget {
  const ReportsPharmacyDomainGroups({
    required this.l10n,
    required this.policy,
    required this.allowedPanels,
    required this.datasetShortcuts,
    required this.onOpenDataset,
    required this.onOpenPanel,
    this.onOpenCatalogDefinition,
    super.key,
  });

  final AppLocalizations l10n;
  final AppAccessPolicy policy;
  final List<ReportsWorkspacePanel> allowedPanels;
  final List<ReportsLookupOption> datasetShortcuts;
  final ValueChanged<String> onOpenDataset;
  final ValueChanged<ReportsWorkspacePanel> onOpenPanel;
  final VoidCallback? onOpenCatalogDefinition;

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
  String _selectedTabId = ReportsPharmacyDomainGroups.analyticsTabId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = widget.l10n;
    final bool canWrite = canWriteReports(widget.policy);
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
          _PharmacyTabBody(
            body: l10n.reportsPharmacyAnalyticsBody,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (analyticsDatasets.isEmpty)
                  AppMutedText(l10n.reportsPharmacyAnalyticsEmpty)
                else
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children: <Widget>[
                      for (final ReportsLookupOption dataset
                          in analyticsDatasets)
                        ActionChip(
                          avatar: const Icon(
                            Icons.bar_chart_outlined,
                            size: 18,
                          ),
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
                        onPressed: () =>
                            widget.onOpenDataset(insight.datasetId),
                      ),
                  ],
                ),
              ],
            ),
          )
        else
          _PharmacyTabBody(
            body: l10n.reportsPharmacyReportingBody,
            child: Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                if (widget.allowedPanels.contains(
                  ReportsWorkspacePanel.catalog,
                ))
                  ActionChip(
                    avatar: const Icon(Icons.library_books_outlined, size: 18),
                    label: Text(l10n.reportsOverviewBrowseCatalogAction),
                    onPressed: () {
                      widget.onOpenPanel(ReportsWorkspacePanel.catalog);
                    },
                  ),
                if (widget.allowedPanels.contains(
                  ReportsWorkspacePanel.delivery,
                ))
                  ActionChip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(l10n.reportsOverviewViewDeliveryAction),
                    onPressed: () {
                      widget.onOpenPanel(ReportsWorkspacePanel.delivery);
                    },
                  ),
                if (canWrite &&
                    widget.allowedPanels.contains(
                      ReportsWorkspacePanel.catalog,
                    ))
                  ActionChip(
                    avatar: const Icon(Icons.play_arrow_outlined, size: 18),
                    label: Text(l10n.reportsOverviewCreateReportAction),
                    onPressed: () {
                      widget.onOpenPanel(ReportsWorkspacePanel.catalog);
                      widget.onOpenCatalogDefinition?.call();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PharmacyTabBody extends StatelessWidget {
  const _PharmacyTabBody({required this.body, required this.child});

  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        child,
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
