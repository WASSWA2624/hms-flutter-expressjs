import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_catalog_mapper.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_prescription_catalog_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Shared remote medicine catalog loader for prescribe / create-order flows.
///
/// Uses the pharmacy drug catalog (prices + availability) so clinical and
/// pharmacy modules stay on one searchable source of truth.
ClinicalPrescriptionCatalogLoader pharmacyPrescriptionCatalogLoader({
  required PharmacyRepository repository,
  String? facilityId,
}) {
  return (String query) async {
    final Result<List<ClinicalActionCatalogOption>> result =
        await loadPharmacyPrescriptionCatalogOptions(
          repository: repository,
          query: query,
          facilityId: facilityId,
        );
    return result.when(
      success: (List<ClinicalActionCatalogOption> drugs) => drugs,
      failure: (_) => const <ClinicalActionCatalogOption>[],
    );
  };
}

Future<Result<List<ClinicalActionCatalogOption>>>
loadPharmacyPrescriptionCatalogOptions({
  required PharmacyRepository repository,
  required String query,
  String? facilityId,
}) async {
  final Result<AppPage<PharmacyDrug>> result = await repository.searchDrugs(
    PharmacyDrugQuery(
      search: query.trim(),
      facilityId: facilityId,
      pageRequest: const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    ),
  );
  return result.when(
    success: (AppPage<PharmacyDrug> page) =>
        Result<List<ClinicalActionCatalogOption>>.success(
          pharmacyDrugsToClinicalCatalogOptions(page.items),
        ),
    failure: (AppFailure failure) =>
        Result<List<ClinicalActionCatalogOption>>.failure(failure),
  );
}

Future<ClinicalRequestPayerContext?> resolvePharmacyPrescriptionPayerContext({
  required InsuranceCatalogRepository repository,
  String? patientId,
}) async {
  final String? id = patientId?.trim();
  if (id == null || id.isEmpty) {
    return null;
  }
  return repository.resolvePayerContextForPatient(id);
}
