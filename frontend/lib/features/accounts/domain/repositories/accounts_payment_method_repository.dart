import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsPaymentMethodRepository {
  Future<Result<AppPage<AccountsPaymentMethod>>> listPaymentMethods(
    AccountsPaymentMethodQuery query,
  );

  Future<Result<AccountsPaymentMethod>> getPaymentMethod(
    String humanFriendlyId,
  );

  Future<Result<AccountsPaymentMethod>> createPaymentMethod(
    Map<String, Object?> payload,
  );

  Future<Result<AccountsPaymentMethod>> updatePaymentMethod(
    String humanFriendlyId,
    Map<String, Object?> payload,
  );

  Future<Result<AccountsPaymentMethod>> applyAction(
    String humanFriendlyId,
    AccountsPaymentMethodAction action, {
    String? reason,
    int? version,
  });
}
