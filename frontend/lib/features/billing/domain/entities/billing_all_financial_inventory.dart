import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing workspace **All** tab scan.
enum BillingAllActionClass {
  /// Invoice line creation / issue (draft → issued).
  createCharge,

  /// Receive payment, shift/day close, claim settlement applying balance.
  settle,

  /// Discount, waive, write-off, credit note, approval holds.
  adjust,

  /// Refund, void, payment reversal.
  reverse,

  /// Claims / pre-auth handoff with outstanding deferred in Billing.
  defer,

  /// Read chrome, navigation, print/export, audited no-charge.
  notBillable,
}

/// One financially relevant atom on the All tab (`?queue=all` or default).
final class BillingAllFinancialAtom {
  const BillingAllFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final BillingAllActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared [BillingRepository] method — null when read-only / navigation.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of All-tab financially relevant atoms (AC1).
///
/// Mutations post through [BillingRepository] / backend billing module only;
/// no parallel ledgers on this tab.
abstract final class BillingAllFinancialInventory {
  static const BillingAllFinancialAtom tab = BillingAllFinancialAtom(
    id: 'tab',
    label: 'All billing work items tab',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.tab,
  );

  static const BillingAllFinancialAtom listChrome = BillingAllFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.listChrome,
  );

  static const BillingAllFinancialAtom detail = BillingAllFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.detail,
  );

  static const BillingAllFinancialAtom closeShift = BillingAllFinancialAtom(
    id: 'close_shift',
    label: 'Close shift',
    actionClass: BillingAllActionClass.settle,
    requirement: BillingAllAtomPermissions.close,
    repositoryMethod: 'closeShift',
    auditNote: 'Reconciles Billing payments for shift',
  );

  static const BillingAllFinancialAtom closeDay = BillingAllFinancialAtom(
    id: 'close_day',
    label: 'Close day',
    actionClass: BillingAllActionClass.settle,
    requirement: BillingAllAtomPermissions.close,
    repositoryMethod: 'closeDay',
    auditNote: 'Day close against Billing ledger',
  );

  static const BillingAllFinancialAtom issue = BillingAllFinancialAtom(
    id: 'issue',
    label: 'Issue invoice',
    actionClass: BillingAllActionClass.createCharge,
    requirement: BillingAllAtomPermissions.issue,
    repositoryMethod: 'issueInvoice',
  );

  static const BillingAllFinancialAtom receivePayment = BillingAllFinancialAtom(
    id: 'receive_payment',
    label: 'Receive payment',
    actionClass: BillingAllActionClass.settle,
    requirement: BillingAllAtomPermissions.receivePayment,
    repositoryMethod: 'receivePayment',
  );

  static const BillingAllFinancialAtom refund = BillingAllFinancialAtom(
    id: 'refund',
    label: 'Request refund',
    actionClass: BillingAllActionClass.reverse,
    requirement: BillingAllAtomPermissions.refund,
    repositoryMethod: 'requestRefund',
  );

  static const BillingAllFinancialAtom adjust = BillingAllFinancialAtom(
    id: 'adjust',
    label: 'Request adjustment',
    actionClass: BillingAllActionClass.adjust,
    requirement: BillingAllAtomPermissions.adjust,
    repositoryMethod: 'requestAdjustment',
    auditNote: 'Covers discount / price correction via Billing adjustment',
  );

  /// Waive / write-off — same [requestAdjustment] path (reason-driven).
  static const BillingAllFinancialAtom waive = BillingAllFinancialAtom(
    id: 'waive',
    label: 'Waive / write-off',
    actionClass: BillingAllActionClass.adjust,
    requirement: BillingAllAtomPermissions.adjust,
    repositoryMethod: 'requestAdjustment',
    auditNote: 'Alias of adjust — no parallel waive ledger',
  );

  /// Credit note — same [requestAdjustment] path (negative / credit amount).
  static const BillingAllFinancialAtom creditNote = BillingAllFinancialAtom(
    id: 'credit_note',
    label: 'Credit note',
    actionClass: BillingAllActionClass.adjust,
    requirement: BillingAllAtomPermissions.adjust,
    repositoryMethod: 'requestAdjustment',
    auditNote: 'Alias of adjust — posts Billing adjustment row',
  );

  static const BillingAllFinancialAtom voidInvoice = BillingAllFinancialAtom(
    id: 'void_invoice',
    label: 'Void invoice',
    actionClass: BillingAllActionClass.reverse,
    requirement: BillingAllAtomPermissions.voidInvoice,
    repositoryMethod: 'requestInvoiceVoid',
  );

  static const BillingAllFinancialAtom send = BillingAllFinancialAtom(
    id: 'send',
    label: 'Send invoice / dunning',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.send,
    repositoryMethod: 'sendInvoice',
    auditNote: 'Notification only — balance unchanged',
  );

  static const BillingAllFinancialAtom approve = BillingAllFinancialAtom(
    id: 'approve',
    label: 'Approve financial hold',
    actionClass: BillingAllActionClass.adjust,
    requirement: BillingAllAtomPermissions.approve,
    repositoryMethod: 'approveApproval',
  );

  static const BillingAllFinancialAtom reject = BillingAllFinancialAtom(
    id: 'reject',
    label: 'Reject financial hold',
    actionClass: BillingAllActionClass.adjust,
    requirement: BillingAllAtomPermissions.approve,
    repositoryMethod: 'rejectApproval',
  );

  static const BillingAllFinancialAtom submitClaim = BillingAllFinancialAtom(
    id: 'submit_claim',
    label: 'Submit claim',
    actionClass: BillingAllActionClass.defer,
    requirement: BillingAllAtomPermissions.nestedWrite,
    repositoryMethod: 'submitClaim',
  );

  static const BillingAllFinancialAtom reconcileClaim = BillingAllFinancialAtom(
    id: 'reconcile_claim',
    label: 'Record insurer response',
    actionClass: BillingAllActionClass.settle,
    requirement: BillingAllAtomPermissions.nestedWrite,
    repositoryMethod: 'reconcileClaim',
  );

  static const BillingAllFinancialAtom preAuthApprove = BillingAllFinancialAtom(
    id: 'pre_auth_approve',
    label: 'Approve pre-authorization',
    actionClass: BillingAllActionClass.defer,
    requirement: BillingAllAtomPermissions.nestedWrite,
    repositoryMethod: 'updatePreAuthorization',
  );

  static const BillingAllFinancialAtom preAuthDeny = BillingAllFinancialAtom(
    id: 'pre_auth_deny',
    label: 'Deny pre-authorization',
    actionClass: BillingAllActionClass.defer,
    requirement: BillingAllAtomPermissions.nestedWrite,
    repositoryMethod: 'updatePreAuthorization',
  );

  static const BillingAllFinancialAtom viewLedger = BillingAllFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.detail,
    repositoryMethod: 'getPatientLedger',
  );

  static const BillingAllFinancialAtom printInvoice = BillingAllFinancialAtom(
    id: 'print_invoice',
    label: 'Print invoice',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.document,
  );

  static const BillingAllFinancialAtom downloadInvoice = BillingAllFinancialAtom(
    id: 'download_invoice',
    label: 'Download invoice PDF',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.document,
    repositoryMethod: 'getInvoiceDocument',
  );

  static const BillingAllFinancialAtom routePayDeepLink = BillingAllFinancialAtom(
    id: 'route_pay',
    label: 'Deep link action=pay → receive payment dialog',
    actionClass: BillingAllActionClass.settle,
    requirement: BillingAllAtomPermissions.receivePayment,
    repositoryMethod: 'receivePayment',
    auditNote: 'Opens payment dialog only when write-authorized',
  );

  static const BillingAllFinancialAtom claimsPendingTab =
      BillingAllFinancialAtom(
    id: 'claims_pending_tab',
    label: 'Claims pending tab strip navigation',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.claimsPendingTab,
  );

  static const BillingAllFinancialAtom loading = BillingAllFinancialAtom(
    id: 'loading',
    label: 'Loading / refreshing queue',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.listChrome,
  );

  static const BillingAllFinancialAtom emptyState = BillingAllFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.listChrome,
  );

  static const BillingAllFinancialAtom errorRetry = BillingAllFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.listChrome,
  );

  static const BillingAllFinancialAtom successFeedback = BillingAllFinancialAtom(
    id: 'success_feedback',
    label: 'Mutation success / pending-approval feedback',
    actionClass: BillingAllActionClass.notBillable,
    requirement: BillingAllAtomPermissions.listChrome,
    auditNote: 'Snackbars / live detail patch — balance from Billing only',
  );

  /// Every atom inventoried for the All tab scan.
  static const List<BillingAllFinancialAtom> all = <BillingAllFinancialAtom>[
    tab,
    listChrome,
    detail,
    closeShift,
    closeDay,
    issue,
    receivePayment,
    refund,
    adjust,
    waive,
    creditNote,
    voidInvoice,
    send,
    approve,
    reject,
    submitClaim,
    reconcileClaim,
    preAuthApprove,
    preAuthDeny,
    viewLedger,
    printInvoice,
    downloadInvoice,
    routePayDeepLink,
    claimsPendingTab,
    loading,
    emptyState,
    errorRetry,
    successFeedback,
  ];

  /// Billable mutations that must post through Billing (no inline bypass).
  static Iterable<BillingAllFinancialAtom> get billableMutations => all.where(
    (BillingAllFinancialAtom atom) =>
        atom.repositoryMethod != null &&
        atom.actionClass != BillingAllActionClass.notBillable,
  );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(BillingAllActionClass actionClass) {
    return switch (actionClass) {
      BillingAllActionClass.settle ||
      BillingAllActionClass.adjust ||
      BillingAllActionClass.reverse ||
      BillingAllActionClass.createCharge ||
      BillingAllActionClass.defer => true,
      _ => false,
    };
  }
}
