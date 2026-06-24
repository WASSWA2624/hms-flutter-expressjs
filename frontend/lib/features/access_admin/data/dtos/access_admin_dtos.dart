import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final class AccessAdminLookupOptionDto {
  const AccessAdminLookupOptionDto({required this.id, required this.label, this.meta});

  factory AccessAdminLookupOptionDto.fromJson(Map<String, dynamic> json) {
    return AccessAdminLookupOptionDto(
      id: _string(json['id']),
      label: _string(json['label']),
      meta: _nullableString(json['facility_type'] ?? json['meta']),
    );
  }

  final String id;
  final String label;
  final String? meta;

  AccessAdminLookupOption toEntity() {
    return AccessAdminLookupOption(id: id, label: label, meta: meta);
  }
}

final class AccessAdminLookupsDto {
  const AccessAdminLookupsDto({
    this.tenants = const <AccessAdminLookupOptionDto>[],
    this.facilities = const <AccessAdminLookupOptionDto>[],
    this.roles = const <AccessAdminLookupOptionDto>[],
    this.permissions = const <AccessAdminLookupOptionDto>[],
    this.userStatuses = const <String>[],
    this.clinicalFlowRoles = const <String>[],
  });

  factory AccessAdminLookupsDto.fromResponse(Object? data) {
    final Map<String, dynamic> json = _map(data);
    return AccessAdminLookupsDto(
      tenants: _options(json['tenants']),
      facilities: _options(json['facilities']),
      roles: _options(json['roles']),
      permissions: _options(json['permissions']),
      userStatuses: _stringList(json['user_statuses']),
      clinicalFlowRoles: _stringList(json['clinical_flow_roles']),
    );
  }

  final List<AccessAdminLookupOptionDto> tenants;
  final List<AccessAdminLookupOptionDto> facilities;
  final List<AccessAdminLookupOptionDto> roles;
  final List<AccessAdminLookupOptionDto> permissions;
  final List<String> userStatuses;
  final List<String> clinicalFlowRoles;

  AccessAdminLookups toEntity() {
    return AccessAdminLookups(
      tenants: tenants.map((entry) => entry.toEntity()).toList(growable: false),
      facilities:
          facilities.map((entry) => entry.toEntity()).toList(growable: false),
      roles: roles.map((entry) => entry.toEntity()).toList(growable: false),
      permissions:
          permissions.map((entry) => entry.toEntity()).toList(growable: false),
      userStatuses: userStatuses,
      clinicalFlowRoles: clinicalFlowRoles,
    );
  }

  static List<AccessAdminLookupOptionDto> _options(Object? value) {
    if (value is! List<Object?>) return const <AccessAdminLookupOptionDto>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(AccessAdminLookupOptionDto.fromJson)
        .toList(growable: false);
  }
}

final class AccessAdminOverviewDto {
  const AccessAdminOverviewDto({
    this.activeUsers = 0,
    this.inactiveUsers = 0,
    this.totalRoles = 0,
    this.totalPermissions = 0,
    this.totalAssignments = 0,
    this.demoUsers = 0,
    this.subscriptionPlan,
    this.activeModulesCount = 0,
  });

  factory AccessAdminOverviewDto.fromJson(Map<String, dynamic>? json) {
    final Map<String, dynamic> data = json ?? const <String, dynamic>{};
    return AccessAdminOverviewDto(
      activeUsers: _int(data['active_users']),
      inactiveUsers: _int(data['inactive_users']),
      totalRoles: _int(data['total_roles']),
      totalPermissions: _int(data['total_permissions']),
      totalAssignments: _int(data['total_assignments']),
      demoUsers: _int(data['demo_users']),
      subscriptionPlan: _nullableString(data['subscription_plan']),
      activeModulesCount: _int(data['active_modules_count']),
    );
  }

  final int activeUsers;
  final int inactiveUsers;
  final int totalRoles;
  final int totalPermissions;
  final int totalAssignments;
  final int demoUsers;
  final String? subscriptionPlan;
  final int activeModulesCount;

  AccessAdminOverview toEntity() {
    return AccessAdminOverview(
      activeUsers: activeUsers,
      inactiveUsers: inactiveUsers,
      totalRoles: totalRoles,
      totalPermissions: totalPermissions,
      totalAssignments: totalAssignments,
      demoUsers: demoUsers,
      subscriptionPlan: subscriptionPlan,
      activeModulesCount: activeModulesCount,
    );
  }
}

