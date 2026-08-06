import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

IconData reportsSummaryCardIcon(String id) {
  return switch (id) {
    'definitions' => Icons.description_outlined,
    'runs_queued' => Icons.hourglass_top_outlined,
    'schedules_due' => Icons.schedule_outlined,
    'widgets_pinned' => Icons.push_pin_outlined,
    'kpi_critical' => Icons.warning_amber_outlined,
    'activity_24h' => Icons.timeline_outlined,
    _ => Icons.analytics_outlined,
  };
}

Color reportsSummaryCardAccent(ColorScheme scheme, String id) {
  return switch (id) {
    'kpi_critical' => scheme.error,
    'runs_queued' => scheme.tertiary,
    'schedules_due' => scheme.secondary,
    'activity_24h' => scheme.primary,
    _ => scheme.primary,
  };
}

List<DashboardMetricCardData> reportsOverviewMetrics({
  required BuildContext context,
  required ReportsWorkspaceOverview overview,
  required void Function(ReportsWorkspacePanel panel) onOpenPanel,
  int maxCards = 4,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final List<ReportsSummaryCard> cards = overview.summary;
  if (cards.isEmpty) {
    return const <DashboardMetricCardData>[];
  }

  return cards.take(maxCards).map((ReportsSummaryCard card) {
    final ReportsWorkspacePanel? target = switch (card.id) {
      'definitions' => ReportsWorkspacePanel.catalog,
      'runs_queued' || 'schedules_due' => ReportsWorkspacePanel.delivery,
      'widgets_pinned' => ReportsWorkspacePanel.dashboards,
      'kpi_critical' => ReportsWorkspacePanel.monitor,
      'activity_24h' => ReportsWorkspacePanel.activity,
      _ => null,
    };
    return DashboardMetricCardData(
      label: card.label,
      value: '${card.value}',
      icon: reportsSummaryCardIcon(card.id),
      accent: reportsSummaryCardAccent(scheme, card.id),
      semanticsLabel: '${card.label}: ${card.value}',
      onTap: target == null ? null : () => onOpenPanel(target),
      compact: true,
    );
  }).toList(growable: false);
}

DashboardPriorityPanelData reportsOverviewPriorityData({
  required AppLocalizations l10n,
  required AppAccessPolicy policy,
  required ReportsWorkspaceOverview overview,
  required void Function(ReportsQueueSummary queue) onOpenQueue,
  required VoidCallback onViewDelivery,
}) {
  final List<ReportsQueueSummary> queues = overview.queueSummaries
      .where(
        (ReportsQueueSummary queue) =>
            queue.count > 0 && canAccessReportsPanel(policy, queue.panel),
      )
      .toList(growable: false);

  return DashboardPriorityPanelData(
    queueTitle: l10n.reportsOverviewQueuesTitle,
    queueItems: <DashboardWorklistItemData>[
      for (final ReportsQueueSummary queue in queues)
        DashboardWorklistItemData(
          icon: Icons.assignment_late_outlined,
          title: queue.label,
          subtitle: '${queue.count}',
          onTap: () => onOpenQueue(queue),
        ),
    ],
    emptyMessage: l10n.reportsOverviewDistributionEmpty,
    maxQueueItems: 5,
    showAlerts: false,
    viewAllLabel: l10n.reportsOverviewViewDeliveryAction,
    onViewAll: onViewDelivery,
  );
}

DashboardChartsData reportsOverviewChartsData({
  required AppLocalizations l10n,
  required ReportsWorkspaceOverview overview,
}) {
  final List<DashboardTrendPointData> trendPoints = overview.summary
      .map(
        (ReportsSummaryCard card) => DashboardTrendPointData(
          value: card.value,
          label: card.label,
        ),
      )
      .where((DashboardTrendPointData point) => point.value > 0)
      .toList(growable: false);

  final List<ReportsQueueSummary> queues = overview.queueSummaries
      .where((ReportsQueueSummary queue) => queue.count > 0)
      .toList(growable: false);
  final num distributionTotal = queues.fold<num>(
    0,
    (num sum, ReportsQueueSummary queue) => sum + queue.count,
  );

  return DashboardChartsData(
    trend: DashboardTrendChartData(
      title: l10n.reportsOverviewTrendTitle,
      emptyMessage: l10n.reportsOverviewTrendEmpty,
      points: trendPoints,
    ),
    distribution: DashboardDistributionChartData(
      title: l10n.reportsOverviewDistributionTitle,
      total: distributionTotal,
      emptyMessage: l10n.reportsOverviewDistributionEmpty,
      totalLabel: 'total',
      segments: <DashboardDistributionSegmentData>[
        for (final ReportsQueueSummary queue in queues)
          DashboardDistributionSegmentData(
            label: queue.label,
            value: queue.count,
          ),
      ],
    ),
  );
}

bool reportsOverviewHasSignals(ReportsWorkspaceOverview overview) {
  final bool hasSummary = overview.summary.any(
    (ReportsSummaryCard card) => card.value > 0,
  );
  final bool hasQueues = overview.queueSummaries.any(
    (ReportsQueueSummary queue) => queue.count > 0,
  );
  return hasSummary || hasQueues || overview.timeline.isNotEmpty;
}
