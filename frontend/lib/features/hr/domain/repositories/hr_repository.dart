import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class HrRepository {
  Future<Result<HrWorkspaceOverview>> loadOverview();

  Future<Result<HrReferenceData>> loadReferenceData({
    String? facilityId,
    String? departmentId,
  });

  Future<Result<AppPage<HrStaffProfile>>> listStaffProfiles(
    HrStaffQuery query,
  );

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
}
