import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_nurse_dashboard_context.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

RoleDashboardLayout homeRoleDashboardLayout(
  HomeDashboardProfile profile, {
  required HomeDashboardTrend trend,
  required HomeDashboardDistribution distribution,
}) {
  return RoleDashboardLayout(
    showMetrics: profile.showMetricsSection,
    showQuickActions: !profile.suppressHomeQuickActions,
    showPriority:
        profile.showQueuePanel ||
        profile.showShortcutsSection(quickActionCount: profile.maxQuickActions),
    showCharts: profile.showChartsWhenData(
      trend: trend,
      distribution: distribution,
    ),
    alertsBeforeMetrics: profile.alertsBeforeMetrics,
  );
}

List<DashboardMetricCardData> homeDashboardMetrics({
  required BuildContext context,
  required WidgetRef ref,
  required HomeDashboard dashboard,
  required AppAccessPolicy policy,
  required bool compact,
}) {
  final HomeDashboardProfile profile = dashboard.profile;
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);

  return dashboard.statusCards
      .take(profile.effectiveMaxStatusCards)
      .map((HomeStatusCard card) {
        final AppWorkspaceStatusTone tone = homeMetricTone(card);
        final Color accent = homeToneColor(theme, tone);
        final String value = homeFormatMetricValue(card);
        final HomeMetricNavigation? navigation = homeMetricNavigation(
          profile: profile,
          card: card,
          policy: policy,
        );
        final HomeMetricAction? action = homeMetricAction(
          profile: profile,
          card: card,
          policy: policy,
        );
        final bool isActionable = navigation != null || action != null;
        final String label = homeMetricCardLabel(l10n, card, compact: compact);

        return DashboardMetricCardData(
          label: label,
          value: value,
          icon: homeMetricIcon(card.id),
          accent: accent,
          compact: compact,
          semanticsLabel: isActionable
              ? l10n.homeMetricCardSemantics(label, value)
              : '$label: $value',
          onTap: isActionable
              ? () {
                  if (action != null) {
                    unawaited(action.invoke(context, ref));
                    return;
                  }
                  if (navigation != null) {
                    homeGoToRoute(
                      context,
                      navigation.route,
                      queryParameters: navigation.queryParameters,
                    );
                  }
                }
              : null,
        );
      })
      .toList(growable: false);
}

List<DashboardQuickActionData> homeDashboardQuickActions({
  required BuildContext context,
  required WidgetRef ref,
  required List<HomeActionDefinition> actions,
  HomeDashboardRequest request = HomeDashboardRequest.empty,
}) {
  return actions
      .map(
        (HomeActionDefinition action) => DashboardQuickActionData(
          label: action.label,
          icon: action.icon,
          semanticsLabel: action.label,
          onPressed: () =>
              homeInvokeAction(context, ref, action, request: request),
        ),
      )
      .toList(growable: false);
}

List<DashboardWorklistItemData> homeDashboardWorklistItems({
  required BuildContext context,
  required WidgetRef ref,
  required AppAccessPolicy policy,
  required List<HomeQueueItem> items,
}) {
  return items
      .map(
        (HomeQueueItem item) => DashboardWorklistItemData(
          icon: homeModuleIcon(item.moduleSlug),
          title: item.label,
          subtitle: homeQueueItemSubtitle(item),
          status: AppWorkspaceStatus(
            label: homeStatusLabel(item.status),
            tone: homeSeverityTone(item.severity ?? item.status),
          ),
          onTap: homeWorklistTap(context, ref, policy, item.target),
        ),
      )
      .toList(growable: false);
}

