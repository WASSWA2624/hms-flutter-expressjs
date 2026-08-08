import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum SubscriptionPanel {
  overview('overview'),
  catalog('catalog'),
  modules('modules'),
  operations('operations'),
  billing('billing'),
  governance('governance'),
  denied('denied');

  const SubscriptionPanel(this.serverValue);

  final String serverValue;

  static SubscriptionPanel fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'denied-modules' || normalized == 'denied_modules') {
      return SubscriptionPanel.denied;
    }
    for (final SubscriptionPanel panel in values) {
      if (panel.serverValue == normalized) {
        return panel;
      }
    }
    return SubscriptionPanel.catalog;
  }
}

enum SubscriptionResource {
  subscriptionPlans('subscription-plans', SubscriptionPanel.catalog),
  modules('modules', SubscriptionPanel.modules),
  subscriptions('subscriptions', SubscriptionPanel.operations),
  moduleSubscriptions('module-subscriptions', SubscriptionPanel.operations),
  subscriptionInvoices('subscription-invoices', SubscriptionPanel.billing),
  licenses('licenses', SubscriptionPanel.governance);

  const SubscriptionResource(this.serverValue, this.defaultPanel);

  final String serverValue;
  final SubscriptionPanel defaultPanel;

  static SubscriptionResource fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final SubscriptionResource resource in values) {
      if (resource.serverValue == normalized) {
        return resource;
      }
    }
    return SubscriptionResource.subscriptionPlans;
  }
}

enum SubscriptionDatePreset {
  none(''),
  today('today'),
  last30Days('last_30_days'),
  next30Days('next_30_days'),
  nextRenewal('next_renewal');

  const SubscriptionDatePreset(this.serverValue);

  final String serverValue;

  static SubscriptionDatePreset fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final SubscriptionDatePreset preset in values) {
      if (preset.serverValue == normalized) {
        return preset;
      }
    }
    return SubscriptionDatePreset.none;
  }
}

@immutable
final class SubscriptionLegacyRouteResolution {
  const SubscriptionLegacyRouteResolution({
    required this.panel,
    required this.resource,
    this.id,
    this.action,
    this.tenantId,
  });

  final SubscriptionPanel panel;
  final SubscriptionResource resource;
  final String? id;
  final String? action;
  final String? tenantId;
}

