import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class BillingPriceBookRepository {
  Future<Result<AppPage<BillingPriceBookEntry>>> listEntries(
    BillingPriceBookQuery query, {
    String? tenantId,
    String? facilityId,
  });

  Future<Result<BillingPriceBookEntry>> createEntry(
    Map<String, Object?> payload,
  );

  Future<Result<BillingPriceBookEntry>> updateEntry(
    String id,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deactivateEntry(String id);
}
