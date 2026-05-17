import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class BillingRepository {
  Future<Result<BillingWorkspaceOverview>> getWorkspace(
    BillingWorkspaceQuery query,
  );

  Future<Result<AppPage<BillingWorkItem>>> listWorkItems(
    BillingWorkspaceQuery query,
  );

  Future<Result<void>> issueInvoice(String invoiceId, {String? notes});

  Future<Result<void>> sendInvoice(String invoiceId, {String? recipientEmail});

  Future<Result<void>> receivePayment(
    BillingWorkItem invoice,
    BillingPaymentDraft draft,
  );

  Future<Result<void>> requestRefund(BillingRefundDraft draft);

  Future<Result<void>> requestAdjustment(
    BillingWorkItem invoice,
    BillingAdjustmentDraft draft,
  );

  Future<Result<void>> requestInvoiceVoid(
    BillingWorkItem invoice, {
    required String reason,
    String? notes,
  });

  Future<Result<void>> closeShift(BillingCloseDraft draft);

  Future<Result<void>> closeDay(BillingCloseDraft draft);
}
