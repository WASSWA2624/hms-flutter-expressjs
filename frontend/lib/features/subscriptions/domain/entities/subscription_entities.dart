import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum SubscriptionPanel {
  overview('overview'),
  catalog('catalog'),
  operations('operations'),
  billing('billing'),
  governance('governance');

  const SubscriptionPanel(this.serverValue);

  final String serverValue;

  static SubscriptionPanel fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final SubscriptionPanel panel in values) {
      if (panel.serverValue == normalized) {
        return panel;
      }
    }
    return SubscriptionPanel.overview;
  }
}

enum SubscriptionResource {
  subscriptionPlans('subscription-plans', SubscriptionPanel.catalog),
  modules('modules', SubscriptionPanel.catalog),
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
    return SubscriptionResource.subscriptions;
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
final class SubscriptionsWorkspaceQuery {
  const SubscriptionsWorkspaceQuery({
    this.search = '',
    this.panel = SubscriptionPanel.overview,
    this.resource = SubscriptionResource.subscriptions,
    this.queue,
    this.tenantId,
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

  final String search;
  final SubscriptionPanel panel;
  final SubscriptionResource resource;
  final String? queue;
  final String? tenantId;
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

  bool get hasActiveFilters {
    return search.trim().isNotEmpty ||
        queue != null ||
        tenantId != null ||
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
  });

  final SubscriptionItem? currentSubscription;
  final SubscriptionPlanReference? currentPlan;
  final SubscriptionUsageSummary? usageSummary;
  final SubscriptionItem? nextInvoice;
  final SubscriptionLicenseSummary licenseSummary;
  final List<SubscriptionRecommendation> recommendations;
  final String? pendingChangeStatus;
  final DateTime? pendingChangeEffectiveAt;
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
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  String get effectiveDisplayId => _firstText(<String?>[
    displayId,
    invoiceDisplayId,
    code,
    id,
  ]);

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
    return resource == SubscriptionResource.moduleSubscriptions && id.isNotEmpty;
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
}

@immutable
final class SubscriptionsWorkspaceState {
  const SubscriptionsWorkspaceState({
    required this.data,
    this.selectedItem,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final SubscriptionsWorkspaceData data;
  final SubscriptionItem? selectedItem;
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
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
  }) {
    return SubscriptionsWorkspaceState(
      data: data ?? this.data,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
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
    required this.price,
    required this.billingCycle,
    this.code,
    this.tierCode,
    this.maxUsers,
    this.maxFacilities,
    this.maxStorageMb,
    this.maxModules,
    this.tenantId,
  });

  final String name;
  final String price;
  final String billingCycle;
  final String? code;
  final String? tierCode;
  final String? maxUsers;
  final String? maxFacilities;
  final String? maxStorageMb;
  final String? maxModules;
  final String? tenantId;
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

const Object _unset = Object();

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _firstText(Iterable<String?> values) {
  for (final String? value in values) {
    if (_hasText(value)) {
      return value!.trim();
    }
  }
  return '';
}
