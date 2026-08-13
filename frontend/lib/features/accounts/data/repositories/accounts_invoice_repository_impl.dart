import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_invoice_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_invoice_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final accountsInvoiceRepositoryProvider = Provider<AccountsInvoiceRepository>((
  Ref ref,
) {
  return AccountsInvoiceRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class AccountsInvoiceRepositoryImpl implements AccountsInvoiceRepository {
  const AccountsInvoiceRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<AccountsInvoice>>> listInvoices(
    AccountsInvoiceQuery query, {
    String? tenantId,
    String? facilityId,
  }) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsInvoice>>(
      ApiEndpoints.collection(HmsApiResource.accountsInvoices),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'tenant_id': tenantId,
        'facility_id': facilityId,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'status': query.status.trim().isEmpty
            ? null
            : query.status.trim().toUpperCase(),
        'date_from': query.dateFrom?.toUtc().toIso8601String(),
        'date_to': query.dateTo?.toUtc().toIso8601String(),
      }),
      decoder: (Object? data) =>
          AccountsInvoicePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsInvoice>> getInvoice(String id) {
    return _apiClient.get<AccountsInvoice>(
      ApiEndpoints.byId(HmsApiResource.accountsInvoices, id),
      decoder: (Object? data) =>
          AccountsInvoiceDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AccountsInvoice>> createInvoice(Map<String, Object?> payload) {
    return _apiClient.post<AccountsInvoice>(
      ApiEndpoints.collection(HmsApiResource.accountsInvoices),
      data: _jsonSafeMap(_withoutEmpty(payload)),
      decoder: (Object? data) =>
          AccountsInvoiceDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AccountsInvoice>> updateInvoice(
    String id,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<AccountsInvoice>(
      ApiEndpoints.byId(HmsApiResource.accountsInvoices, id),
      data: _jsonSafeMap(_withoutEmpty(payload)),
      decoder: (Object? data) =>
          AccountsInvoiceDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AccountsInvoice>> voidInvoice(
    String id, {
    required String reason,
    String? notes,
  }) {
    return _apiClient.post<AccountsInvoice>(
      ApiEndpoints.nested(HmsApiResource.accountsInvoices, id, const <String>[
        'void',
      ]),
      data: _withoutEmpty(<String, Object?>{'reason': reason, 'notes': notes}),
      decoder: (Object? data) =>
          AccountsInvoiceDto.fromResponse(data).toEntity(),
    );
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> source) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in source.entries)
        if (entry.value != null &&
            !(entry.value is String && (entry.value! as String).trim().isEmpty))
          entry.key: entry.value,
    };
  }

  Map<String, dynamic> _jsonSafeMap(Map<String, Object?> source) {
    return <String, dynamic>{
      for (final MapEntry<String, Object?> entry in source.entries)
        entry.key: _jsonSafeValue(entry.value),
    };
  }

  Object? _jsonSafeValue(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): _jsonSafeValue(entry.value),
      };
    }
    if (value is Iterable && value is! String) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }
    return value;
  }
}
