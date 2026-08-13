import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsFiscalPeriodRepository {
  Future<Result<AppPage<AccountsFiscalPeriod>>> listPeriods(
    AccountsFiscalPeriodQuery query,
  );

  Future<Result<AccountsFiscalPeriod>> getPeriod(String humanFriendlyId);

  Future<Result<AccountsFiscalPeriod>> createPeriod(
    Map<String, Object?> payload,
  );

  Future<Result<AccountsFiscalPeriod>> updatePeriod(
    String humanFriendlyId,
    Map<String, Object?> payload,
  );

  Future<Result<AccountsFiscalPeriod>> applyAction(
    String humanFriendlyId,
    AccountsFiscalPeriodAction action, {
    String? reason,
    int? version,
  });
}
