import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/access_admin/data/dtos/access_admin_dtos.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final accessAdminRepositoryProvider = Provider<AccessAdminRepository>((ref) {
  return AccessAdminRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class AccessAdminRepositoryImpl implements AccessAdminRepository {
  const AccessAdminRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AccessAdminWorkspaceData>> getWorkspace(
    AccessAdminWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AccessAdminWorkspaceData>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'workspace',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'panel': query.panel.serverValue,
        'resource': query.resource.serverValue,
        'search': query.search,
        'tenantId': query.tenantId,
        'facilityId': query.facilityId,
        'id': query.recordId,
        'status': query.status,
        'userId': query.userId,
        'roleId': query.roleId,
      }),
      decoder: (Object? data) {
        return AccessAdminWorkspaceDto.fromResponse(data, query).toEntity();
      },
    );
  }

  @override
  Future<Result<AccessAdminLookups>> getReferenceData({
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.get<AccessAdminLookups>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'reference-data',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'tenantId': tenantId,
        'facilityId': facilityId,
      }),
      decoder: (Object? data) {
        return AccessAdminLookupsDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AccessAdminLegacyRouteResolution>> resolveLegacyRoute(
    AccessAdminResource resource,
    String identifier,
  ) {
    return _apiClient.get<AccessAdminLegacyRouteResolution>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'resolve-legacy',
        <String>[resource.serverValue, identifier],
      ),
      decoder: (Object? data) {
        return AccessAdminLegacyRouteResolutionDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AccessAdminUserDetail>> getUserDetail(
    String userId, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.get<AccessAdminUserDetail>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'users',
        <String>[userId, 'detail'],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'tenantId': tenantId,
        'facilityId': facilityId,
      }),
      decoder: (Object? data) {
        return AccessAdminUserDetailDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> createUser(AccessAdminUserDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.users),
      data: _withoutEmpty(<String, Object?>{
        'tenant_id': draft.tenantId,
        'facility_id': draft.facilityId,
        'email': draft.email,
        'phone': draft.phone,
        'position_title': draft.positionTitle,
        'password': draft.password,
        'status': draft.status,
        'permission_ids': draft.permissionIds,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateUser(String userId, AccessAdminUserDraft draft) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.users, userId),
      data: _withoutEmpty(<String, Object?>{
        'facility_id': draft.facilityId,
        'email': draft.email,
        'phone': draft.phone,
        'position_title': draft.positionTitle,
        'status': draft.status,
        'permission_ids': draft.permissionIds,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> setUserStatus(String userId, String status) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.users, userId),
      data: <String, Object?>{'status': status},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createRole(AccessAdminRoleDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.roles),
      data: _withoutEmpty(<String, Object?>{
        'tenant_id': draft.tenantId,
        'facility_id': draft.facilityId,
        'name': draft.name,
        'description': draft.description,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateRole(String roleId, AccessAdminRoleDraft draft) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.roles, roleId),
      data: _withoutEmpty(<String, Object?>{
        'name': draft.name,
        'description': draft.description,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteRole(String roleId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.roles, roleId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> assignUserRole(AccessAdminUserRoleDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.userRoles),
      data: _withoutEmpty(<String, Object?>{
        'user_id': draft.userId,
        'role_id': draft.roleId,
        'tenant_id': draft.tenantId,
        'facility_id': draft.facilityId,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> revokeUserRole(String userRoleId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.userRoles, userRoleId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> assignRolePermission(
    AccessAdminRolePermissionDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.rolePermissions),
      data: <String, Object?>{
        'role_id': draft.roleId,
        'permission_id': draft.permissionId,
      },
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> revokeRolePermission(String rolePermissionId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.rolePermissions, rolePermissionId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<AccessAdminDemoResetResult>> resetDemoUserPassword(String userId) {
    return _apiClient.post<AccessAdminDemoResetResult>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'demo-users',
        <String>[userId, 'reset-password'],
      ),
      decoder: (Object? data) {
        return AccessAdminDemoResetResultDto.fromResponse(data).toEntity();
      },
    );
  }

  Map<String, Object> _withoutEmpty(Map<String, Object?> values) {
    final Map<String, Object> normalized = <String, Object>{};
    values.forEach((String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      normalized[key] = value;
    });
    return normalized;
  }
}
