import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

abstract interface class RoomsBedsRepository {
  Future<Result<FacilitySetupSnapshot>> loadSetup({String? facilityId});

  Future<Result<List<BedAssignmentRecord>>> listBedAssignmentsForBed(
    String bedId,
  );

  Future<Result<BedAdmissionContext>> loadAdmissionContext(String admissionId);

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

  Future<Result<void>> updateTransfer({
    required String admissionId,
    required String action,
    String? transferRequestId,
    String? toBedId,
  });

  Future<Result<BedProfile>> updateBedStatus({
    required BedProfile bed,
    required BedSetupStatus status,
  });
}
