import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsInvoiceRepository {
  Future<Result<AppPage<AccountsInvoice>>> listInvoices(
    AccountsInvoiceQuery query, {
    String? tenantId,
    String? facilityId,
  });

  Future<Result<AccountsInvoice>> getInvoice(String id);

  Future<Result<AccountsInvoice>> createInvoice(Map<String, Object?> payload);

  Future<Result<AccountsInvoice>> updateInvoice(
    String id,
    Map<String, Object?> payload,
  );

  Future<Result<AccountsInvoice>> voidInvoice(
    String id, {
    required String reason,
    String? notes,
  });
}
