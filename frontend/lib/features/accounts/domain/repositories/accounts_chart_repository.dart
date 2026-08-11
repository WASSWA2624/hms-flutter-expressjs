import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsChartRepository {
  Future<Result<AppPage<AccountsChartAccount>>> listAccounts(
    AccountsChartQuery query, {
    String? tenantId,
    String? facilityId,
  });

  Future<Result<AccountsChartAccount>> createAccount(
    Map<String, Object?> payload,
  );

  Future<Result<AccountsChartAccount>> updateAccount(
    String id,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deactivateAccount(String id);
}
