import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HrPayrollDraftsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on HR Payroll drafts (`/hr?section=payroll`).
@immutable
final class HrPayrollDraftsFinancialAtom {
  const HrPayrollDraftsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HrPayrollDraftsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/hr?section=payroll` (Payroll drafts).
///
/// Scope: tab chrome, payroll-draft worklist, next-action Process, work-item
/// detail (Preview / Process), nested preview + process dialogs, and HR
/// activity secondary opened from this tab. Payroll drafts are **staff
/// compensation** (`payroll_run` / `payroll_item`) — not patient Billing.
/// Amounts shown are gross/net pay for staff, never patient ledger balances.
/// Patient create-charge / collect / adjust / refund remain unmounted here;
/// if a staff-paid clinic service were ever added it must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment) and stay
/// separate from payroll process.
abstract final class HrPayrollDraftsBillingInventory {
  static const List<HrPayrollDraftsFinancialAtom> atoms =
      <HrPayrollDraftsFinancialAtom>[
        HrPayrollDraftsFinancialAtom(
          id: 'tab_navigate',
          label: 'Payroll drafts tab (hr:read ∩ hr-rosters)',
          financialClass: HrPayrollDraftsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: HrPayrollDraftsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: HrPayrollDraftsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'payroll_draft_status_display',
          label: 'Draft / period / run status columns (ops, not ledger)',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → payroll work-item detail',
          financialClass: HrPayrollDraftsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'next_action_process',
          label: 'Next action Process payroll (hr:write ∩ financial:approve)',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'detail_preview',
          label: 'Detail Preview payroll (compensation breakdown)',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'detail_process',
          label: 'Detail Process payroll',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'nested_preview_dialog',
          label: 'Nested preview dialog (gross/component breakdown)',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'nested_process_dialog',
          label: 'Nested process dialog (replace items / notes)',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'activity_secondary',
          label: 'HR activity secondary (timeline disclosure, removed)',
          financialClass: HrPayrollDraftsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
          mounted: false,
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'realtime_payroll_sync',
          label: 'Realtime / post-mutation payroll drafts sync',
          financialClass: HrPayrollDraftsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'tab_strip_primary',
          label: 'Tab-strip primary (none — Run payroll on staff detail)',
          financialClass: HrPayrollDraftsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'run_payroll_wizard',
          label: 'Run payroll wizard (Human Resources staff detail)',
          financialClass: HrPayrollDraftsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'patient_create_charge',
          label: 'Patient create-charge / clinical request billing',
          financialClass: HrPayrollDraftsFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment (patient)',
          financialClass: HrPayrollDraftsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HrPayrollDraftsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: HrPayrollDraftsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HrPayrollDraftsFinancialAtom> get billableClasses =>
      atoms.where(
        (HrPayrollDraftsFinancialAtom atom) =>
            atom.financialClass ==
                HrPayrollDraftsFinancialClass.createCharge ||
            atom.financialClass == HrPayrollDraftsFinancialClass.settle ||
            atom.financialClass == HrPayrollDraftsFinancialClass.adjust ||
            atom.financialClass == HrPayrollDraftsFinancialClass.reverse ||
            atom.financialClass == HrPayrollDraftsFinancialClass.defer,
      );

  static Iterable<HrPayrollDraftsFinancialAtom> get mountedAtoms =>
      atoms.where((HrPayrollDraftsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HrPayrollDraftsFinancialAtom atom) =>
        atom.financialClass == HrPayrollDraftsFinancialClass.notRequired ||
        atom.financialClass == HrPayrollDraftsFinancialClass.notBilled ||
        atom.financialClass == HrPayrollDraftsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as patient-billable.
  static bool get payrollDraftsTabHasNoBillableActions => billableClasses.every(
    (HrPayrollDraftsFinancialAtom atom) => !atom.mounted,
  );

  /// Process ∩ matches UI + backend: `hr:write` ∩ `financial:approve`.
  static bool canProcessPayroll(AppAccessPolicy policy) {
    return HrPayrollDraftsAtomPermissions.process.isAllowed(policy);
  }
}

/// Documents Payroll drafts financial scope for tests and audits.
const String hrPayrollDraftsBillingScopeNote =
    'Payroll drafts list staff compensation runs (payroll_run / payroll_item). '
    'Preview and Process are NOT_BILLED staff-pay ops — they must never create '
    'patient invoices, receive patient payments, or mutate patient balances. '
    'Run payroll wizard lives on Human Resources staff detail (off-tab). '
    'Patient create-charge / collect / adjust remain on the Billing module of '
    'record; financial:approve gates payroll process approval, not cashier UX.';

/// Convenience alias aligned with other tab helper naming.
bool hrPayrollDraftsTabHasNoBillableActions() {
  return HrPayrollDraftsBillingInventory.payrollDraftsTabHasNoBillableActions &&
      HrPayrollDraftsBillingInventory.allMountedAtomsExplicitlyNotBillable;
}
