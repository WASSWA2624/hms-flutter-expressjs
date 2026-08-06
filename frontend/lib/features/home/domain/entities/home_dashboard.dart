import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_atom_permissions.dart';

enum HomeDashboardLoadState { ready, tenantContextRequired }

/// Most-sold lookback presets for the pharmacist home dashboard.
enum HomeMostSoldPeriod {
  today,
  lastWeek,
  lastMonth,
  lastThreeMonths,
  lastSixMonths,
  lastYear,
  lastFiveYears,
}

extension HomeMostSoldPeriodX on HomeMostSoldPeriod {
  String get apiValue => switch (this) {
    HomeMostSoldPeriod.today => 'today',
    HomeMostSoldPeriod.lastWeek => 'last_week',
    HomeMostSoldPeriod.lastMonth => 'last_month',
    HomeMostSoldPeriod.lastThreeMonths => 'last_3_months',
    HomeMostSoldPeriod.lastSixMonths => 'last_6_months',
    HomeMostSoldPeriod.lastYear => 'last_year',
    HomeMostSoldPeriod.lastFiveYears => 'last_5_years',
  };

  String get label => switch (this) {
    HomeMostSoldPeriod.today => 'Today',
    HomeMostSoldPeriod.lastWeek => 'Last week',
    HomeMostSoldPeriod.lastMonth => 'Last month',
    HomeMostSoldPeriod.lastThreeMonths => 'Last 3 months',
    HomeMostSoldPeriod.lastSixMonths => 'Last 6 months',
    HomeMostSoldPeriod.lastYear => 'Last year',
    HomeMostSoldPeriod.lastFiveYears => 'Last 5 years',
  };

  static HomeMostSoldPeriod? tryParse(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    return switch (normalized) {
      'today' => HomeMostSoldPeriod.today,
      'last_week' || 'last-week' || 'week' => HomeMostSoldPeriod.lastWeek,
      'last_month' || 'last-month' || 'month' => HomeMostSoldPeriod.lastMonth,
      'last_3_months' || 'last-3-months' || '3_months' =>
        HomeMostSoldPeriod.lastThreeMonths,
      'last_6_months' || 'last-6-months' || '6_months' =>
        HomeMostSoldPeriod.lastSixMonths,
      'last_year' || 'last-year' || 'year' => HomeMostSoldPeriod.lastYear,
      'last_5_years' || 'last-5-years' || '5_years' =>
        HomeMostSoldPeriod.lastFiveYears,
      _ => null,
    };
  }
}

final class HomeDashboardRequest {
  const HomeDashboardRequest({
    this.tenantId,
    this.facilityId,
    this.mostSoldPeriod,
    this.mostSoldLimit,
  });

  factory HomeDashboardRequest.fromQuery(Map<String, String> query) {
    return HomeDashboardRequest(
      tenantId: _string(query['tenant_id'] ?? query['tenantId']),
      facilityId: _string(query['facility_id'] ?? query['facilityId']),
      mostSoldPeriod: HomeMostSoldPeriodX.tryParse(
        query['most_sold_period'] ?? query['mostSoldPeriod'],
      ),
      mostSoldLimit: int.tryParse(
        (query['most_sold_limit'] ?? query['mostSoldLimit'] ?? '').trim(),
      ),
    );
  }

  static const empty = HomeDashboardRequest();

  final String? tenantId;
  final String? facilityId;
  final HomeMostSoldPeriod? mostSoldPeriod;
  final int? mostSoldLimit;

  Map<String, Object?> toQueryParameters() {
    return <String, Object?>{
      if (tenantId != null) 'tenant_id': tenantId,
      if (facilityId != null) 'facility_id': facilityId,
      'limit': 5,
      if (mostSoldPeriod != null) 'most_sold_period': mostSoldPeriod!.apiValue,
      if (mostSoldLimit != null) 'most_sold_limit': mostSoldLimit,
    };
  }

  HomeDashboardRequest copyWith({
    String? tenantId,
    String? facilityId,
    HomeMostSoldPeriod? mostSoldPeriod,
    int? mostSoldLimit,
  }) {
    return HomeDashboardRequest(
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      mostSoldPeriod: mostSoldPeriod ?? this.mostSoldPeriod,
      mostSoldLimit: mostSoldLimit ?? this.mostSoldLimit,
    );
  }

