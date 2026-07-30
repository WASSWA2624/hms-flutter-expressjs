import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing **Overdue** tab scan.
enum BillingOverdueActionClass {
  /// Receive payment / apply collection against overdue balance.
  settle,

  /// Discount, waive, write-off, credit note request.
  adjust,

  /// Refund request / void request (approval-held reverse).
  reverse,

  /// Read chrome, dunning send, navigation, print/export (balance unchanged).
  notBillable,
}

/// One financially relevant atom on the Overdue tab (`?queue=overdue`).
final class BillingOverdueFinancialAtom {
  const BillingOverdueFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final BillingOverdueActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared [BillingRepository] method — null when read-only / navigation.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Overdue tab financially relevant atoms (AC1).
///
/// Collections follow-up: receive payment, dunning send, adjust / waive, void.
/// All postings go through [BillingRepository] / backend billing module only.
abstract final class BillingOverdueFinancialInventory {
  static const BillingOverdueFinancialAtom tab = BillingOverdueFinancialAtom(
    id: 'tab',
    label: 'Overdue tab',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.tab,
  );

  static const BillingOverdueFinancialAtom listChrome =
      BillingOverdueFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.listChrome,
  );

  static const BillingOverdueFinancialAtom detail = BillingOverdueFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.detail,
  );

  static const BillingOverdueFinancialAtom closeShift =
      BillingOverdueFinancialAtom(
    id: 'close_shift',
    label: 'Close shift',
    actionClass: BillingOverdueActionClass.settle,
    requirement: BillingOverdueAtomPermissions.close,
    repositoryMethod: 'closeShift',
    auditNote: 'Reconciles Billing payments for shift',
  );

  static const BillingOverdueFinancialAtom closeDay =
      BillingOverdueFinancialAtom(
    id: 'close_day',
    label: 'Close day',
    actionClass: BillingOverdueActionClass.settle,
    requirement: BillingOverdueAtomPermissions.close,
    repositoryMethod: 'closeDay',
    auditNote: 'Day close against Billing ledger',
  );

  static const BillingOverdueFinancialAtom receivePayment =
      BillingOverdueFinancialAtom(
    id: 'receive_payment',
    label: 'Receive payment',
    actionClass: BillingOverdueActionClass.settle,
    requirement: BillingOverdueAtomPermissions.receivePayment,
    repositoryMethod: 'receivePayment',
    auditNote: 'Payments create + reconcile via Billing; idempotency key required',
  );

  static const BillingOverdueFinancialAtom adjust = BillingOverdueFinancialAtom(
    id: 'adjust',
    label: 'Request adjustment',
    actionClass: BillingOverdueActionClass.adjust,
    requirement: BillingOverdueAtomPermissions.adjust,
    repositoryMethod: 'requestAdjustment',
  );

  /// Collections synonym for [adjust] — same write ∩ and repository path.
  static const BillingOverdueFinancialAtom waive = BillingOverdueFinancialAtom(
    id: 'waive',
    label: 'Waive / write-off (via adjust)',
    actionClass: BillingOverdueActionClass.adjust,
    requirement: BillingOverdueAtomPermissions.waive,
    repositoryMethod: 'requestAdjustment',
    auditNote: 'Waive is adjust with write-off / waiver reason — no parallel path',
  );

  static const BillingOverdueFinancialAtom refund = BillingOverdueFinancialAtom(
    id: 'refund',
    label: 'Request refund',
    actionClass: BillingOverdueActionClass.reverse,
    requirement: BillingOverdueAtomPermissions.write,
    repositoryMethod: 'requestRefund',
    auditNote: 'Reachable from detail when a refundable payment exists',
  );

  static const BillingOverdueFinancialAtom voidInvoice =
      BillingOverdueFinancialAtom(
    id: 'void_invoice',
    label: 'Void invoice',
    actionClass: BillingOverdueActionClass.reverse,
    requirement: BillingOverdueAtomPermissions.voidInvoice,
    repositoryMethod: 'requestInvoiceVoid',
  );

  static const BillingOverdueFinancialAtom dunningSend =
      BillingOverdueFinancialAtom(
    id: 'dunning_send',
    label: 'Send invoice / dunning notice',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.dunningSend,
    repositoryMethod: 'sendInvoice',
    auditNote: 'Notification only — balance unchanged',
  );

  static const BillingOverdueFinancialAtom viewLedger =
      BillingOverdueFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.detail,
    repositoryMethod: 'getPatientLedger',
  );

  static const BillingOverdueFinancialAtom printInvoice =
      BillingOverdueFinancialAtom(
    id: 'print_invoice',
    label: 'Print invoice',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.document,
  );

  static const BillingOverdueFinancialAtom downloadInvoice =
      BillingOverdueFinancialAtom(
    id: 'download_invoice',
    label: 'Download invoice PDF',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.document,
    repositoryMethod: 'getInvoiceDocument',
  );

  static const BillingOverdueFinancialAtom routePayDeepLink =
      BillingOverdueFinancialAtom(
    id: 'route_pay',
    label: 'Deep link action=pay → receive payment dialog',
    actionClass: BillingOverdueActionClass.settle,
    requirement: BillingOverdueAtomPermissions.receivePayment,
    repositoryMethod: 'receivePayment',
    auditNote: 'Opens payment dialog only when write-authorized',
  );

  static const BillingOverdueFinancialAtom claimsPendingTab =
      BillingOverdueFinancialAtom(
    id: 'claims_pending_tab',
    label: 'Claims pending tab strip navigation',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.claimsPendingTab,
  );

  static const BillingOverdueFinancialAtom emptyState =
      BillingOverdueFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.listChrome,
  );

  static const BillingOverdueFinancialAtom errorRetry =
      BillingOverdueFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: BillingOverdueActionClass.notBillable,
    requirement: BillingOverdueAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Overdue tab scan.
  static const List<BillingOverdueFinancialAtom> all =
      <BillingOverdueFinancialAtom>[
    tab,
    listChrome,
    detail,
    closeShift,
    closeDay,
    receivePayment,
    adjust,
    waive,
    refund,
    voidInvoice,
    dunningSend,
    viewLedger,
    printInvoice,
    downloadInvoice,
    routePayDeepLink,
    claimsPendingTab,
    emptyState,
    errorRetry,
  ];

  /// Billable mutations that must post through Billing (no inline bypass).
  static Iterable<BillingOverdueFinancialAtom> get billableMutations =>
      all.where(
        (BillingOverdueFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != BillingOverdueActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(BillingOverdueActionClass actionClass) {
    return switch (actionClass) {
      BillingOverdueActionClass.settle ||
      BillingOverdueActionClass.adjust ||
      BillingOverdueActionClass.reverse => true,
      _ => false,
    };
  }
}
