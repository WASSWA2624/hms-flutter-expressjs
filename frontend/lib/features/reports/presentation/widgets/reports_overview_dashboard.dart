import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/controllers/reports_workspace_controller.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_overview_mapper.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Overview tab: KPIs, domain shortcuts, queues, and charts — not a worklist.
class ReportsOverviewDashboard extends ConsumerWidget {
  const ReportsOverviewDashboard({
    required this.state,
    required this.policy,
    required this.allowedPanels,
    this.onOpenCatalogDefinition,
    this.onPharmacyOpenDataset,
    this.onPharmacyOpenPanel,
    super.key,
  });

  final ReportsWorkspaceState state;
  final AppAccessPolicy policy;
  final List<ReportsWorkspacePanel> allowedPanels;
  final VoidCallback? onOpenCatalogDefinition;

  /// When set (pharmacist Overview), opens dataset shortcuts in-place.
  final ValueChanged<String>? onPharmacyOpenDataset;

  /// When set (pharmacist Overview), opens catalog/delivery shortcuts in-place.
  final ValueChanged<ReportsWorkspacePanel>? onPharmacyOpenPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ReportsWorkspaceController controller = ref.read(
      reportsWorkspaceControllerProvider.notifier,
    );
    final ReportsWorkspaceOverview overview = state.overview;
    final bool canWrite = canWriteReports(policy);
    final bool showPharmacyGroups = ReportsPharmacyDomainGroups.shouldShow(
      policy,
    );
    final List<ReportsLookupOption> datasetShortcuts =
        reportsOverviewDatasetShortcuts(policy, overview.lookups.datasets);

    void openPanel(ReportsWorkspacePanel panel) {
      if (!allowedPanels.contains(panel)) {
        return;
      }
      if (showPharmacyGroups && onPharmacyOpenPanel != null) {
        if (panel == ReportsWorkspacePanel.catalog ||
            panel == ReportsWorkspacePanel.delivery) {
          onPharmacyOpenPanel!(panel);
          return;
        }
      }
      controller.applyPanel(panel);
    }

    final List<DashboardMetricCardData> metrics = reportsOverviewMetrics(
      context: context,
      overview: overview,
      onOpenPanel: openPanel,
    );
    final DashboardPriorityPanelData priority = reportsOverviewPriorityData(
      l10n: l10n,
      policy: policy,
      overview: overview,
      onOpenQueue: (ReportsQueueSummary queue) {
        openPanel(queue.panel);
      },
      onViewDelivery: () {
        openPanel(ReportsWorkspacePanel.delivery);
      },
    );
    final DashboardChartsData charts = reportsOverviewChartsData(
      l10n: l10n,
      overview: overview,
    );
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    if (state.isRefreshing && !reportsOverviewHasSignals(overview)) {
      return AppLoadingIndicator(
        title: l10n.reportsLoadingTitle,
        body: l10n.reportsLoadingBody,
      );
    }

    final List<AppActionItem> nextStepActions = <AppActionItem>[
      if (allowedPanels.contains(ReportsWorkspacePanel.catalog))
        AppActionItem(
          label: l10n.reportsOverviewBrowseCatalogAction,
          leadingIcon: Icons.library_books_outlined,
          semanticLabel: l10n.reportsOverviewBrowseCatalogAction,
          onPressed: () => openPanel(ReportsWorkspacePanel.catalog),
        ),
      if (allowedPanels.contains(ReportsWorkspacePanel.delivery))
        AppActionItem(
          label: l10n.reportsOverviewViewDeliveryAction,
          leadingIcon: Icons.local_shipping_outlined,
          semanticLabel: l10n.reportsOverviewViewDeliveryAction,
          onPressed: () => openPanel(ReportsWorkspacePanel.delivery),
        ),
      if (canWrite && allowedPanels.contains(ReportsWorkspacePanel.catalog))
        AppActionItem(
          label: l10n.reportsOverviewCreateReportAction,
          leadingIcon: Icons.play_arrow_outlined,
          semanticLabel: l10n.reportsOverviewCreateReportAction,
          onPressed: () {
            openPanel(ReportsWorkspacePanel.catalog);
            onOpenCatalogDefinition?.call();
          },
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!showPharmacyGroups) ...<Widget>[
          Text(
            l10n.reportsOverviewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
        ],
        if (showPharmacyGroups) ...<Widget>[
          ReportsPharmacyDomainGroups(
            l10n: l10n,
            policy: policy,
            allowedPanels: allowedPanels,
            datasetShortcuts: datasetShortcuts,
            onOpenDataset: onPharmacyOpenDataset ?? controller.openCatalogDataset,
            onOpenPanel: onPharmacyOpenPanel ?? controller.applyPanel,
            onOpenCatalogDefinition: onOpenCatalogDefinition,
          ),
          SizedBox(height: theme.spacing.xl),
        ],
        // Reporting tab already covers browse/delivery/create for pharmacy.
        if (!showPharmacyGroups) ...<Widget>[
          AppQuickActions(
            title: l10n.reportsOverviewNextStepsTitle,
            leadingIcon: Icons.bolt_outlined,
            presentation: AppQuickActionsPresentation.plain,
            actions: nextStepActions,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        if (!reportsOverviewHasSignals(overview) && metrics.isEmpty)
          AppWorkspaceStatePanel.empty(
            title: l10n.reportsOverviewEmptyTitle,
            body: l10n.reportsOverviewEmptyBody,
            icon: Icons.analytics_outlined,
          )
        else
          RoleDashboardScaffold(
            layout: const RoleDashboardLayout(
              showMetrics: true,
              showQuickActions: false,
              showPriority: true,
              showCharts: true,
            ),
            spacing: theme.spacing,
            summaryBadges: DashboardMetricStrip(
              cards: metrics,
              maxCards: 4,
              compact: true,
            ),
            quickActions: const SizedBox.shrink(),
            priorityPanel: DashboardPriorityPanel(data: priority),
            charts: DashboardChartsRow(data: charts, twoColumns: wide),
          ),
        if (!showPharmacyGroups && datasetShortcuts.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xl),
          AppSectionPanel(
            title: l10n.reportsOverviewDatasetsTitle,
            leadingIcon: Icons.dataset_outlined,
            density: AppContentPanelDensity.compact,
            children: <Widget>[
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final ReportsLookupOption dataset in datasetShortcuts)
                    ActionChip(
                      avatar: const Icon(Icons.insights_outlined, size: 18),
                      label: Text(dataset.label),
                      onPressed: () {
                        controller.openCatalogDataset(dataset.id);
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
        if (overview.timeline.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          ExpansionTile(
            title: Text(l10n.reportsOverviewRecentTitle),
            children: <Widget>[
              for (final ReportsTimelineItem item in overview.timeline.take(5))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.history_outlined),
                  title: Text(item.title),
                  subtitle: item.subtitle == null || item.subtitle!.isEmpty
                      ? null
                      : Text(item.subtitle!),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