  bool get hasTenantContext => tenantId != null;

  @override
  bool operator ==(Object other) {
    return other is HomeDashboardRequest &&
        other.tenantId == tenantId &&
        other.facilityId == facilityId &&
        other.mostSoldPeriod == mostSoldPeriod &&
        other.mostSoldLimit == mostSoldLimit;
  }

  @override
  int get hashCode =>
      Object.hash(tenantId, facilityId, mostSoldPeriod, mostSoldLimit);
}

final class HomeDashboard {
  const HomeDashboard({
    required this.state,
    required this.profile,
    required this.context,
    required this.statusCards,
    required this.trend,
    required this.distribution,
    required this.quickActionIds,
    required this.shortcutIds,
    required this.queuePreview,
    required this.alerts,
    required this.activity,
    required this.tenantOptions,
    this.resultsPreview = const <HomeQueueItem>[],
    this.followUpPreview = const <HomeQueueItem>[],
    this.mostSold = HomeMostSoldSeries.empty,
    this.generatedAt,
    this.usesFallbackData = false,
  });

  final HomeDashboardLoadState state;
  final HomeDashboardProfile profile;
  final HomeDashboardContext context;
  final List<HomeStatusCard> statusCards;
  final HomeDashboardTrend trend;
  final HomeDashboardDistribution distribution;
  final List<String> quickActionIds;
  final List<String> shortcutIds;
  final List<HomeQueueItem> queuePreview;
  final List<HomeAlertItem> alerts;
  final List<HomeActivityItem> activity;
  final List<HomeTenantOption> tenantOptions;
  final List<HomeQueueItem> resultsPreview;
  final List<HomeQueueItem> followUpPreview;
  final HomeMostSoldSeries mostSold;
  final DateTime? generatedAt;
  final bool usesFallbackData;

  HomeDashboard copyWith({
    HomeDashboardProfile? profile,
    HomeDashboardContext? context,
    List<HomeStatusCard>? statusCards,
    HomeDashboardTrend? trend,
    HomeDashboardDistribution? distribution,
    List<String>? quickActionIds,
    List<String>? shortcutIds,
    List<HomeQueueItem>? queuePreview,
    List<HomeAlertItem>? alerts,
    List<HomeActivityItem>? activity,
    List<HomeTenantOption>? tenantOptions,
    List<HomeQueueItem>? resultsPreview,
    List<HomeQueueItem>? followUpPreview,
    HomeMostSoldSeries? mostSold,
    DateTime? generatedAt,
    bool? usesFallbackData,
  }) {
    return HomeDashboard(
      state: state,
      profile: profile ?? this.profile,
      context: context ?? this.context,
      statusCards: statusCards ?? this.statusCards,
      trend: trend ?? this.trend,
      distribution: distribution ?? this.distribution,
      quickActionIds: quickActionIds ?? this.quickActionIds,
      shortcutIds: shortcutIds ?? this.shortcutIds,
      queuePreview: queuePreview ?? this.queuePreview,
      alerts: alerts ?? this.alerts,
      activity: activity ?? this.activity,
      tenantOptions: tenantOptions ?? this.tenantOptions,
      resultsPreview: resultsPreview ?? this.resultsPreview,
      followUpPreview: followUpPreview ?? this.followUpPreview,
      mostSold: mostSold ?? this.mostSold,
      generatedAt: generatedAt ?? this.generatedAt,
      usesFallbackData: usesFallbackData ?? this.usesFallbackData,
    );
  }

  bool get isTenantContextRequired {
    return state == HomeDashboardLoadState.tenantContextRequired;
  }

  bool get hasLiveContent {
    return statusCards.any((HomeStatusCard card) => card.numericValue > 0) ||
        trend.hasData ||
        distribution.hasData ||
        queuePreview.isNotEmpty ||
        resultsPreview.isNotEmpty ||
        followUpPreview.isNotEmpty ||
        alerts.any((HomeAlertItem alert) => alert.count > 0) ||
        activity.isNotEmpty;
  }