final class AccessAdminPanelSummaryDto {
  const AccessAdminPanelSummaryDto({
    required this.id,
    required this.labelKey,
    required this.defaultResource,
  });

  factory AccessAdminPanelSummaryDto.fromJson(Map<String, dynamic> json) {
    return AccessAdminPanelSummaryDto(
      id: _string(json['id']),
      labelKey: _string(json['label_key']),
      defaultResource: _string(json['default_resource']),
    );
  }

  final String id;
  final String labelKey;
  final String defaultResource;

  AccessAdminPanelSummary toEntity() {
    return AccessAdminPanelSummary(
      id: id,
      labelKey: labelKey,
      defaultResource: defaultResource,
    );
  }
}

final class AccessAdminPermissionsDto {
  const AccessAdminPermissionsDto({
    this.canRead = false,
    this.canWrite = false,
    this.canResetDemoPasswords = false,
  });

  factory AccessAdminPermissionsDto.fromJson(Map<String, dynamic>? json) {
    final Map<String, dynamic> data = json ?? const <String, dynamic>{};
    return AccessAdminPermissionsDto(
      canRead: data['can_read'] == true,
      canWrite: data['can_write'] == true,
      canResetDemoPasswords: data['can_reset_demo_passwords'] == true,
    );
  }

  final bool canRead;
  final bool canWrite;
  final bool canResetDemoPasswords;

  AccessAdminWorkspacePermissions toEntity() {
    return AccessAdminWorkspacePermissions(
      canRead: canRead,
      canWrite: canWrite,
      canResetDemoPasswords: canResetDemoPasswords,
    );
  }
}

final class AccessAdminItemDto {
  const AccessAdminItemDto({required this.resource, required this.json});

  factory AccessAdminItemDto.fromJson(
    Map<String, dynamic> json,
    AccessAdminResource resource,
  ) {
    return AccessAdminItemDto(resource: resource, json: json);
  }

  final AccessAdminResource resource;
  final Map<String, dynamic> json;

  AccessAdminItem toEntity() {
    final List<AccessAdminRoleRef> roles = _roles(json['roles']);
    final List<AccessAdminPermissionRef> permissions = _permissions(
      json['permissions'],
    );

    return AccessAdminItem(
      id: _string(json['id']),
      resource: resource,
      displayId: _string(json['display_id'] ?? json['id']),
      title: _titleForResource(),
      subtitle: _subtitleForResource(),
      status: _nullableString(json['status']),
      email: _nullableString(json['email']),
      phone: _nullableString(json['phone']),
      positionTitle: _nullableString(json['position_title']),
      profileName: _nullableString(json['profile_name']),
      staffProfileId: _nullableString(json['staff_profile_id']),
      roles: roles,
      roleCount: _int(json['role_count'], fallback: roles.length),
      permissionCount: _int(json['permission_count'], fallback: permissions.length),
      permissions: permissions,
      userCount: _int(json['user_count']),
      moduleSlug: _nullableString(json['module_slug']),
      moduleGroup: _nullableString(json['module_group']),
      planLabel: _nullableString(json['plan_label']),
      isActive: json['is_active'] == true,
      isDemo: json['is_demo'] == true,
      isClinicalFlowRole: json['is_clinical_flow_role'] == true,
      isSystemCritical: json['is_system_critical'] == true,
      userLabel: _nullableString(json['user_label']),
      roleName: _nullableString(json['role_name']),
      permissionName: _nullableString(json['permission_name']),
      entitlementDenied: json['entitlement_denied'] == true,
      entitlementDenialReason: _nullableString(json['entitlement_denial_reason']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  String _titleForResource() {
    switch (resource) {
      case AccessAdminResource.users:
      case AccessAdminResource.demoUsers:
        return _nullableString(json['profile_name']) ??
            _string(json['email']);
      case AccessAdminResource.roles:
        return _string(json['name']);
      case AccessAdminResource.permissions:
        return _string(json['name']);
      case AccessAdminResource.userRoles:
        return _string(json['user_label'] ?? json['role_name']);
      case AccessAdminResource.rolePermissions:
        return '${_string(json['role_name'])} → ${_string(json['permission_name'])}';
      case AccessAdminResource.moduleEntitlements:
        return _string(json['module_label'] ?? json['module_slug']);
    }
  }

  String? _subtitleForResource() {
    switch (resource) {
      case AccessAdminResource.users:
      case AccessAdminResource.demoUsers:
        return _nullableString(json['position_title']);
      case AccessAdminResource.roles:
        return _nullableString(json['description']);
      case AccessAdminResource.permissions:
        return _nullableString(json['description']);
      case AccessAdminResource.userRoles:
        return _nullableString(json['role_name']);
      case AccessAdminResource.rolePermissions:
        return null;
      case AccessAdminResource.moduleEntitlements:
        return _nullableString(json['module_group']);
    }
  }

  static List<AccessAdminRoleRef> _roles(Object? value) {
    if (value is! List<Object?>) return const <AccessAdminRoleRef>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> json) => AccessAdminRoleRef(
            id: _string(json['id']),
            name: _string(json['name']),
          ),
        )
        .toList(growable: false);
  }

  static List<AccessAdminPermissionRef> _permissions(Object? value) {
    if (value is! List<Object?>) return const <AccessAdminPermissionRef>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> json) => AccessAdminPermissionRef(
            id: _string(json['id']),
            name: _string(json['name']),
          ),
        )
        .toList(growable: false);
  }
}

