import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum NursingHandoverPendingFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Nursing Handover pending
/// (`/nursing?scope=handover-pending`).
@immutable
final class NursingHandoverPendingFinancialAtom {
  const NursingHandoverPendingFinancialAtom({
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
  final NursingHandoverPendingFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/nursing?scope=handover-pending`.
///
/// Tab role: shift handover complete needs clinical:write. Stage create/accept
/// handover is clinical logistics ([notBilled]). Billable nursing procedures,
/// consumables, medication administrations tied to chargeable items, and
/// discharge-pending financial checks reachable from patient detail post
/// through Billing / clinical-request-billing — never nurse-local tallies.
/// Settle / adjust / refund stay on the Billing workspace.
abstract final class NursingHandoverPendingBillingInventory {
  static const NursingHandoverPendingFinancialAtom tab =
      NursingHandoverPendingFinancialAtom(
        id: 'tab',
        label: 'Handover pending tab / count badge',
        financialClass: NursingHandoverPendingFinancialClass.notRequired,
        requirement: NursingHandoverPendingAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingHandoverPendingFinancialAtom listChrome =
      NursingHandoverPendingFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / shift context / pagination',
        financialClass: NursingHandoverPendingFinancialClass.notRequired,
        requirement: NursingHandoverPendingAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingHandoverPendingFinancialAtom emptyLoadingError =
      NursingHandoverPendingFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: NursingHandoverPendingFinancialClass.notRequired,
        requirement: NursingHandoverPendingAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingHandoverPendingFinancialAtom rowSelect =
      NursingHandoverPendingFinancialAtom(
        id: 'row_select',
        label: 'Row select → patient detail',
        financialClass: NursingHandoverPendingFinancialClass.notRequired,
        requirement: NursingHandoverPendingAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingHandoverPendingFinancialAtom nextActionHandover =
      NursingHandoverPendingFinancialAtom(
        id: 'next_action_handover',
        label: 'Next action Create handover',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement: NursingHandoverPendingAtomPermissions.nextActionHandover,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom createHandover =
      NursingHandoverPendingFinancialAtom(
        id: 'create_handover',
        label: 'Create handover (shift sign-off)',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement: NursingHandoverPendingAtomPermissions.createHandover,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom acceptHandover =
      NursingHandoverPendingFinancialAtom(
        id: 'accept_handover',
        label: 'Accept handover',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement: NursingHandoverPendingAtomPermissions.acceptHandover,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom recordVitals =
      NursingHandoverPendingFinancialAtom(
        id: 'record_vitals',
        label: 'Record vitals (clinical charting)',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement: NursingHandoverPendingAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom administerMedication =
      NursingHandoverPendingFinancialAtom(
        id: 'administer_medication',
        label: 'Administer medication (charge at prescribe / Rx)',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement:
            NursingHandoverPendingAtomPermissions.administerMedication,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom prescribe =
      NursingHandoverPendingFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe medication (pharmacy order)',
        financialClass: NursingHandoverPendingFinancialClass.createCharge,
        requirement: NursingHandoverPendingAtomPermissions.prescribe,
        billingPath:
            'createPharmacyOrder → mergeClinicalRequestBilling → '
            'persistPharmacyOrderBilling',
      );

  static const NursingHandoverPendingFinancialAtom orderLab =
      NursingHandoverPendingFinancialAtom(
        id: 'order_lab',
        label: 'Order lab',
        financialClass: NursingHandoverPendingFinancialClass.createCharge,
        requirement: NursingHandoverPendingAtomPermissions.orderLab,
        billingPath:
            'createLabOrder → mergeClinicalRequestBilling → '
            'clinical-request-billing',
      );

  static const NursingHandoverPendingFinancialAtom orderRadiology =
      NursingHandoverPendingFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology',
        financialClass: NursingHandoverPendingFinancialClass.createCharge,
        requirement: NursingHandoverPendingAtomPermissions.orderRadiology,
        billingPath:
            'createRadiologyOrder → mergeClinicalRequestBillingIntoRequestDetails '
            '→ clinical-request-billing',
      );

  static const NursingHandoverPendingFinancialAtom addNote =
      NursingHandoverPendingFinancialAtom(
        id: 'add_note',
        label: 'Add nursing note (optional nursing service charge)',
        financialClass: NursingHandoverPendingFinancialClass.createCharge,
        requirement: NursingHandoverPendingAtomPermissions.addNote,
        billingPath:
            'ipdFlows/.../add-nursing-note → persistNursingServiceBilling '
            '(when billed)',
      );

  static const NursingHandoverPendingFinancialAtom checklistNotes =
      NursingHandoverPendingFinancialAtom(
        id: 'checklist_notes',
        label: 'Admission checklist notes (identity / allergies / belongings)',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement: NursingHandoverPendingAtomPermissions.checklistWrite,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom dischargeClearance =
      NursingHandoverPendingFinancialAtom(
        id: 'discharge_clearance',
        label: 'Discharge clearance (nursing + Billing ledger gate)',
        financialClass: NursingHandoverPendingFinancialClass.defer,
        requirement: NursingHandoverPendingAtomPermissions.dischargeClearance,
        billingPath:
            'ipdFlows/.../update-discharge-clearance → '
            'isBillingSettledForPatient (billing_cleared from ledger)',
      );

  static const NursingHandoverPendingFinancialAtom billingPanel =
      NursingHandoverPendingFinancialAtom(
        id: 'billing_panel',
        label: 'Detail billing clearance panel (ledger status)',
        financialClass: NursingHandoverPendingFinancialClass.defer,
        requirement: NursingHandoverPendingAtomPermissions.billingPanel,
        billingPath:
            'clearance_snapshot.billing_cleared from Billing ledger parity',
      );

  static const NursingHandoverPendingFinancialAtom openBilling =
      NursingHandoverPendingFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: NursingHandoverPendingFinancialClass.defer,
        requirement: NursingHandoverPendingAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const NursingHandoverPendingFinancialAtom escalate =
      NursingHandoverPendingFinancialAtom(
        id: 'escalate',
        label: 'Escalate / critical alert',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement: NursingHandoverPendingAtomPermissions.escalate,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom acknowledgeTransfer =
      NursingHandoverPendingFinancialAtom(
        id: 'acknowledge_transfer',
        label: 'Acknowledge transfer',
        financialClass: NursingHandoverPendingFinancialClass.notBilled,
        requirement:
            NursingHandoverPendingAtomPermissions.acknowledgeTransfer,
        auditCode: 'NOT_BILLED',
      );

  static const NursingHandoverPendingFinancialAtom printSummary =
      NursingHandoverPendingFinancialAtom(
        id: 'print_summary',
        label: 'Print summary',
        financialClass: NursingHandoverPendingFinancialClass.notRequired,
        requirement: NursingHandoverPendingAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingHandoverPendingFinancialAtom openIcu =
      NursingHandoverPendingFinancialAtom(
        id: 'open_icu',
        label: 'Open ICU',
        financialClass: NursingHandoverPendingFinancialClass.notRequired,
        requirement: NursingHandoverPendingAtomPermissions.openIcu,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingHandoverPendingFinancialAtom procedure =
      NursingHandoverPendingFinancialAtom(
        id: 'nursing_procedure',
        label: 'Billable nursing procedure order',
        financialClass: NursingHandoverPendingFinancialClass.createCharge,
        requirement: NursingHandoverPendingAtomPermissions.write,
        billingPath: 'clinical-request-billing / persistNursingServiceBilling',
        mounted: false,
      );

  static const NursingHandoverPendingFinancialAtom consumable =
      NursingHandoverPendingFinancialAtom(
        id: 'consumable',
        label: 'Ward consumable charge',
        financialClass: NursingHandoverPendingFinancialClass.createCharge,
        requirement: NursingHandoverPendingAtomPermissions.write,
        billingPath: 'persistConsumableBilling',
        mounted: false,
      );

  static const NursingHandoverPendingFinancialAtom collectPayment =
      NursingHandoverPendingFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: NursingHandoverPendingFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath:
            'Billing receive-payment (not mounted on Handover pending)',
        mounted: false,
      );

  static const NursingHandoverPendingFinancialAtom adjustRefund =
      NursingHandoverPendingFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: NursingHandoverPendingFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<NursingHandoverPendingFinancialAtom> all =
      <NursingHandoverPendingFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionHandover,
        createHandover,
        acceptHandover,
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
        escalate,
        acknowledgeTransfer,
        printSummary,
        openIcu,
        procedure,
        consumable,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<NursingHandoverPendingFinancialAtom> get mountedAtoms =>
      all.where((NursingHandoverPendingFinancialAtom atom) => atom.mounted);

  static Iterable<NursingHandoverPendingFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (NursingHandoverPendingFinancialAtom atom) =>
            atom.financialClass ==
                NursingHandoverPendingFinancialClass.createCharge ||
            atom.financialClass ==
                NursingHandoverPendingFinancialClass.settle ||
            atom.financialClass ==
                NursingHandoverPendingFinancialClass.adjust ||
            atom.financialClass ==
                NursingHandoverPendingFinancialClass.reverse ||
            atom.financialClass ==
                NursingHandoverPendingFinancialClass.defer,
      );

  static bool forbidsInlineCashier(
    NursingHandoverPendingFinancialClass actionClass,
  ) {
    return switch (actionClass) {
      NursingHandoverPendingFinancialClass.settle ||
      NursingHandoverPendingFinancialClass.adjust ||
      NursingHandoverPendingFinancialClass.reverse => true,
      _ => false,
    };
  }

  static bool get allBillableAtomsWireThroughBilling {
    for (final NursingHandoverPendingFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Section chrome on this tab: sibling [AppCollapsibleSection]s under a
  /// Column in patient detail; worklist has no titled sections. Handover /
  /// note dialogs use single shells or embedded billing panels (not nested).
  static const List<String> titledSectionIds = <String>[
    'detail_quick_actions',
    'detail_admission_checklist',
    'detail_billing_clearance',
    'detail_observations',
    'detail_medications',
    'detail_notes',
    'detail_care_plans',
    'detail_handovers',
    'detail_ward_activity',
  ];

  static String summary() =>
      'Handover pending stage create/accept is NOT_BILLED. Optional nursing '
      'service charges and prescribe / lab / radiology post through '
      'clinical-request-billing. Discharge clearance sets nursing_cleared via '
      'updateDischargeClearance; billing_cleared derives from Billing ledger. '
      'Open billing navigates Billing. Medication admin stays NOT_BILLED '
      '(charge at Rx). No module cashier.';
}

/// Documents Handover pending financial scope for tests and audits.
const String nursingHandoverPendingBillingScopeNote =
    'Nursing Handover pending is shift handover complete (clinical:write). '
    'Create/accept handover never posts charges. Billable nursing notes use '
    'ipdFlows add-nursing-note → persistNursingServiceBilling. Clinical orders '
    'reuse mergeClinicalRequestBilling. Discharge clearance uses '
    'updateDischargeClearance with ledger-derived billing_cleared. Settle / '
    'adjust / refund navigate to Billing — never a parallel cash ledger.';