DashboardPriorityPanelData homeDashboardPriorityData({
  required BuildContext context,
  required WidgetRef ref,
  required HomeDashboard dashboard,
  required List<HomeActionDefinition> actions,
  required List<HomeShortcutDefinition> shortcuts,
  required AppAccessPolicy policy,
  required AppLocalizations l10n,
  HomeDashboardRequest request = HomeDashboardRequest.empty,
}) {
  final HomeDashboardProfile profile = dashboard.profile;
  final bool showQueue = profile.showQueuePanel;
  final bool showAlerts =
      profile.showQueuePanel && profile.showAlertsInPriorityPanel;
  final bool showResults =
      profile.maxResultsItems > 0 && dashboard.resultsPreview.isNotEmpty;
  final bool showFollowUps =
      profile.maxFollowUpItems > 0 && dashboard.followUpPreview.isNotEmpty;
  final bool showShortcuts = profile.showShortcutsSection(
    quickActionCount: actions.length,
  );
  final List<DashboardWorklistItemData> worklistItems = showQueue
      ? homeDashboardWorklistItems(
          context: context,
          ref: ref,
          policy: policy,
          items: dashboard.queuePreview
              .take(profile.maxQueueItems)
              .toList(growable: false),
        )
      : const <DashboardWorklistItemData>[];

  return DashboardPriorityPanelData(
    queueTitle: profile.showQueuePanelTitle
        ? homeQueueTitle(profile.role)
        : null,
    queueItems: worklistItems,
    emptySectionTitle: profile.id == 'super_admin'
        ? l10n.homePlatformManagementTitle
        : null,
    emptyMessage: profile.id == 'super_admin'
        ? l10n.homePlatformManagementDescription
        : profile.emptyMessage,
    emptyActions: homeDashboardEmptyActions(
      context,
      ref,
      profile,
      policy,
      request: request,
      excludeActionIds: actions.map((HomeActionDefinition a) => a.id),
    ),
    maxQueueItems: profile.maxQueueItems,
    alertsTitle: showAlerts ? homeAlertsTitle(profile.role) : null,
    alertItems: showAlerts
        ? dashboard.alerts
              .take(3)
              .map(
                (HomeAlertItem alert) => DashboardWorklistItemData(
                  icon: Icons.warning_amber_outlined,
                  title: alert.label,
                  subtitle: '${alert.count}',
                  status: AppWorkspaceStatus(
                    label: homeStatusLabel(alert.severity),
                    tone: homeSeverityTone(alert.severity),
                  ),
                  onTap: homeWorklistTap(context, ref, policy, alert.target),
                ),
              )
              .toList(growable: false)
        : const <DashboardWorklistItemData>[],
    resultsTitle: profile.maxResultsItems > 0
        ? homeResultsTitle(profile.role)
        : null,
    resultsItems: profile.maxResultsItems > 0
        ? homeDashboardWorklistItems(
            context: context,
            ref: ref,
            policy: policy,
            items: dashboard.resultsPreview
                .take(profile.maxResultsItems)
                .toList(growable: false),
          )
        : const <DashboardWorklistItemData>[],
    maxResultsItems: profile.maxResultsItems,
    followUpTitle: profile.maxFollowUpItems > 0
        ? homeFollowUpTitle(profile.role)
        : null,
    followUpItems: profile.maxFollowUpItems > 0
        ? homeDashboardWorklistItems(
            context: context,
            ref: ref,
            policy: policy,
            items: dashboard.followUpPreview
                .take(profile.maxFollowUpItems)
                .toList(growable: false),
          )
        : const <DashboardWorklistItemData>[],
    maxFollowUpItems: profile.maxFollowUpItems,
    shortcuts: showShortcuts
        ? shortcuts
              .take(profile.maxShortcutTiles)
              .map(
                (HomeShortcutDefinition shortcut) => DashboardShortcutData(
                  label: shortcut.label,
                  icon: shortcut.icon,
                  onTap: () =>
                      homeNavigateShortcut(context, ref, policy, shortcut),
                ),
              )
              .toList(growable: false)
        : const <DashboardShortcutData>[],
    maxShortcuts: profile.maxShortcutTiles,
    shortcutsTitle: l10n.homeDashboardQuickLinksTitle,
    showQueue: showQueue,
    showAlerts: showAlerts,
    showResults: showResults || profile.maxResultsItems > 0,
    showFollowUps: showFollowUps || profile.maxFollowUpItems > 0,
    showShortcuts: showShortcuts,
    viewAllLabel: l10n.homeViewAllAction,
    onViewAll: homeFirstQueueTarget(dashboard.queuePreview) == null
        ? null
        : () {
            homeNavigateRouteTarget(
              context,
              ref,
              policy,
              target: homeFirstQueueTarget(dashboard.queuePreview),
            );
          },
    onViewAllResults: homeFirstQueueTarget(dashboard.resultsPreview) == null
        ? null
        : () {
            homeNavigateRouteTarget(
              context,
              ref,
              policy,
              target: homeFirstQueueTarget(dashboard.resultsPreview),
            );
          },
    onViewAllFollowUps: homeFirstQueueTarget(dashboard.followUpPreview) == null
        ? null
        : () {
            homeNavigateRouteTarget(
              context,
              ref,
              policy,
              target: homeFirstQueueTarget(dashboard.followUpPreview),
            );
          },
  );
}

