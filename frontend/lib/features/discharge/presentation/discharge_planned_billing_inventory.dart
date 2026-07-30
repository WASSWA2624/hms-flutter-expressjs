import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum DischargePlannedFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Discharge Planned
/// (`/discharge?section=planned`).
@immutable
final class DischargePlannedFinancialAtom {
  const DischargePlannedFinancialAtom({
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
  final DischargePlannedFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/discharge?section=planned`.
///
/// Tab role: planned discharges awaiting clearance / finalize. Financial
/// clearance, pharmacy returns, outstanding balances, waivers, and final
/// invoices complete via Billing before discharge closure — this tab navigates
/// to Billing and never collects payment or issues invoices locally. Pharmacy
/// take-home requests post create-charges through clinical-request-billing.
/// Finalize is gated by `assertBillingSettledForDischarge` (Billing ledger).
abstract final class DischargePlannedBillingInventory {
  static const DischargePlannedFinancialAtom tab =
      DischargePlannedFinancialAtom(
        id: 'tab',
        label: 'Planned tab / count badge',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom listChrome =
      DischargePlannedFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom emptyLoadingError =
      DischargePlannedFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom rowSelect =
      DischargePlannedFinancialAtom(
        id: 'row_select',
        label: 'Row select → discharge detail',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom nextActionClearance =
      DischargePlannedFinancialAtom(
        id: 'next_action_clearance',
        label: 'Next action Manage clearance (planning / finalize dialog)',
        financialClass: DischargePlannedFinancialClass.notBilled,
        requirement: DischargePlannedAtomPermissions.nextActionClearance,
        auditCode: 'NOT_BILLED',
      );

  static const DischargePlannedFinancialAtom continueDischarge =
      DischargePlannedFinancialAtom(
        id: 'continue_discharge',
        label: 'Detail Continue / manage clearance / finalize discharge',
        financialClass: DischargePlannedFinancialClass.defer,
        requirement: DischargePlannedAtomPermissions.continueDischarge,
        billingPath:
            'finalizeDischarge → assertBillingSettledForDischarge (Billing ledger)',
      );

  static const DischargePlannedFinancialAtom openBilling =
      DischargePlannedFinancialAtom(
        id: 'open_billing',
        label:
            'Detail / planning / links Open billing (settle, invoice, waive, refund, returns)',
        financialClass: DischargePlannedFinancialClass.settle,
        requirement: DischargePlannedAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const DischargePlannedFinancialAtom requestBilling =
      DischargePlannedFinancialAtom(
        id: 'request_billing',
        label: 'Request final billing (removed — Open billing navigate only)',
        financialClass: DischargePlannedFinancialClass.settle,
        requirement: DischargePlannedAtomPermissions.requestBilling,
        billingPath: 'AppRoutes.billing (no local invoice create)',
        mounted: false,
      );

  static const DischargePlannedFinancialAtom requestPharmacy =
      DischargePlannedFinancialAtom(
        id: 'request_pharmacy',
        label: 'Detail Request medicines (take-home Rx)',
        financialClass: DischargePlannedFinancialClass.createCharge,
        requirement: DischargePlannedAtomPermissions.requestPharmacy,
        billingPath:
            'pharmacy-order create → buildPharmacyOrderBillingFromRequest / persistPharmacyOrderBilling',
      );

  static const DischargePlannedFinancialAtom billingPanel =
      DischargePlannedFinancialAtom(
        id: 'billing_panel',
        label: 'Detail invoices panel (status parity read)',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.billingPanel,
        billingPath: 'GET invoices?patient_id (Billing SoR status)',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom medicinesPanel =
      DischargePlannedFinancialAtom(
        id: 'medicines_panel',
        label: 'Detail pharmacy orders panel',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.medicinesPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom clearanceBillingStep =
      DischargePlannedFinancialAtom(
        id: 'clearance_billing_step',
        label: 'Clearance checklist billing step (parity read)',
        financialClass: DischargePlannedFinancialClass.notRequired,
        requirement: DischargePlannedAtomPermissions.nestedBillingRead,
        billingPath: 'Derived from Billing invoice open/paid parity',
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargePlannedFinancialAtom planningOpenInvoiceResolve =
      DischargePlannedFinancialAtom(
        id: 'planning_open_invoice_resolve',
        label: 'Planning dialog Continue on open invoice → Billing',
        financialClass: DischargePlannedFinancialClass.settle,
        requirement: DischargePlannedAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const DischargePlannedFinancialAtom printSummary =
      DischargePlannedFinancialAtom(
        id: 'print_summary',
        label: 'Print discharge summary (includes billing snapshot)',
        financialClass: DischargePlannedFinancialClass.noCharge,
        requirement: DischargePlannedAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const DischargePlannedFinancialAtom planDischarge =
      DischargePlannedFinancialAtom(
        id: 'plan_discharge',
        label: 'Planning dialog Save plan (already planned rows — rare)',
        financialClass: DischargePlannedFinancialClass.notBilled,
        requirement: DischargePlannedAtomPermissions.create,
        auditCode: 'NOT_BILLED',
      );

  static const DischargePlannedFinancialAtom finalizeWithOverride =
      DischargePlannedFinancialAtom(
        id: 'finalize_override',
        label: 'Finalize with override_reason (defer unpaid clearance)',
        financialClass: DischargePlannedFinancialClass.defer,
        requirement: DischargePlannedAtomPermissions.update,
        billingPath: 'finalizeDischarge override_reason (audited defer)',
      );

  static const DischargePlannedFinancialAtom absentInlineCollect =
      DischargePlannedFinancialAtom(
        id: 'absent_inline_collect',
        label: 'Inline receive-payment / issue-invoice / waive (forbidden)',
        financialClass: DischargePlannedFinancialClass.settle,
        requirement: DischargePlannedAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const DischargePlannedFinancialAtom pharmacyReturn =
      DischargePlannedFinancialAtom(
        id: 'pharmacy_return',
        label: 'Pharmacy return / reverse dispense (via Billing / Pharmacy)',
        financialClass: DischargePlannedFinancialClass.reverse,
        requirement: DischargePlannedAtomPermissions.openPharmacy,
        billingPath: 'Pharmacy + Billing reverse / credit linked to original',
        mounted: false,
      );

  static const List<DischargePlannedFinancialAtom> atoms =
      <DischargePlannedFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionClearance,
        continueDischarge,
        openBilling,
        requestBilling,
        requestPharmacy,
        billingPanel,
        medicinesPanel,
        clearanceBillingStep,
        planningOpenInvoiceResolve,
        printSummary,
        planDischarge,
        finalizeWithOverride,
        absentInlineCollect,
        pharmacyReturn,
      ];

  static List<DischargePlannedFinancialAtom> get billableAtoms => atoms
      .where(
        (DischargePlannedFinancialAtom atom) =>
            atom.financialClass ==
                DischargePlannedFinancialClass.createCharge ||
            atom.financialClass == DischargePlannedFinancialClass.settle ||
            atom.financialClass == DischargePlannedFinancialClass.adjust ||
            atom.financialClass == DischargePlannedFinancialClass.reverse ||
            atom.financialClass == DischargePlannedFinancialClass.defer,
      )
      .toList(growable: false);

  static List<DischargePlannedFinancialAtom> get mountedAtoms => atoms
      .where((DischargePlannedFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    DischargePlannedFinancialClass financialClass,
  ) {
    return financialClass == DischargePlannedFinancialClass.settle ||
        financialClass == DischargePlannedFinancialClass.adjust ||
        financialClass == DischargePlannedFinancialClass.reverse;
  }

  /// Every mounted billable atom must navigate or post via a Billing path.
  static bool get allMountedBillableAtomsWireThroughBilling {
    for (final DischargePlannedFinancialAtom atom in billableAtoms) {
      if (!atom.mounted) {
        continue;
      }
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }
}

/// Documents Planned financial scope for tests and audits.
const String dischargePlannedBillingScopeNote =
    'Discharge Planned is the planned-discharges worklist. Manage clearance / '
    'finalize stay clinical ops gated by Billing ledger settlement '
    '(assertBillingSettledForDischarge). Open billing navigates to the Billing '
    'workspace for settle / invoice / waive / refund / pharmacy returns. '
    'Request medicines posts create-charges via clinical-request-billing. No '
    'inline cashier, receive-payment, or local invoice create on this tab.';
