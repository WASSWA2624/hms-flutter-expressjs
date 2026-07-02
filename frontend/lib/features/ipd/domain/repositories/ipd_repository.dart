import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class IpdRepository {
  Future<Result<AppPage<IpdAdmissionSummary>>> listAdmissions(
    IpdAdmissionQuery query,
  );

  Future<Result<IpdAdmissionDetail>> getAdmission(String admissionId);

  Future<Result<List<IpdWardOption>>> listWards({String? search});

  Future<Result<List<IpdBedOption>>> listBeds({
    String? search,
    String? status,
    String? wardId,
  });

  Future<Result<List<IpdBedBoardEntry>>> listBedBoard({
    String? wardId,
    String? status,
    String? statusAny,
    int limit,
  });

  Future<Result<void>> updateBedStatus({
    required String bedId,
    required String status,
  });

  Future<Result<IpdAdmissionDetail>> startAdmission(
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> requestAdmission(
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> approveAdmission(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> assignBed(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> startIcuStay(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> releaseBed(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> rejectAdmission(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> requestTransfer(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> requestTherapy(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> updateTransfer(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> addWardRound(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> addNursingNote(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> addMedicationAdministration(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> planDischarge(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> finalizeDischarge(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<IpdAdmissionDetail>> updateDischargeClearance(
    String admissionId,
    Map<String, Object?> payload,
  );
}
