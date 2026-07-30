import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';

/// Financial action classification for Claims workspace **Settled** tab scan.
enum ClaimsSettledActionClass {
  /// Remittance already posted on Active Claims / Billing reconcile path.
  /// Settled is review-only — no settle mutation mounts here.
  settle,

  /// Read chrome, filters, print/export, balance display (balance unchanged).
  notBillable,
}

/// One financially relevant atom on Settled (`/claims?section=settled`).
final class ClaimsSettledFinancialAtom {
  const ClaimsSettledFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.auditCode,
    this.billingSource,
    this.repositoryMethod,
  });

  final String id;
  final String label;
  final ClaimsSettledActionClass actionClass;
  final AccessRequirement requirement;

  /// Explicit not-billable audit when [actionClass] is [ClaimsSettledActionClass.notBillable].
  final String? auditCode;

  /// Shared Billing path that owns the amount (display parity / prior settle).
  final String? billingSource;

  /// Claims/Billing repository method — null on pure read chrome.
  final String? repositoryMethod;
}

/// Canonical inventory of Settled tab financially relevant atoms (AC1).
///
/// Tab role: read-heavy settled claims (PAID / CANCELLED). Remittance settle
/// posts via `applyClaimRemittance` on Active Claims / Billing reconcile —
/// Settled must not collect cash or re-post receipts. Patient balance tiles
/// read Billing `balance_due` from the linked invoice.
abstract final class ClaimsSettledFinancialInventory {
  static const ClaimsSettledFinancialAtom tab = ClaimsSettledFinancialAtom(
    id: 'tab',
    label: 'Settled tab',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom listChrome =
      ClaimsSettledFinancialAtom(
    id: 'list_chrome',
    label: 'Search / Clear / Filters / column Settings',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom advancedFilters =
      ClaimsSettledFinancialAtom(
    id: 'advanced_filters',
    label: 'Advanced Filters (Paid / Cancelled)',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom rowSelect = ClaimsSettledFinancialAtom(
    id: 'row_select_detail',
    label: 'Row select → detail',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.detail,
    auditCode: 'NOT_REQUIRED',
    repositoryMethod: 'getDetail',
  );

  static const ClaimsSettledFinancialAtom billingImpact =
      ClaimsSettledFinancialAtom(
    id: 'billing_impact_panel',
    label: 'Billing impact panel (invoice status + patient balance)',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.detail,
    auditCode: 'NOT_BILLED',
    billingSource: 'invoice.financials.balance_due',
  );

  static const ClaimsSettledFinancialAtom invoiceAmount =
      ClaimsSettledFinancialAtom(
    id: 'invoice_amount_display',
    label: 'Invoice / claim / settlement amount columns',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.listChrome,
    auditCode: 'NOT_BILLED',
    billingSource: 'insurance_claim + invoice',
  );

  static const ClaimsSettledFinancialAtom remittanceEvidence =
      ClaimsSettledFinancialAtom(
    id: 'prior_remittance_evidence',
    label:
        'Prior INSURANCE remittance (posted on reconcile — not re-collected here)',
    actionClass: ClaimsSettledActionClass.settle,
    requirement: ClaimsSettledAtomPermissions.approve,
    billingSource: 'lib/billing/claim-remittance.applyClaimRemittance',
    repositoryMethod: 'reconcileClaim',
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom printStatement =
      ClaimsSettledFinancialAtom(
    id: 'print_statement',
    label: 'Print statement',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.export,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom emptyState = ClaimsSettledFinancialAtom(
    id: 'empty_state',
    label: 'Empty Settled queue',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom errorRetry = ClaimsSettledFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom loading = ClaimsSettledFinancialAtom(
    id: 'loading',
    label: 'Loading claims',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  /// Absent mutate atoms documented for no-bypass (must never mount on Settled).
  static const ClaimsSettledFinancialAtom absentPrepare =
      ClaimsSettledFinancialAtom(
    id: 'absent_prepare_claim',
    label: 'Prepare claim (absent on Settled)',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.write,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom absentCloseAsPaid =
      ClaimsSettledFinancialAtom(
    id: 'absent_close_as_paid',
    label: 'Close as paid / reconcile (absent on Settled)',
    actionClass: ClaimsSettledActionClass.settle,
    requirement: ClaimsSettledAtomPermissions.approve,
    billingSource: 'Active Claims → reconcileClaim → applyClaimRemittance',
    repositoryMethod: 'reconcileClaim',
    auditCode: 'NOT_REQUIRED',
  );

  static const ClaimsSettledFinancialAtom absentCollect =
      ClaimsSettledFinancialAtom(
    id: 'absent_inline_collect',
    label: 'Receive payment / refund / adjust (absent — Billing owns)',
    actionClass: ClaimsSettledActionClass.notBillable,
    requirement: ClaimsSettledAtomPermissions.write,
    auditCode: 'NO_CHARGE',
    billingSource: 'frontend/lib/features/billing',
  );

  /// Every atom inventoried for the Settled tab scan.
  static const List<ClaimsSettledFinancialAtom> all =
      <ClaimsSettledFinancialAtom>[
    tab,
    listChrome,
    advancedFilters,
    rowSelect,
    billingImpact,
    invoiceAmount,
    remittanceEvidence,
    printStatement,
    emptyState,
    errorRetry,
    loading,
    absentPrepare,
    absentCloseAsPaid,
    absentCollect,
  ];

  /// Settled mounts no billable mutations — remittance posts elsewhere.
  static bool get settledTabHasNoBillableMutations =>
      all
          .where(
            (ClaimsSettledFinancialAtom atom) =>
                !atom.id.startsWith('absent_') &&
                !atom.id.startsWith('prior_'),
          )
          .every(
            (ClaimsSettledFinancialAtom atom) =>
                atom.actionClass == ClaimsSettledActionClass.notBillable,
          );

  /// True when financial class must never invent a shadow ledger on this tab.
  static bool forbidsInlineCollection(ClaimsSettledActionClass actionClass) {
    return switch (actionClass) {
      ClaimsSettledActionClass.settle => true,
      ClaimsSettledActionClass.notBillable => true,
    };
  }

  /// Atoms that must show Billing balance parity (not coverage estimates).
  static Iterable<ClaimsSettledFinancialAtom> get balanceParityAtoms => all
      .where(
        (ClaimsSettledFinancialAtom atom) =>
            atom.billingSource == 'invoice.financials.balance_due',
      );
}
