import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Financial action classification for the Billing **Approval required** tab scan.
enum BillingApprovalRequiredActionClass {
  /// Executes held adjustment / refund / void through Billing on approve.
  adjust,

  /// Shift/day close reconciles Billing ledger totals.
  settle,

  /// Read chrome, navigation, ledger view, audited rejection (no balance change).
  notBillable,
}

/// One financially relevant atom on the Approval required tab (`?queue=approval-required`).
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

/// Canonical inventory of Approval required tab financially relevant atoms (AC1).
///
/// Approve executes the held mutation (adjustment, refund, void) via Billing;
/// reject records an audited decision without posting a parallel ledger.
abstract final class BillingApprovalRequiredFinancialInventory {
  static const BillingApprovalRequiredFinancialAtom tab =
      BillingApprovalRequiredFinancialAtom(
    id: 'tab',
    label: 'Approval required tab',
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

  static const BillingApprovalRequiredFinancialAtom closeShift =
      BillingApprovalRequiredFinancialAtom(
    id: 'close_shift',
    label: 'Close shift',
    actionClass: BillingApprovalRequiredActionClass.settle,
    requirement: BillingApprovalRequiredAtomPermissions.close,
    repositoryMethod: 'closeShift',
    auditNote: 'Reconciles Billing payments for shift',
  );

  static const BillingApprovalRequiredFinancialAtom closeDay =
      BillingApprovalRequiredFinancialAtom(
    id: 'close_day',
    label: 'Close day',
    actionClass: BillingApprovalRequiredActionClass.settle,
    requirement: BillingApprovalRequiredAtomPermissions.close,
    repositoryMethod: 'closeDay',
    auditNote: 'Day close against Billing ledger',
  );

  static const BillingApprovalRequiredFinancialAtom approve =
      BillingApprovalRequiredFinancialAtom(
    id: 'approve',
    label: 'Approve financial hold',
    actionClass: BillingApprovalRequiredActionClass.adjust,
    requirement: BillingApprovalRequiredAtomPermissions.approve,
    repositoryMethod: 'approveApproval',
    auditNote: 'Executes held adjustment/refund/void in Billing',
  );

  static const BillingApprovalRequiredFinancialAtom reject =
      BillingApprovalRequiredFinancialAtom(
    id: 'reject',
    label: 'Reject financial hold',
    actionClass: BillingApprovalRequiredActionClass.adjust,
    requirement: BillingApprovalRequiredAtomPermissions.approve,
    repositoryMethod: 'rejectApproval',
    auditNote: 'Audited rejection — no parallel ledger',
  );

  static const BillingApprovalRequiredFinancialAtom viewLedger =
      BillingApprovalRequiredFinancialAtom(
    id: 'view_ledger',
    label: 'View ledger',
    actionClass: BillingApprovalRequiredActionClass.notBillable,
    requirement: BillingApprovalRequiredAtomPermissions.detail,
    repositoryMethod: 'getPatientLedger',
  );

  /// Every atom inventoried for the Approval required tab scan.
  static const List<BillingApprovalRequiredFinancialAtom> all =
      <BillingApprovalRequiredFinancialAtom>[
    tab,
    listChrome,
    detail,
    closeShift,
    closeDay,
    approve,
    reject,
    viewLedger,
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
      BillingApprovalRequiredActionClass.settle ||
      BillingApprovalRequiredActionClass.adjust => true,
      _ => false,
    };
  }
}
