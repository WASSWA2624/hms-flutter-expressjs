import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum AccessAdminPanel {
  overview('overview'),
  directory('directory'),
  roles('roles'),
  permissions('permissions'),
  entitlements('entitlements'),
  registrations('registrations'),
  demo('demo');

  const AccessAdminPanel(this.serverValue);

  final String serverValue;

  static AccessAdminPanel fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final AccessAdminPanel panel in values) {
      if (panel.serverValue == normalized) {
        return panel;
      }
    }
    return AccessAdminPanel.directory;
  }
}

enum AccessAdminResource {
  users('users', AccessAdminPanel.directory),
  roles('roles', AccessAdminPanel.roles),
  permissions('permissions', AccessAdminPanel.permissions),
  userRoles('user-roles', AccessAdminPanel.roles),
  rolePermissions('role-permissions', AccessAdminPanel.permissions),
  demoUsers('demo-users', AccessAdminPanel.demo),
  moduleEntitlements('module-entitlements', AccessAdminPanel.entitlements),
  registrationFollowUps(
    'registration-follow-ups',
    AccessAdminPanel.registrations,
  );

  const AccessAdminResource(this.serverValue, this.defaultPanel);

  final String serverValue;
  final AccessAdminPanel defaultPanel;

  static AccessAdminResource fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final AccessAdminResource resource in values) {
      if (resource.serverValue == normalized) {
        return resource;
      }
    }
    return AccessAdminResource.users;
  }
}