@immutable
final class SubscriptionsWorkspaceQuery {
  const SubscriptionsWorkspaceQuery({
    this.search = '',
    this.panel = SubscriptionPanel.catalog,
    this.resource = SubscriptionResource.subscriptionPlans,
    this.queue,
    this.tenantId,
    this.recordId,
    this.action,
    this.status,
    this.tierCode,
    this.billingCycle,
    this.planId,
    this.moduleId,
    this.fitStatus,
    this.changeStatus,
    this.invoiceStatus,
    this.licenseType,
    this.eligibilityState,
    this.datePreset = SubscriptionDatePreset.none,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  factory SubscriptionsWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    SubscriptionPanel panel = SubscriptionPanel.fromServer(params['panel']);
    SubscriptionResource resource = SubscriptionResource.fromServer(
      params['resource'],
    );
    String? queue = _nonEmpty(params['queue']);

    // Legacy: Plans nested Modules → Modules primary tab.
    if (panel == SubscriptionPanel.catalog &&
        resource == SubscriptionResource.modules) {
      panel = SubscriptionPanel.modules;
    }

    // Legacy: module_blocked queue chip → Denied modules primary tab.
    final String? normalizedQueue = queue?.trim().toUpperCase();
    if (normalizedQueue == 'MODULE_BLOCKED' ||
        (queue ?? '').trim().toLowerCase() == 'module_blocked') {
      panel = SubscriptionPanel.denied;
      resource = SubscriptionResource.moduleSubscriptions;
      queue = 'MODULE_BLOCKED';
    }

    if (panel == SubscriptionPanel.modules) {
      resource = SubscriptionResource.modules;
    }
    if (panel == SubscriptionPanel.denied) {
      resource = SubscriptionResource.moduleSubscriptions;
      queue = 'MODULE_BLOCKED';
    }

    // Legacy: nested Module subscriptions under operations → subscriptions
    // worklist (Denied / MODULE_BLOCKED already handled above).
    if (panel == SubscriptionPanel.operations &&
        resource == SubscriptionResource.moduleSubscriptions) {
      resource = SubscriptionResource.subscriptions;
    }

    return SubscriptionsWorkspaceQuery(
      search: params['search'] ?? '',
      panel: panel,
      resource: resource,
      queue: queue,
      tenantId: _nonEmpty(params['tenantId'] ?? params['tenant_id']),
      recordId: _nonEmpty(params['id'] ?? params['recordId']),
      action: _nonEmpty(params['action']),
      status: _nonEmpty(params['status']),
      tierCode: _nonEmpty(params['tierCode'] ?? params['tier_code']),
      billingCycle: _nonEmpty(
        params['billingCycle'] ?? params['billing_cycle'],
      ),
      planId: _nonEmpty(params['planId'] ?? params['plan_id']),
      moduleId: _nonEmpty(params['moduleId'] ?? params['module_id']),
      fitStatus: _nonEmpty(params['fitStatus'] ?? params['fit_status']),
      changeStatus: _nonEmpty(
        params['changeStatus'] ?? params['change_status'],
      ),
      invoiceStatus: _nonEmpty(
        params['invoiceStatus'] ?? params['invoice_status'],
      ),
      licenseType: _nonEmpty(params['licenseType'] ?? params['license_type']),
      eligibilityState: _nonEmpty(
        params['eligibilityState'] ?? params['eligibility_state'],
      ),
      datePreset: SubscriptionDatePreset.fromServer(
        params['datePreset'] ?? params['date_preset'],
      ),
    );
  }

  final String search;
  final SubscriptionPanel panel;
  final SubscriptionResource resource;
  final String? queue;
  final String? tenantId;
  final String? recordId;
  final String? action;
  final String? status;
  final String? tierCode;
  final String? billingCycle;
  final String? planId;
  final String? moduleId;
  final String? fitStatus;
  final String? changeStatus;
  final String? invoiceStatus;
  final String? licenseType;
  final String? eligibilityState;
  final SubscriptionDatePreset datePreset;
  final AppPageRequest pageRequest;

  bool get hasRouteTargeting {
    return recordId != null ||
        action != null ||
        panel != SubscriptionPanel.catalog ||
        resource != SubscriptionResource.subscriptionPlans ||
        queue != null ||
        tenantId != null;
  }

  String location() {
    final Map<String, String> query = <String, String>{
      'panel': panel.serverValue,
    };
    final bool includeResource = panel == SubscriptionPanel.denied ||
        panel == SubscriptionPanel.modules ||
        panel == SubscriptionPanel.operations ||
        resource != SubscriptionResource.subscriptionPlans;
    if (includeResource) {
      query['resource'] = resource.serverValue;
    }
    if (search.isNotEmpty) query['search'] = search;
    if (queue != null) query['queue'] = queue!;
    if (tenantId != null) query['tenantId'] = tenantId!;
    if (recordId != null) query['id'] = recordId!;
    if (action != null) query['action'] = action!;
    if (status != null) query['status'] = status!;
    if (tierCode != null) query['tierCode'] = tierCode!;
    if (billingCycle != null) query['billingCycle'] = billingCycle!;
    return Uri(path: '/subscriptions', queryParameters: query).toString();
  }

  bool get hasActiveFilters {
    return search.trim().isNotEmpty ||
        queue != null ||
        tenantId != null ||
        recordId != null ||
        action != null ||
        status != null ||
        tierCode != null ||
        billingCycle != null ||
        planId != null ||
        moduleId != null ||
        fitStatus != null ||
        changeStatus != null ||
        invoiceStatus != null ||
        licenseType != null ||
        eligibilityState != null ||
        datePreset != SubscriptionDatePreset.none;
  }

  SubscriptionsWorkspaceQuery copyWith({
    String? search,
    SubscriptionPanel? panel,
    SubscriptionResource? resource,
    Object? queue = _unset,
    Object? tenantId = _unset,
    Object? recordId = _unset,
    Object? action = _unset,
    Object? status = _unset,
    Object? tierCode = _unset,
    Object? billingCycle = _unset,
    Object? planId = _unset,
    Object? moduleId = _unset,
    Object? fitStatus = _unset,
    Object? changeStatus = _unset,
    Object? invoiceStatus = _unset,
    Object? licenseType = _unset,
    Object? eligibilityState = _unset,
    SubscriptionDatePreset? datePreset,
    AppPageRequest? pageRequest,
  }) {
    return SubscriptionsWorkspaceQuery(
      search: search ?? this.search,
      panel: panel ?? this.panel,
      resource: resource ?? this.resource,
      queue: queue == _unset ? this.queue : queue as String?,
      tenantId: tenantId == _unset ? this.tenantId : tenantId as String?,
      recordId: recordId == _unset ? this.recordId : recordId as String?,
      action: action == _unset ? this.action : action as String?,
      status: status == _unset ? this.status : status as String?,
      tierCode: tierCode == _unset ? this.tierCode : tierCode as String?,
      billingCycle: billingCycle == _unset
          ? this.billingCycle
          : billingCycle as String?,
      planId: planId == _unset ? this.planId : planId as String?,
      moduleId: moduleId == _unset ? this.moduleId : moduleId as String?,
      fitStatus: fitStatus == _unset ? this.fitStatus : fitStatus as String?,
      changeStatus: changeStatus == _unset
          ? this.changeStatus
          : changeStatus as String?,
      invoiceStatus: invoiceStatus == _unset
          ? this.invoiceStatus
          : invoiceStatus as String?,
      licenseType: licenseType == _unset
          ? this.licenseType
          : licenseType as String?,
      eligibilityState: eligibilityState == _unset
          ? this.eligibilityState
          : eligibilityState as String?,
      datePreset: datePreset ?? this.datePreset,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }

  SubscriptionsWorkspaceQuery resetFilters() {
    return copyWith(
      search: '',
      queue: null,
      tenantId: null,
      recordId: null,
      action: null,
      status: null,
      tierCode: null,
      billingCycle: null,
      planId: null,
      moduleId: null,
      fitStatus: null,
      changeStatus: null,
      invoiceStatus: null,
      licenseType: null,
      eligibilityState: null,
      datePreset: SubscriptionDatePreset.none,
      pageRequest: pageRequest.first(),
    );
  }
}

@immutable
final class SubscriptionLookupItem {
  const SubscriptionLookupItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.meta = const <String, Object?>{},
  });

