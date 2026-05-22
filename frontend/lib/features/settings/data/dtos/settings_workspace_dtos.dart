import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';

final class SettingsWorkspaceDto {
  const SettingsWorkspaceDto({required this.workspace});

  final SettingsWorkspace workspace;

  factory SettingsWorkspaceDto.fromResponse(Object? response) {
    final Map<String, Object?> json = _payloadMap(response);
    final Map<String, Object?> lookups = _jsonMap(json['lookups']);
    final SettingsReferenceData referenceData = SettingsReferenceDataDto.fromJson(
      lookups.isEmpty ? json : <String, Object?>{
        'state': json['state'],
        ...lookups,
      },
    ).toEntity();
    final List<SettingsModuleGroup> moduleGroups = _jsonList(json['module_groups'])
        .map(_moduleGroupFromJson)
        .toList(growable: false);

    return SettingsWorkspaceDto(
      workspace: SettingsWorkspace(
        status: SettingsWorkspaceStatus.fromServer(_string(json['state'])),
        generatedAt: _dateTime(json['generated_at']),
        context: _contextFromJson(_jsonMap(json['context'])),
        summaryCards: _jsonList(json['summary_cards'])
            .map(_summaryCardFromJson)
            .toList(growable: false),
        checklist: _checklistFromJson(_jsonMap(json['checklist'])),
        quickActions: _jsonList(json['quick_actions'])
            .map(_quickActionFromJson)
            .toList(growable: false),
        moduleGroups: moduleGroups,
        referenceData: referenceData,
        stats: _statsFromJson(_jsonMap(json['stats']), moduleGroups),
        permissions: _permissionsFromJson(_jsonMap(json['permissions'])),
      ),
    );
  }
}

final class SettingsReferenceDataDto {
  const SettingsReferenceDataDto({required this.referenceData});

  final SettingsReferenceData referenceData;

  factory SettingsReferenceDataDto.fromResponse(Object? response) {
    return SettingsReferenceDataDto.fromJson(_payloadMap(response));
  }

  factory SettingsReferenceDataDto.fromJson(Map<String, Object?> json) {
    return SettingsReferenceDataDto(
      referenceData: SettingsReferenceData(
        state: SettingsWorkspaceStatus.fromServer(_string(json['state'])),
        tenants: _jsonList(json['tenants'])
            .map(_referenceOptionFromJson)
            .toList(growable: false),
        facilities: _jsonList(json['facilities'])
            .map(_referenceOptionFromJson)
            .toList(growable: false),
      ),
    );
  }

  SettingsReferenceData toEntity() => referenceData;
}

SettingsWorkspaceContext _contextFromJson(Map<String, Object?> json) {
  return SettingsWorkspaceContext(
    state: SettingsWorkspaceStatus.fromServer(_string(json['state'])),
    tenantId: _string(json['tenant_id']),
    tenantName: _string(json['tenant_name']),
    facilityId: _string(json['facility_id']),
    facilityName: _string(json['facility_name']),
    facilityType: _string(json['facility_type']),
    roleKeys: _stringList(json['role_keys']),
  );
}

SettingsSummaryCard _summaryCardFromJson(Map<String, Object?> json) {
  return SettingsSummaryCard(
    id: _string(json['id']) ?? '',
    labelKey: _string(json['label_key']) ?? '',
    totalModules: _int(json['total_modules']),
    configuredModules: _int(json['configured_modules']),
    attentionModules: _int(json['attention_modules']),
    totalRecords: _int(json['total_records']),
    state: _string(json['state']) ?? '',
  );
}

SettingsChecklist _checklistFromJson(Map<String, Object?> json) {
  return SettingsChecklist(
    completedCount: _int(json['completed_count']),
    totalCount: _int(json['total_count']),
    items: _jsonList(json['items'])
        .map(_checklistItemFromJson)
        .toList(growable: false),
  );
}

