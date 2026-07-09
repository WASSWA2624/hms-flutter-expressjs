import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

RoleDashboardLayout homeRoleDashboardLayout(HomeDashboardProfile profile) {
  return RoleDashboardLayout(
    showMetrics: profile.showMetricsSection,
    showQuickActions: !profile.suppressHomeQuickActions,
    showPriority:
        profile.showQueuePanel ||
        profile.showShortcutsSection(quickActionCount: profile.maxQuickActions),
    showCharts: profile.showCharts,
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
}) {
  return actions
      .map(
        (HomeActionDefinition action) => DashboardQuickActionData(
          label: action.label,
          icon: action.icon,
          semanticsLabel: action.label,
          onPressed: () => homeInvokeAction(context, ref, action),
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
  required AppLocalizations l10n,
}) {
  final HomeDashboardProfile profile = dashboard.profile;
  final bool showQueue = profile.showQueuePanel;
  final bool showAlerts = profile.showQueuePanel;
  final bool showShortcuts = profile.showShortcutsSection(
    quickActionCount: actions.length,
  );

  return DashboardPriorityPanelData(
    queueTitle: profile.showQueuePanelTitle
        ? homeQueueTitle(profile.role)
        : null,
    queueItems: showQueue
        ? dashboard.queuePreview
              .take(profile.maxQueueItems)
              .map(
                (HomeQueueItem item) => DashboardWorklistItemData(
                  icon: homeModuleIcon(item.moduleSlug),
                  title: item.label,
                  subtitle: homeTimeLabel(item.occurredAt),
                  status: AppWorkspaceStatus(
                    label: homeStatusLabel(item.status),
                    tone: homeSeverityTone(item.severity ?? item.status),
                  ),
                  onTap: _worklistTap(context, item.target),
                ),
              )
              .toList(growable: false)
        : const <DashboardWorklistItemData>[],
    emptyMessage: profile.emptyMessage,
    emptyActions: homeDashboardEmptyActions(context, ref, profile, actions),
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
                  onTap: _worklistTap(context, alert.target),
                ),
              )
              .toList(growable: false)
        : const <DashboardWorklistItemData>[],
    shortcuts: showShortcuts
        ? shortcuts
              .take(profile.maxShortcutTiles)
              .map(
                (HomeShortcutDefinition shortcut) => DashboardShortcutData(
                  label: shortcut.label,
                  icon: shortcut.icon,
                  onTap: () => homeGoToRoute(context, shortcut.route),
                ),
              )
              .toList(growable: false)
        : const <DashboardShortcutData>[],
    maxShortcuts: profile.maxShortcutTiles,
    shortcutsTitle: l10n.homeDashboardQuickLinksTitle,
    showQueue: showQueue,
    showAlerts: showAlerts,
    showShortcuts: showShortcuts,
    viewAllLabel: l10n.homeViewAllAction,
    onViewAll: homeFirstQueueTarget(dashboard.queuePreview) == null
        ? null
        : () {
            final HomeRouteTarget? target = homeFirstQueueTarget(
              dashboard.queuePreview,
            );
            final AppRouteData? route = homeRouteForTarget(target);
            if (route != null) {
              homeGoToRoute(
                context,
                route,
                queryParameters: homeHrQueryForTarget(target),
              );
            }
          },
  );
}

List<DashboardQuickActionData> homeDashboardEmptyActions(
  BuildContext context,
  WidgetRef ref,
  HomeDashboardProfile profile,
  List<HomeActionDefinition> actions,
) {
  return homeVisibleEmptyActions(profile.emptyActionIds, actions)
      .map(
        (HomeActionDefinition action) => DashboardQuickActionData(
          label: action.label,
          icon: action.icon,
          semanticsLabel: action.label,
          onPressed: () => homeInvokeAction(context, ref, action),
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
      emptyMessage: l10n.homeTrendEmptyMessage,
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
      title: homeDistributionTitle(
        profile.role,
        dashboard.distribution.title,
      ),
      total: dashboard.distribution.total,
      emptyMessage: l10n.homeDistributionEmptyMessage,
      totalLabel: 'total',
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

VoidCallback? _worklistTap(BuildContext context, HomeRouteTarget? target) {
  final AppRouteData? route = homeRouteForTarget(target);
  if (route == null) {
    return null;
  }
  return () => homeGoToRoute(
    context,
    route,
    queryParameters: homeHrQueryForTarget(target),
  );
}
