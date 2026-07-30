import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum DischargeAllPatientsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Discharge All patients (`/discharge?section=all`).
@immutable
final class DischargeAllPatientsFinancialAtom {
  const DischargeAllPatientsFinancialAtom({
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
  final DischargeAllPatientsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/discharge?section=all`.
///
/// Financial clearance, pharmacy returns, outstanding balances, waivers, and
/// final invoices complete via Billing. This tab never collects payment or
/// issues invoices locally — it navigates to Billing and posts pharmacy
/// create-charges through clinical-request-billing.
abstract final class DischargeAllPatientsBillingInventory {
  static const DischargeAllPatientsFinancialAtom tab =
      DischargeAllPatientsFinancialAtom(
        id: 'tab',
        label: 'All patients tab / count badge',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom listChrome =
      DischargeAllPatientsFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom emptyLoadingError =
      DischargeAllPatientsFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom rowSelect =
      DischargeAllPatientsFinancialAtom(
        id: 'row_select',
        label: 'Row select → discharge detail',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom nextActionPlan =
      DischargeAllPatientsFinancialAtom(
        id: 'next_action_plan',
        label: 'Next action Start plan',
        financialClass: DischargeAllPatientsFinancialClass.notBilled,
        requirement: DischargeAllPatientsAtomPermissions.nextActionPlan,
        auditCode: 'NOT_BILLED',
      );

  static const DischargeAllPatientsFinancialAtom nextActionClearance =
      DischargeAllPatientsFinancialAtom(
        id: 'next_action_clearance',
        label: 'Next action Manage clearance',
        financialClass: DischargeAllPatientsFinancialClass.notBilled,
        requirement: DischargeAllPatientsAtomPermissions.nextActionClearance,
        auditCode: 'NOT_BILLED',
      );

  static const DischargeAllPatientsFinancialAtom nextActionPrint =
      DischargeAllPatientsFinancialAtom(
        id: 'next_action_print',
        label: 'Next action Print summary (completed)',
        financialClass: DischargeAllPatientsFinancialClass.noCharge,
        requirement: DischargeAllPatientsAtomPermissions.nextActionPrint,
        auditCode: 'NO_CHARGE',
      );

  static const DischargeAllPatientsFinancialAtom continueDischarge =
      DischargeAllPatientsFinancialAtom(
        id: 'continue_discharge',
        label: 'Detail Continue / plan / finalize discharge',
        financialClass: DischargeAllPatientsFinancialClass.defer,
        requirement: DischargeAllPatientsAtomPermissions.continueDischarge,
        billingPath:
            'finalizeDischarge → assertBillingSettledForDischarge (Billing ledger)',
        auditCode: null,
      );

  static const DischargeAllPatientsFinancialAtom openBilling =
      DischargeAllPatientsFinancialAtom(
        id: 'open_billing',
        label: 'Detail / links Open billing (settle, invoice, waive, refund)',
        financialClass: DischargeAllPatientsFinancialClass.settle,
        requirement: DischargeAllPatientsAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const DischargeAllPatientsFinancialAtom requestBilling =
      DischargeAllPatientsFinancialAtom(
        id: 'request_billing',
        label: 'Request final billing (alias → Open billing navigate)',
        financialClass: DischargeAllPatientsFinancialClass.settle,
        requirement: DischargeAllPatientsAtomPermissions.requestBilling,
        billingPath: 'AppRoutes.billing (no local invoice create)',
        mounted: false,
      );

  static const DischargeAllPatientsFinancialAtom requestPharmacy =
      DischargeAllPatientsFinancialAtom(
        id: 'request_pharmacy',
        label: 'Detail Request medicines (take-home Rx)',
        financialClass: DischargeAllPatientsFinancialClass.createCharge,
        requirement: DischargeAllPatientsAtomPermissions.requestPharmacy,
        billingPath:
            'pharmacy-order create → buildPharmacyOrderBillingFromRequest / persistPharmacyOrderBilling',
      );

  static const DischargeAllPatientsFinancialAtom billingPanel =
      DischargeAllPatientsFinancialAtom(
        id: 'billing_panel',
        label: 'Detail invoices panel (status parity read)',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.billingPanel,
        billingPath: 'GET invoices?patient_id (Billing SoR status)',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom medicinesPanel =
      DischargeAllPatientsFinancialAtom(
        id: 'medicines_panel',
        label: 'Detail pharmacy orders panel',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.medicinesPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom clearanceBillingStep =
      DischargeAllPatientsFinancialAtom(
        id: 'clearance_billing_step',
        label: 'Clearance checklist billing step',
        financialClass: DischargeAllPatientsFinancialClass.notRequired,
        requirement: DischargeAllPatientsAtomPermissions.nestedBillingRead,
        billingPath: 'Derived from Billing invoice open/paid parity',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeAllPatientsFinancialAtom printSummary =
      DischargeAllPatientsFinancialAtom(
        id: 'print_summary',
        label: 'Print discharge summary (includes billing snapshot)',
        financialClass: DischargeAllPatientsFinancialClass.noCharge,
        requirement: DischargeAllPatientsAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const DischargeAllPatientsFinancialAtom planDischarge =
      DischargeAllPatientsFinancialAtom(
        id: 'plan_discharge',
        label: 'Planning dialog Save plan',
        financialClass: DischargeAllPatientsFinancialClass.notBilled,
        requirement: DischargeAllPatientsAtomPermissions.create,
        auditCode: 'NOT_BILLED',
      );

  static const DischargeAllPatientsFinancialAtom finalizeWithOverride =
      DischargeAllPatientsFinancialAtom(
        id: 'finalize_override',
        label: 'Finalize with override_reason (defer unpaid clearance)',
        financialClass: DischargeAllPatientsFinancialClass.defer,
        requirement: DischargeAllPatientsAtomPermissions.update,
        billingPath: 'finalizeDischarge override_reason (audited defer)',
        auditCode: null,
      );

  static const List<DischargeAllPatientsFinancialAtom> atoms =
      <DischargeAllPatientsFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionPlan,
        nextActionClearance,
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
      ];

  static List<DischargeAllPatientsFinancialAtom> get billableAtoms => atoms
      .where(
        (DischargeAllPatientsFinancialAtom atom) =>
            atom.financialClass ==
                DischargeAllPatientsFinancialClass.createCharge ||
            atom.financialClass == DischargeAllPatientsFinancialClass.settle ||
            atom.financialClass == DischargeAllPatientsFinancialClass.adjust ||
            atom.financialClass == DischargeAllPatientsFinancialClass.reverse ||
            atom.financialClass == DischargeAllPatientsFinancialClass.defer,
      )
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    DischargeAllPatientsFinancialClass financialClass,
  ) {
    return financialClass == DischargeAllPatientsFinancialClass.settle ||
        financialClass == DischargeAllPatientsFinancialClass.adjust ||
        financialClass == DischargeAllPatientsFinancialClass.reverse;
  }
}
