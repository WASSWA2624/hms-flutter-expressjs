import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/claims/data/dtos/claims_dtos.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final claimsRepositoryProvider = Provider<ClaimsRepository>((ref) {
  return ClaimsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

/// Repository for the insurance and claims workspace.
///
/// Reads route through the backend `claims-workspace` aggregator
/// (`/api/v1/claims-workspace/*`) so the merged pre-authorization + claim
/// worklist, summary counts, lookups, and authorization context are produced
/// server-side. Mutations (request/approve authorization, prepare/submit/
/// reconcile claim) continue to target the dedicated pre-authorization and
/// insurance-claim modules, which own the workflow state and audit trail.
final class ClaimsRepositoryImpl implements ClaimsRepository {
  const ClaimsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<ClaimsQueueItem>>> listQueue(
    ClaimsQueueQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<ClaimsQueueItem>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.claimsWorkspace.path,
        'work-items',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'kind': claimsFilterKind(query.filter),
        'status': claimsFilterStatus(query.filter),
        'search': query.search,
      }),
      decoder: (Object? data) =>
          ClaimsWorkItemsPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<ClaimsWorkspaceSummary>> loadWorkspaceSummary() {
    return _apiClient.get<ClaimsWorkspaceSummary>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.claimsWorkspace.path,
        'workspace',
      ]),
      decoder: (Object? data) =>
          ClaimsWorkspaceSummaryDto.fromResponse(data).summary,
    );
  }

  @override
  Future<Result<ClaimsQueueDetail>> getDetail(ClaimsQueueItem item) async {
    if (item.isAuthorization) {
      return _getAuthorizationDetail(item);
    }

    return _getClaimDetail(item);
  }

  @override
  Future<Result<ClaimsReferenceData>> loadReferenceData() {
    return _apiClient.get<ClaimsReferenceData>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.claimsWorkspace.path,
        'lookups',
      ]),
      decoder: (Object? data) =>
          ClaimsLookupsDto.fromResponse(data).referenceData,
    );
  }

  @override
  Future<Result<PreAuthorizationRecord>> requestPreAuthorization(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<PreAuthorizationRecord>(
      ApiEndpoints.collection(HmsApiResource.preAuthorizations),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          PreAuthorizationDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PreAuthorizationRecord>> updatePreAuthorization(
    String authorizationId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<PreAuthorizationRecord>(
      ApiEndpoints.byId(HmsApiResource.preAuthorizations, authorizationId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          PreAuthorizationDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<InsuranceClaimRecord>> prepareClaim(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<InsuranceClaimRecord>(
      ApiEndpoints.collection(HmsApiResource.insuranceClaims),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          InsuranceClaimDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<InsuranceClaimRecord>> submitClaim(
    String claimId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<InsuranceClaimRecord>(
      ApiEndpoints.nested(HmsApiResource.insuranceClaims, claimId, <String>[
        'submit',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          InsuranceClaimDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<InsuranceClaimRecord>> reconcileClaim(
    String claimId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<InsuranceClaimRecord>(
      ApiEndpoints.nested(HmsApiResource.insuranceClaims, claimId, <String>[
        'reconcile',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          InsuranceClaimDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<PreAuthorizationRecord>>> listPreAuthorizationsForContext({
    String? patientId,
    String? admissionId,
    String? encounterId,
    int limit = 20,
  }) {
    return _apiClient.get<AppPage<PreAuthorizationRecord>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.claimsWorkspace.path,
        'authorizations',
        'context',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': limit,
        'patient_id': patientId,
        'admission_id': admissionId,
        'encounter_id': encounterId,
      }),
      decoder: (Object? data) {
        return PreAuthorizationPageDto.fromResponse(
          data,
          AppPageRequest(pageSize: limit),
        ).page;
      },
    );
  }

  Future<Result<ClaimsQueueDetail>> _getAuthorizationDetail(
    ClaimsQueueItem item,
  ) async {
    final Result<PreAuthorizationRecord> result = await _apiClient
        .get<PreAuthorizationRecord>(
          ApiEndpoints.byId(HmsApiResource.preAuthorizations, item.apiId),
          decoder: (Object? data) =>
              PreAuthorizationDto.fromResponse(data).toEntity(),
        );

    return result.when<Future<Result<ClaimsQueueDetail>>>(
      success: (PreAuthorizationRecord authorization) async {
        final _OptionalCoveragePlan coverage = await _fetchCoveragePlan(
          authorization.coveragePlanDisplayId,
        );
        return Result<ClaimsQueueDetail>.success(
          ClaimsQueueDetail(
            item: ClaimsQueueItem.authorization(authorization),
            authorization: authorization,
            coveragePlan: coverage.value,
            coverageUnavailable: coverage.unavailable,
          ),
        );
      },
      failure: (AppFailure failure) async {
        return Result<ClaimsQueueDetail>.failure(failure);
      },
    );
  }

  Future<Result<ClaimsQueueDetail>> _getClaimDetail(
    ClaimsQueueItem item,
  ) async {
    final Result<InsuranceClaimRecord> result = await _apiClient
        .get<InsuranceClaimRecord>(
          ApiEndpoints.byId(HmsApiResource.insuranceClaims, item.apiId),
          decoder: (Object? data) =>
              InsuranceClaimDto.fromResponse(data).toEntity(),
        );

    return result.when<Future<Result<ClaimsQueueDetail>>>(
      success: (InsuranceClaimRecord claim) async {
        final _OptionalCoveragePlan coverage = await _fetchCoveragePlan(
          claim.coveragePlanDisplayId,
        );
        final _OptionalInvoice invoice = await _fetchInvoice(
          claim.invoiceDisplayId,
        );
        return Result<ClaimsQueueDetail>.success(
          ClaimsQueueDetail(
            item: ClaimsQueueItem.claim(claim),
            claim: claim,
            coveragePlan: coverage.value,
            invoice: invoice.value,
            coverageUnavailable: coverage.unavailable,
            invoiceUnavailable: invoice.unavailable,
          ),
        );
      },
      failure: (AppFailure failure) async {
        return Result<ClaimsQueueDetail>.failure(failure);
      },
    );
  }

  Future<_OptionalCoveragePlan> _fetchCoveragePlan(String id) async {
    if (id.trim().isEmpty) {
      return const _OptionalCoveragePlan();
    }

    final Result<CoveragePlanOption> result = await _apiClient
        .get<CoveragePlanOption>(
          ApiEndpoints.byId(HmsApiResource.coveragePlans, id),
          decoder: (Object? data) =>
              CoveragePlanDto.fromResponse(data).toEntity(),
        );

    return result.when(
      success: (CoveragePlanOption value) =>
          _OptionalCoveragePlan(value: value),
      failure: (_) => const _OptionalCoveragePlan(unavailable: true),
    );
  }

  Future<_OptionalInvoice> _fetchInvoice(String id) async {
    if (id.trim().isEmpty) {
      return const _OptionalInvoice();
    }

    final Result<ClaimInvoiceOption> result = await _apiClient
        .get<ClaimInvoiceOption>(
          ApiEndpoints.byId(HmsApiResource.invoices, id),
          decoder: (Object? data) =>
              ClaimInvoiceDto.fromResponse(data).toEntity(),
        );

    return result.when(
      success: (ClaimInvoiceOption value) => _OptionalInvoice(value: value),
      failure: (_) => const _OptionalInvoice(unavailable: true),
    );
  }
}

final class _OptionalCoveragePlan {
  const _OptionalCoveragePlan({this.value, this.unavailable = false});

  final CoveragePlanOption? value;
  final bool unavailable;
}

final class _OptionalInvoice {
  const _OptionalInvoice({this.value, this.unavailable = false});

  final ClaimInvoiceOption? value;
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
