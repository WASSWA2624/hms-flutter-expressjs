import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_atom_permissions.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

/// Filters home dashboard atoms by [AccessRequirement] (all-of) before render.
///
/// Prefer filtering the permission-allowed **superset** of the ranked role
/// profile rather than swapping whole role layouts when grants diverge.
/// Quick actions / shortcuts are filtered separately via their libraries.
HomeDashboard filterHomeDashboardForAccess(
  HomeDashboard dashboard,
  AppAccessPolicy policy,
) {
  final HomeDashboardProfile profile = dashboard.profile;
  final List<HomeStatusCard> statusCards = _filterStatusCards(
    cards: dashboard.statusCards,
    profile: profile,
    policy: policy,
  );
  final List<HomeQueueItem> queuePreview = _filterQueue(
    dashboard.queuePreview,
    policy,
  );
  final List<HomeQueueItem> resultsPreview = _filterQueue(
    dashboard.resultsPreview,
    policy,
  );
  final List<HomeQueueItem> followUpPreview = _filterQueue(
    dashboard.followUpPreview,
    policy,
  );
  final List<HomeAlertItem> alerts = dashboard.alerts
      .where(
        (HomeAlertItem alert) => HomeDashboardAtomPermissions.isGranted(
          policy,
          alert.effectiveRequiredPermissions,
        ),
      )
      .toList(growable: false);
  final List<HomeActivityItem> activity = dashboard.activity
      .where(
        (HomeActivityItem item) => HomeDashboardAtomPermissions.isGranted(
          policy,
          item.effectiveRequiredPermissions,
        ),
      )
      .toList(growable: false);

  final bool chartsAllowed = HomeDashboardAtomPermissions.isGranted(
    policy,
    HomeDashboardAtomPermissions.charts,
  );
  final HomeDashboardTrend trend = chartsAllowed
      ? _withChartPermissions(dashboard.trend)
      : HomeDashboardTrend.empty;
  final HomeDashboardDistribution distribution = chartsAllowed
      ? _withChartPermissionsDistribution(dashboard.distribution)
      : HomeDashboardDistribution.empty;

  return dashboard.copyWith(
    statusCards: statusCards,
    queuePreview: queuePreview,
    resultsPreview: resultsPreview,
    followUpPreview: followUpPreview,
    alerts: alerts,
    activity: activity,
    trend: trend,
    distribution: distribution,
  );
}

/// Layout flags after permission filtering — collapse empty sections.
RoleDashboardLayout homeRoleDashboardLayoutAfterFilter({
  required HomeDashboardProfile profile,
  required HomeDashboard dashboard,
  required bool hasQuickActions,
  required bool hasPrioritySurface,
  bool chartsAllowed = true,
}) {
  final bool showMetrics =
      profile.showMetricsSection && dashboard.statusCards.isNotEmpty;
  // [filterHomeDashboardForAccess] clears unauthorized chart payloads; also
  // honor [chartsAllowed] so showCharts never outlives AppAccessGate deny.
  final bool showCharts =
      chartsAllowed &&
      profile.showChartsWhenData(
        trend: dashboard.trend,
        distribution: dashboard.distribution,
      );

  return RoleDashboardLayout(
    showMetrics: showMetrics,
    showQuickActions: !profile.suppressHomeQuickActions && hasQuickActions,
    showPriority: hasPrioritySurface,
    showCharts: showCharts,
    alertsBeforeMetrics:
        profile.alertsBeforeMetrics && dashboard.alerts.isNotEmpty,
  );
}

List<HomeStatusCard> _filterStatusCards({
  required List<HomeStatusCard> cards,
  required HomeDashboardProfile profile,
  required AppAccessPolicy policy,
}) {
  return cards
      .map(
        (HomeStatusCard card) => enrichHomeStatusCardPermissions(card, profile),
      )
      .where(
        (HomeStatusCard card) => HomeDashboardAtomPermissions.isGranted(
          policy,
          card.effectiveRequiredPermissions,
        ),
      )
      .toList(growable: false);
}

/// Attach catalog / profile template permissions when API omitted them.
HomeStatusCard enrichHomeStatusCardPermissions(
  HomeStatusCard card,
  HomeDashboardProfile profile,
) {
  if (card.requiredPermissions.isNotEmpty) {
    return card;
  }
  for (final HomeStatusCardTemplate template in profile.statusCards) {
    if (template.id == card.id && template.requiredPermissions.isNotEmpty) {
      return card.copyWith(requiredPermissions: template.requiredPermissions);
    }
  }
  final List<AppPermission> fromCatalog =
      HomeDashboardAtomPermissions.forStatusCard(card.id);
  if (fromCatalog.isEmpty) {
    return card;
  }
  return card.copyWith(requiredPermissions: fromCatalog);
}

List<HomeQueueItem> _filterQueue(
  List<HomeQueueItem> items,
  AppAccessPolicy policy,
) {
  return items
      .where(
        (HomeQueueItem item) => HomeDashboardAtomPermissions.isGranted(
          policy,
          item.effectiveRequiredPermissions,
        ),
      )
      .toList(growable: false);
}

HomeDashboardTrend _withChartPermissions(HomeDashboardTrend trend) {
  if (trend.requiredPermissions.isNotEmpty) {
    return trend;
  }
  if (trend.title.isEmpty && trend.points.isEmpty) {
    return HomeDashboardTrend.empty;
  }
  return HomeDashboardTrend(
    title: trend.title,
    subtitle: trend.subtitle,
    points: trend.points,
    requiredPermissions: HomeDashboardAtomPermissions.charts,
  );
}

HomeDashboardDistribution _withChartPermissionsDistribution(
  HomeDashboardDistribution distribution,
) {
  if (distribution.requiredPermissions.isNotEmpty) {
    return distribution;
  }
  if (distribution.title.isEmpty &&
      distribution.segments.isEmpty &&
      distribution.total == 0) {
    return HomeDashboardDistribution.empty;
  }
  return HomeDashboardDistribution(
    title: distribution.title,
    subtitle: distribution.subtitle,
    total: distribution.total,
    segments: distribution.segments,
    requiredPermissions: HomeDashboardAtomPermissions.charts,
  );
}
