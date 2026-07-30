import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum LabFollowUpsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Lab Follow-ups (`/lab?section=follow-ups`).
@immutable
final class LabFollowUpsFinancialAtom {
  const LabFollowUpsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.requirement,
    this.billingPath,
    this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final LabFollowUpsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/lab?section=follow-ups`.
///
/// Tab role: hospital-wide scheduled callback worklist (`FollowUpWorklistPanel`
/// with empty scope — not encounter-filtered to lab). Mark
/// completed and reschedule stay `NOT_BILLED` ops (status/schedule only). Create
/// Lab Order primary, result-entry / save / enter results, and cashier settle are
/// **not** mounted here — they post on All / Awaiting results / Processing /
/// Completed / Critical / Billing. Result entry / save is clinical (not
/// payment-gated) when mounted on those tabs. If visit charges or
/// payment UX are introduced, they must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger.
abstract final class LabFollowUpsBillingInventory {
  static const LabFollowUpsFinancialAtom tab = LabFollowUpsFinancialAtom(
    id: 'tab_navigate',
    label: 'Follow-ups tab / count badge',
    financialClass: LabFollowUpsFinancialClass.notRequired,
    requirement: LabFollowUpsAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabFollowUpsFinancialAtom listChrome = LabFollowUpsFinancialAtom(
    id: 'search_columns',
    label: 'Search / clear / columns / table settings',
    financialClass: LabFollowUpsFinancialClass.notRequired,
    requirement: LabFollowUpsAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabFollowUpsFinancialAtom emptyLoadingError =
      LabFollowUpsFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: LabFollowUpsFinancialClass.notRequired,
        requirement: LabFollowUpsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const LabFollowUpsFinancialAtom rowSelect = LabFollowUpsFinancialAtom(
    id: 'row_select_detail',
    label: 'Row select → Follow-up detail dialog',
    financialClass: LabFollowUpsFinancialClass.notRequired,
    requirement: LabFollowUpsAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabFollowUpsFinancialAtom detailClose = LabFollowUpsFinancialAtom(
    id: 'detail_close_readonly',
    label: 'Detail Close (read-only footer)',
    financialClass: LabFollowUpsFinancialClass.notRequired,
    requirement: LabFollowUpsAtomPermissions.close,
    auditCode: 'NOT_REQUIRED',
  );

  static const LabFollowUpsFinancialAtom markCompleted =
      LabFollowUpsFinancialAtom(
        id: 'detail_mark_completed',
        label: 'Mark completed (callback worklist complete)',
        financialClass: LabFollowUpsFinancialClass.notBilled,
        requirement: LabFollowUpsAtomPermissions.markCompleted,
        auditCode: 'NOT_BILLED',
      );

  static const LabFollowUpsFinancialAtom reschedule = LabFollowUpsFinancialAtom(
    id: 'detail_reschedule',
    label: 'Reschedule follow-up',
    financialClass: LabFollowUpsFinancialClass.notBilled,
    requirement: LabFollowUpsAtomPermissions.reschedule,
    auditCode: 'NOT_BILLED',
  );

  static const LabFollowUpsFinancialAtom saveFollowUp =
      LabFollowUpsFinancialAtom(
        id: 'nested_save_follow_up',
        label: 'Save follow-up (nested reschedule dialog)',
        financialClass: LabFollowUpsFinancialClass.notBilled,
        requirement: LabFollowUpsAtomPermissions.saveFollowUp,
        auditCode: 'NOT_BILLED',
      );

  static const LabFollowUpsFinancialAtom realtimeListSync =
      LabFollowUpsFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation Follow-ups list refresh',
        financialClass: LabFollowUpsFinancialClass.notRequired,
        requirement: LabFollowUpsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only affordance reserved for outstanding patient ledger balances.
  /// Not mounted — Billing workspace remains system of record.
  static const LabFollowUpsFinancialAtom openBilling = LabFollowUpsFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (settle / invoice / waive / refund)',
    financialClass: LabFollowUpsFinancialClass.settle,
    requirement: LabFollowUpsAtomPermissions.tab,
    billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const LabFollowUpsFinancialAtom followUpVisitCharge =
      LabFollowUpsFinancialAtom(
        id: 'follow_up_visit_charge',
        label: 'Follow-up visit / consult charge on complete',
        financialClass: LabFollowUpsFinancialClass.createCharge,
        requirement: LabFollowUpsAtomPermissions.write,
        billingPath:
            'clinical-request-billing upsertClinicalRequestBilling (when mounted)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  /// Create Lab Order strip primary — deliberately absent on Follow-ups.
  static const LabFollowUpsFinancialAtom createLabOrderCharge =
      LabFollowUpsFinancialAtom(
        id: 'create_lab_order_charge',
        label: 'Create Lab Order (request-time charge)',
        financialClass: LabFollowUpsFinancialClass.createCharge,
        requirement: LabFollowUpsAtomPermissions.create,
        billingPath:
            'All / Awaiting results → persistLabOrderBilling / '
            'clinical-request-billing (not this tab)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  /// Result entry / save — not reachable from Follow-ups.
  static const LabFollowUpsFinancialAtom resultEntrySave =
      LabFollowUpsFinancialAtom(
        id: 'result_entry_save',
        label: 'Result entry / save / enter results (not payment-gated; not mounted)',
        financialClass: LabFollowUpsFinancialClass.notBilled,
        requirement: LabFollowUpsAtomPermissions.write,
        auditCode: 'NOT_BILLED',
        mounted: false,
      );

  static const LabFollowUpsFinancialAtom collectPayment =
      LabFollowUpsFinancialAtom(
        id: 'collect_payment',
        label: 'Collect payment / receive payment',
        financialClass: LabFollowUpsFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (facility billingPaymentMethods)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const LabFollowUpsFinancialAtom issueInvoiceAdjustRefund =
      LabFollowUpsFinancialAtom(
        id: 'issue_invoice_adjust_refund',
        label: 'Issue invoice / adjust / refund / reverse / write-off',
        financialClass: LabFollowUpsFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / credit-note / refund paths',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const List<LabFollowUpsFinancialAtom> atoms =
      <LabFollowUpsFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        detailClose,
        markCompleted,
        reschedule,
        saveFollowUp,
        realtimeListSync,
        openBilling,
        followUpVisitCharge,
        createLabOrderCharge,
        resultEntrySave,
        collectPayment,
        issueInvoiceAdjustRefund,
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static List<LabFollowUpsFinancialAtom> get billableAtoms => atoms
      .where(
        (LabFollowUpsFinancialAtom atom) =>
            atom.financialClass == LabFollowUpsFinancialClass.createCharge ||
            atom.financialClass == LabFollowUpsFinancialClass.settle ||
            atom.financialClass == LabFollowUpsFinancialClass.adjust ||
            atom.financialClass == LabFollowUpsFinancialClass.reverse ||
            atom.financialClass == LabFollowUpsFinancialClass.defer,
      )
      .toList(growable: false);

  static List<LabFollowUpsFinancialAtom> get mountedAtoms => atoms
      .where((LabFollowUpsFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (LabFollowUpsFinancialAtom atom) =>
        atom.financialClass == LabFollowUpsFinancialClass.notRequired ||
        atom.financialClass == LabFollowUpsFinancialClass.notBilled ||
        atom.financialClass == LabFollowUpsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get followUpsTabHasNoBillableActions =>
      billableAtoms.every((LabFollowUpsFinancialAtom atom) => !atom.mounted);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    LabFollowUpsFinancialClass financialClass,
  ) {
    return financialClass == LabFollowUpsFinancialClass.settle ||
        financialClass == LabFollowUpsFinancialClass.adjust ||
        financialClass == LabFollowUpsFinancialClass.reverse ||
        financialClass == LabFollowUpsFinancialClass.createCharge;
  }

  static String summary() =>
      'Lab Follow-ups is a hospital-wide callback worklist. Mark completed and '
      'reschedule stay NOT_BILLED. Create Order, result entry / save / enter results, '
      'and cashier settle live on other Lab tabs / Billing — never duplicated here.';
}

/// Documents Follow-ups financial scope for tests and audits.
const String labFollowUpsBillingScopeNote =
    'Lab Follow-ups is a hospital-wide scheduled callback worklist '
    '(FollowUpWorklistPanel, empty FollowUpWorklistScope). Mark completed and '
    'reschedule stay NOT_BILLED ops that update follow-up status/schedule only. '
    'Create Lab Order and result-entry / save / enter results are not mounted on '
    'this tab (save is not payment-gated elsewhere); they remain on All / '
    'Awaiting results / Processing / Completed / Critical '
    'and the Billing module. Visit charges must use clinical-request-billing / '
    'receive-payment when introduced. No Create Order primary on this tab.';
