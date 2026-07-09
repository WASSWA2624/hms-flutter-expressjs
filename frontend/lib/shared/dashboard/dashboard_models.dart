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
  });

  final bool showMetrics;
  final bool showQuickActions;
  final bool showPriority;
  final bool showCharts;
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
final class DashboardShortcutData {
  const DashboardShortcutData({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

@immutable
final class DashboardTrendPointData {
  const DashboardTrendPointData({
    required this.value,
    this.label,
    this.date,
  });

  final num value;
  final String? label;
  final DateTime? date;
}

@immutable
final class DashboardTrendChartData {
  const DashboardTrendChartData({
    required this.title,
    required this.points,
    required this.emptyMessage,
  });

  final String title;
  final List<DashboardTrendPointData> points;
  final String emptyMessage;
}

@immutable
final class DashboardDistributionSegmentData {
  const DashboardDistributionSegmentData({
    required this.label,
    required this.value,
    this.colorHex,
  });

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
  });

  final String title;
  final num total;
  final List<DashboardDistributionSegmentData> segments;
  final String emptyMessage;
  final String totalLabel;
}

@immutable
final class DashboardPriorityPanelData {
  const DashboardPriorityPanelData({
    this.queueTitle,
    this.queueItems = const <DashboardWorklistItemData>[],
    this.emptyMessage = '',
    this.emptyActions = const <DashboardQuickActionData>[],
    this.maxQueueItems = 3,
    this.alertsTitle,
    this.alertItems = const <DashboardWorklistItemData>[],
    this.shortcuts = const <DashboardShortcutData>[],
    this.maxShortcuts = 3,
    this.showQueue = true,
    this.showAlerts = true,
    this.showShortcuts = false,
    this.shortcutsTitle = 'Quick links',
    this.viewAllLabel = 'View all',
    this.onViewAll,
  });

  final String? queueTitle;
  final List<DashboardWorklistItemData> queueItems;
  final String emptyMessage;
  final List<DashboardQuickActionData> emptyActions;
  final int maxQueueItems;
  final String? alertsTitle;
  final List<DashboardWorklistItemData> alertItems;
  final List<DashboardShortcutData> shortcuts;
  final int maxShortcuts;
  final bool showQueue;
  final bool showAlerts;
  final bool showShortcuts;
  final String shortcutsTitle;
  final String viewAllLabel;
  final VoidCallback? onViewAll;
}

@immutable
final class DashboardChartsData {
  const DashboardChartsData({
    required this.trend,
    required this.distribution,
  });

  final DashboardTrendChartData trend;
  final DashboardDistributionChartData distribution;
}
