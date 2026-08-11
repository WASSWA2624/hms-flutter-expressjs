import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_chart_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_chart_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final accountsChartRepositoryProvider = Provider<AccountsChartRepository>((
  Ref ref,
) {
  return AccountsChartRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class AccountsChartRepositoryImpl implements AccountsChartRepository {
  const AccountsChartRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<AccountsChartAccount>>> listAccounts(
    AccountsChartQuery query, {
    String? tenantId,
    String? facilityId,
  }) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsChartAccount>>(
      ApiEndpoints.collection(HmsApiResource.chartAccounts),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'tenant_id': tenantId,
        'facility_id': facilityId,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'account_type': query.accountType.trim().isEmpty
            ? null
            : query.accountType.trim(),
        'parent_id': query.parentId.trim().isEmpty ? null : query.parentId.trim(),
        'currency': query.currency.trim().isEmpty
            ? null
            : query.currency.trim().toUpperCase(),
        if (query.isActive != null)
          'is_active': query.isActive! ? 'true' : 'false',
        'sort_by': 'code',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          AccountsChartAccountPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsChartAccount>> createAccount(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<AccountsChartAccount>(
      ApiEndpoints.collection(HmsApiResource.chartAccounts),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          AccountsChartAccountDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AccountsChartAccount>> updateAccount(
    String id,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<AccountsChartAccount>(
      ApiEndpoints.byId(HmsApiResource.chartAccounts, id),
      data: _withoutEmpty(payload),
      decoder: (Object? data) =>
          AccountsChartAccountDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> deactivateAccount(String id) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.chartAccounts, id),
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
