import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing **Collect due** tab scan.
enum BillingAwaitingPaymentActionClass {
  /// Receive payment, shift/day close, claim settlement applying balance.
  settle,

  /// Discount, waive, write-off, credit note request from invoice detail.
  adjust,

  /// Refund, void, payment reversal.
  reverse,

  /// Read chrome, navigation, print/export, send notification (balance unchanged).
  notBillable,
}

/// One financially relevant atom on the Collect due tab (`?section=collect`).
final class BillingAwaitingPaymentFinancialAtom {
  const BillingAwaitingPaymentFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final BillingAwaitingPaymentActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared [BillingRepository] method — null when read-only / navigation.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Collect due tab financially relevant atoms (AC1).
///
/// Primary mutation is Pay (partial + full) via Billing receive-payment;
/// all postings go through [BillingRepository] /
/// backend billing + payment modules only.
abstract final class BillingAwaitingPaymentFinancialInventory {
  static const BillingAwaitingPaymentFinancialAtom tab =
      BillingAwaitingPaymentFinancialAtom(
    id: 'tab',
    label: 'Collect due tab',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.tab,
  );

  static const BillingAwaitingPaymentFinancialAtom listChrome =
      BillingAwaitingPaymentFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.listChrome,
  );

  static const BillingAwaitingPaymentFinancialAtom detail =
      BillingAwaitingPaymentFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.detail,
  );

  static const BillingAwaitingPaymentFinancialAtom closeShift =
      BillingAwaitingPaymentFinancialAtom(
    id: 'close_shift',
    label: 'Close shift',
    actionClass: BillingAwaitingPaymentActionClass.settle,
    requirement: BillingAwaitingPaymentAtomPermissions.close,
    repositoryMethod: 'closeShift',
    auditNote: 'Reconciles Billing payments for shift',
  );

  static const BillingAwaitingPaymentFinancialAtom closeDay =
      BillingAwaitingPaymentFinancialAtom(
    id: 'close_day',
    label: 'Close day',
    actionClass: BillingAwaitingPaymentActionClass.settle,
    requirement: BillingAwaitingPaymentAtomPermissions.close,
    repositoryMethod: 'closeDay',
    auditNote: 'Day close against Billing ledger',
  );

  static const BillingAwaitingPaymentFinancialAtom receivePayment =
      BillingAwaitingPaymentFinancialAtom(
    id: 'receive_payment',
    label: 'Pay',
    actionClass: BillingAwaitingPaymentActionClass.settle,
    requirement: BillingAwaitingPaymentAtomPermissions.receivePayment,
    repositoryMethod: 'receivePayment',
    auditNote: 'Create payment + Billing reconcile; supports partials',
  );

  static const BillingAwaitingPaymentFinancialAtom refund =
      BillingAwaitingPaymentFinancialAtom(
    id: 'refund',
    label: 'Request refund',
    actionClass: BillingAwaitingPaymentActionClass.reverse,
    requirement: BillingAwaitingPaymentAtomPermissions.refund,
    repositoryMethod: 'requestRefund',
    auditNote: 'Reachable from invoice detail when a refundable payment exists',
  );

  static const BillingAwaitingPaymentFinancialAtom adjust =
      BillingAwaitingPaymentFinancialAtom(
    id: 'adjust',
    label: 'Request adjustment',
    actionClass: BillingAwaitingPaymentActionClass.adjust,
    requirement: BillingAwaitingPaymentAtomPermissions.adjust,
    repositoryMethod: 'requestAdjustment',
  );

  static const BillingAwaitingPaymentFinancialAtom voidInvoice =
      BillingAwaitingPaymentFinancialAtom(
    id: 'void_invoice',
    label: 'Void invoice',
    actionClass: BillingAwaitingPaymentActionClass.reverse,
    requirement: BillingAwaitingPaymentAtomPermissions.voidInvoice,
    repositoryMethod: 'requestInvoiceVoid',
  );

  static const BillingAwaitingPaymentFinancialAtom send =
      BillingAwaitingPaymentFinancialAtom(
    id: 'send',
    label: 'Send invoice',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.send,
    repositoryMethod: 'sendInvoice',
    auditNote: 'Notification only — balance unchanged',
  );

  static const BillingAwaitingPaymentFinancialAtom viewLedger =
      BillingAwaitingPaymentFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.detail,
    repositoryMethod: 'getPatientLedger',
  );

  static const BillingAwaitingPaymentFinancialAtom printInvoice =
      BillingAwaitingPaymentFinancialAtom(
    id: 'print_invoice',
    label: 'Print invoice',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.document,
  );

  static const BillingAwaitingPaymentFinancialAtom downloadInvoice =
      BillingAwaitingPaymentFinancialAtom(
    id: 'download_invoice',
    label: 'Download invoice PDF',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.document,
    repositoryMethod: 'getInvoiceDocument',
  );

  static const BillingAwaitingPaymentFinancialAtom routePayDeepLink =
      BillingAwaitingPaymentFinancialAtom(
    id: 'route_pay',
    label: 'Deep link action=pay → receive payment dialog',
    actionClass: BillingAwaitingPaymentActionClass.settle,
    requirement: BillingAwaitingPaymentAtomPermissions.receivePayment,
    repositoryMethod: 'receivePayment',
    auditNote: 'Opens payment dialog only when write-authorized',
  );

  static const BillingAwaitingPaymentFinancialAtom claimsPendingTab =
      BillingAwaitingPaymentFinancialAtom(
    id: 'claims_pending_tab',
    label: 'Claims pending tab strip navigation',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.claimsPendingTab,
  );

  static const BillingAwaitingPaymentFinancialAtom emptyState =
      BillingAwaitingPaymentFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.listChrome,
  );

  static const BillingAwaitingPaymentFinancialAtom errorRetry =
      BillingAwaitingPaymentFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: BillingAwaitingPaymentActionClass.notBillable,
    requirement: BillingAwaitingPaymentAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Awaiting payment tab scan.
  static const List<BillingAwaitingPaymentFinancialAtom> all =
      <BillingAwaitingPaymentFinancialAtom>[
    tab,
    listChrome,
    detail,
    closeShift,
    closeDay,
    receivePayment,
    refund,
    adjust,
    voidInvoice,
    send,
    viewLedger,
    printInvoice,
    downloadInvoice,
    routePayDeepLink,
    claimsPendingTab,
    emptyState,
    errorRetry,
  ];

  /// Billable mutations that must post through Billing (no inline bypass).
  static Iterable<BillingAwaitingPaymentFinancialAtom> get billableMutations =>
      all.where(
        (BillingAwaitingPaymentFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != BillingAwaitingPaymentActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(
    BillingAwaitingPaymentActionClass actionClass,
  ) {
    return switch (actionClass) {
      BillingAwaitingPaymentActionClass.settle ||
      BillingAwaitingPaymentActionClass.adjust ||
      BillingAwaitingPaymentActionClass.reverse => true,
      _ => false,
    };
  }
}
