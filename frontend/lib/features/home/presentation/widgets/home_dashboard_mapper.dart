import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_nurse_dashboard_context.dart';
import 'package:hosspi_hms/features/home/presentation/home_access.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

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

  // Defense-in-depth: never render KPI values that fail homeAllows, even if a
  // caller skipped [filterHomeDashboardForAccess].
  return dashboard.statusCards
      .where(
        (HomeStatusCard card) => homeAllows(
          policy,
          homeStatusCardRequirement(
            id: card.id,
            declared: card.requiredPermissions,
          ),
        ),
      )
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
  // Defense-in-depth: never render queue rows that fail homeAllows.
  return items
      .where(
        (HomeQueueItem item) => homeAllows(
          policy,
          homeQueueItemRequirement(
            id: item.id,
            moduleSlug: item.moduleSlug.isNotEmpty
                ? item.moduleSlug
                : item.target?.moduleSlug,
            declared: item.requiredPermissions,
          ),
        ),
      )
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
  required AppAccessPolicy policy,
  required AppLocalizations l10n,
  HomeDashboardRequest request = HomeDashboardRequest.empty,
}) {
  final HomeDashboardProfile profile = dashboard.profile;
  final bool queuePanelAllowed = profile.showQueuePanel;
  final bool alertsAllowed =
      profile.showQueuePanel && profile.showAlertsInPriorityPanel;
  final List<DashboardWorklistItemData> worklistItems = queuePanelAllowed
      ? homeDashboardWorklistItems(
          context: context,
          ref: ref,
          policy: policy,
          items: dashboard.queuePreview
              .take(profile.maxQueueItems)
              .toList(growable: false),
        )
      : const <DashboardWorklistItemData>[];
  final List<DashboardQuickActionData> emptyActions = homeDashboardEmptyActions(
    context,
    ref,
    profile,
    policy,
    request: request,
    excludeActionIds: actions.map((HomeActionDefinition a) => a.id),
  );
  // Management strips: buttons already state the action — no tutorial body.
  // Keep empty copy only for true work queues with no management actions.
  final String emptyMessage =
      emptyActions.isNotEmpty ? '' : profile.emptyMessage;
  // Collapse blank headers — only surface a queue strip with items, Manage
  // hubs, or a real "nothing due" empty message.
  final bool showQueue = queuePanelAllowed &&
      (worklistItems.isNotEmpty ||
          emptyActions.isNotEmpty ||
          emptyMessage.isNotEmpty);
  final List<DashboardWorklistItemData> alertItems = alertsAllowed
      ? dashboard.alerts
            .where(
              (HomeAlertItem alert) => homeAllows(
                policy,
                homeAlertRequirement(
                  id: alert.id,
                  moduleSlug: alert.target?.moduleSlug,
                  declared: alert.requiredPermissions,
                ),
              ),
            )
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
      : const <DashboardWorklistItemData>[];
  final bool showAlerts = alertItems.isNotEmpty;
  final List<DashboardWorklistItemData> resultsItems =
      profile.maxResultsItems > 0
      ? homeDashboardWorklistItems(
          context: context,
          ref: ref,
          policy: policy,
          items: dashboard.resultsPreview
              .take(profile.maxResultsItems)
              .toList(growable: false),
        )
      : const <DashboardWorklistItemData>[];
  final bool showResults = resultsItems.isNotEmpty;
  final List<DashboardWorklistItemData> followUpItems =
      profile.maxFollowUpItems > 0
      ? homeDashboardWorklistItems(
          context: context,
          ref: ref,
          policy: policy,
          items: dashboard.followUpPreview
              .take(profile.maxFollowUpItems)
              .toList(growable: false),
        )
      : const <DashboardWorklistItemData>[];
  final bool showFollowUps = followUpItems.isNotEmpty;

  return DashboardPriorityPanelData(
    queueTitle: showQueue && profile.showQueuePanelTitle
        ? homeQueueTitle(profile.role)
        : null,
    queueItems: worklistItems,
    emptySectionTitle: showQueue
        ? homeEmptyManagementSectionTitle(profile, l10n)
        : null,
    emptyMessage: showQueue ? emptyMessage : '',
    emptyActions: showQueue ? emptyActions : const <DashboardQuickActionData>[],
    maxQueueItems: profile.maxQueueItems,
    alertsTitle: showAlerts ? homeAlertsTitle(profile.role) : null,
    alertItems: alertItems,
    resultsTitle: showResults ? homeResultsTitle(profile.role) : null,
    resultsItems: resultsItems,
    maxResultsItems: profile.maxResultsItems,
    followUpTitle: showFollowUps ? homeFollowUpTitle(profile.role) : null,
    followUpItems: followUpItems,
    maxFollowUpItems: profile.maxFollowUpItems,
    showQueue: showQueue,
    showAlerts: showAlerts,
    showResults: showResults,
    showFollowUps: showFollowUps,
    viewAllLabel: l10n.homeViewAllAction,
    onViewAll: homeQueueListTarget(dashboard.queuePreview) == null
        ? null
        : () {
            homeNavigateRouteTarget(
              context,
              ref,
              policy,
              target: homeQueueListTarget(dashboard.queuePreview),
            );
          },
    onViewAllResults: homeQueueListTarget(dashboard.resultsPreview) == null
        ? null
        : () {
            homeNavigateRouteTarget(
              context,
              ref,
              policy,
              target: homeQueueListTarget(dashboard.resultsPreview),
            );
          },
    onViewAllFollowUps: homeQueueListTarget(dashboard.followUpPreview) == null
        ? null
        : () {
            homeNavigateRouteTarget(
              context,
              ref,
              policy,
              target: homeQueueListTarget(dashboard.followUpPreview),
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

  final List<DashboardWorklistItemData> alertItems = dashboard.alerts
      .where(
        (HomeAlertItem alert) => homeAllows(
          policy,
          homeAlertRequirement(
            id: alert.id,
            moduleSlug: alert.target?.moduleSlug,
            declared: alert.requiredPermissions,
          ),
        ),
      )
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
      .toList(growable: false);

  return DashboardPriorityPanelData(
    alertsTitle: alertItems.isEmpty ? null : homeAlertsTitle(profile.role),
    alertItems: alertItems,
    showQueue: false,
    showAlerts: alertItems.isNotEmpty,
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
