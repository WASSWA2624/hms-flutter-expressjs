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

final class ClaimsRepositoryImpl implements ClaimsRepository {
  const ClaimsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<ClaimsQueueItem>>> listQueue(
    ClaimsQueueQuery query,
  ) async {
    final List<ClaimsQueueItem> items = <ClaimsQueueItem>[];
    int? total = 0;

    if (filterIncludesAuthorizations(query.filter)) {
      final Result<AppPage<PreAuthorizationRecord>> result =
          await _listPreAuthorizations(query);
      final AppFailure? failure = result.when(
        success: (AppPage<PreAuthorizationRecord> page) {
          items.addAll(page.items.map(ClaimsQueueItem.authorization));
          total = _sumTotals(total, page.totalItemCount);
          return null;
        },
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return Result<AppPage<ClaimsQueueItem>>.failure(failure);
      }
    }

    if (filterIncludesClaims(query.filter)) {
      final Result<AppPage<InsuranceClaimRecord>> result = await _listClaims(
        query,
      );
      final AppFailure? failure = result.when(
        success: (AppPage<InsuranceClaimRecord> page) {
          items.addAll(page.items.map(ClaimsQueueItem.claim));
          total = _sumTotals(total, page.totalItemCount);
          return null;
        },
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return Result<AppPage<ClaimsQueueItem>>.failure(failure);
      }
    }

    final List<ClaimsQueueItem> visibleItems =
        items
            .where(
              (ClaimsQueueItem item) => matchesClaimsSearch(item, query.search),
            )
            .toList(growable: false)
          ..sort(_compareQueueItems);
    final bool isSearching = query.search.trim().isNotEmpty;

    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: visibleItems,
        request: query.pageRequest,
        totalItemCount: isSearching ? visibleItems.length : total,
      ),
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
  Future<Result<ClaimsReferenceData>> loadReferenceData() async {
    final AppPageRequest request = const AppPageRequest(pageSize: 50);
    final Result<AppPage<CoveragePlanOption>> coverageResult = await _apiClient
        .get<AppPage<CoveragePlanOption>>(
          ApiEndpoints.collection(HmsApiResource.coveragePlans),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': request.pageSize,
            'sort_by': 'name',
            'order': 'asc',
          }),
          decoder: (Object? data) =>
              CoveragePlanPageDto.fromResponse(data, request).page,
        );
    final Result<AppPage<ClaimInvoiceOption>> invoiceResult = await _apiClient
        .get<AppPage<ClaimInvoiceOption>>(
          ApiEndpoints.collection(HmsApiResource.invoices),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': request.pageSize,
            'sort_by': 'issued_at',
            'order': 'desc',
          }),
          decoder: (Object? data) =>
              ClaimInvoicePageDto.fromResponse(data, request).page,
        );

    return Result<ClaimsReferenceData>.success(
      ClaimsReferenceData(
        coveragePlans: coverageResult.when(
          success: (AppPage<CoveragePlanOption> page) => page.items,
          failure: (_) => const <CoveragePlanOption>[],
        ),
        invoices: invoiceResult.when(
          success: (AppPage<ClaimInvoiceOption> page) => page.items,
          failure: (_) => const <ClaimInvoiceOption>[],
        ),
        coverageUnavailable: coverageResult.isFailure,
        invoicesUnavailable: invoiceResult.isFailure,
      ),
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

  Future<Result<AppPage<PreAuthorizationRecord>>> _listPreAuthorizations(
    ClaimsQueueQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<PreAuthorizationRecord>>(
      ApiEndpoints.collection(HmsApiResource.preAuthorizations),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'status': preAuthorizationStatusForFilter(query.filter),
        'sort_by': 'requested_at',
        'order': 'desc',
      }),
      decoder: (Object? data) {
        return PreAuthorizationPageDto.fromResponse(data, request).page;
      },
    );
  }

  Future<Result<AppPage<InsuranceClaimRecord>>> _listClaims(
    ClaimsQueueQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<InsuranceClaimRecord>>(
      ApiEndpoints.collection(HmsApiResource.insuranceClaims),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'status': insuranceClaimStatusForFilter(query.filter),
        'sort_by': 'submitted_at',
        'order': 'desc',
      }),
      decoder: (Object? data) {
        return InsuranceClaimPageDto.fromResponse(data, request).page;
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
      success: (CoveragePlanOption value) => _OptionalCoveragePlan(value),
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
      success: (ClaimInvoiceOption value) => _OptionalInvoice(value),
      failure: (_) => const _OptionalInvoice(unavailable: true),
    );
  }
}

final class _OptionalCoveragePlan {
  const _OptionalCoveragePlan([this.value, this.unavailable = false]);

  final CoveragePlanOption? value;
  final bool unavailable;
}

final class _OptionalInvoice {
  const _OptionalInvoice([this.value, this.unavailable = false]);

  final ClaimInvoiceOption? value;
  final bool unavailable;
}

int? _sumTotals(int? left, int? right) {
  if (left == null || right == null) {
    return null;
  }
  return left + right;
}

int _compareQueueItems(ClaimsQueueItem left, ClaimsQueueItem right) {
  final DateTime leftDate =
      left.timelineAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final DateTime rightDate =
      right.timelineAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return rightDate.compareTo(leftDate);
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
