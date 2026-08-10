import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class HrRepository {
  Future<Result<HrWorkspaceOverview>> loadOverview();

  Future<Result<HrReferenceData>> loadReferenceData({
    String? facilityId,
    String? departmentId,
  });

  Future<Result<String>> generateStaffNumber({
    required String tenantId,
    String? facilityId,
  });

  Future<Result<AppPage<HrStaffProfile>>> listStaffProfiles(HrStaffQuery query);

  Future<Result<HrStaffDetail>> loadStaffDetail(HrStaffProfile profile);

  Future<Result<AppPage<HrWorkItem>>> listWorkItems(HrWorkItemsQuery query);

  Future<Result<HrStaffProfile>> createStaffProfile(
    Map<String, Object?> payload,
  );

  Future<Result<HrStaffProfile>> updateStaffProfile(
    String staffProfileId,
    Map<String, Object?> payload,
  );

  Future<Result<Object?>> createStaffAssignment(Map<String, Object?> payload);

  Future<Result<Object?>> createStaffAvailability(Map<String, Object?> payload);

  Future<Result<Object?>> createStaffAvailabilityBatch(
    Map<String, Object?> payload,
  );

  Future<Result<List<HrStaffAvailability>>> listStaffAvailabilities(
    String staffProfileId,
  );

  Future<Result<Object?>> createStaffLeave(Map<String, Object?> payload);

  Future<Result<Object?>> createShiftAssignment(Map<String, Object?> payload);

  Future<Result<Object?>> createShiftSwapRequest(Map<String, Object?> payload);

  Future<Result<Object?>> createPayrollRun(Map<String, Object?> payload);

  Future<Result<Object?>> approveLeave(String leaveId, {String? reason});

  Future<Result<Object?>> rejectLeave(String leaveId, {required String reason});

  Future<Result<Object?>> approveSwap(String swapId, {String? reason});

  Future<Result<Object?>> rejectSwap(String swapId, {required String reason});

  Future<Result<Object?>> publishRoster(
    String rosterId, {
    bool notifyStaff = true,
    bool allowPartialPublish = false,
    String? publishNote,
  });

  Future<Result<Object?>> generateRoster(
    String rosterId, {
    bool replaceExistingAssignments = true,
    bool dryRun = false,
  });

  Future<Result<Object?>> overrideShift(
    String shiftId, {
    required String staffProfileId,
    required String reason,
  });

  Future<Result<Object?>> processPayrollRun(
    String payrollRunId, {
    bool replaceExistingItems = false,
    String? notes,
  });

  Future<Result<HrStaffAccessSummary>> loadStaffAccessSummary(
    String staffProfileId,
  );

  Future<Result<void>> assignUserRole({
    required String userId,
    required String roleId,
    required String tenantId,
    String? facilityId,
  });

  Future<Result<void>> revokeUserRole(String userRoleId);

  Future<Result<Object?>> createUserAccount(Map<String, Object?> payload);

  Future<Result<Object?>> createUserProfile(Map<String, Object?> payload);

  Future<Result<Object?>> updateStaffAssignment(
    String assignmentId,
    Map<String, Object?> payload,
  );

  Future<Result<Object?>> createShiftTemplate(Map<String, Object?> payload);

  Future<Result<Object?>> updateShiftTemplate(
    String templateId,
    Map<String, Object?> payload,
  );

  Future<Result<Object?>> deleteShiftTemplate(String templateId);

  Future<Result<Map<String, Object?>>> createRoster(Map<String, Object?> payload);

  Future<Result<Object?>> updateRoster(
    String rosterId,
    Map<String, Object?> payload,
  );

  Future<Result<Object?>> deleteRoster(String rosterId);

  Future<Result<Map<String, Object?>>> restoreRoster(String rosterId);

  Future<Result<Object?>> permanentDeleteRoster(String rosterId);

  Future<Result<Map<String, Object?>>> getRoster(String rosterId);

  Future<Result<Map<String, Object?>>> attachRosterStaff({
    required String rosterId,
    required String staffProfileId,
    String? staffCategory,
  });

  Future<Result<Map<String, Object?>>> detachRosterStaff({
    required String rosterId,
    required String staffProfileId,
  });

  Future<Result<HrPayrollPreview>> previewPayrollRun(
    String payrollRunId, {
    String? staffProfileId,
    String? facilityId,
    String? departmentId,
  });

  Future<Result<Object?>> offboardStaff(
    String staffProfileId,
    Map<String, Object?> payload,
  );

  Future<Result<HrRosterGenerateResult>> generateRosterPreview(
    String rosterId, {
    bool replaceExistingAssignments = true,
  });

  Future<Result<AppPage<HrAccessUser>>> listAccessUsers(HrAccessQuery query);

  Future<Result<AppPage<HrAccessRole>>> listAccessRoles(HrAccessQuery query);

  Future<Result<AppPage<HrAccessPermission>>> listAccessPermissions(
    HrAccessQuery query,
  );

  Future<Result<List<HrAccessPermission>>> listAllAccessPermissions(
    HrAccessQuery query,
  );

  Future<Result<Object?>> updateUserAccount(
    String userId,
    Map<String, Object?> payload,
  );

  Future<Result<Object?>> createRole(Map<String, Object?> payload);

  Future<Result<Object?>> updateRole(
    String roleId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteRole(String roleId);

  Future<Result<Object?>> createPermission(Map<String, Object?> payload);

  Future<Result<Object?>> updatePermission(
    String permissionId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deletePermission(String permissionId);

  Future<Result<void>> assignRolePermission({
    required String roleId,
    required String permissionId,
  });

  Future<Result<void>> revokeRolePermission(String rolePermissionId);

  Future<Result<AppPage<HrOption>>> listRolePermissions(String roleId);

  Future<Result<HrAccessUserDetail>> loadAccessUserDetail(String userId);

  Future<Result<List<HrUserRole>>> listUserRoles({
    required String userId,
    String? tenantId,
  });

  Future<Result<AppPage<HrStaffPosition>>> listStaffPositions(
    HrStaffPositionQuery query,
  );

  Future<Result<HrStaffPosition>> getStaffPosition(String positionId);

  Future<Result<HrStaffPosition>> createStaffPosition(
    Map<String, Object?> payload,
  );

  Future<Result<HrStaffPosition>> updateStaffPosition(
    String positionId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteStaffPosition(String positionId);

  Future<Result<HrStaffPosition>> restoreStaffPosition(String positionId);

  Future<Result<void>> permanentDeleteStaffPosition(String positionId);
}
