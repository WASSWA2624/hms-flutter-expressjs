import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';

abstract interface class AccessAdminRepository {
  Future<Result<AccessAdminWorkspaceData>> getWorkspace(
    AccessAdminWorkspaceQuery query,
  );

  Future<Result<AccessAdminLookups>> getReferenceData({
    String? tenantId,
    String? facilityId,
    List<String> include = const <String>[],
    bool forceRefresh = false,
  });

  Future<Result<AccessAdminLegacyRouteResolution>> resolveLegacyRoute(
    AccessAdminResource resource,
    String identifier,
  );

  Future<Result<AccessAdminUserDetail>> getUserDetail(
    String userId, {
    String? tenantId,
    String? facilityId,
  });

  Future<Result<String>> createUser(AccessAdminUserDraft draft);

  Future<Result<void>> updateUser(String userId, AccessAdminUserDraft draft);

  Future<Result<void>> syncUserDirectPermissions({
    required String userId,
    required List<String> permissionIds,
  });

  Future<Result<void>> deleteUser(String userId);

  Future<Result<void>> restoreUser(String userId);

  Future<Result<void>> setUserStatus(String userId, String status);

  Future<Result<List<AccessAdminUserRoleAssignment>>> listUserRoles({
    required String userId,
    String? tenantId,
  });

  Future<Result<void>> syncUserRoles({
    required String userId,
    required String tenantId,
    required List<String> roleIds,
    String? facilityId,
  });

  Future<Result<void>> createRole(AccessAdminRoleDraft draft);

  Future<Result<void>> updateRole(String roleId, AccessAdminRoleDraft draft);

  Future<Result<void>> deleteRole(String roleId);

  Future<Result<List<AccessAdminRolePermissionAssignment>>> listRolePermissions(
    String roleId,
  );

  Future<Result<void>> syncRolePermissions({
    required String roleId,
    required List<String> permissionIds,
  });

  Future<Result<void>> assignUserRole(AccessAdminUserRoleDraft draft);

  Future<Result<void>> revokeUserRole(String userRoleId);

  Future<Result<void>> assignRolePermission(
    AccessAdminRolePermissionDraft draft,
  );

  Future<Result<void>> revokeRolePermission(String rolePermissionId);

  Future<Result<AccessAdminDemoResetResult>> resetDemoUserPassword(
    String userId,
  );

  Future<Result<void>> activateRegistration(String userId);

  Future<Result<void>> rejectRegistration(String userId);
}
