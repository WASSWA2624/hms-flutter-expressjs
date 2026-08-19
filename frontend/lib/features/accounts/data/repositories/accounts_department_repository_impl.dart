import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_department_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_department_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Canonical section slug shared by the route, the tab, and the API.
const String accountsDepartmentsSectionSlug = 'departments-and-cost-centres';

final accountsDepartmentRepositoryProvider =
    Provider<AccountsDepartmentRepository>((Ref ref) {
      return AccountsDepartmentRepositoryImpl(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final class AccountsDepartmentRepositoryImpl
    implements AccountsDepartmentRepository {
  const AccountsDepartmentRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static Uri _collection() => ApiEndpoints.apiV1(<String>[
    HmsApiResource.accounts.path,
    accountsDepartmentsSectionSlug,
  ]);

  static Uri _byReference(String humanFriendlyId, [String? action]) {
    return ApiEndpoints.apiV1(<String>[
      HmsApiResource.accounts.path,
      accountsDepartmentsSectionSlug,
      humanFriendlyId,
      ?action,
    ]);
  }

  @override
  Future<Result<AppPage<AccountsDepartment>>> listDepartments(
    AccountsDepartmentQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsDepartment>>(
      _collection(),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search.trim(),
        'status': query.statuses
            .map((AccountsDepartmentStatus status) => status.wireValue)
            .join(','),
        'department_code': query.departmentCode.trim(),
        'department_name': query.departmentName.trim(),
        'cost_centre_code': query.costCentreCodes.join(','),
        'cost_centre_name': query.costCentreName.trim(),
        'facility_id': query.facilityId.trim(),
        'owner_id': query.ownerId.trim(),
        'default_revenue_account_id': query.revenueAccountId.trim(),
        'default_expense_account_id': query.expenseAccountId.trim(),
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
        'sort_by': query.sortBy,
        'order': query.ascending ? 'asc' : 'desc',
      }),
      decoder: (Object? data) =>
          AccountsDepartmentPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsDepartment>> getDepartment(String humanFriendlyId) {
    return _apiClient.get<AccountsDepartment>(
      _byReference(humanFriendlyId),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsDepartment>> createDepartment(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<AccountsDepartment>(
      _collection(),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsDepartment>> updateDepartment(
    String humanFriendlyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<AccountsDepartment>(
      _byReference(humanFriendlyId),
      data: _withoutEmpty(payload),
      decoder: _decodeOne,
    );
  }

  @override
  Future<Result<AccountsDepartment>> applyAction(
    String humanFriendlyId,
    AccountsDepartmentAction action, {
    String? reason,
    int? version,
  }) {
    return _apiClient.post<AccountsDepartment>(
      _byReference(humanFriendlyId, action.wireValue),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        'version': version,
      }),
      decoder: _decodeOne,
    );
  }

  static AccountsDepartment _decodeOne(Object? data) {
    final AccountsDepartment? entity = AccountsDepartmentDto.fromResponse(
      data,
    ).toEntity();
    if (entity == null) {
      throw const FormatException('Department response is incomplete.');
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
