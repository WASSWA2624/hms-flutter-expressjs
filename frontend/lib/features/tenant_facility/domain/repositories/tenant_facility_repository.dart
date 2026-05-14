import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

abstract interface class TenantFacilityRepository {
  Future<Result<FacilitySetupSnapshot>> loadSetup();

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

  Future<Result<BranchProfile>> createBranch({
    required String tenantId,
    required String facilityId,
    required String name,
    required bool isActive,
  });

  Future<Result<DepartmentProfile>> createDepartment({
    required String tenantId,
    required String facilityId,
    required String name,
    String? shortName,
    required DepartmentSetupType type,
    required bool isActive,
  });

  Future<Result<UnitProfile>> createUnit({
    required String tenantId,
    required String facilityId,
    required String name,
    String? departmentId,
    required bool isActive,
  });
}
