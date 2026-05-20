import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum IntegrationWorkItemKind { integration, apiKey, webhook, log, interop }

enum IntegrationWorkspaceFilter {
  all,
  integrations,
  apiKeys,
  webhooks,
  logs,
  interop,
  active,
  warning,
  failed,
  disabled,
}

@immutable
final class IntegrationWorkspaceQuery {
  const IntegrationWorkspaceQuery({
    this.search = '',
    this.filter = IntegrationWorkspaceFilter.all,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final IntegrationWorkspaceFilter filter;
  final AppPageRequest pageRequest;

  IntegrationWorkspaceQuery copyWith({
    String? search,
    IntegrationWorkspaceFilter? filter,
    AppPageRequest? pageRequest,
  }) {
    return IntegrationWorkspaceQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class IntegrationRecord {
  const IntegrationRecord({
    required this.id,
    this.displayId,
    this.tenantId,
    this.tenantLabel,
    this.integrationType,
    this.status,
    this.name,
    this.configSummary = const <String, Object?>{},
    this.hasConfig = false,
    this.logCount = 0,
    this.webhookSubscriptionCount = 0,
    this.requiresAttention = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? tenantLabel;
  final String? integrationType;
  final String? status;
  final String? name;
  final Map<String, Object?> configSummary;
  final bool hasConfig;
  final int logCount;
  final int webhookSubscriptionCount;
  final bool requiresAttention;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => _firstNonEmpty(<String?>[id, displayId]) ?? id;

  String get title => _firstNonEmpty(<String?>[name, displayId, id]) ?? id;

  DateTime? get timelineAt => updatedAt ?? createdAt;

  bool get isActive => status?.toUpperCase() == 'ACTIVE';

  bool get isDisabled => status?.toUpperCase() == 'INACTIVE';
}

@immutable
final class ApiKeyRecord {
  const ApiKeyRecord({
    required this.id,
    this.displayId,
    this.humanFriendlyId,
    this.tenantId,
    this.userId,
    this.name,
    this.isActive = false,
    this.expiresAt,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
    this.oneTimeSecret,
  });

  final String id;
  final String? displayId;
  final String? humanFriendlyId;
  final String? tenantId;
  final String? userId;
  final String? name;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? oneTimeSecret;

  String get apiId => id;

  String get title {
    return _firstNonEmpty(<String?>[name, displayId, humanFriendlyId, id]) ??
        id;
  }

  String get maskedValue {
    final String prefix =
        _firstNonEmpty(<String?>[humanFriendlyId, displayId, id]) ?? '';
    if (prefix.isEmpty) {
      return '********';
    }
    return '$prefix.********';
  }

  bool get isExpired {
    final DateTime? expiry = expiresAt;
    return expiry != null && expiry.isBefore(DateTime.now().toUtc());
  }

  DateTime? get timelineAt => lastUsedAt ?? updatedAt ?? createdAt;
}

@immutable
final class ApiKeyPermissionRecord {
  const ApiKeyPermissionRecord({
    required this.id,
    required this.apiKeyId,
    required this.permissionId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String apiKeyId;
  final String permissionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class IntegrationPermissionOption {
  const IntegrationPermissionOption({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;

  String get label {
    return _firstNonEmpty(<String?>[name, description, id]) ?? id;
  }
}

@immutable
final class WebhookSubscriptionRecord {
  const WebhookSubscriptionRecord({
    required this.id,
    this.displayId,
    this.tenantId,
    this.tenantLabel,
    this.integrationId,
    this.integrationDisplayId,
    this.integrationLabel,
    this.integrationType,
    this.integrationStatus,
    this.event,
    this.targetUrl,
    this.targetHost,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? tenantLabel;
  final String? integrationId;
  final String? integrationDisplayId;
  final String? integrationLabel;
  final String? integrationType;
  final String? integrationStatus;
  final String? event;
  final String? targetUrl;
  final String? targetHost;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => id;

  String get title {
    return _firstNonEmpty(<String?>[event, displayId, id]) ?? id;
  }

  DateTime? get timelineAt => updatedAt ?? createdAt;
}

@immutable
final class IntegrationLogRecord {
  const IntegrationLogRecord({
    required this.id,
    this.displayId,
    this.integrationId,
    this.integrationDisplayId,
    this.integrationLabel,
    this.integrationType,
    this.integrationStatus,
    this.tenantId,
    this.tenantLabel,
    this.status,
    this.message,
    this.loggedAt,
    this.timelineAt,
    this.requiresAttention = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? integrationId;
  final String? integrationDisplayId;
  final String? integrationLabel;
  final String? integrationType;
  final String? integrationStatus;
  final String? tenantId;
  final String? tenantLabel;
  final String? status;
  final String? message;
  final DateTime? loggedAt;
  final DateTime? timelineAt;
  final bool requiresAttention;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => id;

  String get title {
    return _firstNonEmpty(<String?>[
          integrationLabel,
          integrationDisplayId,
          displayId,
          id,
        ]) ??
        id;
  }
}

@immutable
final class InteropCapabilityStatus {
  const InteropCapabilityStatus({
    required this.id,
    required this.title,
    required this.scope,
    required this.status,
    required this.nextAction,
    this.backendGap,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String scope;
  final String status;
  final String nextAction;
  final String? backendGap;
  final DateTime? updatedAt;

  bool get requiresAttention => backendGap != null;
}

@immutable
final class IntegrationActionResult {
  const IntegrationActionResult({
    required this.title,
    required this.status,
    this.message,
    this.timelineAt,
  });

  final String title;
  final String status;
  final String? message;
  final DateTime? timelineAt;
}

@immutable
final class IntegrationWorkItem {
  const IntegrationWorkItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.status,
    required this.scope,
    required this.nextAction,
    this.displayId,
    this.owner,
    this.lastEventAt,
    this.errorSummary,
    this.integration,
    this.apiKey,
    this.webhook,
    this.log,
    this.interop,
  });

  factory IntegrationWorkItem.integration(IntegrationRecord record) {
    final bool failed = record.requiresAttention;
    return IntegrationWorkItem(
      kind: IntegrationWorkItemKind.integration,
      id: record.apiId,
      displayId: record.displayId,
      title: record.title,
      status: record.status ?? 'UNKNOWN',
      owner: record.tenantLabel ?? record.tenantId,
      scope: record.integrationType ?? 'INTEGRATION',
      lastEventAt: record.timelineAt,
      errorSummary: failed ? record.status : null,
      nextAction: failed
          ? 'review_failure'
          : record.isDisabled
          ? 'enable'
          : 'monitor',
      integration: record,
    );
  }

  factory IntegrationWorkItem.apiKey(
    ApiKeyRecord record,
    Iterable<ApiKeyPermissionRecord> permissions,
  ) {
    final int permissionCount = permissions.where((
      ApiKeyPermissionRecord permission,
    ) {
      return permission.apiKeyId == record.id;
    }).length;
    final bool warning = record.isExpired || !record.isActive;
    return IntegrationWorkItem(
      kind: IntegrationWorkItemKind.apiKey,
      id: record.apiId,
      displayId: record.displayId ?? record.humanFriendlyId,
      title: record.title,
      status: record.isActive && !record.isExpired ? 'ACTIVE' : 'INACTIVE',
      owner: record.userId,
      scope: permissionCount == 0
          ? 'NO_SCOPES'
          : permissionCount == 1
          ? '1_SCOPE'
          : '${permissionCount}_SCOPES',
      lastEventAt: record.timelineAt,
      errorSummary: warning ? 'KEY_REVIEW_REQUIRED' : null,
      nextAction: warning ? 'review_key' : 'rotate_or_monitor',
      apiKey: record,
    );
  }

  factory IntegrationWorkItem.webhook(WebhookSubscriptionRecord record) {
    final bool failed = record.integrationStatus?.toUpperCase() == 'ERROR';
    return IntegrationWorkItem(
      kind: IntegrationWorkItemKind.webhook,
      id: record.apiId,
      displayId: record.displayId,
      title: record.title,
      status: record.isActive ? 'ACTIVE' : 'INACTIVE',
      owner: record.tenantLabel ?? record.tenantId,
      scope:
          _firstNonEmpty(<String?>[
            record.integrationLabel,
            record.integrationDisplayId,
            record.integrationType,
          ]) ??
          'WEBHOOK',
      lastEventAt: record.timelineAt,
      errorSummary: failed ? record.integrationStatus : null,
      nextAction: record.isActive ? 'monitor_delivery' : 'enable_webhook',
      webhook: record,
    );
  }

  factory IntegrationWorkItem.log(IntegrationLogRecord record) {
    return IntegrationWorkItem(
      kind: IntegrationWorkItemKind.log,
      id: record.apiId,
      displayId: record.displayId,
      title: record.title,
      status: record.status ?? 'UNKNOWN',
      owner: record.tenantLabel ?? record.tenantId,
      scope: record.integrationType ?? 'LOG',
      lastEventAt: record.timelineAt ?? record.loggedAt,
      errorSummary: record.requiresAttention ? record.message : null,
      nextAction: record.requiresAttention ? 'replay_or_escalate' : 'review',
      log: record,
    );
  }

  factory IntegrationWorkItem.interop(InteropCapabilityStatus record) {
    return IntegrationWorkItem(
      kind: IntegrationWorkItemKind.interop,
      id: record.id,
      title: record.title,
      status: record.status,
      scope: record.scope,
      lastEventAt: record.updatedAt,
      errorSummary: record.backendGap,
      nextAction: record.nextAction,
      interop: record,
    );
  }

  final IntegrationWorkItemKind kind;
  final String id;
  final String? displayId;
  final String title;
  final String status;
  final String? owner;
  final String scope;
  final DateTime? lastEventAt;
  final String? errorSummary;
  final String nextAction;
  final IntegrationRecord? integration;
  final ApiKeyRecord? apiKey;
  final WebhookSubscriptionRecord? webhook;
  final IntegrationLogRecord? log;
  final InteropCapabilityStatus? interop;

  String get rowKey => '${kind.name}:$id';
}

@immutable
final class IntegrationWorkspaceState {
  const IntegrationWorkspaceState({
    required this.query,
    this.integrations = const <IntegrationRecord>[],
    this.apiKeys = const <ApiKeyRecord>[],
    this.apiKeyPermissions = const <ApiKeyPermissionRecord>[],
    this.permissionOptions = const <IntegrationPermissionOption>[],
    this.webhooks = const <WebhookSubscriptionRecord>[],
    this.logs = const <IntegrationLogRecord>[],
    this.interopStatuses = const <InteropCapabilityStatus>[],
    this.selectedItem,
    this.lastFailure,
    this.lastActionResult,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final IntegrationWorkspaceQuery query;
  final List<IntegrationRecord> integrations;
  final List<ApiKeyRecord> apiKeys;
  final List<ApiKeyPermissionRecord> apiKeyPermissions;
  final List<IntegrationPermissionOption> permissionOptions;
  final List<WebhookSubscriptionRecord> webhooks;
  final List<IntegrationLogRecord> logs;
  final List<InteropCapabilityStatus> interopStatuses;
  final IntegrationWorkItem? selectedItem;
  final Object? lastFailure;
  final IntegrationActionResult? lastActionResult;
  final bool isRefreshing;
  final bool isSaving;

  List<IntegrationWorkItem> get workItems {
    final List<IntegrationWorkItem> items = <IntegrationWorkItem>[
      for (final IntegrationRecord record in integrations)
        IntegrationWorkItem.integration(record),
      for (final ApiKeyRecord record in apiKeys)
        IntegrationWorkItem.apiKey(record, apiKeyPermissions),
      for (final WebhookSubscriptionRecord record in webhooks)
        IntegrationWorkItem.webhook(record),
      for (final IntegrationLogRecord record in logs)
        IntegrationWorkItem.log(record),
      for (final InteropCapabilityStatus record in interopStatuses)
        IntegrationWorkItem.interop(record),
    ];

    final List<IntegrationWorkItem> filtered =
        items
            .where(_matchesFilter)
            .where(
              (IntegrationWorkItem item) =>
                  matchesIntegrationSearch(item, query.search),
            )
            .toList(growable: false)
          ..sort(_compareWorkItems);

    return filtered;
  }

  AppPage<IntegrationWorkItem> get workItemsPage {
    final List<IntegrationWorkItem> visibleItems = workItems;
    final int start = query.pageRequest.offset.clamp(0, visibleItems.length);
    final int end = (start + query.pageRequest.pageSize).clamp(
      start,
      visibleItems.length,
    );
    return AppPage<IntegrationWorkItem>(
      items: visibleItems.sublist(start, end),
      request: query.pageRequest,
      totalItemCount: visibleItems.length,
    );
  }

  int get activeCount {
    return workItems.where((IntegrationWorkItem item) {
      return item.status.toUpperCase() == 'ACTIVE';
    }).length;
  }

  int get warningCount {
    return workItems.where((IntegrationWorkItem item) {
      final String status = item.status.toUpperCase();
      return item.errorSummary != null ||
          status == 'WARNING' ||
          status == 'INACTIVE';
    }).length;
  }

  int get failedCount {
    return workItems.where((IntegrationWorkItem item) {
      final String status = item.status.toUpperCase();
      return status == 'ERROR' ||
          status == 'FAILED' ||
          item.errorSummary != null && item.kind == IntegrationWorkItemKind.log;
    }).length;
  }

  int get disabledCount {
    return workItems.where((IntegrationWorkItem item) {
      return item.status.toUpperCase() == 'INACTIVE';
    }).length;
  }

  int get workloadCount => warningCount + failedCount;

  List<ApiKeyPermissionRecord> permissionsForKey(ApiKeyRecord key) {
    return apiKeyPermissions
        .where((ApiKeyPermissionRecord permission) {
          return permission.apiKeyId == key.id;
        })
        .toList(growable: false);
  }

  IntegrationPermissionOption? permissionOption(String permissionId) {
    for (final IntegrationPermissionOption option in permissionOptions) {
      if (option.id == permissionId) {
        return option;
      }
    }
    return null;
  }

  List<WebhookSubscriptionRecord> webhooksForIntegration(
    IntegrationRecord integration,
  ) {
    return webhooks
        .where((WebhookSubscriptionRecord webhook) {
          return webhook.integrationId == integration.id ||
              webhook.integrationDisplayId == integration.displayId;
        })
        .toList(growable: false);
  }

  List<IntegrationLogRecord> logsForIntegration(IntegrationRecord integration) {
    return logs
        .where((IntegrationLogRecord log) {
          return log.integrationId == integration.id ||
              log.integrationDisplayId == integration.displayId;
        })
        .toList(growable: false);
  }

  IntegrationWorkspaceState copyWith({
    IntegrationWorkspaceQuery? query,
    List<IntegrationRecord>? integrations,
    List<ApiKeyRecord>? apiKeys,
    List<ApiKeyPermissionRecord>? apiKeyPermissions,
    List<IntegrationPermissionOption>? permissionOptions,
    List<WebhookSubscriptionRecord>? webhooks,
    List<IntegrationLogRecord>? logs,
    List<InteropCapabilityStatus>? interopStatuses,
    IntegrationWorkItem? selectedItem,
    Object? lastFailure,
    IntegrationActionResult? lastActionResult,
    bool? isRefreshing,
    bool? isSaving,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
    bool clearLastActionResult = false,
  }) {
    return IntegrationWorkspaceState(
      query: query ?? this.query,
      integrations: integrations ?? this.integrations,
      apiKeys: apiKeys ?? this.apiKeys,
      apiKeyPermissions: apiKeyPermissions ?? this.apiKeyPermissions,
      permissionOptions: permissionOptions ?? this.permissionOptions,
      webhooks: webhooks ?? this.webhooks,
      logs: logs ?? this.logs,
      interopStatuses: interopStatuses ?? this.interopStatuses,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      lastActionResult: clearLastActionResult
          ? null
          : lastActionResult ?? this.lastActionResult,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  bool _matchesFilter(IntegrationWorkItem item) {
    return switch (query.filter) {
      IntegrationWorkspaceFilter.all => true,
      IntegrationWorkspaceFilter.integrations =>
        item.kind == IntegrationWorkItemKind.integration,
      IntegrationWorkspaceFilter.apiKeys =>
        item.kind == IntegrationWorkItemKind.apiKey,
      IntegrationWorkspaceFilter.webhooks =>
        item.kind == IntegrationWorkItemKind.webhook,
      IntegrationWorkspaceFilter.logs =>
        item.kind == IntegrationWorkItemKind.log,
      IntegrationWorkspaceFilter.interop =>
        item.kind == IntegrationWorkItemKind.interop,
      IntegrationWorkspaceFilter.active =>
        item.status.toUpperCase() == 'ACTIVE',
      IntegrationWorkspaceFilter.warning =>
        item.errorSummary != null ||
            item.status.toUpperCase() == 'WARNING' ||
            item.status.toUpperCase() == 'INACTIVE',
      IntegrationWorkspaceFilter.failed =>
        item.status.toUpperCase() == 'ERROR' ||
            item.status.toUpperCase() == 'FAILED' ||
            item.errorSummary != null &&
                item.kind == IntegrationWorkItemKind.log,
      IntegrationWorkspaceFilter.disabled =>
        item.status.toUpperCase() == 'INACTIVE',
    };
  }
}

bool matchesIntegrationSearch(IntegrationWorkItem item, String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  final List<String> values = <String>[
    item.title,
    item.status,
    item.scope,
    item.nextAction,
    item.kind.name,
    ?item.displayId,
    ?item.owner,
    ?item.errorSummary,
  ];

  return values.any((String value) => value.toLowerCase().contains(normalized));
}

int _compareWorkItems(IntegrationWorkItem left, IntegrationWorkItem right) {
  final DateTime leftDate =
      left.lastEventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final DateTime rightDate =
      right.lastEventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final int dateComparison = rightDate.compareTo(leftDate);
  if (dateComparison != 0) {
    return dateComparison;
  }
  return left.title.toLowerCase().compareTo(right.title.toLowerCase());
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return null;
}
