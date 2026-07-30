import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum DischargeCompletedFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Discharge Completed
/// (`/discharge?section=completed`).
@immutable
final class DischargeCompletedFinancialAtom {
  const DischargeCompletedFinancialAtom({
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
  final DischargeCompletedFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/discharge?section=completed`.
///
/// Prefer-read desk for discharged patients. Financial clearance, pharmacy
/// returns, outstanding balances, waivers, and final invoices complete via
/// Billing — this tab navigates to Billing and never collects payment or
/// issues invoices locally. Pharmacy take-home requests post create-charges
/// through clinical-request-billing. Continue / finalize are absent once
/// completed.
abstract final class DischargeCompletedBillingInventory {
  static const DischargeCompletedFinancialAtom tab =
      DischargeCompletedFinancialAtom(
        id: 'tab',
        label: 'Completed tab / count badge',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom listChrome =
      DischargeCompletedFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom emptyLoadingError =
      DischargeCompletedFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom rowSelect =
      DischargeCompletedFinancialAtom(
        id: 'row_select',
        label: 'Row select → discharge detail',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom nextActionPrint =
      DischargeCompletedFinancialAtom(
        id: 'next_action_print',
        label: 'Next action Print summary (completed rows)',
        financialClass: DischargeCompletedFinancialClass.noCharge,
        requirement: DischargeCompletedAtomPermissions.nextActionPrint,
        auditCode: 'NO_CHARGE',
      );

  static const DischargeCompletedFinancialAtom continueDischarge =
      DischargeCompletedFinancialAtom(
        id: 'continue_discharge',
        label: 'Detail Continue / plan / finalize (absent when completed)',
        financialClass: DischargeCompletedFinancialClass.defer,
        requirement: DischargeCompletedAtomPermissions.continueDischarge,
        billingPath:
            'finalizeDischarge → assertBillingSettledForDischarge (Billing ledger)',
        mounted: false,
      );

  static const DischargeCompletedFinancialAtom openBilling =
      DischargeCompletedFinancialAtom(
        id: 'open_billing',
        label:
            'Detail / links Open billing (settle, invoice, waive, refund, returns)',
        financialClass: DischargeCompletedFinancialClass.settle,
        requirement: DischargeCompletedAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const DischargeCompletedFinancialAtom requestBilling =
      DischargeCompletedFinancialAtom(
        id: 'request_billing',
        label: 'Request final billing (removed — Open billing navigate only)',
        financialClass: DischargeCompletedFinancialClass.settle,
        requirement: DischargeCompletedAtomPermissions.requestBilling,
        billingPath: 'AppRoutes.billing (no local invoice create)',
        mounted: false,
      );

  static const DischargeCompletedFinancialAtom requestPharmacy =
      DischargeCompletedFinancialAtom(
        id: 'request_pharmacy',
        label: 'Detail Request medicines (take-home Rx)',
        financialClass: DischargeCompletedFinancialClass.createCharge,
        requirement: DischargeCompletedAtomPermissions.requestPharmacy,
        billingPath:
            'pharmacy-order create → buildPharmacyOrderBillingFromRequest / persistPharmacyOrderBilling',
      );

  static const DischargeCompletedFinancialAtom billingPanel =
      DischargeCompletedFinancialAtom(
        id: 'billing_panel',
        label: 'Detail invoices panel (status parity read)',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.billingPanel,
        billingPath: 'GET invoices?patient_id (Billing SoR status)',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom medicinesPanel =
      DischargeCompletedFinancialAtom(
        id: 'medicines_panel',
        label: 'Detail pharmacy orders panel',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.medicinesPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom clearanceBillingStep =
      DischargeCompletedFinancialAtom(
        id: 'clearance_billing_step',
        label: 'Clearance checklist billing step (historical read)',
        financialClass: DischargeCompletedFinancialClass.notRequired,
        requirement: DischargeCompletedAtomPermissions.nestedBillingRead,
        billingPath: 'Derived from Billing invoice open/paid parity',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeCompletedFinancialAtom printSummary =
      DischargeCompletedFinancialAtom(
        id: 'print_summary',
        label: 'Print discharge summary (includes billing snapshot)',
        financialClass: DischargeCompletedFinancialClass.noCharge,
        requirement: DischargeCompletedAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const DischargeCompletedFinancialAtom planDischarge =
      DischargeCompletedFinancialAtom(
        id: 'plan_discharge',
        label: 'Planning dialog (not opened from completed next-action)',
        financialClass: DischargeCompletedFinancialClass.notBilled,
        requirement: DischargeCompletedAtomPermissions.create,
        auditCode: 'NOT_BILLED',
        mounted: false,
      );

  static const DischargeCompletedFinancialAtom finalizeWithOverride =
      DischargeCompletedFinancialAtom(
        id: 'finalize_override',
        label: 'Finalize with override_reason (already completed — n/a)',
        financialClass: DischargeCompletedFinancialClass.defer,
        requirement: DischargeCompletedAtomPermissions.update,
        billingPath: 'finalizeDischarge override_reason (audited defer)',
        mounted: false,
      );

  static const DischargeCompletedFinancialAtom absentInlineCollect =
      DischargeCompletedFinancialAtom(
        id: 'absent_inline_collect',
        label: 'Inline receive-payment / issue-invoice / waive (forbidden)',
        financialClass: DischargeCompletedFinancialClass.settle,
        requirement: DischargeCompletedAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const List<DischargeCompletedFinancialAtom> atoms =
      <DischargeCompletedFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionPrint,
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

  static List<DischargeCompletedFinancialAtom> get billableAtoms => atoms
      .where(
        (DischargeCompletedFinancialAtom atom) =>
            atom.mounted &&
            (atom.financialClass ==
                    DischargeCompletedFinancialClass.createCharge ||
                atom.financialClass ==
                    DischargeCompletedFinancialClass.settle ||
                atom.financialClass ==
                    DischargeCompletedFinancialClass.adjust ||
                atom.financialClass ==
                    DischargeCompletedFinancialClass.reverse ||
                atom.financialClass == DischargeCompletedFinancialClass.defer),
      )
      .toList(growable: false);

  static List<DischargeCompletedFinancialAtom> get mountedAtoms => atoms
      .where((DischargeCompletedFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    DischargeCompletedFinancialClass financialClass,
  ) {
    return financialClass == DischargeCompletedFinancialClass.settle ||
        financialClass == DischargeCompletedFinancialClass.adjust ||
        financialClass == DischargeCompletedFinancialClass.reverse;
  }

  /// Every settle/adjust/reverse atom must navigate or post via Billing path.
  static bool get allBillableAtomsWireThroughBilling {
    for (final DischargeCompletedFinancialAtom atom in billableAtoms) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}
