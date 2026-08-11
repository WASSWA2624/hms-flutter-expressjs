import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/billing/data/dtos/billing_price_book_dtos.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_price_book_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final billingPriceBookRepositoryProvider =
    Provider<BillingPriceBookRepository>((Ref ref) {
      return BillingPriceBookRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class BillingPriceBookRepositoryImpl
    implements BillingPriceBookRepository {
  const BillingPriceBookRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<BillingPriceBookEntry>>> listEntries(
    BillingPriceBookQuery query, {
    String? tenantId,
    String? facilityId,
  }) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<BillingPriceBookEntry>>(
      ApiEndpoints.collection(HmsApiResource.priceBookEntries),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'tenant_id': tenantId,
        'facility_id': facilityId,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'catalog_type': query.catalogType.trim().isEmpty
            ? null
            : query.catalogType.trim(),
        'payment_mode': query.paymentMode.trim().isEmpty
            ? null
            : query.paymentMode.trim(),
        'billing_entity': query.billingEntity.trim().isEmpty
            ? null
            : query.billingEntity.trim(),
        'coverage_plan_id': query.coveragePlanId.trim().isEmpty
            ? null
            : query.coveragePlanId.trim(),
        if (query.isActive != null) 'is_active': query.isActive! ? 'true' : 'false',
        'sort_by': 'effective_from',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          BillingPriceBookEntryPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<BillingPriceBookEntry>> createEntry(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<BillingPriceBookEntry>(
      ApiEndpoints.collection(HmsApiResource.priceBookEntries),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          BillingPriceBookEntryDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<BillingPriceBookEntry>> updateEntry(
    String id,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<BillingPriceBookEntry>(
      ApiEndpoints.byId(HmsApiResource.priceBookEntries, id),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          BillingPriceBookEntryDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> deactivateEntry(String id) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.priceBookEntries, id),
      data: const <String, Object?>{'is_active': false},
      decoder: (_) {},
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
}
