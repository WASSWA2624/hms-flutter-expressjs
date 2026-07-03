import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/clinical/data/dtos/clinical_dtos.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final clinicalRepositoryProvider = Provider<ClinicalRepository>((ref) {
  return ClinicalRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class ClinicalRepositoryImpl implements ClinicalRepository {
  const ClinicalRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int _largeCatalogPageSize = 5000;
  static const int _largeRadiologyCatalogPageSize = 6500;
  static const int _defaultCatalogPageSize = 100;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<ClinicalWorklistEntry>>> listEncounters(
    ClinicalWorklistQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<ClinicalWorklistEntry>>(
      ApiEndpoints.collection(HmsApiResource.encounters),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        ..._worklistSearchParameters(query),
        'status': query.scope == ClinicalQueueScope.completed
            ? 'CLOSED'
            : 'OPEN',
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          ClinicalWorklistPageDto.fromEncounterResponse(data, request).page,
    );
  }

  @override
  Future<Result<AppPage<ClinicalWorklistEntry>>> listAdmissions(
    ClinicalWorklistQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<ClinicalWorklistEntry>>(
      ApiEndpoints.collection(HmsApiResource.admissions),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 25,
        'status': query.scope == ClinicalQueueScope.completed
            ? 'DISCHARGED'
            : 'ADMITTED',
        ..._worklistSearchParameters(query),
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          ClinicalWorklistPageDto.fromAdmissionResponse(data, request).page,
    );
  }

  @override
  Future<Result<ClinicalEncounterBundle>> loadEncounterBundle(
    ClinicalWorklistEntry entry,
  ) async {
    final String encounterId = entry.encounterId;
    final List<List<ClinicalRelatedRecord>>
    results = await Future.wait(<Future<List<ClinicalRelatedRecord>>>[
      _relatedListOrEmpty(
        HmsApiResource.clinicalNotes,
        encounterId,
        'clinical_note',
      ),
      _relatedListOrEmpty(HmsApiResource.diagnoses, encounterId, 'diagnosis'),
      _relatedListOrEmpty(HmsApiResource.procedures, encounterId, 'procedure'),
      _relatedListOrEmpty(HmsApiResource.carePlans, encounterId, 'care_plan'),
      _relatedListOrEmpty(HmsApiResource.labOrders, encounterId, 'lab_order'),
      _relatedListOrEmpty(
        HmsApiResource.radiologyOrders,
        encounterId,
        'radiology_order',
      ),
      _relatedListOrEmpty(
        HmsApiResource.pharmacyOrders,
        encounterId,
        'pharmacy_order',
      ),
      _relatedListOrEmpty(HmsApiResource.referrals, encounterId, 'referral'),
      _relatedListOrEmpty(HmsApiResource.followUps, encounterId, 'follow_up'),
      _relatedListOrEmpty(HmsApiResource.admissions, encounterId, 'admission'),
    ]);

    final bundle = ClinicalEncounterBundle(
      entry: entry,
      clinicalNotes: results[0],
      diagnoses: results[1],
      procedures: results[2],
      carePlans: results[3],
      labOrders: results[4],
      radiologyOrders: results[5],
      pharmacyOrders: results[6],
      referrals: results[7],
      followUps: results[8],
      admissions: results[9],
    );

    return Result<ClinicalEncounterBundle>.success(
      bundle.copyWith(
        entry: entry.copyWith(resultsReady: bundle.hasResultsReady),
      ),
    );
  }

  @override
  Future<Result<ClinicalReferenceData>> loadReferenceData() async {
    final results = await Future.wait(<Future<List<ClinicalCatalogOption>>>[
      _catalogOrEmpty(
        HmsApiResource.labTests,
        limit: _largeCatalogPageSize,
        queryParameters: const <String, Object?>{
          'include_standard_catalog': true,
        },
      ),
      _catalogOrEmpty(
        HmsApiResource.labPanels,
        limit: _largeCatalogPageSize,
        queryParameters: const <String, Object?>{
          'include_standard_catalog': true,
        },
      ),
      _catalogOrEmpty(
        HmsApiResource.radiologyTests,
        limit: _largeRadiologyCatalogPageSize,
        queryParameters: const <String, Object?>{
          'include_standard_catalog': true,
        },
      ),
      _catalogOrEmpty(HmsApiResource.drugs),
      _catalogOrEmpty(
        HmsApiResource.beds,
        queryParameters: const <String, Object?>{'status': 'AVAILABLE'},
      ),
      _catalogOrEmpty(HmsApiResource.wards),
      _catalogOrEmpty(HmsApiResource.rooms),
    ]);

    return Result<ClinicalReferenceData>.success(
      ClinicalReferenceData(
        labTests: results[0],
        labPanels: results[1],
        radiologyTests: results[2],
        drugs: results[3],
        availableBeds: results[4],
        wards: results[5],
        rooms: results[6],
      ),
    );
  }

  @override
  Future<Result<List<ClinicalCatalogOption>>> searchClinicalTerms({
    required String termType,
    String? query,
    int limit = 25,
    String source = 'ALL',
  }) {
    return searchClinicalCatalog(
      termType: termType,
      query: query,
      limit: limit,
      source: source,
    );
  }

  @override
  Future<Result<List<ClinicalCatalogOption>>> searchClinicalCatalog({
    required String termType,
    String? query,
    int limit = 80,
    String source = 'ALL',
    bool offeredOnly = false,
  }) {
    return _apiClient.get<List<ClinicalCatalogOption>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.clinicalCatalog.path,
        'search',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'term_type': termType,
        'source': source,
        'q': query,
        'limit': limit.clamp(1, 1000),
        if (offeredOnly) 'offered_only': 'true',
      }),
      decoder: decodeClinicalTermOptions,
    );
  }

  @override
  Future<Result<void>> createClinicalTermFavorite(
    Map<String, Object?> payload,
  ) {
    return _postVoid(HmsApiResource.clinicalTermFavorites, payload);
  }

  @override
  Future<Result<void>> upsertFacilityCatalogOffering(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.clinicalCatalog.path,
        'offerings',
      ]),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<List<Map<String, Object?>>>> listFacilityCatalogOfferings({
    required String facilityId,
    String? termType,
    String? query,
  }) {
    return _apiClient.get<List<Map<String, Object?>>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.clinicalCatalog.path,
        'offerings',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'facility_id': facilityId,
        'term_type': termType,
        'q': query,
        'limit': 1000,
      }),
      decoder: (Object? data) {
        final Object? payload = (data as Map<String, Object?>?)?['data'];
        if (payload is! List) {
          return const <Map<String, Object?>>[];
        }
        return payload.whereType<Map<String, Object?>>().toList(
          growable: false,
        );
      },
    );
  }

  @override
  Future<Result<void>> createClinicalNote(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.clinicalNotes, payload);
  }

  @override
  Future<Result<void>> createDiagnosis(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.diagnoses, payload);
  }

  @override
  Future<Result<void>> createProcedure(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.procedures, payload);
  }

  @override
  Future<Result<void>> createCarePlan(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.carePlans, payload);
  }

  @override
  Future<Result<void>> createLabOrder(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.labOrders, payload);
  }

  @override
  Future<Result<void>> updateLabOrder(
    String labOrderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.labOrders, labOrderId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteLabOrder(String labOrderId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.labOrders, labOrderId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createRadiologyOrder(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.radiologyOrders, payload);
  }

  @override
  Future<Result<void>> updateRadiologyOrder(
    String radiologyOrderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.radiologyOrders, radiologyOrderId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteRadiologyOrder(String radiologyOrderId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.radiologyOrders, radiologyOrderId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createPharmacyOrder(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.pharmacyOrders, payload);
  }

  @override
  Future<Result<void>> updatePharmacyOrder(
    String pharmacyOrderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.pharmacyOrders, pharmacyOrderId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deletePharmacyOrder(String pharmacyOrderId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.pharmacyOrders, pharmacyOrderId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createReferral(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.referrals, payload);
  }

  @override
  Future<Result<void>> createFollowUp(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.followUps, payload);
  }

  @override
  Future<Result<void>> createAdmission(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.admissions, payload);
  }

  @override
  Future<Result<void>> dischargeAdmission(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.admissions,
        admissionId,
        const <String>['discharge'],
      ),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<ClinicalWorklistEntry>> updateEncounter(
    String encounterId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<ClinicalWorklistEntry>(
      ApiEndpoints.byId(HmsApiResource.encounters, encounterId),
      data: _withoutEmpty(payload),
      decoder: decodeEncounter,
    );
  }

  Future<Result<List<ClinicalRelatedRecord>>> _fetchRelatedList(
    HmsApiResource resource,
    String encounterId,
    String kind,
  ) {
    return _apiClient.get<List<ClinicalRelatedRecord>>(
      ApiEndpoints.collection(resource),
      queryParameters: <String, Object?>{
        'encounter_id': encounterId,
        'page': 1,
        'limit': 50,
        'sort_by': 'updated_at',
        'order': 'desc',
      },
      decoder: (Object? data) => decodeRelatedRecords(data, kind),
    );
  }

  Future<List<ClinicalRelatedRecord>> _relatedListOrEmpty(
    HmsApiResource resource,
    String encounterId,
    String kind,
  ) async {
    final Result<List<ClinicalRelatedRecord>> result = await _fetchRelatedList(
      resource,
      encounterId,
      kind,
    );

    return result.when(
      success: (List<ClinicalRelatedRecord> value) => value,
      failure: (_) => const <ClinicalRelatedRecord>[],
    );
  }

  Future<List<ClinicalCatalogOption>> _catalogOrEmpty(
    HmsApiResource resource, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
    int limit = _defaultCatalogPageSize,
  }) async {
    final Result<List<ClinicalCatalogOption>> result = await _apiClient
        .get<List<ClinicalCatalogOption>>(
          ApiEndpoints.collection(resource),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': limit,
            'sort_by': resource == HmsApiResource.beds ? 'label' : 'name',
            'order': 'asc',
            ...queryParameters,
          }),
          decoder: decodeCatalogOptions,
        );

    return result.when(
      success: (List<ClinicalCatalogOption> value) => value,
      failure: (_) => const <ClinicalCatalogOption>[],
    );
  }

  Future<Result<void>> _postVoid(
    HmsApiResource resource,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(resource),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.isEmpty;
    }
    if (value is Map<Object?, Object?>) {
      return value.isEmpty;
    }
    return false;
  }

  Map<String, Object?> _worklistSearchParameters(ClinicalWorklistQuery query) {
    final ClinicalWorklistFilters filters = query.filters;
    return <String, Object?>{
      'search': query.search,
      'patient': filters.patient,
      'patient_id': filters.patientIdentifier,
      'patient_phone': filters.patientPhone,
      'encounter': filters.encounter,
      'queue': filters.queue,
      'provider': filters.providerText,
      'worklist_status': filters.statusText,
      'location': filters.location,
      'source_queue': filters.sourceQueue,
      'stage': filters.status,
      'assigned_provider': filters.provider,
      'updated_from': filters.dateFrom?.toUtc().toIso8601String(),
      'updated_to': filters.dateTo?.toUtc().toIso8601String(),
    };
  }
}