  int get attentionCount {
    final int alertTotal = alerts.fold<int>(
      0,
      (int sum, HomeAlertItem item) => sum + item.count,
    );
    return alertTotal +
        queuePreview.length +
        resultsPreview.length +
        followUpPreview.length;
  }
}

final class HomeMetricRouteTarget {
  const HomeMetricRouteTarget({
    this.queryParameters = const <String, String>{},
  });

  final Map<String, String> queryParameters;
}

/// Typed modal action for a home KPI card (HR workforce dashboard).
enum HomeMetricActionKind {
  hrStaffDirectory,
  hrWorkQueue,
  hrTodayShifts,
  hrOnLeaveToday,
  hrAttendedToday,
}

final class HomeMetricActionTarget {
  const HomeMetricActionTarget({
    required this.kind,
    this.hrQueue,
    this.staffStatusFilter,
    this.workItemStatus,
  });

  final HomeMetricActionKind kind;
  final String? hrQueue;
  final String? staffStatusFilter;
  final String? workItemStatus;
}

/// Toolbar action ids resolved by [buildHomeToolbarSecondary].
enum HomeToolbarActionId { openHrWorkspace }

final class HomeDashboardProfile {
  const HomeDashboardProfile({
    required this.id,
    required this.role,
    required this.roleLabel,
    required this.homeTitle,
    required this.emptyMessage,
    required this.statusCards,
    required this.quickActionIds,
    required this.shortcutIds,
    this.emptyActionIds = const <String>[],
    this.metricRouteTargets = const <String, HomeMetricRouteTarget>{},
    this.metricActionTargets = const <String, HomeMetricActionTarget>{},
    this.toolbarActionIds = const <HomeToolbarActionId>[],
    this.maxStatusCards = 6,
    this.showEmptyWorkspaceLink = false,
    this.suppressHomeQuickActions = false,
    this.suppressHomeShortcuts = false,
  });

  final String id;
  final AppRole role;
  final String roleLabel;
  final String homeTitle;
  final String emptyMessage;
  final List<HomeStatusCardTemplate> statusCards;
  final List<String> quickActionIds;
  final List<String> shortcutIds;
  final List<String> emptyActionIds;
  final Map<String, HomeMetricRouteTarget> metricRouteTargets;
  final Map<String, HomeMetricActionTarget> metricActionTargets;
  final List<HomeToolbarActionId> toolbarActionIds;
  final int maxStatusCards;
  final bool showEmptyWorkspaceLink;
  final bool suppressHomeQuickActions;
  final bool suppressHomeShortcuts;

  HomeDashboardProfile copyWith({
    String? id,
    AppRole? role,
    String? roleLabel,
    String? homeTitle,
    String? emptyMessage,
    List<HomeStatusCardTemplate>? statusCards,
    List<String>? quickActionIds,
    List<String>? shortcutIds,
    List<String>? emptyActionIds,
    Map<String, HomeMetricRouteTarget>? metricRouteTargets,
    Map<String, HomeMetricActionTarget>? metricActionTargets,
    List<HomeToolbarActionId>? toolbarActionIds,
    int? maxStatusCards,
    bool? showEmptyWorkspaceLink,
    bool? suppressHomeQuickActions,
    bool? suppressHomeShortcuts,
  }) {
    return HomeDashboardProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      roleLabel: roleLabel ?? this.roleLabel,
      homeTitle: homeTitle ?? this.homeTitle,
      emptyMessage: emptyMessage ?? this.emptyMessage,
      statusCards: statusCards ?? this.statusCards,
      quickActionIds: quickActionIds ?? this.quickActionIds,
      shortcutIds: shortcutIds ?? this.shortcutIds,
      emptyActionIds: emptyActionIds ?? this.emptyActionIds,
      metricRouteTargets: metricRouteTargets ?? this.metricRouteTargets,
      metricActionTargets: metricActionTargets ?? this.metricActionTargets,
      toolbarActionIds: toolbarActionIds ?? this.toolbarActionIds,
      maxStatusCards: maxStatusCards ?? this.maxStatusCards,
      showEmptyWorkspaceLink:
          showEmptyWorkspaceLink ?? this.showEmptyWorkspaceLink,
      suppressHomeQuickActions:
          suppressHomeQuickActions ?? this.suppressHomeQuickActions,
      suppressHomeShortcuts:
          suppressHomeShortcuts ?? this.suppressHomeShortcuts,
    );
  }

  List<HomeStatusCard> fallbackStatusCards() {
    return statusCards
        .map(
          (HomeStatusCardTemplate template) => HomeStatusCard(
            id: template.id,
            label: template.label,
            value: 0,
            format: template.format,
            requiredPermissions: template.effectiveRequiredPermissions,
          ),
        )
        .toList(growable: false);
  }
}