SettingsChecklistItem _checklistItemFromJson(Map<String, Object?> json) {
  return SettingsChecklistItem(
    id: _string(json['id']) ?? '',
    labelKey: _string(json['label_key']) ?? '',
    completed: _bool(json['completed']),
    priority: _int(json['priority']),
    route: _string(json['route']),
    createRoute: _string(json['create_route']),
  );
}

SettingsQuickAction _quickActionFromJson(Map<String, Object?> json) {
  return SettingsQuickAction(
    id: _string(json['id']) ?? '',
    moduleId: _string(json['module_id']) ?? '',
    moduleLabelKey: _string(json['module_label_key']) ?? '',
    labelKey: _string(json['label_key']) ?? '',
    canExecute: _bool(json['can_execute']),
    icon: _string(json['icon']),
    route: _string(json['route']),
  );
}

SettingsModuleGroup _moduleGroupFromJson(Map<String, Object?> json) {
  return SettingsModuleGroup(
    id: _string(json['id']) ?? '',
    labelKey: _string(json['label_key']) ?? '',
    modules: _jsonList(json['modules'])
        .map(_moduleItemFromJson)
        .toList(growable: false),
  );
}

SettingsModuleItem _moduleItemFromJson(Map<String, Object?> json) {
  return SettingsModuleItem(
    moduleId: _string(json['module_id']) ?? '',
    labelKey: _string(json['label_key']) ?? '',
    groupId: _string(json['group_id']) ?? '',
    count: _int(json['count']),
    state: SettingsModuleState.fromServer(_string(json['state'])),
    canRead: _bool(json['can_read'], fallback: true),
    canWrite: _bool(json['can_write']),
    canCreate: _bool(json['can_create']),
    dependencies: _jsonList(json['dependencies'])
        .map(_dependencyFromJson)
        .toList(growable: false),
    icon: _string(json['icon']),
    route: _string(json['route']),
    createRoute: _string(json['create_route']),
    lastUpdatedAt: _dateTime(json['last_updated_at']),
    attentionReasonKey: _string(json['attention_reason_key']),
  );
}

SettingsModuleDependency _dependencyFromJson(Map<String, Object?> json) {
  return SettingsModuleDependency(
    moduleId: _string(json['module_id']) ?? '',
    isReady: _bool(json['is_ready']),
  );
}

SettingsWorkspaceStats _statsFromJson(
  Map<String, Object?> json,
  List<SettingsModuleGroup> moduleGroups,
) {
  final int computedTotal = moduleGroups.fold<int>(
    0,
    (int total, SettingsModuleGroup group) => total + group.modules.length,
  );
  return SettingsWorkspaceStats(
    totalModules: _int(json['total_modules'], fallback: computedTotal),
    configuredModules: _int(json['configured_modules']),
    attentionModules: _int(json['attention_modules']),
    totalRecords: _int(json['total_records']),
  );
}

SettingsWorkspacePermissions _permissionsFromJson(Map<String, Object?> json) {
  return SettingsWorkspacePermissions(canWrite: _bool(json['can_write']));
}

SettingsReferenceOption _referenceOptionFromJson(Map<String, Object?> json) {
  return SettingsReferenceOption(
    id: _string(json['id']) ?? '',
    label: _string(json['label']) ?? '',
    meta: _jsonMap(json['meta']),
  );
}

Map<String, Object?> _payloadMap(Object? response) {
  final Map<String, Object?> root = _jsonMap(response);
  final Map<String, Object?> data = _jsonMap(root['data']);
  return data.isEmpty ? root : data;
}

Map<String, Object?> _jsonMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        '${entry.key}': entry.value,
    };
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> _jsonList(Object? value) {
  if (value is! Iterable) {
    return const <Map<String, Object?>>[];
  }
  return value
      .map(_jsonMap)
      .where((Map<String, Object?> item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _string(Object? value) {
  final String text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map(_string)
        .whereType<String>()
        .toList(growable: false);
  }
  return const <String>[];
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final String normalized = '${value ?? ''}'.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? _dateTime(Object? value) {
  final String? text = _string(value);
  return text == null ? null : DateTime.tryParse(text);
}
