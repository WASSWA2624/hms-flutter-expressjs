import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HrShiftsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on HR Shifts (`/hr?section=shifts`).
@immutable
final class HrShiftsFinancialAtom {
  const HrShiftsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HrShiftsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/hr?section=shifts` (roster templates / shifts).
///
/// Scope: tab chrome, queue switcher (roster drafts / unassigned / overdue /
/// swap requests), worklist, next-actions, work-item detail, schedule-template
/// manage/create/edit/delete/detail dialogs, preview/generate/publish roster,
/// override shift, approve/reject swap, and HR activity disclosure opened from
/// this tab.
///
/// Roster and shift mutations are **staff scheduling ops**, not patient
/// revenue. Staff compensation / payroll drafts live on the Payroll drafts
/// tab and must stay out of patient Billing. If a staff-paid clinic service
/// were ever mounted here, it must post via shared Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger.
abstract final class HrShiftsBillingInventory {
  static const List<HrShiftsFinancialAtom> atoms = <HrShiftsFinancialAtom>[
    HrShiftsFinancialAtom(
      id: 'tab_navigate',
      label: 'Shifts tab (hr:read ∩ hr-rosters)',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'schedule_templates_chrome',
      label: 'Schedule templates (strip primary → manage dialog)',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'hr_activity_disclosure',
      label: 'HR activity progressive disclosure',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'queue_switcher_search_filters_columns',
      label: 'Queue switcher / search / filters / columns / pagination',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'empty_error_retry_loading',
      label: 'Empty / loading / error / retry states',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'success_validation_feedback',
      label: 'Success snackbar / form validation feedback',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'row_select_work_item_detail',
      label: 'Row select → work-item detail',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'next_action_publish_roster',
      label: 'Next action Publish roster',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'next_action_override_shift',
      label: 'Next action Override shift',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'next_action_approve_reject_swap',
      label: 'Next action Approve / Reject swap',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'detail_preview_generate_roster',
      label: 'Detail Preview / Generate roster',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'detail_publish_roster',
      label: 'Detail Publish roster',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'detail_override_shift',
      label: 'Detail Override shift',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'detail_approve_reject_swap',
      label: 'Detail Approve / Reject swap',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'template_create_edit',
      label: 'Schedule template Create / Edit',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'template_delete',
      label: 'Schedule template Delete',
      financialClass: HrShiftsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    HrShiftsFinancialAtom(
      id: 'template_detail_weekly_schedule',
      label: 'Schedule template detail / weekly schedule (read-only)',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'realtime_worklist_sync',
      label: 'Realtime / post-mutation Shifts worklist sync',
      financialClass: HrShiftsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    HrShiftsFinancialAtom(
      id: 'staff_payroll_compensation',
      label: 'Staff payroll / compensation (Payroll drafts tab)',
      financialClass: HrShiftsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
      mounted: false,
    ),
    HrShiftsFinancialAtom(
      id: 'patient_clinical_charge_via_shift',
      label: 'Patient clinical charge implied by shift / roster action',
      financialClass: HrShiftsFinancialClass.createCharge,
      // Reserved: must post via Billing clinical-request-billing when mounted.
      auditCode: 'REQUIRES_BILLING',
      mounted: false,
    ),
    HrShiftsFinancialAtom(
      id: 'collect_payment',
      label: 'Collect payment / receive payment',
      financialClass: HrShiftsFinancialClass.settle,
      auditCode: 'REQUIRES_BILLING',
      mounted: false,
    ),
    HrShiftsFinancialAtom(
      id: 'issue_invoice_adjust_refund',
      label: 'Issue invoice / adjust / refund / reverse / write-off',
      financialClass: HrShiftsFinancialClass.adjust,
      auditCode: 'REQUIRES_BILLING',
      mounted: false,
    ),
  ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HrShiftsFinancialAtom> get billableClasses => atoms.where(
    (HrShiftsFinancialAtom atom) =>
        atom.financialClass == HrShiftsFinancialClass.createCharge ||
        atom.financialClass == HrShiftsFinancialClass.settle ||
        atom.financialClass == HrShiftsFinancialClass.adjust ||
        atom.financialClass == HrShiftsFinancialClass.reverse ||
        atom.financialClass == HrShiftsFinancialClass.defer,
  );

  static Iterable<HrShiftsFinancialAtom> get mountedAtoms =>
      atoms.where((HrShiftsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HrShiftsFinancialAtom atom) =>
        atom.financialClass == HrShiftsFinancialClass.notRequired ||
        atom.financialClass == HrShiftsFinancialClass.notBilled ||
        atom.financialClass == HrShiftsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get shiftsTabHasNoBillableActions => billableClasses.every(
    (HrShiftsFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Shifts financial scope for tests and audits.
const String hrShiftsBillingScopeNote =
    'HR Shifts is roster templates and shift scheduling. Publish roster, '
    'override shift, approve/reject swap, and schedule-template CRUD stay '
    'NOT_BILLED internal ops (audited). Coverage / gap / assignment counts are '
    'NOT_BILLED operational telemetry, not a patient ledger balance. Staff '
    'compensation and payroll drafts are separate (Payroll drafts tab) and '
    'must not mix into patient Billing. Patient clinical charges and '
    'collect/adjust/refund affordances are not mounted on this tab; if '
    'introduced they must post through the Billing module of record.';
