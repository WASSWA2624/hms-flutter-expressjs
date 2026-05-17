import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/discharge/data/dtos/discharge_dtos.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/ipd/data/dtos/ipd_dtos.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final dischargeRepositoryProvider = Provider<DischargeRepository>((ref) {
  return DischargeRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class DischargeRepositoryImpl implements DischargeRepository {
  const DischargeRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<IpdAdmissionSummary>>> listQueue(
    DischargeWorklistQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    final String? stage = serverStageForDischargeStatus(query.status);
    return _apiClient.get<AppPage<IpdAdmissionSummary>>(
      ApiEndpoints.collection(HmsApiResource.ipdFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'queue_scope': 'ALL',
        'stage': stage,
        'sort_by': 'admitted_at',
        'order': 'desc',
      }),
      decoder: (Object? data) {
        final AppPage<IpdAdmissionSummary> page =
            IpdAdmissionPageDto.fromResponse(data, request).page;
        final List<IpdAdmissionSummary> filtered = page.items
            .where(
              (IpdAdmissionSummary item) =>
                  matchesDischargeStatus(item, query.status),
            )
            .toList(growable: false);

        return AppPage<IpdAdmissionSummary>(
          items: filtered,
          request: page.request,
          totalItemCount:
              stage == null && query.status != DischargeStatusFilter.all
              ? filtered.length
              : page.totalItemCount,
        );
      },
    );
  }

  @override
  Future<Result<DischargeAdmissionDetail>> getAdmissionDetail(
    String admissionId,
  ) async {
    final Result<Object?> detailResult = await _apiClient.get<Object?>(
      ApiEndpoints.byId(
        HmsApiResource.ipdFlows,
        admissionId,
        queryParameters: const <String, String>{'include_icu': 'false'},
      ),
      decoder: (Object? data) => data,
    );

    return detailResult.when<Future<Result<DischargeAdmissionDetail>>>(
      success: (Object? responseData) async {
        final DischargeAdmissionDetail base = DischargeAdmissionDetailDto(
          responseData: responseData,
        ).toEntity();
        final _OptionalRelatedRecords pharmacy = await _fetchPharmacyOrders(
          encounterId: base.encounterId,
          patientId: base.patientId,
        );
        final _OptionalRelatedRecords invoices = await _fetchInvoices(
          patientId: base.patientId,
        );

        return Result<DischargeAdmissionDetail>.success(
          base.copyWith(
            pharmacyOrders: pharmacy.items,
            invoices: invoices.items,
            pharmacyDataUnavailable: pharmacy.unavailable,
            billingDataUnavailable: invoices.unavailable,
          ),
        );
      },
      failure: (failure) async {
        return Result<DischargeAdmissionDetail>.failure(failure);
      },
    );
  }

  @override
  Future<Result<DischargeReferenceData>> loadReferenceData() async {
    final Result<List<DischargeDrugOption>> drugsResult = await _apiClient
        .get<List<DischargeDrugOption>>(
          ApiEndpoints.collection(HmsApiResource.drugs),
          queryParameters: const <String, Object?>{
            'page': 1,
            'limit': 50,
            'sort_by': 'name',
            'order': 'asc',
          },
          decoder: decodeDischargeDrugOptions,
        );

    return Result<DischargeReferenceData>.success(
      DischargeReferenceData(
        drugs: drugsResult.when(
          success: (List<DischargeDrugOption> value) => value,
          failure: (_) => const <DischargeDrugOption>[],
        ),
      ),
    );
  }

  @override
  Future<Result<void>> planDischarge(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(HmsApiResource.ipdFlows, admissionId, <String>[
        'plan-discharge',
      ]),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> finalizeDischarge(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(HmsApiResource.ipdFlows, admissionId, <String>[
        'finalize-discharge',
      ]),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createFinalInvoice(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.invoices),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createPharmacyOrder(Map<String, Object?> payload) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.pharmacyOrders),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  Future<_OptionalRelatedRecords> _fetchPharmacyOrders({
    required String? encounterId,
    required String? patientId,
  }) async {
    if ((encounterId == null || encounterId.isEmpty) &&
        (patientId == null || patientId.isEmpty)) {
      return const _OptionalRelatedRecords();
    }

    final Result<List<DischargeRelatedRecord>> result = await _apiClient
        .get<List<DischargeRelatedRecord>>(
          ApiEndpoints.collection(HmsApiResource.pharmacyOrders),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 20,
            'encounter_id': encounterId,
            if (encounterId == null || encounterId.isEmpty)
              'patient_id': patientId,
            'sort_by': 'ordered_at',
            'order': 'desc',
          }),
          decoder: decodeDischargePharmacyOrders,
        );

    return result.when(
      success: (List<DischargeRelatedRecord> value) {
        return _OptionalRelatedRecords(items: value);
      },
      failure: (_) => const _OptionalRelatedRecords(unavailable: true),
    );
  }

  Future<_OptionalRelatedRecords> _fetchInvoices({
    required String? patientId,
  }) async {
    if (patientId == null || patientId.isEmpty) {
      return const _OptionalRelatedRecords();
    }

    final Result<List<DischargeRelatedRecord>> result = await _apiClient
        .get<List<DischargeRelatedRecord>>(
          ApiEndpoints.collection(HmsApiResource.invoices),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 20,
            'patient_id': patientId,
            'sort_by': 'issued_at',
            'order': 'desc',
          }),
          decoder: decodeDischargeInvoices,
        );

    return result.when(
      success: (List<DischargeRelatedRecord> value) {
        return _OptionalRelatedRecords(items: value);
      },
      failure: (_) => const _OptionalRelatedRecords(unavailable: true),
    );
  }
}

final class _OptionalRelatedRecords {
  const _OptionalRelatedRecords({
    this.items = const <DischargeRelatedRecord>[],
    this.unavailable = false,
  });

  final List<DischargeRelatedRecord> items;
  final bool unavailable;
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}
