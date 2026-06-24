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

  Future<Result<BillingMutationResult>> issueInvoice(
    String invoiceId, {
    String? notes,
  });

  Future<Result<BillingMutationResult>> sendInvoice(
    String invoiceId, {
    String? recipientEmail,
  });

  Future<Result<BillingMutationResult>> receivePayment(
    BillingWorkItem invoice,
    BillingPaymentDraft draft,
  );

  Future<Result<BillingMutationResult>> requestRefund(BillingRefundDraft draft);

  Future<Result<BillingMutationResult>> requestAdjustment(
    BillingWorkItem invoice,
    BillingAdjustmentDraft draft,
  );

  Future<Result<BillingMutationResult>> requestInvoiceVoid(
    BillingWorkItem invoice, {
    required String reason,
    String? notes,
  });

  Future<Result<void>> closeShift(BillingCloseDraft draft);

  Future<Result<void>> closeDay(BillingCloseDraft draft);

  Future<Result<BillingPatientLedger>> getPatientLedger(
    String patientIdentifier,
    BillingLedgerQuery query,
  );

  Future<Result<BillingMutationResult>> approveApproval(
    String approvalId,
    BillingApprovalDecisionDraft draft,
  );

  Future<Result<BillingMutationResult>> rejectApproval(
    String approvalId,
    BillingApprovalDecisionDraft draft,
  );

  Future<Result<BillingInvoiceDocument>> getInvoiceDocument(String invoiceId);

  Future<Result<BillingMutationResult>> submitClaim(
    String claimId,
    BillingClaimActionDraft draft,
  );

  Future<Result<BillingMutationResult>> reconcileClaim(
    String claimId,
    BillingClaimActionDraft draft,
  );

  Future<Result<BillingMutationResult>> updatePreAuthorization(
    String preAuthorizationId,
    Map<String, Object?> payload,
  );
}
