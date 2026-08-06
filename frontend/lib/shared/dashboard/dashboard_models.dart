import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Layout flags for [RoleDashboardScaffold].
@immutable
final class RoleDashboardLayout {
  const RoleDashboardLayout({
    this.showMetrics = true,
    this.showQuickActions = true,
    this.showPriority = true,
    this.showCharts = true,
    this.alertsBeforeMetrics = false,
  });

  final bool showMetrics;
  final bool showQuickActions;
  final bool showPriority;
  final bool showCharts;
  final bool alertsBeforeMetrics;
}

@immutable
final class DashboardMetricCardData {
  const DashboardMetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.semanticsLabel,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final bool compact;
}

@immutable
final class DashboardQuickActionData {
  const DashboardQuickActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.semanticsLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String semanticsLabel;
}

@immutable
final class DashboardWorklistItemData {
  const DashboardWorklistItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppWorkspaceStatus? status;
  final VoidCallback? onTap;
}

@immutable
final class DashboardTrendPointData {
  const DashboardTrendPointData({required this.value, this.label, this.date});

  final num value;
  final String? label;
  final DateTime? date;
}

/// How [DashboardTrendChartPainter] renders series points.
enum DashboardTrendChartStyle {
  /// Bars plus overlay line (legacy home trend).
  combined,
  bar,
  line,
}

@immutable
final class DashboardTrendChartData {
  const DashboardTrendChartData({
    required this.title,
    required this.points,
    required this.emptyMessage,
    this.subtitle,
    this.chartStyle = DashboardTrendChartStyle.combined,
    this.headerTrailing,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<DashboardTrendPointData> points;
  final String emptyMessage;
  final DashboardTrendChartStyle chartStyle;
  final Widget? headerTrailing;
  final Widget? footer;
}

@immutable
final class DashboardDistributionSegmentData {
  const DashboardDistributionSegmentData({
    required this.label,
    required this.value,
    this.id,
    this.colorHex,
  });

  final String? id;
  final String label;
  final num value;
  final String? colorHex;
}

@immutable
final class DashboardDistributionChartData {
  const DashboardDistributionChartData({
    required this.title,
    required this.total,
    required this.segments,
    required this.emptyMessage,
    required this.totalLabel,
    this.onSegmentSelected,
  });

  final String title;
  final num total;
  final List<DashboardDistributionSegmentData> segments;
  final String emptyMessage;
  final String totalLabel;
  final ValueChanged<DashboardDistributionSegmentData>? onSegmentSelected;
}

@immutable
final class DashboardPriorityPanelData {
  const DashboardPriorityPanelData({
    this.queueTitle,
    this.queueItems = const <DashboardWorklistItemData>[],
    this.emptySectionTitle,
    this.emptyMessage = '',
    this.emptyActions = const <DashboardQuickActionData>[],
    this.maxQueueItems = 3,
    this.alertsTitle,
    this.alertItems = const <DashboardWorklistItemData>[],
    this.resultsTitle,
    this.resultsItems = const <DashboardWorklistItemData>[],
    this.maxResultsItems = 0,
    this.followUpTitle,
    this.followUpItems = const <DashboardWorklistItemData>[],
    this.maxFollowUpItems = 0,
    this.showQueue = true,
    this.showAlerts = true,
    this.showResults = false,
    this.showFollowUps = false,
    this.viewAllLabel = 'View all',
    this.onViewAll,
    this.onViewAllResults,
    this.onViewAllFollowUps,
  });

  final String? queueTitle;
  final List<DashboardWorklistItemData> queueItems;
  final String? emptySectionTitle;
  final String emptyMessage;
  final List<DashboardQuickActionData> emptyActions;
  final int maxQueueItems;
  final String? alertsTitle;
  final List<DashboardWorklistItemData> alertItems;
  final String? resultsTitle;
  final List<DashboardWorklistItemData> resultsItems;
  final int maxResultsItems;
  final String? followUpTitle;
  final List<DashboardWorklistItemData> followUpItems;
  final int maxFollowUpItems;
  final bool showQueue;
  final bool showAlerts;
  final bool showResults;
  final bool showFollowUps;
  final String viewAllLabel;
  final VoidCallback? onViewAll;
  final VoidCallback? onViewAllResults;
  final VoidCallback? onViewAllFollowUps;
}

@immutable
final class DashboardChartsData {
  const DashboardChartsData({required this.trend, required this.distribution});

  final DashboardTrendChartData trend;
  final DashboardDistributionChartData distribution;
}