DashboardPriorityPanelData homeDashboardAlertsPanelData({
  required BuildContext context,
  required WidgetRef ref,
  required HomeDashboard dashboard,
  required AppAccessPolicy policy,
}) {
  final HomeDashboardProfile profile = dashboard.profile;

  return DashboardPriorityPanelData(
    alertsTitle: homeAlertsTitle(profile.role),
    alertItems: dashboard.alerts
        .take(3)
        .map(
          (HomeAlertItem alert) => DashboardWorklistItemData(
            icon: Icons.warning_amber_outlined,
            title: alert.label,
            subtitle: '${alert.count}',
            status: AppWorkspaceStatus(
              label: homeStatusLabel(alert.severity),
              tone: homeSeverityTone(alert.severity),
            ),
            onTap: homeWorklistTap(context, ref, policy, alert.target),
          ),
        )
        .toList(growable: false),
    showQueue: false,
    showAlerts: true,
    showShortcuts: false,
  );
}

List<DashboardQuickActionData> homeDashboardEmptyActions(
  BuildContext context,
  WidgetRef ref,
  HomeDashboardProfile profile,
  AppAccessPolicy policy, {
  HomeDashboardRequest request = HomeDashboardRequest.empty,
  Iterable<String> excludeActionIds = const <String>[],
}) {
  return homeVisibleEmptyActions(
    profile.emptyActionIds,
    policy,
    excludeActionIds: excludeActionIds,
  )
      .map(
        (HomeActionDefinition action) => DashboardQuickActionData(
          label: action.label,
          icon: action.icon,
          semanticsLabel: action.label,
          onPressed: () =>
              homeInvokeAction(context, ref, action, request: request),
        ),
      )
      .toList(growable: false);
}

DashboardChartsData homeDashboardChartsData({
  required HomeDashboard dashboard,
  required AppLocalizations l10n,
}) {
  final HomeDashboardProfile profile = dashboard.profile;

  return DashboardChartsData(
    trend: DashboardTrendChartData(
      title: homeTrendTitle(profile.role, dashboard.trend.title),
      emptyMessage: profile.id == 'pharmacist'
          ? 'No dispensing activity in the last 7 days.'
          : l10n.homeTrendEmptyMessage,
      subtitle: profile.id == 'pharmacist' && dashboard.trend.points.isNotEmpty
          ? _pharmacyTrendSubtitle(dashboard.trend.points)
          : null,
      points: dashboard.trend.points
          .map(
            (HomeTrendPoint point) => DashboardTrendPointData(
              value: point.value,
              label: point.label,
              date: point.date,
            ),
          )
          .toList(growable: false),
    ),
    distribution: DashboardDistributionChartData(
      title: profile.role == AppRole.nurse
          ? nurseDistributionTitleForKind(
              nurseDepartmentKindFromValue(dashboard.context.nurseContext),
            )
          : homeDistributionTitle(profile.role, dashboard.distribution.title),
      total: dashboard.distribution.total,
      emptyMessage: profile.id == 'pharmacist'
          ? 'No pharmacy order status data yet.'
          : l10n.homeDistributionEmptyMessage,
      totalLabel: profile.id == 'pharmacist' ? 'orders' : 'total',
      segments: dashboard.distribution.segments
          .map(
            (HomeDistributionSegment segment) =>
                DashboardDistributionSegmentData(
                  label: segment.label,
                  value: segment.value,
                  colorHex: segment.color,
                ),
          )
          .toList(growable: false),
    ),
  );
}

String? _pharmacyTrendSubtitle(List<HomeTrendPoint> points) {
  final num total = points.fold<num>(
    0,
    (num sum, HomeTrendPoint point) => sum + point.value,
  );
  if (total <= 0) {
    return 'Dispenses logged over the last 7 days';
  }
  final String unit = total == 1 ? 'dispense' : 'dispenses';
  return '$total $unit over the last 7 days';
}
