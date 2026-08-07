import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HrLeaveRequestsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on HR Leave requests (`/hr?…=leave`).
@immutable
final class HrLeaveRequestsFinancialAtom {
  const HrLeaveRequestsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HrLeaveRequestsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/hr?section=leave-requests` (Leave requests tab).
///
/// Scope: tab chrome, Filters queue facet (leave + swap), leave/swap worklist,
/// next-actions (approve), detail dialog (approve / reject), request-leave
/// dialog (search trailing), and nested confirm/reason dialogs opened from
/// this tab. Leave/swap are **staff attendance / roster ops** — request/
/// approve/reject update `staff_leave` / swap status with
/// audit + realtime. `UNPAID` leave type is compensation eligibility metadata
/// for payroll (Payroll drafts tab), not patient revenue. Patient Billing and
/// payroll processing are not mounted here.
abstract final class HrLeaveRequestsBillingInventory {
  static const List<HrLeaveRequestsFinancialAtom> atoms =
      <HrLeaveRequestsFinancialAtom>[
        HrLeaveRequestsFinancialAtom(
          id: 'tab_navigate',
          label: 'Leave requests tab (hr:read ∩ hr-rosters)',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'leave_status_type_columns',
          label: 'Leave type / status / period columns (ops, not ledger)',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'unpaid_leave_type_metadata',
          label:
              'UNPAID leave type (payroll eligibility metadata, not patient charge)',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'activity_disclosure',
          label: 'HR activity progressive disclosure (removed)',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
          mounted: false,
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → leave work-item detail',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'request_leave',
          label: 'Request leave (search trailing + dialog)',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'next_action_approve_leave',
          label: 'Next action Approve leave',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'detail_approve_leave',
          label: 'Detail Approve leave',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'detail_reject_leave',
          label: 'Detail Reject leave',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'nested_reason_dialogs',
          label: 'Nested approve / reject reason dialogs',
          financialClass: HrLeaveRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'success_validation_feedback',
          label: 'Success snackbar / form validation feedback',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation leave queue sync',
          financialClass: HrLeaveRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'payroll_process_off_tab',
          label: 'Process payroll draft (Payroll drafts tab only)',
          financialClass: HrLeaveRequestsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'patient_clinical_charge_via_leave',
          label: 'Patient clinical charge implied by leave action',
          financialClass: HrLeaveRequestsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: HrLeaveRequestsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HrLeaveRequestsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: HrLeaveRequestsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HrLeaveRequestsFinancialAtom> get billableClasses =>
      atoms.where(
        (HrLeaveRequestsFinancialAtom atom) =>
            atom.financialClass ==
                HrLeaveRequestsFinancialClass.createCharge ||
            atom.financialClass == HrLeaveRequestsFinancialClass.settle ||
            atom.financialClass == HrLeaveRequestsFinancialClass.adjust ||
            atom.financialClass == HrLeaveRequestsFinancialClass.reverse ||
            atom.financialClass == HrLeaveRequestsFinancialClass.defer,
      );

  static Iterable<HrLeaveRequestsFinancialAtom> get mountedAtoms =>
      atoms.where((HrLeaveRequestsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HrLeaveRequestsFinancialAtom atom) =>
        atom.financialClass == HrLeaveRequestsFinancialClass.notRequired ||
        atom.financialClass == HrLeaveRequestsFinancialClass.notBilled ||
        atom.financialClass == HrLeaveRequestsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get leaveRequestsTabHasNoBillableActions => billableClasses.every(
    (HrLeaveRequestsFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Leave requests financial scope for tests and audits.
const String hrLeaveRequestsBillingScopeNote =
    'HR Leave requests covers staff leave request/approve/reject. Mutations '
    'update staff_leave with audit and realtime sync and stay NOT_BILLED '
    'internal ops; they do not create patient invoice lines. UNPAID leave type '
    'is payroll eligibility metadata (Payroll drafts), not a patient ledger '
    'balance. Payment collection and invoice issuance remain on Billing; '
    'payroll processing stays on the Payroll drafts tab.';