final class AccessAdminWorkspaceDto {
  const AccessAdminWorkspaceDto({
    required this.state,
    required this.overview,
    required this.panelSummaries,
    required this.lookups,
    required this.items,
    required this.page,
    required this.permissions,
    required this.query,
    this.generatedAt,
  });

  factory AccessAdminWorkspaceDto.fromResponse(
    Object? data,
    AccessAdminWorkspaceQuery query,
  ) {
    final Map<String, dynamic> json = _map(data);
    final Map<String, dynamic> filters = _map(json['filters']);
    final AccessAdminResource resource = AccessAdminResource.fromServer(
      _nullableString(filters['resource']) ?? query.resource.serverValue,
    );
    final List<AccessAdminItemDto> itemDtos = (json['items'] as List<Object?>?)
            ?.whereType<Map<String, dynamic>>()
            .map((entry) => AccessAdminItemDto.fromJson(entry, resource))
            .toList(growable: false) ??
        const <AccessAdminItemDto>[];
    final Map<String, dynamic> pagination = _map(json['pagination']);
    final AppPageRequest request = query.pageRequest;
    final int total = _int(pagination['total'], fallback: itemDtos.length);

    return AccessAdminWorkspaceDto(
      state: _string(json['state'], fallback: 'ready'),
      generatedAt: _dateTime(json['generated_at']),
      overview: AccessAdminOverviewDto.fromJson(_map(json['overview'])),
      panelSummaries: (json['panel_summaries'] as List<Object?>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AccessAdminPanelSummaryDto.fromJson)
              .toList(growable: false) ??
          const <AccessAdminPanelSummaryDto>[],
      lookups: AccessAdminLookupsDto.fromResponse(json['lookups']),
      items: itemDtos,
      page: AppPage<AccessAdminItem>(
        items: itemDtos.map((entry) => entry.toEntity()).toList(growable: false),
        request: request,
        totalItemCount: total,
      ),
      permissions: AccessAdminPermissionsDto.fromJson(_map(json['permissions'])),
      query: query.copyWith(
        panel: AccessAdminPanel.fromServer(
          _nullableString(filters['panel']) ?? query.panel.serverValue,
        ),
        resource: resource,
        search: _nullableString(filters['search']) ?? query.search,
        status: _nullableString(filters['status']) ?? query.status,
        tenantId: _nullableString(filters['tenant_id']) ?? query.tenantId,
        facilityId: _nullableString(filters['facility_id']) ?? query.facilityId,
        recordId: _nullableString(filters['record_id']) ?? query.recordId,
        userId: _nullableString(filters['user_id']) ?? query.userId,
        roleId: _nullableString(filters['role_id']) ?? query.roleId,
      ),
    );
  }

