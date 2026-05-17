import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class NursingRepository {
  Future<Result<AppPage<NursingPatientSummary>>> listWardPatients(
    NursingWorklistQuery query,
  );

  Future<Result<NursingPatientDetail>> loadPatientDetail(
    NursingPatientSummary summary,
  );

  Future<Result<List<NursingHandover>>> listPendingHandovers();

  Future<Result<List<NursingRosterAssignment>>> listCurrentRosters();

  Future<Result<NursingPatientDetail>> recordVitals(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  );

  Future<Result<NursingPatientDetail>> addNursingNote(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  );

  Future<Result<NursingPatientDetail>> addMedicationAdministration(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  );

  Future<Result<NursingPatientDetail>> addCarePlan(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  );

  Future<Result<NursingPatientDetail>> createHandover(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  );

  Future<Result<void>> acceptHandover(
    String handoverId,
    Map<String, Object?> payload,
  );

  Future<Result<NursingPatientDetail>> updateTransfer(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  );
}
