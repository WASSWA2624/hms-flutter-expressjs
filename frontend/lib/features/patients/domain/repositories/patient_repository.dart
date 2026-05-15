import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class PatientRepository {
  Future<Result<AppPage<Patient>>> listPatients(PatientListQuery query);

  Future<Result<PatientRegistryOverview>> loadOverview();

  Future<Result<PatientReferenceData>> loadReferenceData();

  Future<Result<PatientDetail>> loadPatientDetail(String patientId);

  Future<Result<Patient>> createPatient(Map<String, Object?> payload);

  Future<Result<Patient>> updatePatient(
    String patientId,
    Map<String, Object?> payload,
  );

  Future<Result<PatientMutationResult>> deletePatient(String patientId);

  Future<Result<void>> createRelatedRecord(
    PatientRelatedResource resource,
    Map<String, Object?> payload,
  );

  Future<Result<void>> updateRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
  );
}
