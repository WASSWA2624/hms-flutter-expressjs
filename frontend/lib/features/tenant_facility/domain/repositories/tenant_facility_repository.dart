import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

abstract interface class TenantFacilityRepository {
  Future<Result<FacilitySetupSnapshot>> loadSetup({String? facilityId});

  Future<Result<TenantProfile>> saveTenant({
    String? id,
    required String name,
    String? slug,
    required bool isActive,
  });

  Future<Result<FacilityProfile>> saveFacility({
    String? id,
    required String tenantId,
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    String? logoUrl,
  });

  Future<Result<void>> saveFacilityContactAddress({
    required String tenantId,
    required String facilityId,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
  });

  Future<Result<BranchProfile>> saveBranch({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required bool isActive,
  });

  Future<Result<void>> deleteBranch(String id);

  Future<Result<DepartmentProfile>> saveDepartment({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    String? branchId,
    required DepartmentSetupType type,
    required bool isActive,
  });

  Future<Result<void>> deleteDepartment(String id);

  Future<Result<UnitProfile>> saveUnit({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? departmentId,
    required bool isActive,
  });

  Future<Result<void>> deleteUnit(String id);

  Future<Result<WardProfile>> saveWard({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required WardSetupType type,
    String? departmentId,
    required bool isActive,
  });

  Future<Result<void>> deleteWard(String id);

  Future<Result<RoomProfile>> saveRoom({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? wardId,
    String? floor,
  });

  Future<Result<void>> deleteRoom(String id);

  Future<Result<BedProfile>> saveBed({
    String? id,
    required String tenantId,
    required String facilityId,
    required String wardId,
    required String label,
    required BedSetupStatus status,
    String? roomId,
  });

  Future<Result<void>> deleteBed(String id);
}
