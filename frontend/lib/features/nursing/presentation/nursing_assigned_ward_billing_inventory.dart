import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum NursingAssignedWardFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Nursing Assigned ward
/// (`/nursing?scope=assigned-ward`).
@immutable
final class NursingAssignedWardFinancialAtom {
  const NursingAssignedWardFinancialAtom({
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
  final NursingAssignedWardFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/nursing?scope=assigned-ward`.
///
/// Tab role: ABAC ward/assignment-scoped worklist. Billable nursing procedures,
/// consumables, medication administrations tied to chargeable items, and
/// discharge-pending financial checks post through Billing /
/// clinical-request-billing — never nurse-local tallies. Settle / adjust /
/// refund stay on the Billing workspace.
abstract final class NursingAssignedWardBillingInventory {
  static const NursingAssignedWardFinancialAtom tab =
      NursingAssignedWardFinancialAtom(
        id: 'tab',
        label: 'Assigned ward tab / count badge',
        financialClass: NursingAssignedWardFinancialClass.notRequired,
        requirement: NursingAssignedWardAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAssignedWardFinancialAtom listChrome =
      NursingAssignedWardFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / shift context / pagination',
        financialClass: NursingAssignedWardFinancialClass.notRequired,
        requirement: NursingAssignedWardAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAssignedWardFinancialAtom emptyLoadingError =
      NursingAssignedWardFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: NursingAssignedWardFinancialClass.notRequired,
        requirement: NursingAssignedWardAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAssignedWardFinancialAtom rowSelect =
      NursingAssignedWardFinancialAtom(
        id: 'row_select',
        label: 'Row select → patient detail',
        financialClass: NursingAssignedWardFinancialClass.notRequired,
        requirement: NursingAssignedWardAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAssignedWardFinancialAtom recordVitals =
      NursingAssignedWardFinancialAtom(
        id: 'record_vitals',
        label: 'Record vitals (clinical charting)',
        financialClass: NursingAssignedWardFinancialClass.notBilled,
        requirement: NursingAssignedWardAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAssignedWardFinancialAtom administerMedication =
      NursingAssignedWardFinancialAtom(
        id: 'administer_medication',
        label: 'Administer medication (charge at prescribe / Rx)',
        financialClass: NursingAssignedWardFinancialClass.notBilled,
        requirement: NursingAssignedWardAtomPermissions.administerMedication,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAssignedWardFinancialAtom prescribe =
      NursingAssignedWardFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe medication (pharmacy order)',
        financialClass: NursingAssignedWardFinancialClass.createCharge,
        requirement: NursingAssignedWardAtomPermissions.prescribe,
        billingPath:
            'createPharmacyOrder → mergeClinicalRequestBilling → '
            'persistPharmacyOrderBilling',
      );

  static const NursingAssignedWardFinancialAtom orderLab =
      NursingAssignedWardFinancialAtom(
        id: 'order_lab',
        label: 'Order lab',
        financialClass: NursingAssignedWardFinancialClass.createCharge,
        requirement: NursingAssignedWardAtomPermissions.orderLab,
        billingPath:
            'createLabOrder → mergeClinicalRequestBilling → '
            'clinical-request-billing',
      );

  static const NursingAssignedWardFinancialAtom orderRadiology =
      NursingAssignedWardFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology',
        financialClass: NursingAssignedWardFinancialClass.createCharge,
        requirement: NursingAssignedWardAtomPermissions.orderRadiology,
        billingPath:
            'createRadiologyOrder → mergeClinicalRequestBillingIntoRequestDetails '
            '→ clinical-request-billing',
      );

  static const NursingAssignedWardFinancialAtom addNote =
      NursingAssignedWardFinancialAtom(
        id: 'add_note',
        label: 'Add nursing note (optional nursing service charge)',
        financialClass: NursingAssignedWardFinancialClass.createCharge,
        requirement: NursingAssignedWardAtomPermissions.addNote,
        billingPath:
            'ipdFlows/.../add-nursing-note → persistNursingServiceBilling '
            '(when billed)',
      );

  static const NursingAssignedWardFinancialAtom checklistNotes =
      NursingAssignedWardFinancialAtom(
        id: 'checklist_notes',
        label: 'Admission checklist notes (identity / allergies / belongings)',
        financialClass: NursingAssignedWardFinancialClass.notBilled,
        requirement: NursingAssignedWardAtomPermissions.checklistWrite,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAssignedWardFinancialAtom dischargeClearance =
      NursingAssignedWardFinancialAtom(
        id: 'discharge_clearance',
        label: 'Discharge clearance (nursing + Billing ledger gate)',
        financialClass: NursingAssignedWardFinancialClass.defer,
        requirement: NursingAssignedWardAtomPermissions.dischargeClearance,
        billingPath:
            'ipdFlows/.../update-discharge-clearance → '
            'isBillingSettledForPatient (billing_cleared from ledger)',
      );

  static const NursingAssignedWardFinancialAtom billingPanel =
      NursingAssignedWardFinancialAtom(
        id: 'billing_panel',
        label: 'Detail billing clearance panel (ledger status)',
        financialClass: NursingAssignedWardFinancialClass.defer,
        requirement: NursingAssignedWardAtomPermissions.billingPanel,
        billingPath:
            'clearance_snapshot.billing_cleared from Billing ledger parity',
      );

  static const NursingAssignedWardFinancialAtom openBilling =
      NursingAssignedWardFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: NursingAssignedWardFinancialClass.defer,
        requirement: NursingAssignedWardAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const NursingAssignedWardFinancialAtom handover =
      NursingAssignedWardFinancialAtom(
        id: 'handover',
        label: 'Create / accept handover',
        financialClass: NursingAssignedWardFinancialClass.notBilled,
        requirement: NursingAssignedWardAtomPermissions.acceptHandover,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAssignedWardFinancialAtom transfer =
      NursingAssignedWardFinancialAtom(
        id: 'acknowledge_transfer',
        label: 'Acknowledge transfer',
        financialClass: NursingAssignedWardFinancialClass.notBilled,
        requirement: NursingAssignedWardAtomPermissions.acknowledgeTransfer,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAssignedWardFinancialAtom escalate =
      NursingAssignedWardFinancialAtom(
        id: 'escalate',
        label: 'Escalate / critical alert',
        financialClass: NursingAssignedWardFinancialClass.notBilled,
        requirement: NursingAssignedWardAtomPermissions.escalate,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAssignedWardFinancialAtom printSummary =
      NursingAssignedWardFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: NursingAssignedWardFinancialClass.notRequired,
        requirement: NursingAssignedWardAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAssignedWardFinancialAtom openIcu =
      NursingAssignedWardFinancialAtom(
        id: 'open_icu',
        label: 'Open ICU',
        financialClass: NursingAssignedWardFinancialClass.notRequired,
        requirement: NursingAssignedWardAtomPermissions.openIcu,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAssignedWardFinancialAtom procedure =
      NursingAssignedWardFinancialAtom(
        id: 'nursing_procedure',
        label: 'Billable nursing procedure order',
        financialClass: NursingAssignedWardFinancialClass.createCharge,
        requirement: NursingAssignedWardAtomPermissions.write,
        billingPath: 'clinical-request-billing / persistNursingServiceBilling',
        mounted: false,
      );

  static const NursingAssignedWardFinancialAtom consumable =
      NursingAssignedWardFinancialAtom(
        id: 'consumable',
        label: 'Ward consumable charge',
        financialClass: NursingAssignedWardFinancialClass.createCharge,
        requirement: NursingAssignedWardAtomPermissions.write,
        billingPath: 'persistConsumableBilling',
        mounted: false,
      );

  static const NursingAssignedWardFinancialAtom collectPayment =
      NursingAssignedWardFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: NursingAssignedWardFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Assigned ward)',
        mounted: false,
      );

  static const NursingAssignedWardFinancialAtom adjustRefund =
      NursingAssignedWardFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: NursingAssignedWardFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<NursingAssignedWardFinancialAtom> all =
      <NursingAssignedWardFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
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
        handover,
        transfer,
        escalate,
        printSummary,
        openIcu,
        procedure,
        consumable,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<NursingAssignedWardFinancialAtom> get billableMounted =>
      all.where(
        (NursingAssignedWardFinancialAtom atom) =>
            atom.mounted &&
            (atom.financialClass ==
                    NursingAssignedWardFinancialClass.createCharge ||
                atom.financialClass ==
                    NursingAssignedWardFinancialClass.settle ||
                atom.financialClass ==
                    NursingAssignedWardFinancialClass.adjust ||
                atom.financialClass ==
                    NursingAssignedWardFinancialClass.reverse ||
                atom.financialClass == NursingAssignedWardFinancialClass.defer),
      );

  static bool forbidsInlineCashier(NursingAssignedWardFinancialClass actionClass) {
    return switch (actionClass) {
      NursingAssignedWardFinancialClass.settle ||
      NursingAssignedWardFinancialClass.adjust ||
      NursingAssignedWardFinancialClass.reverse => true,
      _ => false,
    };
  }

  static String summary() =>
      'Assigned ward posts optional nursing service charges, prescribe / lab / '
      'radiology through clinical-request-billing. Discharge clearance sets '
      'nursing_cleared via updateDischargeClearance; billing_cleared derives '
      'from Billing ledger. Open billing navigates Billing. Medication admin '
      'stays NOT_BILLED (charge at Rx). No module cashier.';
}

/// Documents Assigned ward financial scope for tests and audits.
const String nursingAssignedWardBillingScopeNote =
    'Nursing Assigned ward is ABAC ward/assignment-scoped. Billable nursing '
    'notes use ipdFlows add-nursing-note → persistNursingServiceBilling. '
    'Clinical orders reuse mergeClinicalRequestBilling. Discharge clearance '
    'uses updateDischargeClearance with ledger-derived billing_cleared. '
    'Settle / adjust / refund navigate to Billing — never a parallel cash ledger.';
