import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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
        'search': query.search,
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
    final List<Result<List<ClinicalRelatedRecord>>> results =
        await Future.wait(<Future<Result<List<ClinicalRelatedRecord>>>>[
          _fetchRelatedList(HmsApiResource.clinicalNotes, encounterId, 'clinical_note'),
          _fetchRelatedList(HmsApiResource.diagnoses, encounterId, 'diagnosis'),
          _fetchRelatedList(HmsApiResource.procedures, encounterId, 'procedure'),
          _fetchRelatedList(HmsApiResource.carePlans, encounterId, 'care_plan'),
          _fetchRelatedList(HmsApiResource.labOrders, encounterId, 'lab_order'),
          _fetchRelatedList(
            HmsApiResource.radiologyOrders,
            encounterId,
            'radiology_order',
          ),
          _fetchRelatedList(
            HmsApiResource.pharmacyOrders,
            encounterId,
            'pharmacy_order',
          ),
          _fetchRelatedList(HmsApiResource.referrals, encounterId, 'referral'),
          _fetchRelatedList(HmsApiResource.followUps, encounterId, 'follow_up'),
          _fetchRelatedList(HmsApiResource.admissions, encounterId, 'admission'),
        ]);

    final AppFailure? failure = _firstFailure(results);
    if (failure != null) {
      return Result<ClinicalEncounterBundle>.failure(failure);
    }

    final bundle = ClinicalEncounterBundle(
      entry: entry,
      clinicalNotes: _successValue(results[0]),
      diagnoses: _successValue(results[1]),
      procedures: _successValue(results[2]),
      carePlans: _successValue(results[3]),
      labOrders: _successValue(results[4]),
      radiologyOrders: _successValue(results[5]),
      pharmacyOrders: _successValue(results[6]),
      referrals: _successValue(results[7]),
      followUps: _successValue(results[8]),
      admissions: _successValue(results[9]),
    );

    return Result<ClinicalEncounterBundle>.success(
      bundle.copyWith(entry: entry.copyWith(resultsReady: bundle.hasResultsReady)),
    );
  }

  @override
  Future<Result<ClinicalReferenceData>> loadReferenceData() async {
    final results = await Future.wait(<Future<List<ClinicalCatalogOption>>>[
      _catalogOrEmpty(HmsApiResource.labTests),
      _catalogOrEmpty(HmsApiResource.labPanels),
      _catalogOrEmpty(HmsApiResource.radiologyTests),
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
  }) {
    return _apiClient.get<List<ClinicalCatalogOption>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.clinicalTerms.path,
        'suggestions',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'term_type': termType,
        'q': query,
        'limit': 20,
      }),
      decoder: decodeClinicalTermOptions,
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
  Future<Result<void>> createRadiologyOrder(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.radiologyOrders, payload);
  }

  @override
  Future<Result<void>> createPharmacyOrder(Map<String, Object?> payload) {
    return _postVoid(HmsApiResource.pharmacyOrders, payload);
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

  Future<List<ClinicalCatalogOption>> _catalogOrEmpty(
    HmsApiResource resource, {
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) async {
    final Result<List<ClinicalCatalogOption>> result =
        await _apiClient.get<List<ClinicalCatalogOption>>(
          ApiEndpoints.collection(resource),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 100,
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

  AppFailure? _firstFailure<T>(List<Result<T>> results) {
    for (final Result<T> result in results) {
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return failure;
      }
    }
    return null;
  }

  T _successValue<T>(Result<T> result) {
    return result.when(
      success: (T value) => value,
      failure: (_) => throw StateError('Expected successful result.'),
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
}
