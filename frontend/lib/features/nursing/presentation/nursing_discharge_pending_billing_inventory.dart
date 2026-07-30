import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum NursingDischargePendingFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Nursing Discharge pending
/// (`/nursing?scope=discharge-pending`).
@immutable
final class NursingDischargePendingFinancialAtom {
  const NursingDischargePendingFinancialAtom({
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
  final NursingDischargePendingFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/nursing?scope=discharge-pending`.
///
/// Tab role: nursing discharge checks. Billable nursing procedures/consumables,
/// medication administrations tied to chargeable Rx items, and discharge
/// financial checks post through Billing / clinical-request-billing — never
/// nurse-local tallies. Nursing clearance uses ipd-flow
/// `update-discharge-clearance` (`nursing_cleared`); `billing_cleared` is
/// derived from the live Billing ledger. Settle / adjust / refund stay on the
/// Billing workspace. Billing clearance panel needs `billing:read`.
abstract final class NursingDischargePendingBillingInventory {
  static const NursingDischargePendingFinancialAtom tab =
      NursingDischargePendingFinancialAtom(
        id: 'tab',
        label: 'Discharge pending tab / count badge',
        financialClass: NursingDischargePendingFinancialClass.notRequired,
        requirement: NursingDischargePendingAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingDischargePendingFinancialAtom listChrome =
      NursingDischargePendingFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / shift context / pagination',
        financialClass: NursingDischargePendingFinancialClass.notRequired,
        requirement: NursingDischargePendingAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingDischargePendingFinancialAtom emptyLoadingError =
      NursingDischargePendingFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: NursingDischargePendingFinancialClass.notRequired,
        requirement: NursingDischargePendingAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingDischargePendingFinancialAtom rowSelect =
      NursingDischargePendingFinancialAtom(
        id: 'row_select',
        label: 'Row select → patient detail',
        financialClass: NursingDischargePendingFinancialClass.notRequired,
        requirement: NursingDischargePendingAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingDischargePendingFinancialAtom nextActionDischarge =
      NursingDischargePendingFinancialAtom(
        id: 'next_action_discharge',
        label: 'Next action Discharge clearance',
        financialClass: NursingDischargePendingFinancialClass.defer,
        requirement:
            NursingDischargePendingAtomPermissions.nextActionDischarge,
        billingPath:
            'ipdFlows/.../update-discharge-clearance → '
            'isBillingSettledForPatient (billing_cleared from ledger)',
      );

  static const NursingDischargePendingFinancialAtom recordVitals =
      NursingDischargePendingFinancialAtom(
        id: 'record_vitals',
        label: 'Record vitals (clinical charting)',
        financialClass: NursingDischargePendingFinancialClass.notBilled,
        requirement: NursingDischargePendingAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const NursingDischargePendingFinancialAtom administerMedication =
      NursingDischargePendingFinancialAtom(
        id: 'administer_medication',
        label: 'Administer medication (charge at prescribe / Rx)',
        financialClass: NursingDischargePendingFinancialClass.notBilled,
        requirement:
            NursingDischargePendingAtomPermissions.administerMedication,
        auditCode: 'NOT_BILLED',
      );

  static const NursingDischargePendingFinancialAtom prescribe =
      NursingDischargePendingFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe medication (pharmacy order)',
        financialClass: NursingDischargePendingFinancialClass.createCharge,
        requirement: NursingDischargePendingAtomPermissions.prescribe,
        billingPath:
            'createPharmacyOrder → mergeClinicalRequestBilling → '
            'persistPharmacyOrderBilling',
      );

  static const NursingDischargePendingFinancialAtom orderLab =
      NursingDischargePendingFinancialAtom(
        id: 'order_lab',
        label: 'Order lab',
        financialClass: NursingDischargePendingFinancialClass.createCharge,
        requirement: NursingDischargePendingAtomPermissions.orderLab,
        billingPath:
            'createLabOrder → mergeClinicalRequestBilling → '
            'clinical-request-billing',
      );

  static const NursingDischargePendingFinancialAtom orderRadiology =
      NursingDischargePendingFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology',
        financialClass: NursingDischargePendingFinancialClass.createCharge,
        requirement: NursingDischargePendingAtomPermissions.orderRadiology,
        billingPath:
            'createRadiologyOrder → mergeClinicalRequestBillingIntoRequestDetails '
            '→ clinical-request-billing',
      );

  static const NursingDischargePendingFinancialAtom addNote =
      NursingDischargePendingFinancialAtom(
        id: 'add_note',
        label: 'Add nursing note (optional nursing service charge)',
        financialClass: NursingDischargePendingFinancialClass.createCharge,
        requirement: NursingDischargePendingAtomPermissions.addNote,
        billingPath:
            'ipdFlows/.../add-nursing-note → persistNursingServiceBilling '
            '(when billed)',
      );

  static const NursingDischargePendingFinancialAtom checklistNotes =
      NursingDischargePendingFinancialAtom(
        id: 'checklist_notes',
        label: 'Admission checklist notes (identity / allergies / belongings)',
        financialClass: NursingDischargePendingFinancialClass.notBilled,
        requirement: NursingDischargePendingAtomPermissions.checklistWrite,
        auditCode: 'NOT_BILLED',
      );

  static const NursingDischargePendingFinancialAtom dischargeClearance =
      NursingDischargePendingFinancialAtom(
        id: 'discharge_clearance',
        label: 'Discharge clearance dialog (nursing + Billing ledger gate)',
        financialClass: NursingDischargePendingFinancialClass.defer,
        requirement: NursingDischargePendingAtomPermissions.write,
        billingPath:
            'recordDischargeClearance → updateDischargeClearance '
            '(nursing_cleared) + checklist note; billing_cleared from ledger',
      );

  static const NursingDischargePendingFinancialAtom billingPanel =
      NursingDischargePendingFinancialAtom(
        id: 'billing_panel',
        label: 'Detail billing clearance panel (ledger status parity)',
        financialClass: NursingDischargePendingFinancialClass.defer,
        requirement: NursingDischargePendingAtomPermissions.billingPanel,
        billingPath:
            'clearance_snapshot.billing_cleared from Billing ledger parity',
      );

  static const NursingDischargePendingFinancialAtom openBilling =
      NursingDischargePendingFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: NursingDischargePendingFinancialClass.defer,
        requirement: NursingDischargePendingAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const NursingDischargePendingFinancialAtom printSummary =
      NursingDischargePendingFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: NursingDischargePendingFinancialClass.notRequired,
        requirement: NursingDischargePendingAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingDischargePendingFinancialAtom openIcu =
      NursingDischargePendingFinancialAtom(
        id: 'open_icu',
        label: 'Open ICU',
        financialClass: NursingDischargePendingFinancialClass.notRequired,
        requirement: NursingDischargePendingAtomPermissions.openIcu,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingDischargePendingFinancialAtom procedure =
      NursingDischargePendingFinancialAtom(
        id: 'nursing_procedure',
        label: 'Billable nursing procedure order',
        financialClass: NursingDischargePendingFinancialClass.createCharge,
        requirement: NursingDischargePendingAtomPermissions.write,
        billingPath: 'clinical-request-billing / persistNursingServiceBilling',
        mounted: false,
      );

  static const NursingDischargePendingFinancialAtom consumable =
      NursingDischargePendingFinancialAtom(
        id: 'consumable',
        label: 'Ward consumable charge',
        financialClass: NursingDischargePendingFinancialClass.createCharge,
        requirement: NursingDischargePendingAtomPermissions.write,
        billingPath: 'persistConsumableBilling',
        mounted: false,
      );

  static const NursingDischargePendingFinancialAtom collectPayment =
      NursingDischargePendingFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: NursingDischargePendingFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath:
            'Billing receive-payment (not mounted on Discharge pending)',
        mounted: false,
      );

  static const NursingDischargePendingFinancialAtom adjustRefund =
      NursingDischargePendingFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: NursingDischargePendingFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<NursingDischargePendingFinancialAtom> all =
      <NursingDischargePendingFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionDischarge,
        recordVitals,
        administerMedication,
        prescribe,
        orderLab,
        orderRadiology,
        addNote,
        checklistNotes,
        dischargeClearance,
        billingPanel,
        openBilling,
        printSummary,
        openIcu,
        procedure,
        consumable,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<NursingDischargePendingFinancialAtom> get mountedAtoms =>
      all.where((NursingDischargePendingFinancialAtom atom) => atom.mounted);

  static Iterable<NursingDischargePendingFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (NursingDischargePendingFinancialAtom atom) =>
            atom.financialClass ==
                NursingDischargePendingFinancialClass.createCharge ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.settle ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.adjust ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.reverse ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.defer,
      );

  static bool forbidsInlineCashier(
    NursingDischargePendingFinancialClass actionClass,
  ) {
    return switch (actionClass) {
      NursingDischargePendingFinancialClass.settle ||
      NursingDischargePendingFinancialClass.adjust ||
      NursingDischargePendingFinancialClass.reverse => true,
      _ => false,
    };
  }

  static bool get allBillableAtomsWireThroughBilling {
    for (final NursingDischargePendingFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  static String summary() =>
      'Discharge pending posts optional nursing service charges and '
      'prescribe / lab / radiology through clinical-request-billing. Discharge '
      'clearance sets nursing_cleared via updateDischargeClearance; '
      'billing_cleared derives from Billing ledger. Open billing navigates '
      'Billing. Medication admin stays NOT_BILLED (charge at Rx). No module cashier.';
}

/// Documents Discharge pending financial scope for tests and audits.
const String nursingDischargePendingBillingScopeNote =
    'Nursing Discharge pending is nursing discharge checks. Billable nursing '
    'notes use ipdFlows add-nursing-note → persistNursingServiceBilling. '
    'Clinical orders reuse mergeClinicalRequestBilling. Discharge clearance '
    'uses updateDischargeClearance with ledger-derived billing_cleared. '
    'Settle / adjust / refund navigate to Billing — never a parallel cash ledger.';
