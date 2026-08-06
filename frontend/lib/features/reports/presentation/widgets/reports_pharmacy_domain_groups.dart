import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_role_tailoring.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Pharmacist Overview groups: Analysis, Analytics, and Reporting shortcuts.
class ReportsPharmacyDomainGroups extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canWrite = canWriteReports(policy);
    final List<ReportsLookupOption> analysisDatasets = datasetShortcuts
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
        AppSectionPanel(
          title: l10n.reportsPharmacyAnalysisTitle,
          leadingIcon: Icons.query_stats_outlined,
          density: AppContentPanelDensity.compact,
          children: <Widget>[
            Text(
              l10n.reportsPharmacyAnalysisBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (analysisDatasets.isEmpty)
              AppMutedText(l10n.reportsPharmacyAnalysisEmpty)
            else
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final ReportsLookupOption dataset in analysisDatasets)
                    ActionChip(
                      avatar: const Icon(Icons.bar_chart_outlined, size: 18),
                      label: Text(dataset.label),
                      onPressed: () => onOpenDataset(dataset.id),
                    ),
                ],
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.reportsPharmacyAnalyticsTitle,
          leadingIcon: Icons.insights_outlined,
          density: AppContentPanelDensity.compact,
          children: <Widget>[
            Text(
              l10n.reportsPharmacyAnalyticsBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
        ),
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.reportsPharmacyReportingTitle,
          leadingIcon: Icons.description_outlined,
          density: AppContentPanelDensity.compact,
          children: <Widget>[
            Text(
              l10n.reportsPharmacyReportingBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                if (allowedPanels.contains(ReportsWorkspacePanel.catalog))
                  ActionChip(
                    avatar: const Icon(Icons.library_books_outlined, size: 18),
                    label: Text(l10n.reportsOverviewBrowseCatalogAction),
                    onPressed: () {
                      onOpenPanel(ReportsWorkspacePanel.catalog);
                    },
                  ),
                if (allowedPanels.contains(ReportsWorkspacePanel.delivery))
                  ActionChip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(l10n.reportsOverviewViewDeliveryAction),
                    onPressed: () {
                      onOpenPanel(ReportsWorkspacePanel.delivery);
                    },
                  ),
                if (canWrite &&
                    allowedPanels.contains(ReportsWorkspacePanel.catalog))
                  ActionChip(
                    avatar: const Icon(Icons.play_arrow_outlined, size: 18),
                    label: Text(l10n.reportsOverviewCreateReportAction),
                    onPressed: () {
                      onOpenPanel(ReportsWorkspacePanel.catalog);
                      onOpenCatalogDefinition?.call();
                    },
                  ),
              ],
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