  final String id;
  final String label;
  final String? subtitle;
  final Map<String, Object?> meta;
}

@immutable
final class SubscriptionLookups {
  const SubscriptionLookups({
    this.tenants = const <SubscriptionLookupItem>[],
    this.plans = const <SubscriptionLookupItem>[],
    this.modules = const <SubscriptionLookupItem>[],
    this.statuses = const <SubscriptionLookupItem>[],
    this.changeStatuses = const <SubscriptionLookupItem>[],
    this.fitStatuses = const <SubscriptionLookupItem>[],
    this.billingCycles = const <SubscriptionLookupItem>[],
    this.tiers = const <SubscriptionLookupItem>[],
    this.licenseTypes = const <SubscriptionLookupItem>[],
    this.invoiceStatuses = const <SubscriptionLookupItem>[],
    this.eligibilityStates = const <SubscriptionLookupItem>[],
  });

  final List<SubscriptionLookupItem> tenants;
  final List<SubscriptionLookupItem> plans;
  final List<SubscriptionLookupItem> modules;
  final List<SubscriptionLookupItem> statuses;
  final List<SubscriptionLookupItem> changeStatuses;
  final List<SubscriptionLookupItem> fitStatuses;
  final List<SubscriptionLookupItem> billingCycles;
  final List<SubscriptionLookupItem> tiers;
  final List<SubscriptionLookupItem> licenseTypes;
  final List<SubscriptionLookupItem> invoiceStatuses;
  final List<SubscriptionLookupItem> eligibilityStates;
}

