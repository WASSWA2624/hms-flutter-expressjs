import 'package:hosspi_hms/core/permissions/access_policy.dart';

enum HomeDashboardLoadState { ready, tenantContextRequired }

final class HomeDashboardRequest {
  const HomeDashboardRequest({this.tenantId, this.facilityId, this.branchId});

  factory HomeDashboardRequest.fromQuery(Map<String, String> query) {
    return HomeDashboardRequest(
      tenantId: _string(query['tenant_id'] ?? query['tenantId']),
      facilityId: _string(query['facility_id'] ?? query['facilityId']),
      branchId: _string(query['branch_id'] ?? query['branchId']),
    );
  }

  static const empty = HomeDashboardRequest();

  final String? tenantId;
  final String? facilityId;
  final String? branchId;

  Map<String, Object?> toQueryParameters() {
    return <String, Object?>{
      if (tenantId != null) 'tenant_id': tenantId,
      if (facilityId != null) 'facility_id': facilityId,
      if (branchId != null) 'branch_id': branchId,
      'limit': 5,
    };
  }

  bool get hasTenantContext => tenantId != null;

  @override
  bool operator ==(Object other) {
    return other is HomeDashboardRequest &&
        other.tenantId == tenantId &&
        other.facilityId == facilityId &&
        other.branchId == branchId;
  }

  @override
  int get hashCode => Object.hash(tenantId, facilityId, branchId);
}

final class HomeDashboard {
  const HomeDashboard({
    required this.state,
    required this.profile,
    required this.context,
    required this.statusCards,
    required this.quickActionIds,
    required this.shortcutIds,
    required this.queuePreview,
    required this.alerts,
    required this.activity,
    required this.tenantOptions,
    this.generatedAt,
    this.usesFallbackData = false,
  });

  final HomeDashboardLoadState state;
  final HomeDashboardProfile profile;
  final HomeDashboardContext context;
  final List<HomeStatusCard> statusCards;
  final List<String> quickActionIds;
  final List<String> shortcutIds;
  final List<HomeQueueItem> queuePreview;
  final List<HomeAlertItem> alerts;
  final List<HomeActivityItem> activity;
  final List<HomeTenantOption> tenantOptions;
  final DateTime? generatedAt;
  final bool usesFallbackData;

  HomeDashboard copyWith({
    HomeDashboardProfile? profile,
    HomeDashboardContext? context,
    List<HomeStatusCard>? statusCards,
    List<String>? quickActionIds,
    List<String>? shortcutIds,
    List<HomeQueueItem>? queuePreview,
    List<HomeAlertItem>? alerts,
    List<HomeActivityItem>? activity,
    List<HomeTenantOption>? tenantOptions,
    DateTime? generatedAt,
    bool? usesFallbackData,
  }) {
    return HomeDashboard(
      state: state,
      profile: profile ?? this.profile,
      context: context ?? this.context,
      statusCards: statusCards ?? this.statusCards,
      quickActionIds: quickActionIds ?? this.quickActionIds,
      shortcutIds: shortcutIds ?? this.shortcutIds,
      queuePreview: queuePreview ?? this.queuePreview,
      alerts: alerts ?? this.alerts,
      activity: activity ?? this.activity,
      tenantOptions: tenantOptions ?? this.tenantOptions,
      generatedAt: generatedAt ?? this.generatedAt,
      usesFallbackData: usesFallbackData ?? this.usesFallbackData,
    );
  }

  bool get isTenantContextRequired {
    return state == HomeDashboardLoadState.tenantContextRequired;
  }

  bool get hasLiveContent {
    return statusCards.any((HomeStatusCard card) => card.numericValue > 0) ||
        queuePreview.isNotEmpty ||
        alerts.any((HomeAlertItem alert) => alert.count > 0) ||
        activity.isNotEmpty;
  }
}

final class HomeDashboardProfile {
  const HomeDashboardProfile({
    required this.id,
    required this.role,
    required this.roleLabel,
    required this.homeTitle,
    required this.homeSubtitle,
    required this.emptyMessage,
    required this.statusCards,
    required this.quickActionIds,
    required this.shortcutIds,
    this.emptyActionIds = const <String>[],
  });

  final String id;
  final AppRole role;
  final String roleLabel;
  final String homeTitle;
  final String homeSubtitle;
  final String emptyMessage;
  final List<HomeStatusCardTemplate> statusCards;
  final List<String> quickActionIds;
  final List<String> shortcutIds;
  final List<String> emptyActionIds;

  List<HomeStatusCard> fallbackStatusCards() {
    return statusCards
        .map(
          (HomeStatusCardTemplate template) => HomeStatusCard(
            id: template.id,
            label: template.label,
            value: 0,
            format: template.format,
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
  });

  final String id;
  final String label;
  final String format;
}

final class HomeDashboardContext {
  const HomeDashboardContext({
    this.roleValue,
    this.tenantId,
    this.facilityId,
    this.facilityName,
    this.facilityType,
    this.branchId,
  });

  final String? roleValue;
  final String? tenantId;
  final String? facilityId;
  final String? facilityName;
  final String? facilityType;
  final String? branchId;
}

final class HomeStatusCard {
  const HomeStatusCard({
    required this.id,
    required this.label,
    required this.value,
    this.format = 'number',
  });

  final String id;
  final String label;
  final num value;
  final String format;

  int get numericValue => value.round();
}

final class HomeQueueItem {
  const HomeQueueItem({
    required this.id,
    required this.label,
    required this.moduleSlug,
    required this.status,
    required this.severity,
    this.occurredAt,
    this.target,
  });

  final String id;
  final String label;
  final String moduleSlug;
  final String? status;
  final String? severity;
  final DateTime? occurredAt;
  final HomeRouteTarget? target;
}

final class HomeAlertItem {
  const HomeAlertItem({
    required this.id,
    required this.label,
    required this.severity,
    required this.count,
    this.target,
  });

  final String id;
  final String label;
  final String severity;
  final int count;
  final HomeRouteTarget? target;
}

final class HomeActivityItem {
  const HomeActivityItem({
    required this.id,
    required this.label,
    required this.moduleSlug,
    this.status,
    this.occurredAt,
    this.target,
  });

  final String id;
  final String label;
  final String moduleSlug;
  final String? status;
  final DateTime? occurredAt;
  final HomeRouteTarget? target;
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