@immutable
final class AccessAdminWorkspaceQuery {
  const AccessAdminWorkspaceQuery({
    this.search = '',
    this.panel = AccessAdminPanel.directory,
    this.resource = AccessAdminResource.users,
    this.tenantId,
    this.facilityId,
    this.recordId,
    this.status,
    this.userId,
    this.roleId,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  factory AccessAdminWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    return AccessAdminWorkspaceQuery(
      search: params['search'] ?? '',
      panel: AccessAdminPanel.fromServer(params['panel']),
      resource: AccessAdminResource.fromServer(params['resource']),
      tenantId: _nonEmpty(params['tenantId'] ?? params['tenant_id']),
      facilityId: _nonEmpty(params['facilityId'] ?? params['facility_id']),
      recordId: _nonEmpty(params['id'] ?? params['recordId']),
      status: _nonEmpty(params['status']),
      userId: _nonEmpty(params['userId'] ?? params['user_id']),
      roleId: _nonEmpty(params['roleId'] ?? params['role_id']),
    );
  }

  final String search;
  final AccessAdminPanel panel;
  final AccessAdminResource resource;
  final String? tenantId;
  final String? facilityId;
  final String? recordId;
  final String? status;
  final String? userId;
  final String? roleId;
  final AppPageRequest pageRequest;

  bool get hasRouteTargeting {
    return recordId != null ||
        panel != AccessAdminPanel.directory ||
        resource != AccessAdminResource.users ||
        tenantId != null ||
        facilityId != null;
  }

  AccessAdminWorkspaceQuery copyWith({
    String? search,
    AccessAdminPanel? panel,
    AccessAdminResource? resource,
    Object? tenantId = _unset,
    Object? facilityId = _unset,
    Object? recordId = _unset,
    Object? status = _unset,
    Object? userId = _unset,
    Object? roleId = _unset,
    AppPageRequest? pageRequest,
  }) {
    return AccessAdminWorkspaceQuery(
      search: search ?? this.search,
      panel: panel ?? this.panel,
      resource: resource ?? this.resource,
      tenantId: identical(tenantId, _unset)
          ? this.tenantId
          : tenantId as String?,
      facilityId: identical(facilityId, _unset)
          ? this.facilityId
          : facilityId as String?,
      recordId: identical(recordId, _unset)
          ? this.recordId
          : recordId as String?,
      status: identical(status, _unset) ? this.status : status as String?,
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      roleId: identical(roleId, _unset) ? this.roleId : roleId as String?,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }

  static String? _nonEmpty(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static const Object _unset = Object();
}

@immutable
final class AccessAdminLegacyRouteResolution {
  const AccessAdminLegacyRouteResolution({
    required this.panel,
    required this.resource,
    this.id,
    this.action,
  });

  final AccessAdminPanel panel;
  final AccessAdminResource resource;
  final String? id;
  final String? action;
}

@immutable
final class AccessAdminLookupOption {
  const AccessAdminLookupOption({
    required this.id,
    required this.label,
    this.meta,
  });

  final String id;
  final String label;
  final String? meta;
}

@immutable
final class AccessAdminLookups {
  const AccessAdminLookups({
    this.tenants = const <AccessAdminLookupOption>[],
    this.facilities = const <AccessAdminLookupOption>[],
    this.roles = const <AccessAdminLookupOption>[],
    this.permissions = const <AccessAdminLookupOption>[],
    this.userStatuses = const <String>[],
    this.clinicalFlowRoles = const <String>[],
  });

  final List<AccessAdminLookupOption> tenants;
  final List<AccessAdminLookupOption> facilities;
  final List<AccessAdminLookupOption> roles;
  final List<AccessAdminLookupOption> permissions;
  final List<String> userStatuses;
  final List<String> clinicalFlowRoles;
}

@immutable
final class AccessAdminWorkspacePermissions {
  const AccessAdminWorkspacePermissions({
    this.canRead = false,
    this.canWrite = false,
    this.canResetDemoPasswords = false,
  });

  final bool canRead;
  final bool canWrite;
  final bool canResetDemoPasswords;
}

@immutable
final class AccessAdminOverview {
  const AccessAdminOverview({
    this.activeUsers = 0,
    this.inactiveUsers = 0,
    this.totalRoles = 0,
    this.totalPermissions = 0,
    this.totalAssignments = 0,
    this.demoUsers = 0,
    this.subscriptionPlan,
    this.activeModulesCount = 0,
  });

  final int activeUsers;
  final int inactiveUsers;
  final int totalRoles;
  final int totalPermissions;
  final int totalAssignments;
  final int demoUsers;
  final String? subscriptionPlan;
  final int activeModulesCount;
}

@immutable
final class AccessAdminPanelSummary {
  const AccessAdminPanelSummary({
    required this.id,
    required this.labelKey,
    required this.defaultResource,
  });

  final String id;
  final String labelKey;
  final String defaultResource;
}

@immutable
final class AccessAdminWorkspaceData {
  const AccessAdminWorkspaceData({
    this.state = 'ready',
    this.generatedAt,
    this.overview = const AccessAdminOverview(),
    this.panelSummaries = const <AccessAdminPanelSummary>[],
    this.lookups = const AccessAdminLookups(),
    this.items = const <AccessAdminItem>[],
    this.page = const AppPage<AccessAdminItem>(
      items: <AccessAdminItem>[],
      request: AppPageRequest(pageSize: 12),
    ),
    this.permissions = const AccessAdminWorkspacePermissions(),
    this.query = const AccessAdminWorkspaceQuery(),
  });

  final String state;
  final DateTime? generatedAt;
  final AccessAdminOverview overview;
  final List<AccessAdminPanelSummary> panelSummaries;
  final AccessAdminLookups lookups;
  final List<AccessAdminItem> items;
  final AppPage<AccessAdminItem> page;
  final AccessAdminWorkspacePermissions permissions;
  final AccessAdminWorkspaceQuery query;
}

@immutable
final class AccessAdminRoleRef {
  const AccessAdminRoleRef({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
final class AccessAdminPermissionRef {
  const AccessAdminPermissionRef({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
final class AccessAdminItem {
  const AccessAdminItem({
    required this.id,
    required this.resource,
    required this.displayId,
    required this.title,
    this.subtitle,
    this.status,
    this.email,
    this.phone,
    this.positionTitle,
    this.profileName,
    this.staffProfileId,
    this.roles = const <AccessAdminRoleRef>[],
    this.roleCount = 0,
    this.permissionCount = 0,
    this.permissions = const <AccessAdminPermissionRef>[],
    this.userCount = 0,
    this.moduleSlug,
    this.moduleGroup,
    this.planLabel,
    this.isActive = false,
    this.isDemo = false,
    this.isClinicalFlowRole = false,
    this.isSystemCritical = false,
    this.userLabel,
    this.roleName,
    this.permissionName,
    this.entitlementDenied = false,
    this.entitlementDenialReason,
    this.updatedAt,
  });

  final String id;
  final AccessAdminResource resource;
  final String displayId;
  final String title;
  final String? subtitle;
  final String? status;
  final String? email;
  final String? phone;
  final String? positionTitle;
  final String? profileName;
  final String? staffProfileId;
  final List<AccessAdminRoleRef> roles;
  final int roleCount;
  final int permissionCount;
  final List<AccessAdminPermissionRef> permissions;
  final int userCount;
  final String? moduleSlug;
  final String? moduleGroup;
  final String? planLabel;
  final bool isActive;
  final bool isDemo;
  final bool isClinicalFlowRole;
  final bool isSystemCritical;
  final String? userLabel;
  final String? roleName;
  final String? permissionName;
  final bool entitlementDenied;
  final String? entitlementDenialReason;
  final DateTime? updatedAt;

  String get effectiveDisplayId => displayId.isNotEmpty ? displayId : id;
}

@immutable
final class AccessAdminUserDetail {
  const AccessAdminUserDetail({
    required this.item,
    this.directPermissions = const <AccessAdminPermissionRef>[],
    this.effectivePermissions = const <String>[],
    this.rolePermissionPreview = const <AccessAdminRolePermissionPreview>[],
  });

  final AccessAdminItem item;
  final List<AccessAdminPermissionRef> directPermissions;
  final List<String> effectivePermissions;
  final List<AccessAdminRolePermissionPreview> rolePermissionPreview;
}

@immutable
final class AccessAdminRolePermissionPreview {
  const AccessAdminRolePermissionPreview({
    required this.name,
    required this.sourceRole,
  });

  final String name;
  final String sourceRole;
}

@immutable
final class AccessAdminUserDraft {
  const AccessAdminUserDraft({
    required this.tenantId,
    required this.email,
    required this.positionTitle,
    required this.password,
    this.facilityId,
    this.phone,
    this.status = 'ACTIVE',
    this.permissionIds = const <String>[],
  });

  final String tenantId;
  final String? facilityId;
  final String email;
  final String? phone;
  final String positionTitle;
  final String password;
  final String status;
  final List<String> permissionIds;
}

@immutable
final class AccessAdminRoleDraft {
  const AccessAdminRoleDraft({
    required this.tenantId,
    required this.name,
    this.facilityId,
    this.description,
    this.permissionIds = const <String>[],
  });

  final String tenantId;
  final String? facilityId;
  final String name;
  final String? description;
  final List<String> permissionIds;
}

@immutable
final class AccessAdminUserRoleDraft {
  const AccessAdminUserRoleDraft({
    required this.userId,
    required this.roleId,
    required this.tenantId,
    this.facilityId,
  });

  final String userId;
  final String roleId;
  final String tenantId;
  final String? facilityId;
}

@immutable
final class AccessAdminRolePermissionDraft {
  const AccessAdminRolePermissionDraft({
    required this.roleId,
    required this.permissionId,
  });

  final String roleId;
  final String permissionId;
}

@immutable
final class AccessAdminDemoResetResult {
  const AccessAdminDemoResetResult({
    required this.userId,
    required this.email,
    required this.resetAt,
    this.environment,
  });

  final String userId;
  final String email;
  final DateTime? resetAt;
  final String? environment;
}

@immutable
final class AccessAdminWorkspaceState {
  const AccessAdminWorkspaceState({
    required this.data,
    this.query = const AccessAdminWorkspaceQuery(),
    this.selectedItem,
    this.selectedUserDetail,
    this.isRefreshing = false,
    this.isSaving = false,
    this.lastFailure,
  });

  final AccessAdminWorkspaceData data;
  final AccessAdminWorkspaceQuery query;
  final AccessAdminItem? selectedItem;
  final AccessAdminUserDetail? selectedUserDetail;
  final bool isRefreshing;
  final bool isSaving;
  final Object? lastFailure;

  bool get isTenantContextRequired => data.state == 'tenant_context_required';

  AccessAdminWorkspaceState copyWith({
    AccessAdminWorkspaceData? data,
    AccessAdminWorkspaceQuery? query,
    Object? selectedItem = _unset,
    Object? selectedUserDetail = _unset,
    bool? isRefreshing,
    bool? isSaving,
    Object? lastFailure = _unset,
    bool clearLastFailure = false,
  }) {
    return AccessAdminWorkspaceState(
      data: data ?? this.data,
      query: query ?? this.query,
      selectedItem: identical(selectedItem, _unset)
          ? this.selectedItem
          : selectedItem as AccessAdminItem?,
      selectedUserDetail: identical(selectedUserDetail, _unset)
          ? this.selectedUserDetail
          : selectedUserDetail as AccessAdminUserDetail?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      lastFailure: clearLastFailure
          ? null
          : identical(lastFailure, _unset)
          ? this.lastFailure
          : lastFailure,
    );
  }

  static const Object _unset = Object();
}