@immutable
final class SubscriptionSummaryMetric {
  const SubscriptionSummaryMetric({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final int value;
}

@immutable
final class SubscriptionQueueSummary {
  const SubscriptionQueueSummary({
    required this.id,
    required this.label,
    required this.count,
    required this.panel,
    required this.resource,
    this.queue,
  });

  final String id;
  final String label;
  final int count;
  final SubscriptionPanel panel;
  final SubscriptionResource resource;
  final String? queue;
}

@immutable
final class SubscriptionPanelSummary {
  const SubscriptionPanelSummary({
    required this.panel,
    required this.count,
    required this.defaultResource,
  });

  final SubscriptionPanel panel;
  final int count;
  final SubscriptionResource defaultResource;
}

@immutable
final class SubscriptionUsageSummary {
  const SubscriptionUsageSummary({
    this.subscriptionId,
    this.planId,
    this.usersUsed,
    this.facilitiesUsed,
    this.storageUsedMb,
    this.modulesUsed,
    this.fitStatus,
  });

  final String? subscriptionId;
  final String? planId;
  final int? usersUsed;
  final int? facilitiesUsed;
  final int? storageUsedMb;
  final int? modulesUsed;
  final String? fitStatus;
}

@immutable
final class SubscriptionLicenseSummary {
  const SubscriptionLicenseSummary({
    this.activeCount = 0,
    this.expiringCount = 0,
    this.primaryLicense,
    this.items = const <SubscriptionItem>[],
  });

  final int activeCount;
  final int expiringCount;
  final SubscriptionItem? primaryLicense;
  final List<SubscriptionItem> items;
}

@immutable
final class SubscriptionRecommendation {
  const SubscriptionRecommendation({
    required this.id,
    required this.title,
    this.type,
    this.description,
    this.queue,
    this.subscriptionId,
  });

  final String id;
  final String title;
  final String? type;
  final String? description;
  final String? queue;
  final String? subscriptionId;
}

@immutable
final class SubscriptionsOverview {
  const SubscriptionsOverview({
    this.currentSubscription,
    this.currentPlan,
    this.usageSummary,
    this.nextInvoice,
    this.licenseSummary = const SubscriptionLicenseSummary(),
    this.recommendations = const <SubscriptionRecommendation>[],
    this.pendingChangeStatus,
    this.pendingChangeEffectiveAt,
    this.activePlanTenants = const SubscriptionTenantCohortSummary(
      cohort: SubscriptionTenantCohort.active,
    ),
    this.notSubscribedTenants = const SubscriptionTenantCohortSummary(
      cohort: SubscriptionTenantCohort.notSubscribed,
    ),
    this.closedSubscriptionTenants = const SubscriptionTenantCohortSummary(
      cohort: SubscriptionTenantCohort.closed,
    ),
  });

  final SubscriptionItem? currentSubscription;
  final SubscriptionPlanReference? currentPlan;
  final SubscriptionUsageSummary? usageSummary;
  final SubscriptionItem? nextInvoice;
  final SubscriptionLicenseSummary licenseSummary;
  final List<SubscriptionRecommendation> recommendations;
  final String? pendingChangeStatus;
  final DateTime? pendingChangeEffectiveAt;
  final SubscriptionTenantCohortSummary activePlanTenants;
  final SubscriptionTenantCohortSummary notSubscribedTenants;
  final SubscriptionTenantCohortSummary closedSubscriptionTenants;

  SubscriptionTenantCohortSummary cohortSummary(
    SubscriptionTenantCohort cohort,
  ) {
    return switch (cohort) {
      SubscriptionTenantCohort.active => activePlanTenants,
      SubscriptionTenantCohort.notSubscribed => notSubscribedTenants,
      SubscriptionTenantCohort.closed => closedSubscriptionTenants,
    };
  }
}

enum SubscriptionTenantCohort { active, notSubscribed, closed }

@immutable
final class SubscriptionTenantAccount {
  const SubscriptionTenantAccount({
    required this.id,
    required this.tenantId,
    this.tenantLabel,
    this.subscriptionId,
    this.status,
    this.planId,
    this.planLabel,
    this.planCode,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String tenantId;
  final String? tenantLabel;
  final String? subscriptionId;
  final String? status;
  final String? planId;
  final String? planLabel;
  final String? planCode;
  final DateTime? startDate;
  final DateTime? endDate;

  String get title {
    return _firstText(<String?>[tenantLabel, tenantId, id]);
  }
}

@immutable
final class SubscriptionTenantCohortSummary {
  const SubscriptionTenantCohortSummary({
    required this.cohort,
    this.count = 0,
    this.accounts = const <SubscriptionTenantAccount>[],
  });

  final SubscriptionTenantCohort cohort;
  final int count;
  final List<SubscriptionTenantAccount> accounts;
}

@immutable
final class SubscriptionPlanReference {
  const SubscriptionPlanReference({
    this.id,
    this.label,
    this.code,
    this.tierCode,
    this.billingCycle,
  });

  final String? id;
  final String? label;
  final String? code;
  final String? tierCode;
  final String? billingCycle;
}

@immutable
final class SubscriptionTimelineItem {
  const SubscriptionTimelineItem({
    required this.id,
    required this.title,
    required this.resource,
    this.subtitle,
    this.status,
    this.occurredAt,
    this.targetId,
  });

  final String id;
  final String title;
  final SubscriptionResource resource;
  final String? subtitle;
  final String? status;
  final DateTime? occurredAt;
  final String? targetId;
}

@immutable
final class SubscriptionItem {
  const SubscriptionItem({
    required this.id,
    required this.resource,
    this.displayId,
    this.tenantId,
    this.tenantLabel,
    this.planId,
    this.planLabel,
    this.planCode,
    this.tierCode,
    this.billingCycle,
    this.moduleId,
    this.moduleLabel,
    this.moduleSlug,
    this.name,
    this.code,
    this.description,
    this.status,
    this.changeStatus,
    this.fitStatus,
    this.licenseType,
    this.invoiceId,
    this.invoiceDisplayId,
    this.invoiceStatus,
    this.billingStatus,
    this.currency,
    this.price,
    this.monthlyPrice,
    this.annualPrice,
    this.totalAmount,
    this.maxUsers,
    this.maxFacilities,
    this.maxStorageMb,
    this.maxModules,
    this.usersUsed,
    this.facilitiesUsed,
    this.storageUsedMb,
    this.modulesUsed,
    this.activeModuleCount,
    this.subscriptionCount,
    this.isActive,
    this.isAddOn,
    this.entitlementDenied = false,
    this.entitlementDenialReason,
    this.includedModuleIds = const <String>[],
    this.startDate,
    this.endDate,
    this.issuedAt,
    this.paidAt,
    this.expiresAt,
    this.updatedAt,
  });

  final String id;
  final SubscriptionResource resource;
  final String? displayId;
  final String? tenantId;
  final String? tenantLabel;
  final String? planId;
  final String? planLabel;
  final String? planCode;
  final String? tierCode;
  final String? billingCycle;
  final String? moduleId;
  final String? moduleLabel;
  final String? moduleSlug;
  final String? name;
  final String? code;
  final String? description;
  final String? status;
  final String? changeStatus;
  final String? fitStatus;
  final String? licenseType;
  final String? invoiceId;
  final String? invoiceDisplayId;
  final String? invoiceStatus;
  final String? billingStatus;
  final String? currency;
  final num? price;
  final num? monthlyPrice;
  final num? annualPrice;
  final num? totalAmount;
  final int? maxUsers;
  final int? maxFacilities;
  final int? maxStorageMb;
  final int? maxModules;
  final int? usersUsed;
  final int? facilitiesUsed;
  final int? storageUsedMb;
  final int? modulesUsed;
  final int? activeModuleCount;
  final int? subscriptionCount;
  final bool? isActive;
  final bool? isAddOn;
  final bool entitlementDenied;
  final String? entitlementDenialReason;
  final List<String> includedModuleIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  String get effectiveDisplayId =>
      _firstText(<String?>[displayId, invoiceDisplayId, code, id]);

  num? get resolvedMonthlyPrice {
    if (monthlyPrice != null) {
      return monthlyPrice;
    }
    if (price == null) {
      return null;
    }
    final String cycle = (billingCycle ?? '').trim().toUpperCase();
    if (cycle.contains('YEAR') || cycle == 'ANNUAL') {
      return num.parse((price! / 12).toStringAsFixed(2));
    }
    return price;
  }

  num? get resolvedAnnualPrice {
    if (annualPrice != null) {
      return annualPrice;
    }
    if (price == null) {
      return null;
    }
    final String cycle = (billingCycle ?? '').trim().toUpperCase();
    if (cycle.contains('YEAR') || cycle == 'ANNUAL') {
      return price;
    }
    return num.parse((price! * 12).toStringAsFixed(2));
  }

  String get title {
    return _firstText(<String?>[
      if (resource == SubscriptionResource.subscriptionPlans) name,
      if (resource == SubscriptionResource.modules) name,
      if (resource == SubscriptionResource.moduleSubscriptions) moduleLabel,
      if (resource == SubscriptionResource.subscriptionInvoices)
        invoiceDisplayId,
      if (resource == SubscriptionResource.licenses) licenseType,
      if (resource == SubscriptionResource.subscriptions) planLabel,
      displayId,
      id,
    ]);
  }

  String? get subtitle {
    final parts = <String>[
      if (_hasText(tenantLabel)) tenantLabel!.trim(),
      if (_hasText(planLabel) && resource != SubscriptionResource.subscriptions)
        planLabel!.trim(),
      if (_hasText(tierCode)) tierCode!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' | ');
  }

  String? get primaryStatus {
    if (resource == SubscriptionResource.moduleSubscriptions) {
      if (entitlementDenied) {
        return 'DENIED';
      }
      return isActive == true ? 'ACTIVE' : 'INACTIVE';
    }
    if (resource == SubscriptionResource.subscriptionInvoices) {
      return invoiceStatus ?? billingStatus;
    }
    return status ?? fitStatus ?? changeStatus;
  }

  bool get canRenewSubscription {
    return resource == SubscriptionResource.subscriptions && id.isNotEmpty;
  }

  bool get canActivateSubscription {
    final String normalized = (status ?? '').trim().toUpperCase();
    return resource == SubscriptionResource.subscriptions &&
        id.isNotEmpty &&
        normalized != 'ACTIVE' &&
        normalized != 'TRIAL';
  }

  bool get canCancelSubscription {
    final String normalized = (status ?? '').trim().toUpperCase();
    return resource == SubscriptionResource.subscriptions &&
        id.isNotEmpty &&
        normalized != 'CANCELLED';
  }

  bool get canToggleModule {
    return resource == SubscriptionResource.moduleSubscriptions &&
        id.isNotEmpty;
  }

  bool get canCollectInvoice {
    final String normalized = (invoiceStatus ?? billingStatus ?? '')
        .trim()
        .toUpperCase();
    return resource == SubscriptionResource.subscriptionInvoices &&
        id.isNotEmpty &&
        normalized != 'PAID' &&
        normalized != 'CANCELLED';
  }
}

@immutable
final class SubscriptionsWorkspaceData {
  const SubscriptionsWorkspaceData({
    required this.query,
    required this.summary,
    required this.queueSummaries,
    required this.panelSummaries,
    required this.lookups,
    required this.items,
    required this.overview,
    required this.timeline,
  });

  final SubscriptionsWorkspaceQuery query;
  final List<SubscriptionSummaryMetric> summary;
  final List<SubscriptionQueueSummary> queueSummaries;
  final List<SubscriptionPanelSummary> panelSummaries;
  final SubscriptionLookups lookups;
  final AppPage<SubscriptionItem> items;
  final SubscriptionsOverview overview;
  final List<SubscriptionTimelineItem> timeline;

  SubscriptionsWorkspaceData copyWith({
    SubscriptionsWorkspaceQuery? query,
    List<SubscriptionSummaryMetric>? summary,
    List<SubscriptionQueueSummary>? queueSummaries,
    List<SubscriptionPanelSummary>? panelSummaries,
    SubscriptionLookups? lookups,
    AppPage<SubscriptionItem>? items,
    SubscriptionsOverview? overview,
    List<SubscriptionTimelineItem>? timeline,
  }) {
    return SubscriptionsWorkspaceData(
      query: query ?? this.query,
      summary: summary ?? this.summary,
      queueSummaries: queueSummaries ?? this.queueSummaries,
      panelSummaries: panelSummaries ?? this.panelSummaries,
      lookups: lookups ?? this.lookups,
      items: items ?? this.items,
      overview: overview ?? this.overview,
      timeline: timeline ?? this.timeline,
    );
  }
}

@immutable
final class SubscriptionsWorkspaceState {
  const SubscriptionsWorkspaceState({
    required this.data,
    this.selectedItem,
    this.planDetail,
    this.isLoadingPlanDetail = false,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final SubscriptionsWorkspaceData data;
  final SubscriptionItem? selectedItem;
  final SubscriptionPlanDetail? planDetail;
  final bool isLoadingPlanDetail;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;

  SubscriptionsWorkspaceQuery get query => data.query;
  AppPage<SubscriptionItem> get items => data.items;
  List<SubscriptionSummaryMetric> get summary => data.summary;
  List<SubscriptionQueueSummary> get queueSummaries => data.queueSummaries;
  SubscriptionLookups get lookups => data.lookups;
  SubscriptionsOverview get overview => data.overview;
  List<SubscriptionTimelineItem> get timeline => data.timeline;

  int summaryValue(String id) {
    for (final SubscriptionSummaryMetric metric in summary) {
      if (metric.id == id) {
        return metric.value;
      }
    }
    return 0;
  }

  int get workloadCount {
    return summaryValue('pending_changes') +
        summaryValue('past_due_invoices') +
        summaryValue('denied_modules') +
        summaryValue('expiring_licenses') +
        summaryValue('approaching_limits');
  }

  SubscriptionsWorkspaceState copyWith({
    SubscriptionsWorkspaceData? data,
    SubscriptionItem? selectedItem,
    SubscriptionPlanDetail? planDetail,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool? isLoadingPlanDetail,
    bool clearSelectedItem = false,
    bool clearPlanDetail = false,
    bool clearLastFailure = false,
  }) {
    return SubscriptionsWorkspaceState(
      data: data ?? this.data,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      planDetail: clearPlanDetail ? null : planDetail ?? this.planDetail,
      isLoadingPlanDetail: isLoadingPlanDetail ?? this.isLoadingPlanDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

@immutable
final class SubscriptionPlanDraft {
  const SubscriptionPlanDraft({
    required this.name,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.billingCycle,
    this.code,
    this.tierCode,
    this.description,
    this.maxUsers,
    this.maxFacilities,
    this.maxStorageMb,
    this.maxModules,
    this.tenantId,
    this.includedModuleIds = const <String>[],
  });

  final String name;
  final String monthlyPrice;
  final String annualPrice;
  final String billingCycle;
  final String? code;
  final String? tierCode;
  final String? description;
  final String? maxUsers;
  final String? maxFacilities;
  final String? maxStorageMb;
  final String? maxModules;
  final String? tenantId;
  final List<String> includedModuleIds;

  /// Canonical billable amount kept for backend compatibility.
  String get price => monthlyPrice;
}

@immutable
final class SubscriptionPlanDetailStats {
  const SubscriptionPlanDetailStats({
    this.activeCount = 0,
    this.pendingCount = 0,
    this.closedCount = 0,
    this.totalCount = 0,
  });

  final int activeCount;
  final int pendingCount;
  final int closedCount;
  final int totalCount;
}

@immutable
final class SubscriptionPlanDetail {
  const SubscriptionPlanDetail({
    required this.plan,
    this.stats = const SubscriptionPlanDetailStats(),
    this.activeAccounts = const <SubscriptionTenantAccount>[],
    this.pendingAccounts = const <SubscriptionTenantAccount>[],
    this.closedAccounts = const <SubscriptionTenantAccount>[],
  });

  final SubscriptionItem plan;
  final SubscriptionPlanDetailStats stats;
  final List<SubscriptionTenantAccount> activeAccounts;
  final List<SubscriptionTenantAccount> pendingAccounts;
  final List<SubscriptionTenantAccount> closedAccounts;
}

@immutable
final class SubscriptionDraft {
  const SubscriptionDraft({
    required this.tenantId,
    required this.planId,
    required this.status,
    this.startDate,
    this.endDate,
  });

  final String tenantId;
  final String planId;
  final String status;
  final String? startDate;
  final String? endDate;
}

@immutable
final class SubscriptionRenewalDraft {
  const SubscriptionRenewalDraft({this.endDate, this.reason});

  final String? endDate;
  final String? reason;
}

@immutable
final class SubscriptionPlanChangeDraft {
  const SubscriptionPlanChangeDraft({
    required this.targetPlanId,
    required this.changeType,
    this.effectiveAt,
    this.reason,
  });

  final String targetPlanId;
  final String changeType;
  final String? effectiveAt;
  final String? reason;
}

@immutable
final class ModuleSubscriptionDraft {
  const ModuleSubscriptionDraft({
    required this.subscriptionId,
    required this.moduleId,
    this.isActive = true,
  });

  final String subscriptionId;
  final String moduleId;
  final bool isActive;
}

@immutable
final class LicenseDraft {
  const LicenseDraft({
    required this.tenantId,
    required this.licenseType,
    required this.status,
    this.issuedAt,
    this.expiresAt,
  });

  final String tenantId;
  final String licenseType;
  final String status;
  final String? issuedAt;
  final String? expiresAt;
}

@immutable
final class SubscriptionActionDraft {
  const SubscriptionActionDraft({this.reason, this.notes, this.paymentMethod});

  final String? reason;
  final String? notes;
  final String? paymentMethod;
}

enum SubscriptionUpgradeBillingCycle { monthly, annual }

@immutable
final class SubscriptionUpgradePlanOption {
  const SubscriptionUpgradePlanOption({
    required this.id,
    required this.label,
    this.tierCode,
    this.billingCycle,
    this.price,
    this.monthlyPrice,
    this.annualPrice,
    this.maxUsers,
    this.maxFacilities,
    this.maxStorageMb,
    this.includedModuleSlugs = const <String>[],
  });

  final String id;
  final String label;
  final String? tierCode;
  final String? billingCycle;
  final double? price;
  final double? monthlyPrice;
  final double? annualPrice;
  final int? maxUsers;
  final int? maxFacilities;
  final int? maxStorageMb;
  final List<String> includedModuleSlugs;

  double? priceFor(SubscriptionUpgradeBillingCycle cycle) {
    return switch (cycle) {
      SubscriptionUpgradeBillingCycle.monthly => resolvedMonthlyPrice,
      SubscriptionUpgradeBillingCycle.annual => resolvedAnnualPrice,
    };
  }

  double? get resolvedMonthlyPrice {
    if (monthlyPrice != null) {
      return monthlyPrice;
    }
    if (price == null) {
      return null;
    }
    final String cycle = (billingCycle ?? '').trim().toUpperCase();
    if (cycle.contains('YEAR') || cycle == 'ANNUAL') {
      return double.parse((price! / 12).toStringAsFixed(2));
    }
    return price;
  }

  double? get resolvedAnnualPrice {
    if (annualPrice != null) {
      return annualPrice;
    }
    if (price == null) {
      return null;
    }
    final String cycle = (billingCycle ?? '').trim().toUpperCase();
    if (cycle.contains('YEAR') || cycle == 'ANNUAL') {
      return price;
    }
    return double.parse((price! * 12).toStringAsFixed(2));
  }

  /// Free tier or zero-priced plan — no payment steps required.
  bool isNoPaymentPlan(SubscriptionUpgradeBillingCycle cycle) {
    final String tier = (tierCode ?? '').trim().toUpperCase();
    if (tier == 'FREE') {
      return true;
    }
    final double? amount = priceFor(cycle);
    return amount != null && amount <= 0;
  }
}

@immutable
final class SubscriptionUpgradeContext {
  const SubscriptionUpgradeContext({
    this.summary,
    this.currentSubscriptionId,
    this.currentPlanId,
    this.currentPlanLabel,
    this.recommendedPlanId,
    this.plans = const <SubscriptionUpgradePlanOption>[],
    this.paymentMethods = const <String>[],
    this.platformAdminContact,
    this.bankTransferDetails,
    this.expiringSoonDays = 14,
  });

  final TenantSubscriptionSummary? summary;
  final String? currentSubscriptionId;
  final String? currentPlanId;
  final String? currentPlanLabel;
  final String? recommendedPlanId;
  final List<SubscriptionUpgradePlanOption> plans;
  final List<String> paymentMethods;
  final PlatformAdminContact? platformAdminContact;
  final PlatformBankTransferDetails? bankTransferDetails;
  final int expiringSoonDays;
}

@immutable
final class SubscriptionPaymentRequestDraft {
  const SubscriptionPaymentRequestDraft({
    required this.targetPlanId,
    required this.paymentMethod,
    this.amount,
    this.currency,
    this.billingCycle,
    this.invoiceEmail,
    this.reference,
    this.notes,
    this.paymentProvider,
    this.payerPhone,
    this.bankName,
    this.cardHolderName,
    this.cardLastFour,
    this.proofBytes,
    this.proofFileName,
    this.proofMimeType,
  });

  final String targetPlanId;
  final String paymentMethod;
  final String? amount;
  final String? currency;
  final String? billingCycle;
  final String? invoiceEmail;
  final String? reference;
  final String? notes;
  final String? paymentProvider;
  final String? payerPhone;
  final String? bankName;
  final String? cardHolderName;
  final String? cardLastFour;
  final List<int>? proofBytes;
  final String? proofFileName;
  final String? proofMimeType;
}

const Object _unset = Object();

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _firstText(Iterable<String?> values) {
  for (final String? value in values) {
    if (_hasText(value)) {
      return value!.trim();
    }
  }
  return '';
}
