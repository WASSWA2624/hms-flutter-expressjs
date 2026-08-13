import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_currency_rate_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_currency_rate.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_currency_rate_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Canonical section slug shared by the route, the tab, and the API.
const String accountsCurrencyRatesSectionSlug = 'currencies-and-exchange-rates';

final accountsCurrencyRateRepositoryProvider =
    Provider<AccountsCurrencyRateRepository>((Ref ref) {
      return AccountsCurrencyRateRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class AccountsCurrencyRateRepositoryImpl
    implements AccountsCurrencyRateRepository {
  const AccountsCurrencyRateRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static Uri _collection() => ApiEndpoints.apiV1(<String>[
    HmsApiResource.accounts.path,
    accountsCurrencyRatesSectionSlug,
  ]);

  static Uri _byReference(String humanFriendlyId, [String? action]) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.accounts.path,
      accountsCurrencyRatesSectionSlug,
      humanFriendlyId,
      ?action,
    ]);
  }

  @override
  Future<Result<AppPage<AccountsCurrencyRate>>> listRates(
    AccountsCurrencyRateQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsCurrencyRate>>(
      _collection(),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search.trim(),
        'status': query.statuses
            .map((AccountsCurrencyStatus status) => status.wireValue)
            .join(','),
        'currency_code': query.currencyCode.trim().toUpperCase(),
        'rate_type': query.rateTypes
            .map((AccountsCurrencyRateType type) => type.wireValue)
            .join(','),
        'base_currency': query.baseCurrencyOnly?.toString(),
        'source': query.source.trim(),
        'facility_id': query.facilityId.trim(),
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
        'sort_by': query.sortBy,
        'order': query.ascending ? 'asc' : 'desc',
      }),
      decoder: (Object? data) =>
          AccountsCurrencyRatePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsCurrencyRate>> getRate(String humanFriendlyId) {
    return _apiClient.get<AccountsCurrencyRate>(
      _byReference(humanFriendlyId),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsCurrencyRate>> createRate(
    Map<String, Object?> payload, {
    String? idempotencyKey,
  }) {
    return _apiClient.post<AccountsCurrencyRate>(
      _collection(),
      data: _withoutEmpty(payload),
      options: _idempotent(idempotencyKey),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsCurrencyRate>> updateRate(
    String humanFriendlyId,
    Map<String, Object?> payload, {
    String? idempotencyKey,
  }) {
    return _apiClient.put<AccountsCurrencyRate>(
      _byReference(humanFriendlyId),
      data: _withoutEmpty(payload),
      options: _idempotent(idempotencyKey),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsCurrencyRate>> applyAction(
    String humanFriendlyId,
    AccountsCurrencyRateAction action, {
    String? reason,
    int? version,
    String? idempotencyKey,
  }) {
    return _apiClient.post<AccountsCurrencyRate>(
      _byReference(humanFriendlyId, action.wireValue),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        'version': version,
      }),
      options: _idempotent(idempotencyKey),
      decoder: _decodeOne,
    );
  }

  static Options? _idempotent(String? key) {
    final String trimmed = (key ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return idempotentRequestOptions(idempotencyKey: trimmed);
  }

  static AccountsCurrencyRate _decodeOne(Object? data) {
    final AccountsCurrencyRate? entity =
        AccountsCurrencyRateDto.fromResponse(data).toEntity();
    if (entity == null) {
      throw const FormatException('Currency rate response is incomplete.');
    }
    return entity;
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
