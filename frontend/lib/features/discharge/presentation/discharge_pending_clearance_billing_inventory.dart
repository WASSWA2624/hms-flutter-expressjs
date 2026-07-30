import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum DischargePendingClearanceFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Discharge Pending clearance
/// (`/discharge?section=pending-clearance`).
@immutable
final class DischargePendingClearanceFinancialAtom {
  const DischargePendingClearanceFinancialAtom({
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
  final DischargePendingClearanceFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/discharge?section=pending-clearance`.
///
/// Multi-department clearance desk. Billing clearance checklist reflects live
/// outstanding invoices and blocks unsafe closure. Financial clearance,
/// pharmacy returns, outstanding balances, waivers, and final invoices
/// complete via Billing — this tab navigates to Billing and never collects
/// payment or issues invoices locally. Pharmacy take-home requests post
/// create-charges through clinical-request-billing. Section gates per module
/// rights (pharmacy / billing / operations ∩).
abstract final class DischargePendingClearanceBillingInventory {
  static const DischargePendingClearanceFinancialAtom tab =
      DischargePendingClearanceFinancialAtom(
        id: 'tab',
        label: 'Pending clearance tab / count badge',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement: DischargePendingClearanceAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom listChrome =
      DischargePendingClearanceFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement: DischargePendingClearanceAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom emptyLoadingError =
      DischargePendingClearanceFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement: DischargePendingClearanceAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom rowSelect =
      DischargePendingClearanceFinancialAtom(
        id: 'row_select',
        label: 'Row select → discharge detail',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement: DischargePendingClearanceAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom nextActionPlan =
      DischargePendingClearanceFinancialAtom(
        id: 'next_action_plan',
        label: 'Next action Start plan',
        financialClass: DischargePendingClearanceFinancialClass.notBilled,
        requirement: DischargePendingClearanceAtomPermissions.nextActionPlan,
        auditCode: 'NOT_BILLED',
      );

  static const DischargePendingClearanceFinancialAtom nextActionClearance =
      DischargePendingClearanceFinancialAtom(
        id: 'next_action_clearance',
        label: 'Next action Manage clearance',
        financialClass: DischargePendingClearanceFinancialClass.notBilled,
        requirement:
            DischargePendingClearanceAtomPermissions.nextActionClearance,
        auditCode: 'NOT_BILLED',
      );

  static const DischargePendingClearanceFinancialAtom continueDischarge =
      DischargePendingClearanceFinancialAtom(
        id: 'continue_discharge',
        label: 'Detail Continue / plan / finalize discharge',
        financialClass: DischargePendingClearanceFinancialClass.defer,
        requirement:
            DischargePendingClearanceAtomPermissions.continueDischarge,
        billingPath:
            'finalizeDischarge → assertBillingSettledForDischarge (Billing ledger)',
      );

  static const DischargePendingClearanceFinancialAtom openBilling =
      DischargePendingClearanceFinancialAtom(
        id: 'open_billing',
        label:
            'Detail / links Open billing (settle, invoice, waive, refund, returns)',
        financialClass: DischargePendingClearanceFinancialClass.settle,
        requirement: DischargePendingClearanceAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const DischargePendingClearanceFinancialAtom requestBilling =
      DischargePendingClearanceFinancialAtom(
        id: 'request_billing',
        label: 'Request final billing (removed — Open billing navigate only)',
        financialClass: DischargePendingClearanceFinancialClass.settle,
        requirement: DischargePendingClearanceAtomPermissions.requestBilling,
        billingPath: 'AppRoutes.billing (no local invoice create)',
        mounted: false,
      );

  static const DischargePendingClearanceFinancialAtom requestPharmacy =
      DischargePendingClearanceFinancialAtom(
        id: 'request_pharmacy',
        label: 'Detail Request medicines (take-home Rx)',
        financialClass: DischargePendingClearanceFinancialClass.createCharge,
        requirement: DischargePendingClearanceAtomPermissions.requestPharmacy,
        billingPath:
            'pharmacy-order create → buildPharmacyOrderBillingFromRequest / persistPharmacyOrderBilling',
      );

  static const DischargePendingClearanceFinancialAtom billingPanel =
      DischargePendingClearanceFinancialAtom(
        id: 'billing_panel',
        label: 'Detail invoices panel (status parity read)',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement: DischargePendingClearanceAtomPermissions.billingPanel,
        billingPath: 'GET invoices?patient_id (Billing SoR status)',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom medicinesPanel =
      DischargePendingClearanceFinancialAtom(
        id: 'medicines_panel',
        label: 'Detail pharmacy orders panel',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement: DischargePendingClearanceAtomPermissions.medicinesPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom clearanceBillingStep =
      DischargePendingClearanceFinancialAtom(
        id: 'clearance_billing_step',
        label:
            'Clearance checklist billing step (live outstanding invoices gate)',
        financialClass: DischargePendingClearanceFinancialClass.notRequired,
        requirement:
            DischargePendingClearanceAtomPermissions.nestedBillingRead,
        billingPath:
            'Derived from Billing invoice open/paid parity; blocks finalize when open',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePendingClearanceFinancialAtom printSummary =
      DischargePendingClearanceFinancialAtom(
        id: 'print_summary',
        label: 'Print discharge summary (includes billing snapshot)',
        financialClass: DischargePendingClearanceFinancialClass.noCharge,
        requirement: DischargePendingClearanceAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const DischargePendingClearanceFinancialAtom planDischarge =
      DischargePendingClearanceFinancialAtom(
        id: 'plan_discharge',
        label: 'Planning dialog Save plan',
        financialClass: DischargePendingClearanceFinancialClass.notBilled,
        requirement: DischargePendingClearanceAtomPermissions.create,
        auditCode: 'NOT_BILLED',
      );

  static const DischargePendingClearanceFinancialAtom finalizeWithOverride =
      DischargePendingClearanceFinancialAtom(
        id: 'finalize_override',
        label: 'Finalize with override_reason (defer unpaid clearance)',
        financialClass: DischargePendingClearanceFinancialClass.defer,
        requirement: DischargePendingClearanceAtomPermissions.update,
        billingPath: 'finalizeDischarge override_reason (audited defer)',
      );

  static const DischargePendingClearanceFinancialAtom absentInlineCollect =
      DischargePendingClearanceFinancialAtom(
        id: 'absent_inline_collect',
        label: 'Inline receive-payment / issue-invoice / waive (forbidden)',
        financialClass: DischargePendingClearanceFinancialClass.settle,
        requirement: DischargePendingClearanceAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const List<DischargePendingClearanceFinancialAtom> atoms =
      <DischargePendingClearanceFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionPlan,
        nextActionClearance,
        continueDischarge,
        openBilling,
        requestBilling,
        requestPharmacy,
        billingPanel,
        medicinesPanel,
        clearanceBillingStep,
        printSummary,
        planDischarge,
        finalizeWithOverride,
        absentInlineCollect,
      ];

  static List<DischargePendingClearanceFinancialAtom> get billableAtoms =>
      atoms
          .where(
            (DischargePendingClearanceFinancialAtom atom) =>
                atom.mounted &&
                (atom.financialClass ==
                        DischargePendingClearanceFinancialClass.createCharge ||
                    atom.financialClass ==
                        DischargePendingClearanceFinancialClass.settle ||
                    atom.financialClass ==
                        DischargePendingClearanceFinancialClass.adjust ||
                    atom.financialClass ==
                        DischargePendingClearanceFinancialClass.reverse ||
                    atom.financialClass ==
                        DischargePendingClearanceFinancialClass.defer),
          )
          .toList(growable: false);

  static List<DischargePendingClearanceFinancialAtom> get mountedAtoms => atoms
      .where((DischargePendingClearanceFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    DischargePendingClearanceFinancialClass financialClass,
  ) {
    return financialClass == DischargePendingClearanceFinancialClass.settle ||
        financialClass == DischargePendingClearanceFinancialClass.adjust ||
        financialClass == DischargePendingClearanceFinancialClass.reverse;
  }

  /// Every settle/adjust/reverse/create/defer atom must navigate or post via Billing.
  static bool get allBillableAtomsWireThroughBilling {
    for (final DischargePendingClearanceFinancialAtom atom in billableAtoms) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}
