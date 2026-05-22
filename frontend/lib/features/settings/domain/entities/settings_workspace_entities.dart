import 'package:flutter/foundation.dart';

enum SettingsWorkspaceStatus {
  ready('ready'),
  tenantContextRequired('tenant_context_required');

  const SettingsWorkspaceStatus(this.serverValue);

  final String serverValue;

  static SettingsWorkspaceStatus fromServer(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'tenant_context_required' => SettingsWorkspaceStatus.tenantContextRequired,
      _ => SettingsWorkspaceStatus.ready,
    };
  }
}

enum SettingsModuleState {
  configured('configured'),
  empty('empty'),
  attention('attention');

  const SettingsModuleState(this.serverValue);

  final String serverValue;

  static SettingsModuleState fromServer(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'configured' => SettingsModuleState.configured,
      'attention' => SettingsModuleState.attention,
      _ => SettingsModuleState.empty,
    };
  }
}

@immutable
final class SettingsWorkspaceQuery {
  const SettingsWorkspaceQuery({
    this.tenantId,
    this.facilityId,
    this.group,
    this.state,
    this.search = '',
    this.actionableOnly = false,
  });

  final String? tenantId;
  final String? facilityId;
  final String? group;
  final SettingsModuleState? state;
  final String search;
  final bool actionableOnly;

  SettingsWorkspaceQuery copyWith({
    String? tenantId,
    String? facilityId,
    String? group,
    SettingsModuleState? state,
    String? search,
    bool? actionableOnly,
    bool clearTenant = false,
    bool clearFacility = false,
    bool clearGroup = false,
    bool clearState = false,
  }) {
    return SettingsWorkspaceQuery(
      tenantId: clearTenant ? null : tenantId ?? this.tenantId,
      facilityId: clearFacility ? null : facilityId ?? this.facilityId,
      group: clearGroup ? null : group ?? this.group,
      state: clearState ? null : state ?? this.state,
      search: search ?? this.search,
      actionableOnly: actionableOnly ?? this.actionableOnly,
    );
  }
}

@immutable
final class SettingsReferenceOption {
  const SettingsReferenceOption({
    required this.id,
    required this.label,
    this.meta = const <String, Object?>{},
  });

  final String id;
  final String label;
  final Map<String, Object?> meta;
}

@immutable
final class SettingsReferenceData {
  const SettingsReferenceData({
    this.state = SettingsWorkspaceStatus.ready,
    this.tenants = const <SettingsReferenceOption>[],
    this.facilities = const <SettingsReferenceOption>[],
  });

  final SettingsWorkspaceStatus state;
  final List<SettingsReferenceOption> tenants;
  final List<SettingsReferenceOption> facilities;
}

@immutable
final class SettingsWorkspaceContext {
  const SettingsWorkspaceContext({
    required this.state,
    this.tenantId,
    this.tenantName,
    this.facilityId,
    this.facilityName,
    this.facilityType,
    this.roleKeys = const <String>[],
  });

  final SettingsWorkspaceStatus state;
  final String? tenantId;
  final String? tenantName;
  final String? facilityId;
  final String? facilityName;
  final String? facilityType;
  final List<String> roleKeys;
}

@immutable
final class SettingsSummaryCard {
  const SettingsSummaryCard({
    required this.id,
    required this.labelKey,
    required this.totalModules,
    required this.configuredModules,
    required this.attentionModules,
    required this.totalRecords,
    required this.state,
  });

  final String id;
  final String labelKey;
  final int totalModules;
  final int configuredModules;
  final int attentionModules;
  final int totalRecords;
  final String state;
}

@immutable
final class SettingsChecklist {
  const SettingsChecklist({
    required this.completedCount,
    required this.totalCount,
    required this.items,
  });

  final int completedCount;
  final int totalCount;
  final List<SettingsChecklistItem> items;
}

@immutable
final class SettingsChecklistItem {
  const SettingsChecklistItem({
    required this.id,
    required this.labelKey,
    required this.completed,
    required this.priority,
    this.route,
    this.createRoute,
  });

  final String id;
  final String labelKey;
  final bool completed;
  final int priority;
  final String? route;
  final String? createRoute;
}

@immutable
final class SettingsQuickAction {
  const SettingsQuickAction({
    required this.id,
    required this.moduleId,
    required this.moduleLabelKey,
    required this.labelKey,
    required this.canExecute,
    this.icon,
    this.route,
  });

  final String id;
  final String moduleId;
  final String moduleLabelKey;
  final String labelKey;
  final bool canExecute;
  final String? icon;
  final String? route;
}

@immutable
final class SettingsModuleItem {
  const SettingsModuleItem({
    required this.moduleId,
    required this.labelKey,
    required this.groupId,
    required this.count,
    required this.state,
    required this.canRead,
    required this.canWrite,
    required this.canCreate,
    required this.dependencies,
    this.icon,
    this.route,
    this.createRoute,
    this.lastUpdatedAt,
    this.attentionReasonKey,
  });

  final String moduleId;
  final String labelKey;
  final String groupId;
  final int count;
  final SettingsModuleState state;
  final bool canRead;
  final bool canWrite;
  final bool canCreate;
  final List<SettingsModuleDependency> dependencies;
  final String? icon;
  final String? route;
  final String? createRoute;
  final DateTime? lastUpdatedAt;
  final String? attentionReasonKey;
}

@immutable
final class SettingsModuleDependency {
  const SettingsModuleDependency({required this.moduleId, required this.isReady});

  final String moduleId;
  final bool isReady;
}

@immutable
final class SettingsModuleGroup {
  const SettingsModuleGroup({
    required this.id,
    required this.labelKey,
    required this.modules,
  });

  final String id;
  final String labelKey;
  final List<SettingsModuleItem> modules;
}

@immutable
final class SettingsWorkspaceStats {
  const SettingsWorkspaceStats({
    required this.totalModules,
    required this.configuredModules,
    required this.attentionModules,
    required this.totalRecords,
  });

  final int totalModules;
  final int configuredModules;
  final int attentionModules;
  final int totalRecords;
}

@immutable
final class SettingsWorkspacePermissions {
  const SettingsWorkspacePermissions({required this.canWrite});

  final bool canWrite;
}

@immutable
final class SettingsWorkspace {
  const SettingsWorkspace({
    required this.status,
    required this.generatedAt,
    required this.context,
    required this.summaryCards,
    required this.checklist,
    required this.quickActions,
    required this.moduleGroups,
    required this.referenceData,
    required this.stats,
    required this.permissions,
  });

  final SettingsWorkspaceStatus status;
  final DateTime? generatedAt;
  final SettingsWorkspaceContext context;
  final List<SettingsSummaryCard> summaryCards;
  final SettingsChecklist checklist;
  final List<SettingsQuickAction> quickActions;
  final List<SettingsModuleGroup> moduleGroups;
  final SettingsReferenceData referenceData;
  final SettingsWorkspaceStats stats;
  final SettingsWorkspacePermissions permissions;
}
