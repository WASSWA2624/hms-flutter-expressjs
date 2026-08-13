import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_fiscal_period_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_fiscal_period_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Canonical section slug shared by the route, the tab, and the API.
const String accountsFiscalPeriodsSectionSlug = 'fiscal-years-and-periods';

final accountsFiscalPeriodRepositoryProvider =
    Provider<AccountsFiscalPeriodRepository>((Ref ref) {
      return AccountsFiscalPeriodRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class AccountsFiscalPeriodRepositoryImpl
    implements AccountsFiscalPeriodRepository {
  const AccountsFiscalPeriodRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static Uri _collection() => ApiEndpoints.apiV1(<String>[
    HmsApiResource.accounts.path,
    accountsFiscalPeriodsSectionSlug,
  ]);

  static Uri _byReference(String humanFriendlyId, [String? action]) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.accounts.path,
      accountsFiscalPeriodsSectionSlug,
      humanFriendlyId,
      ?action,
    ]);
  }

  @override
  Future<Result<AppPage<AccountsFiscalPeriod>>> listPeriods(
    AccountsFiscalPeriodQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsFiscalPeriod>>(
      _collection(),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search.trim(),
        'status': query.statuses
            .map((AccountsFiscalPeriodStatus status) => status.wireValue)
            .join(','),
        'fiscal_year': query.fiscalYear.trim(),
        'module': query.module.trim().toUpperCase(),
        'period_name': query.periodName.trim(),
        'facility_id': query.facilityId.trim(),
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
        'sort_by': query.sortBy,
        'order': query.ascending ? 'asc' : 'desc',
      }),
      decoder: (Object? data) =>
          AccountsFiscalPeriodPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsFiscalPeriod>> getPeriod(String humanFriendlyId) {
    return _apiClient.get<AccountsFiscalPeriod>(
      _byReference(humanFriendlyId),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsFiscalPeriod>> createPeriod(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<AccountsFiscalPeriod>(
      _collection(),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsFiscalPeriod>> updatePeriod(
    String humanFriendlyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<AccountsFiscalPeriod>(
      _byReference(humanFriendlyId),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsFiscalPeriod>> applyAction(
    String humanFriendlyId,
    AccountsFiscalPeriodAction action, {
    String? reason,
    int? version,
  }) {
    return _apiClient.post<AccountsFiscalPeriod>(
      _byReference(humanFriendlyId, action.wireValue),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        'version': version,
      }),
      decoder: _decodeOne,
    );
  }

  static AccountsFiscalPeriod _decodeOne(Object? data) {
    final AccountsFiscalPeriod? entity =
        AccountsFiscalPeriodDto.fromResponse(data).toEntity();
    if (entity == null) {
      throw const FormatException('Fiscal period response is incomplete.');
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