  final String state;
  final DateTime? generatedAt;
  final AccessAdminOverviewDto overview;
  final List<AccessAdminPanelSummaryDto> panelSummaries;
  final AccessAdminLookupsDto lookups;
  final List<AccessAdminItemDto> items;
  final AppPage<AccessAdminItem> page;
  final AccessAdminPermissionsDto permissions;
  final AccessAdminWorkspaceQuery query;

  AccessAdminWorkspaceData toEntity() {
    return AccessAdminWorkspaceData(
      state: state,
      generatedAt: generatedAt,
      overview: overview.toEntity(),
      panelSummaries:
          panelSummaries.map((entry) => entry.toEntity()).toList(growable: false),
      lookups: lookups.toEntity(),
      items: page.items,
      page: page,
      permissions: permissions.toEntity(),
      query: query,
    );
  }
}

final class AccessAdminLegacyRouteResolutionDto {
  const AccessAdminLegacyRouteResolutionDto({
    required this.panel,
    required this.resource,
    this.id,
    this.action,
  });

  factory AccessAdminLegacyRouteResolutionDto.fromResponse(Object? data) {
    final Map<String, dynamic> json = _map(data);
    return AccessAdminLegacyRouteResolutionDto(
      panel: _string(json['panel']),
      resource: _string(json['resource']),
      id: _nullableString(json['id']),
      action: _nullableString(json['action']),
    );
  }

  final String panel;
  final String resource;
  final String? id;
  final String? action;

  AccessAdminLegacyRouteResolution toEntity() {
    return AccessAdminLegacyRouteResolution(
      panel: AccessAdminPanel.fromServer(panel),
      resource: AccessAdminResource.fromServer(resource),
      id: id,
      action: action,
    );
  }
}

final class AccessAdminUserDetailDto {
  const AccessAdminUserDetailDto({required this.json, required this.resource});

  factory AccessAdminUserDetailDto.fromResponse(Object? data) {
    final Map<String, dynamic> json = _map(data);
    return AccessAdminUserDetailDto(
      json: json,
      resource: AccessAdminResource.users,
    );
  }

  final Map<String, dynamic> json;
  final AccessAdminResource resource;

  AccessAdminUserDetail toEntity() {
    final AccessAdminItem item = AccessAdminItemDto.fromJson(json, resource).toEntity();
    final List<AccessAdminPermissionRef> directPermissions =
        AccessAdminItemDto._permissions(json['direct_permissions']);
    final List<String> effectivePermissions = _stringList(json['effective_permissions']);
    final List<AccessAdminRolePermissionPreview> previews =
        (json['role_permission_preview'] as List<Object?>?)
                ?.whereType<Map<String, dynamic>>()
                .map(
                  (Map<String, dynamic> entry) => AccessAdminRolePermissionPreview(
                    name: _string(entry['name']),
                    sourceRole: _string(entry['source_role']),
                  ),
                )
                .toList(growable: false) ??
            const <AccessAdminRolePermissionPreview>[];

    return AccessAdminUserDetail(
      item: item,
      directPermissions: directPermissions,
      effectivePermissions: effectivePermissions,
      rolePermissionPreview: previews,
    );
  }
}

final class AccessAdminDemoResetResultDto {
  const AccessAdminDemoResetResultDto({
    required this.userId,
    required this.email,
    this.resetAt,
    this.environment,
  });

  factory AccessAdminDemoResetResultDto.fromResponse(Object? data) {
    final Map<String, dynamic> json = _map(data);
    return AccessAdminDemoResetResultDto(
      userId: _string(json['user_id']),
      email: _string(json['email']),
      resetAt: _dateTime(json['reset_at']),
      environment: _nullableString(json['environment']),
    );
  }

  final String userId;
  final String email;
  final DateTime? resetAt;
  final String? environment;

  AccessAdminDemoResetResult toEntity() {
    return AccessAdminDemoResetResult(
      userId: userId,
      email: email,
      resetAt: resetAt,
      environment: environment,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _string(Object? value, {String fallback = ''}) {
  final String normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableString(Object? value) {
  final String normalized = (value ?? '').toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse('$value') ?? fallback;
}

DateTime? _dateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

List<String> _stringList(Object? value) {
  if (value is! List<Object?>) return const <String>[];
  return value
      .map((entry) => entry?.toString().trim() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}
