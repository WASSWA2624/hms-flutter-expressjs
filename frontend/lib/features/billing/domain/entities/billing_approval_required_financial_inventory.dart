import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing **Need approval** tab scan.
enum BillingApprovalRequiredActionClass {
  /// Executes held adjustment (write-off / discount / credit) through Billing.
  adjust,

  /// Executes held refund or void through Billing on approve.
  reverse,

  /// Read chrome, navigation, ledger view, audited rejection (no balance change).
  notBillable,
}

/// One financially relevant atom on the Need approval tab (`?section=approvals`).
final class BillingApprovalRequiredFinancialAtom {
  const BillingApprovalRequiredFinancialAtom({
    required this.id,
    required this.label,
    required this.actionClass,
    required this.requirement,
    this.repositoryMethod,
    this.auditNote,
  });

  final String id;
  final String label;
  final BillingApprovalRequiredActionClass actionClass;
  final AccessRequirement requirement;

  /// Shared [BillingRepository] method — null when read-only / navigation.
  final String? repositoryMethod;
  final String? auditNote;
}

/// Canonical inventory of Need approval tab financially relevant atoms (AC1).
///
/// Approve executes the held mutation (ADJUSTMENT / REFUND / VOID) via Billing;
/// reject records an audited decision without posting a ledger row.
/// Close shift / Close day are Collect due–owned trailing actions — not mounted.
abstract final class BillingApprovalRequiredFinancialInventory {
  static const BillingApprovalRequiredFinancialAtom tab =
      BillingApprovalRequiredFinancialAtom(
    id: 'tab',
    label: 'Need approval tab',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.tab,
  );

  static const BillingApprovalRequiredFinancialAtom listChrome =
      BillingApprovalRequiredFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.listChrome,
  );

  static const BillingApprovalRequiredFinancialAtom detail =
      BillingApprovalRequiredFinancialAtom(
    id: 'detail',
    label: 'Row select → detail',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.detail,
  );

  static const BillingApprovalRequiredFinancialAtom approve =
      BillingApprovalRequiredFinancialAtom(
    id: 'approve',
    label: 'Approve financial hold',
    actionClass: BillingApprovalRequiredActionClass.adjust,
    requirement: BillingApprovalRequiredAtomPermissions.approve,
    repositoryMethod: 'approveApproval',
    auditNote:
        'Executes held ADJUSTMENT (or REFUND/VOID reverse) in Billing; '
        'claim uses PENDING→APPROVED to block duplicate posts',
  );

  static const BillingApprovalRequiredFinancialAtom approveRefundOrVoid =
      BillingApprovalRequiredFinancialAtom(
    id: 'approve_refund_or_void',
    label: 'Approve refund / void hold',
    actionClass: BillingApprovalRequiredActionClass.reverse,
    requirement: BillingApprovalRequiredAtomPermissions.approve,
    repositoryMethod: 'approveApproval',
    auditNote:
        'Same approveApproval path — REFUND creates refund row; VOID cancels invoice',
  );

  static const BillingApprovalRequiredFinancialAtom reject =
      BillingApprovalRequiredFinancialAtom(
    id: 'reject',
    label: 'Reject financial hold',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.approve,
    repositoryMethod: 'rejectApproval',
    auditNote: 'Audited REJECTED — no ledger post; realtime refreshes queue',
  );

  static const BillingApprovalRequiredFinancialAtom viewLedger =
      BillingApprovalRequiredFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.detail,
    repositoryMethod: 'getPatientLedger',
  );

  /// Print/download invoice mounts only for invoice kinds.
  static const BillingApprovalRequiredFinancialAtom printInvoice =
      BillingApprovalRequiredFinancialAtom(
    id: 'print_invoice',
    label: 'Print invoice (invoice kinds only)',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.document,
    auditNote: 'NOT_REQUIRED on approval work items — control not mounted',
  );

  static const BillingApprovalRequiredFinancialAtom printApproval =
      BillingApprovalRequiredFinancialAtom(
    id: 'print_approval_packet',
    label: 'Print approval packet',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.document,
    auditNote: 'Approval packet preview — never silent print',
  );

  static const BillingApprovalRequiredFinancialAtom downloadInvoice =
      BillingApprovalRequiredFinancialAtom(
    id: 'download_invoice',
    label: 'Download invoice PDF (invoice kinds only)',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.document,
    repositoryMethod: 'getInvoiceDocument',
    auditNote: 'NOT_REQUIRED on approval work items — control not mounted',
  );

  static const BillingApprovalRequiredFinancialAtom claimsPendingTab =
      BillingApprovalRequiredFinancialAtom(
    id: 'claims_pending_tab',
    label: 'Open claims tab strip navigation',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.claimsPendingTab,
  );

  static const BillingApprovalRequiredFinancialAtom emptyState =
      BillingApprovalRequiredFinancialAtom(
    id: 'empty_state',
    label: 'Empty queue state',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.listChrome,
  );

  static const BillingApprovalRequiredFinancialAtom errorRetry =
      BillingApprovalRequiredFinancialAtom(
    id: 'error_retry',
    label: 'Error / retry surface',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.listChrome,
  );

  /// Every atom inventoried for the Need approval tab scan.
  static const List<BillingApprovalRequiredFinancialAtom> all =
      <BillingApprovalRequiredFinancialAtom>[
    tab,
    listChrome,
    detail,
    approve,
    approveRefundOrVoid,
    reject,
    viewLedger,
    printInvoice,
    printApproval,
    downloadInvoice,
    claimsPendingTab,
    emptyState,
    errorRetry,
  ];

  /// Billable mutations that must post through Billing (no inline bypass).
  static Iterable<BillingApprovalRequiredFinancialAtom> get billableMutations =>
      all.where(
        (BillingApprovalRequiredFinancialAtom atom) =>
            atom.repositoryMethod != null &&
            atom.actionClass != BillingApprovalRequiredActionClass.notBillable,
      );

  /// True when the atom must never mutate balances outside Billing APIs.
  static bool forbidsInlineCollection(
    BillingApprovalRequiredActionClass actionClass,
  ) {
    return switch (actionClass) {
      BillingApprovalRequiredActionClass.adjust ||
      BillingApprovalRequiredActionClass.reverse => true,
      _ => false,
    };
  }
}
