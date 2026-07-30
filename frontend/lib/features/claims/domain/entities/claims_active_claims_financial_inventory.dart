import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';

/// Financial action classification for the Claims **Active Claims** tab scan.
enum ClaimsActiveClaimsActionClass {
  /// Claim prepare / submit / resubmit / non-settling response — outstanding
  /// remains in Billing (no new payment row).
  defer,

  /// Remittance reconcile (PAID/PARTIAL), close-as-paid, sync when settled.
  settle,

  /// Read chrome, print, navigation, empty/error (balance unchanged).
  notBillable,
}

/// One financially relevant atom on the Active Claims tab (`?section=active-claims`).
final class ClaimsActiveClaimsFinancialAtom {
  const ClaimsActiveClaimsFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final ClaimsActiveClaimsActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared claims / Billing repository method — null when read-only.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Active Claims tab financially relevant atoms (AC1).
///
/// Focus: prepare / submit / amend (resubmit), remittance settlement, co-pay
/// residual collection via Billing receive-payment deep-link. Mutations post
/// through insurance-claim handlers that call [applyClaimRemittance] — never a
/// module-private cash ledger.
abstract final class ClaimsActiveClaimsFinancialInventory {
  static const ClaimsActiveClaimsFinancialAtom tab =
      ClaimsActiveClaimsFinancialAtom(
    id: 'tab',
    label: 'Active Claims tab',
    actionClass: ClaimsActiveClaimsActionClass.notBillable,
    requirement: ClaimsActiveClaimsAtomPermissions.tab,
  );

  static const ClaimsActiveClaimsFinancialAtom listChrome =
      ClaimsActiveClaimsFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / summary chips',
    actionClass: ClaimsActiveClaimsActionClass.notBillable,
    requirement: ClaimsActiveClaimsAtomPermissions.listChrome,
  );

  static const ClaimsActiveClaimsFinancialAtom detail =
      ClaimsActiveClaimsFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: ClaimsActiveClaimsActionClass.notBillable,
    requirement: ClaimsActiveClaimsAtomPermissions.detail,
  );

  static const ClaimsActiveClaimsFinancialAtom prepareClaim =
      ClaimsActiveClaimsFinancialAtom(
    id: 'prepare_claim',
    label: 'Prepare claim',
    actionClass: ClaimsActiveClaimsActionClass.defer,
    requirement: ClaimsActiveClaimsAtomPermissions.prepare,
    repositoryMethod: 'prepareClaim',
    auditNote: 'Links existing Billing invoice to claim; no new charge',
  );

  static const ClaimsActiveClaimsFinancialAtom submitClaim =
      ClaimsActiveClaimsFinancialAtom(
    id: 'submit_claim',
    label: 'Submit / resubmit claim',
    actionClass: ClaimsActiveClaimsActionClass.defer,
    requirement: ClaimsActiveClaimsAtomPermissions.submit,
    repositoryMethod: 'submitClaim',
    auditNote: 'Insurer handoff; patient share remains in Billing',
  );

  static const ClaimsActiveClaimsFinancialAtom recordResponse =
      ClaimsActiveClaimsFinancialAtom(
    id: 'record_response',
    label: 'Record insurer response',
    actionClass: ClaimsActiveClaimsActionClass.settle,
    requirement: ClaimsActiveClaimsAtomPermissions.recordResponse,
    repositoryMethod: 'reconcileClaim',
    auditNote:
        'APPROVED/REJECTED defer; PAID/PARTIAL posts INSURANCE remittance',
  );

  static const ClaimsActiveClaimsFinancialAtom closeAsPaid =
      ClaimsActiveClaimsFinancialAtom(
    id: 'close_as_paid',
    label: 'Close as paid',
    actionClass: ClaimsActiveClaimsActionClass.settle,
    requirement: ClaimsActiveClaimsAtomPermissions.closeAsPaid,
    repositoryMethod: 'reconcileClaim',
    auditNote: 'PAID remittance via applyClaimRemittance + invoice recalculate',
  );

  static const ClaimsActiveClaimsFinancialAtom syncStatus =
      ClaimsActiveClaimsFinancialAtom(
    id: 'sync_status',
    label: 'Sync insurer status',
    actionClass: ClaimsActiveClaimsActionClass.settle,
    requirement: ClaimsActiveClaimsAtomPermissions.sync,
    repositoryMethod: 'syncClaimStatus',
    auditNote: 'May reconcile to PAID/PARTIAL → remittance when adapter settles',
  );

  static const ClaimsActiveClaimsFinancialAtom collectPatientShare =
      ClaimsActiveClaimsFinancialAtom(
    id: 'collect_patient_share',
    label: 'Collect patient share',
    actionClass: ClaimsActiveClaimsActionClass.settle,
    requirement: billingWorkspaceWriteRequirement,
    repositoryMethod: 'receivePayment',
    auditNote:
        'Deep-links Billing receive-payment; never invents cashier logic here',
  );

  static const ClaimsActiveClaimsFinancialAtom printStatement =
      ClaimsActiveClaimsFinancialAtom(
    id: 'print_statement',
    label: 'Print statement',
    actionClass: ClaimsActiveClaimsActionClass.notBillable,
    requirement: ClaimsActiveClaimsAtomPermissions.document,
  );

  static const ClaimsActiveClaimsFinancialAtom emptyState =
      ClaimsActiveClaimsFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: ClaimsActiveClaimsActionClass.notBillable,
    requirement: ClaimsActiveClaimsAtomPermissions.listChrome,
  );

  static const ClaimsActiveClaimsFinancialAtom errorRetry =
      ClaimsActiveClaimsFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: ClaimsActiveClaimsActionClass.notBillable,
    requirement: ClaimsActiveClaimsAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Active Claims tab scan.
  static const List<ClaimsActiveClaimsFinancialAtom> all =
      <ClaimsActiveClaimsFinancialAtom>[
    tab,
    listChrome,
    detail,
    prepareClaim,
    submitClaim,
    recordResponse,
    closeAsPaid,
    syncStatus,
    collectPatientShare,
    printStatement,
    emptyState,
    errorRetry,
  ];

  /// Billable mutations that must post through Billing / remittance APIs.
  static Iterable<ClaimsActiveClaimsFinancialAtom> get billableMutations =>
      all.where(
        (ClaimsActiveClaimsFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != ClaimsActiveClaimsActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(
    ClaimsActiveClaimsActionClass actionClass,
  ) {
    return switch (actionClass) {
      ClaimsActiveClaimsActionClass.settle ||
      ClaimsActiveClaimsActionClass.defer => true,
      _ => false,
    };
  }
}
