import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class ClinicalRepository {
  Future<Result<AppPage<ClinicalWorklistEntry>>> listEncounters(
    ClinicalWorklistQuery query,
  );

  Future<Result<AppPage<ClinicalWorklistEntry>>> listAdmissions(
    ClinicalWorklistQuery query,
  );

  Future<Result<ClinicalEncounterBundle>> loadEncounterBundle(
    ClinicalWorklistEntry entry,
  );

  Future<Result<ClinicalReferenceData>> loadReferenceData();

  Future<Result<List<ClinicalCatalogOption>>> searchClinicalTerms({
    required String termType,
    String? query,
  });

  Future<Result<void>> createClinicalNote(Map<String, Object?> payload);

  Future<Result<void>> createDiagnosis(Map<String, Object?> payload);

  Future<Result<void>> createProcedure(Map<String, Object?> payload);

  Future<Result<void>> createCarePlan(Map<String, Object?> payload);

  Future<Result<void>> createLabOrder(Map<String, Object?> payload);

  Future<Result<void>> createRadiologyOrder(Map<String, Object?> payload);

  Future<Result<void>> createPharmacyOrder(Map<String, Object?> payload);

  Future<Result<void>> createReferral(Map<String, Object?> payload);

  Future<Result<void>> createFollowUp(Map<String, Object?> payload);

  Future<Result<void>> createAdmission(Map<String, Object?> payload);

  Future<Result<ClinicalWorklistEntry>> updateEncounter(
    String encounterId,
    Map<String, Object?> payload,
  );
}
