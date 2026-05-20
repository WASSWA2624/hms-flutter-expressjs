import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef SubscriptionJsonMap = Map<String, Object?>;

final class SubscriptionsWorkspaceDto {
  const SubscriptionsWorkspaceDto(this.json, {required this.query});

  final SubscriptionJsonMap json;
  final SubscriptionsWorkspaceQuery query;

  factory SubscriptionsWorkspaceDto.fromResponse(
    Object? responseData,
    SubscriptionsWorkspaceQuery query,
  ) {
    return SubscriptionsWorkspaceDto(_dataMap(responseData), query: query);
  }

  SubscriptionsWorkspaceData toEntity() {
    final List<SubscriptionItem> items = _list(json['items'])
        .map((SubscriptionJsonMap item) {
          return SubscriptionItemDto(
            item,
            resource: query.resource,
          ).toEntity();
        })
        .where((SubscriptionItem item) => item.id.isNotEmpty)
        .toList(growable: false);

    return SubscriptionsWorkspaceData(
      query: query,
      summary: _list(json['summary'])
          .map(SubscriptionSummaryMetricDto.new)
          .map((SubscriptionSummaryMetricDto dto) => dto.toEntity())
          .where((SubscriptionSummaryMetric metric) => metric.id.isNotEmpty)
          .toList(growable: false),
      queueSummaries: _list(json['queue_summaries'])
          .map(SubscriptionQueueSummaryDto.new)
          .map((SubscriptionQueueSummaryDto dto) => dto.toEntity())
          .where((SubscriptionQueueSummary queue) => queue.id.isNotEmpty)
          .toList(growable: false),
      panelSummaries: _list(json['panel_summaries'])
          .map(SubscriptionPanelSummaryDto.new)
          .map((SubscriptionPanelSummaryDto dto) => dto.toEntity())
          .toList(growable: false),
      lookups: SubscriptionLookupsDto(_map(json['lookups'])).toEntity(),
      items: AppPage<SubscriptionItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: _int(_map(json['pagination'])['total']),
      ),
      overview: SubscriptionsOverviewDto(_map(json['overview'])).toEntity(),
      timeline: _list(json['timeline'])
          .map(SubscriptionTimelineItemDto.new)
          .map((SubscriptionTimelineItemDto dto) => dto.toEntity())
          .where((SubscriptionTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class SubscriptionSummaryMetricDto {
  const SubscriptionSummaryMetricDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionSummaryMetric toEntity() {
    return SubscriptionSummaryMetric(
      id: _string(json['id']) ?? '',
      label: _string(json['label']) ?? _apiLabel(_string(json['id'])),
      value: _int(json['value']) ?? 0,
    );
  }
}

final class SubscriptionQueueSummaryDto {
  const SubscriptionQueueSummaryDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionQueueSummary toEntity() {
    return SubscriptionQueueSummary(
      id: _string(json['id']) ?? '',
      label: _string(json['label']) ?? _apiLabel(_string(json['id'])),
      count: _int(json['count']) ?? 0,
      panel: SubscriptionPanel.fromServer(_string(json['panel'])),
      resource: SubscriptionResource.fromServer(_string(json['resource'])),
      queue: _string(json['queue']),
    );
  }
}

final class SubscriptionPanelSummaryDto {
  const SubscriptionPanelSummaryDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionPanelSummary toEntity() {
    return SubscriptionPanelSummary(
      panel: SubscriptionPanel.fromServer(_string(json['id'])),
      count: _int(json['count']) ?? 0,
      defaultResource: SubscriptionResource.fromServer(
        _string(json['default_resource']),
      ),
    );
  }
}

final class SubscriptionLookupsDto {
  const SubscriptionLookupsDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionLookups toEntity() {
    return SubscriptionLookups(
      tenants: _lookupList(json['tenants']),
      plans: _lookupList(json['plans']),
      modules: _lookupList(json['modules']),
      statuses: _lookupList(json['statuses']),
      changeStatuses: _lookupList(json['change_statuses']),
      fitStatuses: _lookupList(json['fit_statuses']),
      billingCycles: _lookupList(json['billing_cycles']),
      tiers: _lookupList(json['tiers']),
      licenseTypes: _lookupList(json['license_types']),
      invoiceStatuses: _lookupList(json['invoice_statuses']),
      eligibilityStates: _lookupList(json['eligibility_states']),
    );
  }
}

final class SubscriptionsOverviewDto {
  const SubscriptionsOverviewDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionsOverview toEntity() {
    final SubscriptionJsonMap pendingChange = _map(json['pending_change']);
    return SubscriptionsOverview(
      currentSubscription: _nullableItem(
        json['current_subscription'],
        SubscriptionResource.subscriptions,
      ),
      currentPlan: SubscriptionPlanReferenceDto(
        _map(json['current_plan']),
      ).toEntity(),
      usageSummary: SubscriptionUsageSummaryDto(
        _map(json['usage_summary']),
      ).toEntity(),
      nextInvoice: _nullableItem(
        json['next_invoice'],
        SubscriptionResource.subscriptionInvoices,
      ),
      licenseSummary: SubscriptionLicenseSummaryDto(
        _map(json['license_summary']),
      ).toEntity(),
      recommendations: _list(json['recommendations'])
          .map(SubscriptionRecommendationDto.new)
          .map((SubscriptionRecommendationDto dto) => dto.toEntity())
          .where((SubscriptionRecommendation item) => item.id.isNotEmpty)
          .toList(growable: false),
      pendingChangeStatus: _string(pendingChange['status']),
      pendingChangeEffectiveAt: _date(pendingChange['effective_at']),
    );
  }
}

final class SubscriptionPlanReferenceDto {
  const SubscriptionPlanReferenceDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionPlanReference? toEntity() {
    if (json.isEmpty) {
      return null;
    }
    return SubscriptionPlanReference(
      id: _string(json['id']),
      label: _string(json['label']),
      code: _string(json['code']),
      tierCode: _string(json['tier_code']),
      billingCycle: _string(json['billing_cycle']),
    );
  }
}

final class SubscriptionUsageSummaryDto {
  const SubscriptionUsageSummaryDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionUsageSummary? toEntity() {
    if (json.isEmpty) {
      return null;
    }
    return SubscriptionUsageSummary(
      subscriptionId: _string(json['subscription_id']),
      planId: _string(json['plan_id']),
      usersUsed: _int(json['users_used']),
      facilitiesUsed: _int(json['facilities_used']),
      storageUsedMb: _int(json['storage_used_mb']),
      modulesUsed: _int(json['modules_used']),
      fitStatus: _string(json['fit_status']),
    );
  }
}

final class SubscriptionLicenseSummaryDto {
  const SubscriptionLicenseSummaryDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionLicenseSummary toEntity() {
    return SubscriptionLicenseSummary(
      activeCount: _int(json['active_count']) ?? 0,
      expiringCount: _int(json['expiring_count']) ?? 0,
      primaryLicense: _nullableItem(
        json['primary_license'],
        SubscriptionResource.licenses,
      ),
      items: _list(json['items'])
          .map((SubscriptionJsonMap item) {
            return SubscriptionItemDto(
              item,
              resource: SubscriptionResource.licenses,
            ).toEntity();
          })
          .where((SubscriptionItem item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class SubscriptionRecommendationDto {
  const SubscriptionRecommendationDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionRecommendation toEntity() {
    return SubscriptionRecommendation(
      id: _string(json['id']) ?? '',
      title: _string(json['title']) ?? '',
      type: _string(json['type']),
      description: _string(json['description']),
      queue: _string(json['queue']),
      subscriptionId: _string(json['subscription_id']),
    );
  }
}

final class SubscriptionTimelineItemDto {
  const SubscriptionTimelineItemDto(this.json);

  final SubscriptionJsonMap json;

  SubscriptionTimelineItem toEntity() {
    return SubscriptionTimelineItem(
      id: _string(json['id']) ?? '',
      title: _string(json['title']) ?? '',
      resource: SubscriptionResource.fromServer(_string(json['resource'])),
      subtitle: _string(json['subtitle']),
      status: _string(json['status']),
      occurredAt: _date(json['occurred_at']),
      targetId: _string(json['target_id']),
    );
  }
}

final class SubscriptionItemDto {
  const SubscriptionItemDto(this.json, {required this.resource});

  final SubscriptionJsonMap json;
  final SubscriptionResource resource;

  SubscriptionItem toEntity() {
    return SubscriptionItem(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      resource: resource,
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      tenantLabel: _string(json['tenant_label']),
      planId: _string(json['plan_id']),
      planLabel: _string(json['plan_label']),
      planCode: _string(json['plan_code']),
      tierCode:
          _string(json['tier_code']) ?? _string(json['plan_tier_code']),
      billingCycle: _string(json['billing_cycle']),
      moduleId: _string(json['module_id']),
      moduleLabel:
          _string(json['module_label']) ?? _string(json['module_name']),
      moduleSlug: _string(json['module_slug']) ?? _string(json['slug']),
      name: _string(json['name']),
      code: _string(json['code']),
      status: _string(json['status']),
      changeStatus: _string(json['change_status']),
      fitStatus:
          _string(json['plan_fit_status']) ??
          _string(json['evaluated_plan_fit_status']),
      licenseType: _string(json['license_type']),
      invoiceId: _string(json['invoice_id']),
      invoiceDisplayId: _string(json['invoice_display_id']),
      invoiceStatus: _string(json['invoice_status']),
      billingStatus: _string(json['billing_status']),
      currency: _string(json['currency']),
      price: _num(json['price']) ?? _num(json['add_on_price']),
      totalAmount: _num(json['total_amount']),
      maxUsers: _int(json['max_users']),
      maxFacilities: _int(json['max_facilities']),
      maxStorageMb: _int(json['max_storage_mb']),
      maxModules: _int(json['max_modules']),
      usersUsed: _int(json['users_used']),
      facilitiesUsed: _int(json['facilities_used']),
      storageUsedMb: _int(json['storage_used_mb']),
      modulesUsed: _int(json['modules_used']),
      activeModuleCount: _int(json['active_module_count']),
      subscriptionCount: _int(json['subscription_count']),
      isActive: _bool(json['is_active']),
      isAddOn: _bool(json['is_add_on']),
      entitlementDenied: _bool(json['entitlement_denied']) ?? false,
      entitlementDenialReason: _string(json['entitlement_denial_reason']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      issuedAt: _date(json['issued_at']),
      paidAt: _date(json['paid_at']),
      expiresAt: _date(json['expires_at']),
      updatedAt: _date(json['updated_at']) ?? _date(json['created_at']),
    );
  }
}

String decodeSubscriptionRecordId(Object? responseData) {
  final SubscriptionJsonMap data = _dataMap(responseData);
  return _firstString(<Object?>[
    data['id'],
    data['display_id'],
    data['human_friendly_id'],
  ]);
}

SubscriptionItem? _nullableItem(Object? value, SubscriptionResource resource) {
  final SubscriptionJsonMap json = _map(value);
  if (json.isEmpty) {
    return null;
  }
  final SubscriptionItem item = SubscriptionItemDto(
    json,
    resource: resource,
  ).toEntity();
  return item.id.isEmpty ? null : item;
}

List<SubscriptionLookupItem> _lookupList(Object? value) {
  return _list(value)
      .map((SubscriptionJsonMap item) {
        return SubscriptionLookupItem(
          id: _firstString(<Object?>[item['id'], item['value']]),
          label:
              _string(item['label']) ??
              _apiLabel(_string(item['id']) ?? _string(item['value'])),
          subtitle: _string(item['subtitle']),
          meta: _map(item['meta']),
        );
      })
      .where((SubscriptionLookupItem item) => item.id.isNotEmpty)
      .toList(growable: false);
}

SubscriptionJsonMap _dataMap(Object? responseData) {
  final SubscriptionJsonMap response = _map(responseData);
  final SubscriptionJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

SubscriptionJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<SubscriptionJsonMap> _list(Object? value) {
  if (value is! Iterable) {
    return const <SubscriptionJsonMap>[];
  }
  return value
      .map(_map)
      .where((SubscriptionJsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

String _firstString(Iterable<Object?> values) {
  for (final Object? value in values) {
    final String? normalized = _string(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return '';
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.replaceAll(',', '').trim());
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool? _bool(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return switch (value.toString().trim().toUpperCase()) {
    'TRUE' || '1' || 'YES' || 'ACTIVE' => true,
    'FALSE' || '0' || 'NO' || 'INACTIVE' || 'DISABLED' => false,
    _ => null,
  };
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

String _apiLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .replaceAll('-', '_')
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}
