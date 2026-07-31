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
    int limit = 25,
    String source = 'ALL',
    String? facilityId,
  });

  Future<Result<List<ClinicalCatalogOption>>> searchClinicalCatalog({
    required String termType,
    String? query,
    int limit = 80,
    String source = 'ALL',
    bool offeredOnly = false,
    String? facilityId,
  });

  Future<Result<void>> createClinicalTermFavorite(Map<String, Object?> payload);

  Future<Result<void>> upsertFacilityCatalogOffering(
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteFacilityCatalogOffering(String offeringId);

  Future<Result<List<Map<String, Object?>>>> listFacilityCatalogOfferings({
    required String facilityId,
    String? termType,
    String? query,
  });

  Future<Result<ClinicalCatalogOption>> createClinicalCatalogTerm(
    Map<String, Object?> payload,
  );

  Future<Result<ClinicalCatalogOption>> updateClinicalCatalogTerm(
    String termId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteClinicalCatalogTerm(String termId);

  Future<Result<void>> createClinicalNote(Map<String, Object?> payload);

  Future<Result<void>> updateClinicalNote(
    String noteId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> createDiagnosis(Map<String, Object?> payload);

  Future<Result<void>> updateDiagnosis(
    String diagnosisId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteDiagnosis(String diagnosisId);

  Future<Result<void>> createProcedure(Map<String, Object?> payload);

  Future<Result<void>> createCarePlan(Map<String, Object?> payload);

  Future<Result<void>> createLabOrder(Map<String, Object?> payload);

  Future<Result<void>> updateLabOrder(
    String labOrderId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteLabOrder(String labOrderId);

  Future<Result<void>> createRadiologyOrder(Map<String, Object?> payload);

  Future<Result<void>> updateRadiologyOrder(
    String radiologyOrderId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteRadiologyOrder(String radiologyOrderId);

  Future<Result<void>> createPharmacyOrder(Map<String, Object?> payload);

  Future<Result<void>> updatePharmacyOrder(
    String pharmacyOrderId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deletePharmacyOrder(String pharmacyOrderId);

  Future<Result<void>> createReferral(Map<String, Object?> payload);

  Future<Result<void>> createFollowUp(Map<String, Object?> payload);

  Future<Result<void>> createAdmission(Map<String, Object?> payload);

  Future<Result<void>> dischargeAdmission(
    String admissionId,
    Map<String, Object?> payload,
  );

  Future<Result<ClinicalWorklistEntry>> updateEncounter(
    String encounterId,
    Map<String, Object?> payload,
  );
}
