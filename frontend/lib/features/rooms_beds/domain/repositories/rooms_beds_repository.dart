import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

abstract interface class RoomsBedsRepository {
  Future<Result<FacilitySetupSnapshot>> loadSetup({String? facilityId});

  Future<Result<WardProfile>> saveWard({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required WardSetupType type,
    String? departmentId,
    required bool isActive,
  });

  Future<Result<RoomProfile>> saveRoom({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? wardId,
    String? floor,
  });

  Future<Result<BedProfile>> saveBed({
    String? id,
    required String tenantId,
    required String facilityId,
    required String wardId,
    required String label,
    required BedSetupStatus status,
    String? roomId,
  });

  Future<Result<List<BedAssignmentRecord>>> listBedAssignmentsForBed(
    String bedId,
  );

  Future<Result<void>> assignBed({
    required String admissionId,
    required String bedId,
  });

  Future<Result<void>> releaseBed({required String admissionId});

  Future<Result<void>> requestTransfer({
    required String admissionId,
    String? fromWardId,
    required String toWardId,
  });
}
