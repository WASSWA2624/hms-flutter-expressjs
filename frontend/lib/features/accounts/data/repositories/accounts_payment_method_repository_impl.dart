import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_payment_method_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_payment_method_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Canonical section slug shared by the route, the tab, and the API.
const String accountsPaymentMethodsSectionSlug = 'payment-methods';

final accountsPaymentMethodRepositoryProvider =
    Provider<AccountsPaymentMethodRepository>((Ref ref) {
      return AccountsPaymentMethodRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class AccountsPaymentMethodRepositoryImpl
    implements AccountsPaymentMethodRepository {
  const AccountsPaymentMethodRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static Uri _collection() => ApiEndpoints.apiV1(<String>[
    HmsApiResource.accounts.path,
    accountsPaymentMethodsSectionSlug,
  ]);

  static Uri _byReference(String humanFriendlyId, [String? action]) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.accounts.path,
      accountsPaymentMethodsSectionSlug,
      humanFriendlyId,
      ?action,
    ]);
  }

  @override
  Future<Result<AppPage<AccountsPaymentMethod>>> listPaymentMethods(
    AccountsPaymentMethodQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsPaymentMethod>>(
      _collection(),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search.trim(),
        'status': query.statuses
            .map((AccountsPaymentMethodStatus status) => status.wireValue)
            .join(','),
        'method_type': query.methodTypes
            .map((AccountsPaymentMethodType type) => type.wireValue)
            .join(','),
        'direction': query.directions
            .map(
              (AccountsPaymentMethodDirection direction) => direction.wireValue,
            )
            .join(','),
        'method_code': query.methodCode.trim(),
        'method_name': query.methodName.trim(),
        'facility_id': query.facilityId.trim(),
        'settlement_account_id': query.settlementAccountId.trim(),
        'clearing_account_id': query.clearingAccountId.trim(),
        'requires_external_reference': query.requiresExternalReference
            ?.toString(),
        'requires_approval': query.requiresApproval?.toString(),
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
        'sort_by': query.sortBy,
        'order': query.ascending ? 'asc' : 'desc',
      }),
      decoder: (Object? data) =>
          AccountsPaymentMethodPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsPaymentMethod>> getPaymentMethod(
    String humanFriendlyId,
  ) {
    return _apiClient.get<AccountsPaymentMethod>(
      _byReference(humanFriendlyId),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsPaymentMethod>> createPaymentMethod(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<AccountsPaymentMethod>(
      _collection(),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsPaymentMethod>> updatePaymentMethod(
    String humanFriendlyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<AccountsPaymentMethod>(
      _byReference(humanFriendlyId),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsPaymentMethod>> applyAction(
    String humanFriendlyId,
    AccountsPaymentMethodAction action, {
    String? reason,
    int? version,
  }) {
    return _apiClient.post<AccountsPaymentMethod>(
      _byReference(humanFriendlyId, action.wireValue),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        'version': version,
      }),
      decoder: _decodeOne,
    );
  }

  static AccountsPaymentMethod _decodeOne(Object? data) {
    final AccountsPaymentMethod? entity = AccountsPaymentMethodDto.fromResponse(
      data,
    ).toEntity();
    if (entity == null) {
      throw const FormatException('Payment method response is incomplete.');
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
