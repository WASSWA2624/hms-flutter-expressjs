import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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

final class _ReferenceDataCacheEntry {
  const _ReferenceDataCacheEntry({
    required this.lookups,
    required this.cachedAt,
  });

  final AccessAdminLookups lookups;
  final DateTime cachedAt;
}

final class AccessAdminRepositoryImpl implements AccessAdminRepository {
  AccessAdminRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;
  final Map<String, _ReferenceDataCacheEntry> _referenceDataCache =
      <String, _ReferenceDataCacheEntry>{};
  static const Duration _referenceDataTtl = Duration(minutes: 2);

  String _referenceDataCacheKey({
    String? tenantId,
    String? facilityId,
    List<String> include = const <String>[],
  }) {
    final List<String> includeKey = List<String>.from(include)..sort();
    return <String>[
      tenantId ?? '',
      facilityId ?? '',
      includeKey.join(','),
    ].join('|');
  }

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
        'roleScope': query.roleScope,
        'userId': query.userId,
        'roleId': query.roleId,
        'include_deleted': query.includeDeleted ? 'true' : null,
        'lean': query.lean ? 'true' : null,
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
    List<String> include = const <String>[],
    bool forceRefresh = false,
  }) async {
    final String cacheKey = _referenceDataCacheKey(
      tenantId: tenantId,
      facilityId: facilityId,
      include: include,
    );
    if (!forceRefresh) {
      final _ReferenceDataCacheEntry? cached = _referenceDataCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) <= _referenceDataTtl) {
        return Result<AccessAdminLookups>.success(cached.lookups);
      }
    }

    final Result<AccessAdminLookups> result = await _apiClient
        .get<AccessAdminLookups>(
          ApiEndpoints.nested(
            HmsApiResource.accessAdminWorkspace,
            'reference-data',
            const <String>[],
          ),
          queryParameters: _withoutEmpty(<String, Object?>{
            'tenantId': tenantId,
            'facilityId': facilityId,
            'include': include.isEmpty ? null : include.join(','),
          }),
          decoder: (Object? data) {
            return AccessAdminLookupsDto.fromResponse(data).toEntity();
          },
        );

    result.when(
      success: (AccessAdminLookups lookups) {
        _referenceDataCache[cacheKey] = _ReferenceDataCacheEntry(
          lookups: lookups,
          cachedAt: DateTime.now(),
        );
      },
      failure: (_) {},
    );
    return result;
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
        return AccessAdminLegacyRouteResolutionDto.fromResponse(
          data,
        ).toEntity();
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
  Future<Result<String>> createUser(AccessAdminUserDraft draft) async {
    final Result<String?> createResult = await _apiClient.post<String?>(
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
      decoder: (Object? responseData) => _extractRecordId(
        responseData is Map<String, dynamic>
            ? responseData['data'] ?? responseData
            : responseData,
      ),
    );

    return createResult.when(
      success: (String? userId) {
        if (userId == null || userId.isEmpty) {
          return const Result<String>.failure(AppFailure.unexpected());
        }
        return Result<String>.success(userId);
      },
      failure: (AppFailure failure) => Result<String>.failure(failure),
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
        'password': draft.password,
        'status': draft.status,
        'permission_ids': draft.permissionIds,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> syncUserDirectPermissions({
    required String userId,
    required List<String> permissionIds,
  }) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.users, userId),
      data: <String, Object?>{'permission_ids': permissionIds},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteUser(String userId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.users, userId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> restoreUser(String userId) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.users,
        userId,
        const <String>['restore'],
      ),
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
        'permission_ids': draft.permissionIds,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateRole(String roleId, AccessAdminRoleDraft draft) {
    final Map<String, Object?> payload = <String, Object?>{
      ..._withoutEmpty(<String, Object?>{
        'name': draft.name,
        'description': draft.description,
      }),
      'facility_id': draft.facilityId,
      'permission_ids': draft.permissionIds,
    };
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.roles, roleId),
      data: payload,
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
  Future<Result<List<AccessAdminRolePermissionAssignment>>> listRolePermissions(
    String roleId,
  ) async {
    final List<AccessAdminRolePermissionAssignment> all =
        <AccessAdminRolePermissionAssignment>[];
    var pageIndex = 0;
    const int pageSize = AppPageRequest.maxPageSize;

    while (true) {
      final Result<List<AccessAdminRolePermissionAssignment>> result =
          await _fetchRolePermissionsPage(
            roleId: roleId,
            pageIndex: pageIndex,
            pageSize: pageSize,
          );
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure value) => value,
      );
      if (failure != null) {
        return Result<List<AccessAdminRolePermissionAssignment>>.failure(
          failure,
        );
      }

      final List<AccessAdminRolePermissionAssignment> page = result.when(
        success: (List<AccessAdminRolePermissionAssignment> value) => value,
        failure: (_) => throw StateError('unreachable'),
      );
      all.addAll(page);
      if (page.length < pageSize) {
        break;
      }
      pageIndex += 1;
    }

    return Result<List<AccessAdminRolePermissionAssignment>>.success(all);
  }

  Future<Result<List<AccessAdminRolePermissionAssignment>>>
  _fetchRolePermissionsPage({
    required String roleId,
    required int pageIndex,
    required int pageSize,
  }) {
    return _apiClient.get<List<AccessAdminRolePermissionAssignment>>(
      ApiEndpoints.collection(HmsApiResource.rolePermissions),
      queryParameters: <String, Object?>{
        'role_id': roleId,
        'page': pageIndex + 1,
        'limit': pageSize,
      },
      decoder: (Object? data) {
        final Map<String, Object?> response = data is Map<String, Object?>
            ? data
            : <String, Object?>{};
        final List<Object?> rows = response['data'] is List<Object?>
            ? response['data']! as List<Object?>
            : const <Object?>[];
        return rows
            .whereType<Map<Object?, Object?>>()
            .map((Map<Object?, Object?> entry) {
              final Map<String, Object?> row = entry.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>(key.toString(), value),
              );
              final Object? permissionRaw = row['permission'];
              final Map<String, Object?> permission =
                  permissionRaw is Map<Object?, Object?>
                  ? permissionRaw.map(
                      (Object? key, Object? value) =>
                          MapEntry<String, Object?>(key.toString(), value),
                    )
                  : <String, Object?>{};
              final String assignmentId =
                  _string(row['human_friendly_id']) ??
                  _string(row['display_id']) ??
                  _string(row['id']) ??
                  '';
              final String? permissionId =
                  _string(permission['human_friendly_id']) ??
                  _string(permission['display_id']) ??
                  _string(permission['id']) ??
                  _string(row['permission_id']);
              final String? permissionName =
                  _string(permission['name']) ??
                  _string(row['permission_name']);
              return AccessAdminRolePermissionAssignment(
                id: assignmentId,
                permissionId: permissionId,
                permissionName: permissionName,
              );
            })
            .where(
              (AccessAdminRolePermissionAssignment item) => item.id.isNotEmpty,
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<Result<void>> syncRolePermissions({
    required String roleId,
    required List<String> permissionIds,
  }) async {
    final Result<List<AccessAdminRolePermissionAssignment>> currentResult =
        await listRolePermissions(roleId);
    final List<AccessAdminRolePermissionAssignment> current =
        currentResult.when(
          success: (List<AccessAdminRolePermissionAssignment> value) => value,
          failure: (_) => const <AccessAdminRolePermissionAssignment>[],
        );
    final Set<String> desiredPermissionIds = permissionIds.toSet();
    final Set<String> currentPermissionIds = current
        .map(
          (AccessAdminRolePermissionAssignment assignment) =>
              assignment.permissionId,
        )
        .whereType<String>()
        .toSet();

    AppFailure? lastFailure;
    for (final AccessAdminRolePermissionAssignment assignment in current) {
      final String? permissionId = assignment.permissionId;
      if (permissionId == null || desiredPermissionIds.contains(permissionId)) {
        continue;
      }
      final Result<void> result = await revokeRolePermission(assignment.id);
      if (result case ResultFailure<void>(:final failure)) {
        lastFailure ??= failure;
      }
    }

    for (final String permissionId in desiredPermissionIds) {
      if (currentPermissionIds.contains(permissionId)) {
        continue;
      }
      final Result<void> result = await assignRolePermission(
        AccessAdminRolePermissionDraft(
          roleId: roleId,
          permissionId: permissionId,
        ),
      );
      if (result case ResultFailure<void>(:final failure)) {
        lastFailure ??= failure;
      }
    }

    if (lastFailure != null) {
      return Result<void>.failure(lastFailure);
    }
    return const Result<void>.success(null);
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
  Future<Result<List<AccessAdminUserRoleAssignment>>> listUserRoles({
    required String userId,
    String? tenantId,
  }) async {
    final List<AccessAdminUserRoleAssignment> all =
        <AccessAdminUserRoleAssignment>[];
    var pageIndex = 0;
    const int pageSize = AppPageRequest.maxPageSize;

    while (true) {
      final Result<List<AccessAdminUserRoleAssignment>> result =
          await _fetchUserRolesPage(
            userId: userId,
            tenantId: tenantId,
            pageIndex: pageIndex,
            pageSize: pageSize,
          );
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure value) => value,
      );
      if (failure != null) {
        return Result<List<AccessAdminUserRoleAssignment>>.failure(failure);
      }

      final List<AccessAdminUserRoleAssignment> page = result.when(
        success: (List<AccessAdminUserRoleAssignment> value) => value,
        failure: (_) => throw StateError('unreachable'),
      );
      all.addAll(page);
      if (page.length < pageSize) {
        break;
      }
      pageIndex += 1;
    }

    return Result<List<AccessAdminUserRoleAssignment>>.success(all);
  }

  Future<Result<List<AccessAdminUserRoleAssignment>>> _fetchUserRolesPage({
    required String userId,
    String? tenantId,
    required int pageIndex,
    required int pageSize,
  }) {
    return _apiClient.get<List<AccessAdminUserRoleAssignment>>(
      ApiEndpoints.collection(HmsApiResource.userRoles),
      queryParameters: _withoutEmpty(<String, Object?>{
        'user_id': userId,
        'tenant_id': tenantId,
        'page': pageIndex + 1,
        'limit': pageSize,
      }),
      decoder: (Object? data) {
        final Map<String, Object?> response = data is Map<String, Object?>
            ? data
            : <String, Object?>{};
        final List<Object?> rows = response['data'] is List<Object?>
            ? response['data']! as List<Object?>
            : const <Object?>[];
        return rows
            .whereType<Map<String, Object?>>()
            .map((Map<String, Object?> json) {
              final Map<String, Object?> role =
                  json['role'] is Map<String, Object?>
                  ? json['role']! as Map<String, Object?>
                  : <String, Object?>{};
              final String assignmentId =
                  _string(json['id']) ??
                  _string(json['backend_identifier']) ??
                  _string(json['display_id']) ??
                  '';
              final String? roleId =
                  _nullableString(json['role_id']) ??
                  _nullableString(role['id']) ??
                  _nullableString(role['display_id']);
              return AccessAdminUserRoleAssignment(
                id: assignmentId,
                roleId: roleId,
              );
            })
            .where((AccessAdminUserRoleAssignment item) => item.id.isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  @override
  Future<Result<void>> syncUserRoles({
    required String userId,
    required String tenantId,
    required List<String> roleIds,
    String? facilityId,
  }) async {
    final Result<List<AccessAdminUserRoleAssignment>> currentResult =
        await listUserRoles(userId: userId, tenantId: tenantId);
    final List<AccessAdminUserRoleAssignment> currentRoles = currentResult.when(
      success: (List<AccessAdminUserRoleAssignment> value) => value,
      failure: (_) => const <AccessAdminUserRoleAssignment>[],
    );
    final Set<String> desiredRoleIds = roleIds.toSet();
    final Set<String> currentRoleIds = currentRoles
        .map((AccessAdminUserRoleAssignment role) => role.roleId)
        .whereType<String>()
        .toSet();

    AppFailure? lastFailure;
    for (final AccessAdminUserRoleAssignment assignment in currentRoles) {
      final String? roleId = assignment.roleId;
      if (roleId == null || desiredRoleIds.contains(roleId)) {
        continue;
      }
      final Result<void> result = await revokeUserRole(assignment.id);
      if (result case ResultFailure<void>(:final failure)) {
        lastFailure ??= failure;
      }
    }

    for (final String roleId in desiredRoleIds) {
      if (currentRoleIds.contains(roleId)) {
        continue;
      }
      final Result<void> result = await assignUserRole(
        AccessAdminUserRoleDraft(
          userId: userId,
          roleId: roleId,
          tenantId: tenantId,
          facilityId: facilityId,
        ),
      );
      if (result case ResultFailure<void>(:final failure)) {
        lastFailure ??= failure;
      }
    }

    if (lastFailure != null) {
      return Result<void>.failure(lastFailure);
    }
    return const Result<void>.success(null);
  }

  String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _string(Object? value) => _nullableString(value);

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
  Future<Result<AccessAdminDemoResetResult>> resetDemoUserPassword(
    String userId,
  ) {
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

  @override
  Future<Result<void>> activateRegistration(String userId) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'registrations',
        <String>[userId, 'activate'],
      ),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> rejectRegistration(String userId) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.accessAdminWorkspace,
        'registrations',
        <String>[userId, 'reject'],
      ),
      decoder: (_) {},
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

  String? _extractRecordId(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final Object? id = payload['id'] ?? payload['human_friendly_id'];
    if (id == null) {
      return null;
    }
    final String normalized = id.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}
