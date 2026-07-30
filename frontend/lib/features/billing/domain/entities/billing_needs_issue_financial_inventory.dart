import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing **Needs issue** tab scan.
enum BillingNeedsIssueActionClass {
  /// Draft invoice issuance (DRAFT → ISSUED) with line provenance preserved.
  /// Includes Send, which issues first via Billing then delivers the PDF.
  createCharge,

  /// Shift/day close reconciles Billing ledger totals.
  settle,

  /// Discount, waive, write-off request on draft invoice detail.
  adjust,

  /// Void invoice request from detail.
  reverse,

  /// Read chrome, navigation, print/export, ledger (balance unchanged).
  notBillable,
}

/// One financially relevant atom on the Needs issue tab (`?queue=needs-issue`).
final class BillingNeedsIssueFinancialAtom {
  const BillingNeedsIssueFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final BillingNeedsIssueActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared [BillingRepository] method — null when read-only / navigation.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Needs issue tab financially relevant atoms (AC1).
///
/// Primary mutation is invoice issue from DRAFT clinical charges; all postings
/// go through [BillingRepository] / backend billing module only.
abstract final class BillingNeedsIssueFinancialInventory {
  static const BillingNeedsIssueFinancialAtom tab =
      BillingNeedsIssueFinancialAtom(
    id: 'tab',
    label: 'Needs issue tab',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.tab,
  );

  static const BillingNeedsIssueFinancialAtom listChrome =
      BillingNeedsIssueFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.listChrome,
  );

  static const BillingNeedsIssueFinancialAtom detail =
      BillingNeedsIssueFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.detail,
  );

  static const BillingNeedsIssueFinancialAtom closeShift =
      BillingNeedsIssueFinancialAtom(
    id: 'close_shift',
    label: 'Close shift',
    actionClass: BillingNeedsIssueActionClass.settle,
    requirement: BillingNeedsIssueAtomPermissions.close,
    repositoryMethod: 'closeShift',
    auditNote: 'Reconciles Billing payments for shift',
  );

  static const BillingNeedsIssueFinancialAtom closeDay =
      BillingNeedsIssueFinancialAtom(
    id: 'close_day',
    label: 'Close day',
    actionClass: BillingNeedsIssueActionClass.settle,
    requirement: BillingNeedsIssueAtomPermissions.close,
    repositoryMethod: 'closeDay',
    auditNote: 'Day close against Billing ledger',
  );

  static const BillingNeedsIssueFinancialAtom issue =
      BillingNeedsIssueFinancialAtom(
    id: 'issue',
    label: 'Issue invoice',
    actionClass: BillingNeedsIssueActionClass.createCharge,
    requirement: BillingNeedsIssueAtomPermissions.issue,
    repositoryMethod: 'issueInvoice',
    auditNote: 'DRAFT → ISSUED; preserves clinical line provenance',
  );

  static const BillingNeedsIssueFinancialAtom adjust =
      BillingNeedsIssueFinancialAtom(
    id: 'adjust',
    label: 'Request adjustment',
    actionClass: BillingNeedsIssueActionClass.adjust,
    requirement: BillingNeedsIssueAtomPermissions.write,
    repositoryMethod: 'requestAdjustment',
    auditNote: 'Reachable from draft invoice detail when exposed',
  );

  static const BillingNeedsIssueFinancialAtom voidInvoice =
      BillingNeedsIssueFinancialAtom(
    id: 'void_invoice',
    label: 'Void invoice',
    actionClass: BillingNeedsIssueActionClass.reverse,
    requirement: BillingNeedsIssueAtomPermissions.write,
    repositoryMethod: 'requestInvoiceVoid',
    auditNote: 'Reachable from draft invoice detail when exposed',
  );

  static const BillingNeedsIssueFinancialAtom send =
      BillingNeedsIssueFinancialAtom(
    id: 'send',
    label: 'Send invoice',
    actionClass: BillingNeedsIssueActionClass.createCharge,
    requirement: BillingNeedsIssueAtomPermissions.write,
    repositoryMethod: 'sendInvoice',
    auditNote:
        'Backend sendInvoice calls issueInvoice first (DRAFT → ISSUED), then emails PDF',
  );

  static const BillingNeedsIssueFinancialAtom viewLedger =
      BillingNeedsIssueFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.detail,
    repositoryMethod: 'getPatientLedger',
  );

  static const BillingNeedsIssueFinancialAtom printInvoice =
      BillingNeedsIssueFinancialAtom(
    id: 'print_invoice',
    label: 'Print invoice',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.document,
  );

  static const BillingNeedsIssueFinancialAtom downloadInvoice =
      BillingNeedsIssueFinancialAtom(
    id: 'download_invoice',
    label: 'Download invoice PDF',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.document,
    repositoryMethod: 'getInvoiceDocument',
  );

  static const BillingNeedsIssueFinancialAtom claimsPendingTab =
      BillingNeedsIssueFinancialAtom(
    id: 'claims_pending_tab',
    label: 'Claims pending tab strip navigation',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.claimsPendingTab,
  );

  static const BillingNeedsIssueFinancialAtom emptyState =
      BillingNeedsIssueFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.listChrome,
  );

  static const BillingNeedsIssueFinancialAtom errorRetry =
      BillingNeedsIssueFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: BillingNeedsIssueActionClass.notBillable,
    requirement: BillingNeedsIssueAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Needs issue tab scan.
  static const List<BillingNeedsIssueFinancialAtom> all =
      <BillingNeedsIssueFinancialAtom>[
    tab,
    listChrome,
    detail,
    closeShift,
    closeDay,
    issue,
    adjust,
    voidInvoice,
    send,
    viewLedger,
    printInvoice,
    downloadInvoice,
    claimsPendingTab,
    emptyState,
    errorRetry,
  ];

  /// Billable mutations that must post through Billing (no inline bypass).
  static Iterable<BillingNeedsIssueFinancialAtom> get billableMutations => all
      .where(
        (BillingNeedsIssueFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != BillingNeedsIssueActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(BillingNeedsIssueActionClass actionClass) {
    return switch (actionClass) {
      BillingNeedsIssueActionClass.settle ||
      BillingNeedsIssueActionClass.adjust ||
      BillingNeedsIssueActionClass.reverse ||
      BillingNeedsIssueActionClass.createCharge => true,
      _ => false,
    };
  }
}
