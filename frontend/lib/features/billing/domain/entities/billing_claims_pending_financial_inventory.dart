import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing **Claims pending** tab scan.
enum BillingClaimsPendingActionClass {
  /// Claim submit / pre-auth handoff — outstanding remains in Billing.
  defer,

  /// Remittance reconcile, shift/day close applying ledger totals.
  settle,

  /// Read chrome, navigation, print/export, ledger view (balance unchanged).
  notBillable,
}

/// One financially relevant atom on the Claims pending tab (`?queue=claims-pending`).
final class BillingClaimsPendingFinancialAtom {
  const BillingClaimsPendingFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final BillingClaimsPendingActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared [BillingRepository] method — null when read-only / navigation.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Claims pending tab financially relevant atoms (AC1).
///
/// Primary focus: insurance claim handoff, co-pay remaining, and remittance
/// reconciliation back into Billing. Mutations go through [BillingRepository]
/// → insurance-claim / pre-authorization handlers that post Billing rows.
abstract final class BillingClaimsPendingFinancialInventory {
  static const BillingClaimsPendingFinancialAtom tab =
      BillingClaimsPendingFinancialAtom(
    id: 'tab',
    label: 'Claims pending tab',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.tab,
  );

  static const BillingClaimsPendingFinancialAtom listChrome =
      BillingClaimsPendingFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.listChrome,
  );

  static const BillingClaimsPendingFinancialAtom detail =
      BillingClaimsPendingFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.detail,
  );

  static const BillingClaimsPendingFinancialAtom closeShift =
      BillingClaimsPendingFinancialAtom(
    id: 'close_shift',
    label: 'Close shift',
    actionClass: BillingClaimsPendingActionClass.settle,
    requirement: BillingClaimsPendingAtomPermissions.close,
    repositoryMethod: 'closeShift',
    auditNote: 'Reconciles Billing payments for shift',
  );

  static const BillingClaimsPendingFinancialAtom closeDay =
      BillingClaimsPendingFinancialAtom(
    id: 'close_day',
    label: 'Close day',
    actionClass: BillingClaimsPendingActionClass.settle,
    requirement: BillingClaimsPendingAtomPermissions.close,
    repositoryMethod: 'closeDay',
    auditNote: 'Day close against Billing ledger',
  );

  static const BillingClaimsPendingFinancialAtom submitClaim =
      BillingClaimsPendingFinancialAtom(
    id: 'submit_claim',
    label: 'Submit claim',
    actionClass: BillingClaimsPendingActionClass.defer,
    requirement: BillingClaimsPendingAtomPermissions.submit,
    repositoryMethod: 'submitClaim',
    auditNote: 'Handoff to insurer; patient share remains in Billing',
  );

  static const BillingClaimsPendingFinancialAtom reconcileClaim =
      BillingClaimsPendingFinancialAtom(
    id: 'reconcile_claim',
    label: 'Record insurer response',
    actionClass: BillingClaimsPendingActionClass.settle,
    requirement: BillingClaimsPendingAtomPermissions.reconcile,
    repositoryMethod: 'reconcileClaim',
    auditNote:
        'PAID/PARTIAL posts INSURANCE remittance payment + invoice recalculate',
  );

  static const BillingClaimsPendingFinancialAtom preAuthApprove =
      BillingClaimsPendingFinancialAtom(
    id: 'pre_auth_approve',
    label: 'Approve authorization',
    actionClass: BillingClaimsPendingActionClass.defer,
    requirement: BillingClaimsPendingAtomPermissions.preAuth,
    repositoryMethod: 'updatePreAuthorization',
    auditNote: 'Pre-auth gate only — no cashier collection on this tab',
  );

  static const BillingClaimsPendingFinancialAtom preAuthDeny =
      BillingClaimsPendingFinancialAtom(
    id: 'pre_auth_deny',
    label: 'Deny authorization',
    actionClass: BillingClaimsPendingActionClass.defer,
    requirement: BillingClaimsPendingAtomPermissions.preAuth,
    repositoryMethod: 'updatePreAuthorization',
  );

  static const BillingClaimsPendingFinancialAtom viewLedger =
      BillingClaimsPendingFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.nestedRead,
    repositoryMethod: 'getPatientLedger',
  );

  static const BillingClaimsPendingFinancialAtom printInvoice =
      BillingClaimsPendingFinancialAtom(
    id: 'print_invoice',
    label: 'Print invoice',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.document,
    auditNote: 'Invoice documents only — never mounts for claim/pre-auth rows',
  );

  static const BillingClaimsPendingFinancialAtom printClaim =
      BillingClaimsPendingFinancialAtom(
    id: 'print_claim',
    label: 'Print statement',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.document,
    auditNote: 'Claim / pre-auth statement preview — never silent print',
  );

  static const BillingClaimsPendingFinancialAtom downloadInvoice =
      BillingClaimsPendingFinancialAtom(
    id: 'download_invoice',
    label: 'Download invoice PDF',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.document,
    repositoryMethod: 'getInvoiceDocument',
    auditNote: 'Invoice documents only — never mounts for claim/pre-auth rows',
  );

  static const BillingClaimsPendingFinancialAtom emptyState =
      BillingClaimsPendingFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.listChrome,
  );

  static const BillingClaimsPendingFinancialAtom errorRetry =
      BillingClaimsPendingFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: BillingClaimsPendingActionClass.notBillable,
    requirement: BillingClaimsPendingAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Claims pending tab scan.
  static const List<BillingClaimsPendingFinancialAtom> all =
      <BillingClaimsPendingFinancialAtom>[
    tab,
    listChrome,
    detail,
    closeShift,
    closeDay,
    submitClaim,
    reconcileClaim,
    preAuthApprove,
    preAuthDeny,
    viewLedger,
    printInvoice,
    printClaim,
    downloadInvoice,
    emptyState,
    errorRetry,
  ];

  /// Billable mutations that must post through Billing (no inline bypass).
  static Iterable<BillingClaimsPendingFinancialAtom> get billableMutations =>
      all.where(
        (BillingClaimsPendingFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != BillingClaimsPendingActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(
    BillingClaimsPendingActionClass actionClass,
  ) {
    return switch (actionClass) {
      BillingClaimsPendingActionClass.settle ||
      BillingClaimsPendingActionClass.defer => true,
      _ => false,
    };
  }
}
