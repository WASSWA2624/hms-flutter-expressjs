import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HrHumanResourcesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on HR Human resources (`/hr?section=staff`).
@immutable
final class HrHumanResourcesFinancialAtom {
  const HrHumanResourcesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HrHumanResourcesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/hr?section=staff` (Human resources / staff directory).
///
/// Scope: tab chrome, Add staff, staff worklist, next-actions, staff detail
/// (roles / assignments / leave / availability / shifts / compensation), and
/// nested dialogs (onboarding, compensation, payroll wizard, offboard, roster
/// / leave / access). Payroll and compensation are **staff pay structure**
/// (`staff_compensation` / `payroll_run`) — not patient Billing. Consultation
/// fee on the profile is price-catalog config for later OPD/clinical-request
/// charges; this tab never collects patient revenue. Patient create-charge /
/// collect / adjust remain unmounted; if a staff-paid clinic service were
/// added it must post via Billing and stay separate from payroll.
abstract final class HrHumanResourcesBillingInventory {
  static const List<HrHumanResourcesFinancialAtom> atoms =
      <HrHumanResourcesFinancialAtom>[
        HrHumanResourcesFinancialAtom(
          id: 'tab_navigate',
          label: 'Human resources tab (hr:read ∩ hr-rosters)',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'add_staff',
          label: 'Add staff (strip primary + onboarding dialog)',
          financialClass: HrHumanResourcesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'activity_disclosure',
          label: 'HR activity progressive disclosure',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → staff detail dialog',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'next_action_assign_or_review',
          label: 'Next action Assign department/position / Review profile',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'edit_staff',
          label: 'Edit staff (onboarding dialog)',
          financialClass: HrHumanResourcesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'consultation_fee_catalog',
          label:
              'Consultation fee display/edit (price catalog, not cash collect)',
          financialClass: HrHumanResourcesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'compensation_mutate',
          label: 'Compensation dialog / rate card (staff pay structure)',
          financialClass: HrHumanResourcesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'run_payroll_wizard',
          label: 'Run payroll wizard (staff compensation draft → process)',
          financialClass: HrHumanResourcesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'offboard_schedule_final_payroll',
          label: 'Offboard + schedule final payroll (staff payroll draft)',
          financialClass: HrHumanResourcesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'roster_leave_access_ops',
          label:
              'Assign dept/position / availability / shift / leave / role / access',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'detail_sections_roles_assignments_leave_shifts_comp',
          label: 'Detail sibling sections (roles…compensation)',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'success_validation_feedback',
          label: 'Success snackbar / form validation feedback',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation staff directory sync',
          financialClass: HrHumanResourcesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrHumanResourcesFinancialAtom(
          id: 'patient_create_charge',
          label: 'Patient create-charge / clinical request billing',
          financialClass: HrHumanResourcesFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HrHumanResourcesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment (patient)',
          financialClass: HrHumanResourcesFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HrHumanResourcesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: HrHumanResourcesFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HrHumanResourcesFinancialAtom> get billableClasses =>
      atoms.where(
        (HrHumanResourcesFinancialAtom atom) =>
            atom.financialClass ==
                HrHumanResourcesFinancialClass.createCharge ||
            atom.financialClass == HrHumanResourcesFinancialClass.settle ||
            atom.financialClass == HrHumanResourcesFinancialClass.adjust ||
            atom.financialClass == HrHumanResourcesFinancialClass.reverse ||
            atom.financialClass == HrHumanResourcesFinancialClass.defer,
      );

  static Iterable<HrHumanResourcesFinancialAtom> get mountedAtoms =>
      atoms.where((HrHumanResourcesFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HrHumanResourcesFinancialAtom atom) =>
        atom.financialClass == HrHumanResourcesFinancialClass.notRequired ||
        atom.financialClass == HrHumanResourcesFinancialClass.notBilled ||
        atom.financialClass == HrHumanResourcesFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as patient-billable.
  static bool get humanResourcesTabHasNoBillableActions =>
      billableClasses.every((HrHumanResourcesFinancialAtom atom) => !atom.mounted);

  static bool canRunPayroll(AppAccessPolicy policy) {
    return HrHumanResourcesAtomPermissions.runPayroll.isAllowed(policy);
  }

  static bool canMutateCompensation(AppAccessPolicy policy) {
    return HrHumanResourcesAtomPermissions.compensation.isAllowed(policy);
  }
}

/// Documents Human resources financial scope for tests and audits.
const String hrHumanResourcesBillingScopeNote =
    'Human resources (staff directory) manages roster identity, compensation '
    'rate cards, and payroll drafts (payroll_run / payroll_item). Those are '
    'NOT_BILLED staff-pay ops — they must never create patient invoices, '
    'receive patient payments, or mutate patient balances. Consultation fee '
    'is price-catalog config for later clinical-request Billing. Patient '
    'create-charge / collect / adjust remain on the Billing module of record.';

/// Convenience alias aligned with other tab helper naming.
bool hrHumanResourcesTabHasNoBillableActions() {
  return HrHumanResourcesBillingInventory.humanResourcesTabHasNoBillableActions &&
      HrHumanResourcesBillingInventory.allMountedAtomsExplicitlyNotBillable;
}