final class HomeStatusCardTemplate {
  const HomeStatusCardTemplate({
    required this.id,
    required this.label,
    this.format = 'number',
    this.requiredPermissions = const <AppPermission>[],
  });

  final String id;
  final String label;
  final String format;

  /// Explicit all-of permissions. When empty, resolve via catalog by [id].
  final List<AppPermission> requiredPermissions;

  List<AppPermission> get effectiveRequiredPermissions {
    return HomeDashboardAtomPermissions.resolveStatusCard(
      id: id,
      declared: requiredPermissions,
    );
  }
}

final class HomeDashboardContext {
  const HomeDashboardContext({
    this.roleValue,
    this.tenantId,
    this.facilityId,
    this.facilityName,
    this.facilityType,
    this.nurseContext,
    this.departmentName,
  });

  final String? roleValue;
  final String? tenantId;
  final String? facilityId;
  final String? facilityName;
  final String? facilityType;
  final String? nurseContext;
  final String? departmentName;
}

final class HomeStatusCard {
  const HomeStatusCard({
    required this.id,
    required this.label,
    required this.value,
    this.secondaryValue,
    this.hint,
    this.format = 'number',
    this.requiredPermissions = const <AppPermission>[],
  });

  final String id;
  final String label;
  final num value;
  final num? secondaryValue;
  final String? hint;
  final String format;

  /// All-of permissions. Prefer API metadata; else catalog / profile template.
  final List<AppPermission> requiredPermissions;

  int get numericValue => value.round();

  List<AppPermission> get effectiveRequiredPermissions {
    return HomeDashboardAtomPermissions.resolveStatusCard(
      id: id,
      declared: requiredPermissions,
    );
  }

  HomeStatusCard copyWith({
    String? id,
    String? label,
    num? value,
    num? secondaryValue,
    String? hint,
    String? format,
    List<AppPermission>? requiredPermissions,
  }) {
    return HomeStatusCard(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      hint: hint ?? this.hint,
      format: format ?? this.format,
      requiredPermissions: requiredPermissions ?? this.requiredPermissions,
    );
  }
}

final class HomeDashboardTrend {
  const HomeDashboardTrend({
    required this.title,
    required this.subtitle,
    required this.points,
    this.requiredPermissions = HomeDashboardAtomPermissions.charts,
  });

  static const empty = HomeDashboardTrend(
    title: '',
    subtitle: '',
    points: <HomeTrendPoint>[],
    requiredPermissions: <AppPermission>[],
  );

  final String title;
  final String subtitle;
  final List<HomeTrendPoint> points;
  final List<AppPermission> requiredPermissions;

  bool get hasData {
    return points.any((HomeTrendPoint point) => point.value > 0);
  }
}

final class HomeTrendPoint {
  const HomeTrendPoint({
    required this.id,
    required this.date,
    required this.value,
    this.label,
  });

  final String id;
  final DateTime? date;
  final num value;
  final String? label;
}

/// Last-month most-sold drug rankings for the pharmacy dashboard bar chart.
enum HomeMostSoldMetric { qty, amount, profit }

final class HomeMostSoldSeries {
  const HomeMostSoldSeries({
    this.qty = const <HomeTrendPoint>[],
    this.amount = const <HomeTrendPoint>[],
    this.profit = const <HomeTrendPoint>[],
  });

  static const empty = HomeMostSoldSeries();

  final List<HomeTrendPoint> qty;
  final List<HomeTrendPoint> amount;
  final List<HomeTrendPoint> profit;

