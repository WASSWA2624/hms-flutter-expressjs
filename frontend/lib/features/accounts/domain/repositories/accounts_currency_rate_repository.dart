import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_currency_rate.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsCurrencyRateRepository {
  Future<Result<AppPage<AccountsCurrencyRate>>> listRates(
    AccountsCurrencyRateQuery query,
  );

  Future<Result<AccountsCurrencyRate>> getRate(String humanFriendlyId);

  /// [idempotencyKey] must be reused across retries of one logical submit so
  /// the backend replays the first response instead of writing a duplicate.
  Future<Result<AccountsCurrencyRate>> createRate(
    Map<String, Object?> payload, {
    String? idempotencyKey,
  });

  Future<Result<AccountsCurrencyRate>> updateRate(
    String humanFriendlyId,
    Map<String, Object?> payload, {
    String? idempotencyKey,
  });

  Future<Result<AccountsCurrencyRate>> applyAction(
    String humanFriendlyId,
    AccountsCurrencyRateAction action, {
    String? reason,
    int? version,
    String? idempotencyKey,
  });
}