  bool get hasData =>
      qty.any((HomeTrendPoint p) => p.value > 0) ||
      amount.any((HomeTrendPoint p) => p.value > 0) ||
      profit.any((HomeTrendPoint p) => p.value > 0);

  List<HomeTrendPoint> forMetric(HomeMostSoldMetric metric) {
    return switch (metric) {
      HomeMostSoldMetric.qty => qty,
      HomeMostSoldMetric.amount => amount,
      HomeMostSoldMetric.profit => profit,
    };
  }
}

final class HomeDashboardDistribution {
  const HomeDashboardDistribution({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.segments,
    this.requiredPermissions = HomeDashboardAtomPermissions.charts,
  });

  static const empty = HomeDashboardDistribution(
    title: '',
    subtitle: '',
    total: 0,
    segments: <HomeDistributionSegment>[],
    requiredPermissions: <AppPermission>[],
  );

  final String title;
  final String subtitle;
  final num total;
  final List<HomeDistributionSegment> segments;
  final List<AppPermission> requiredPermissions;

  bool get hasData {
    return total > 0 ||
        segments.any((HomeDistributionSegment segment) => segment.value > 0);
  }
}

final class HomeDistributionSegment {
  const HomeDistributionSegment({
    required this.id,
    required this.label,
    required this.value,
    this.color,
  });

  final String id;
  final String label;
  final num value;
  final String? color;
}

final class HomeQueueItem {
  const HomeQueueItem({
    required this.id,
    required this.label,
    required this.moduleSlug,
    required this.status,
    required this.severity,
    this.subtitle,
    this.occurredAt,
    this.target,
    this.requiredPermissions = const <AppPermission>[],
  });

  final String id;
  final String label;
  final String moduleSlug;
  final String? status;
  final String? severity;
  final String? subtitle;
  final DateTime? occurredAt;
  final HomeRouteTarget? target;
  final List<AppPermission> requiredPermissions;

  List<AppPermission> get effectiveRequiredPermissions {
    if (requiredPermissions.isNotEmpty) {
      return requiredPermissions;
    }
    return HomeDashboardAtomPermissions.forQueueItem(
      id: id,
      moduleSlug: moduleSlug.isNotEmpty
          ? moduleSlug
          : target?.moduleSlug,
    );
  }
}

final class HomeAlertItem {
  const HomeAlertItem({
    required this.id,
    required this.label,
    required this.severity,
    required this.count,
    this.target,
    this.requiredPermissions = const <AppPermission>[],
  });

  final String id;
  final String label;
  final String severity;
  final int count;
  final HomeRouteTarget? target;
  final List<AppPermission> requiredPermissions;

  List<AppPermission> get effectiveRequiredPermissions {
    if (requiredPermissions.isNotEmpty) {
      return requiredPermissions;
    }
    return HomeDashboardAtomPermissions.forAlert(
      id: id,
      moduleSlug: target?.moduleSlug,
    );
  }
}

final class HomeActivityItem {
  const HomeActivityItem({
    required this.id,
    required this.label,
    required this.moduleSlug,
    this.status,
    this.occurredAt,
    this.target,
    this.requiredPermissions = const <AppPermission>[],
  });

  final String id;
  final String label;
  final String moduleSlug;
  final String? status;
  final DateTime? occurredAt;
  final HomeRouteTarget? target;
  final List<AppPermission> requiredPermissions;

  List<AppPermission> get effectiveRequiredPermissions {
    if (requiredPermissions.isNotEmpty) {
      return requiredPermissions;
    }
    return HomeDashboardAtomPermissions.forActivity(
      id: id,
      moduleSlug: moduleSlug.isNotEmpty
          ? moduleSlug
          : target?.moduleSlug,
    );
  }
}

final class HomeRouteTarget {
  const HomeRouteTarget({
    required this.moduleSlug,
    this.resource,
    this.publicId,
    this.action,
  });

  final String moduleSlug;
  final String? resource;
  final String? publicId;
  final String? action;
}

final class HomeTenantOption {
  const HomeTenantOption({required this.id, required this.label});

  final String id;
  final String label;
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
