import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum NursingAllFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Nursing All (`/nursing` / `?scope=all`).
@immutable
final class NursingAllFinancialAtom {
  const NursingAllFinancialAtom({
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
  final NursingAllFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/nursing` / `?scope=all` (full nursing worklist).
///
/// Tab role: billable nursing procedures/consumables (when mounted), medication
/// administrations tied to chargeable Rx items (charge at prescribe / pharmacy
/// order), and discharge-pending financial checks via Billing. Optional nursing
/// service on notes posts through IPD `add-nursing-note` →
/// `persistNursingServiceBilling`. Prescribe / lab / radiology reuse
/// clinical-request-billing. Settle / adjust / refund stay on the Billing
/// workspace — this tab never mounts a parallel cashier.
abstract final class NursingAllBillingInventory {
  static const NursingAllFinancialAtom tab = NursingAllFinancialAtom(
    id: 'tab',
    label: 'All tab / count badge',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom shiftContext = NursingAllFinancialAtom(
    id: 'shift_context',
    label: 'Shift context toolbar',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.shiftContext,
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom listChrome = NursingAllFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom emptyLoadingError =
      NursingAllFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: NursingAllFinancialClass.notRequired,
        requirement: NursingAllAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAllFinancialAtom rowSelect = NursingAllFinancialAtom(
    id: 'row_select',
    label: 'Row select → patient detail',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom nextActionVitals =
      NursingAllFinancialAtom(
        id: 'next_action_vitals',
        label: 'Next action Record vitals',
        financialClass: NursingAllFinancialClass.notBilled,
        requirement: NursingAllAtomPermissions.nextActionVitals,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAllFinancialAtom nextActionMedication =
      NursingAllFinancialAtom(
        id: 'next_action_medication',
        label: 'Next action Administer medication (MAR; charge on Rx)',
        financialClass: NursingAllFinancialClass.notBilled,
        requirement: NursingAllAtomPermissions.nextActionMedication,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAllFinancialAtom nextActionHandover =
      NursingAllFinancialAtom(
        id: 'next_action_handover',
        label: 'Next action Create handover',
        financialClass: NursingAllFinancialClass.notBilled,
        requirement: NursingAllAtomPermissions.nextActionHandover,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAllFinancialAtom nextActionTransfer =
      NursingAllFinancialAtom(
        id: 'next_action_transfer',
        label: 'Next action Acknowledge transfer (logistics)',
        financialClass: NursingAllFinancialClass.notRequired,
        requirement: NursingAllAtomPermissions.nextActionTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAllFinancialAtom nextActionDischarge =
      NursingAllFinancialAtom(
        id: 'next_action_discharge',
        label: 'Next action Discharge clearance (clinical; settle on Billing)',
        financialClass: NursingAllFinancialClass.defer,
        requirement: NursingAllAtomPermissions.nextActionDischarge,
        billingPath:
            'updateDischargeClearance → isBillingSettledForPatient; Open billing',
        auditCode: 'NOT_BILLED',
      );

  static const NursingAllFinancialAtom addNote = NursingAllFinancialAtom(
    id: 'add_note',
    label: 'Add nursing note (optional service charge)',
    financialClass: NursingAllFinancialClass.createCharge,
    requirement: NursingAllAtomPermissions.addNote,
    billingPath:
        'add-nursing-note → persistNursingServiceBilling (NURSING_SERVICE)',
  );

  static const NursingAllFinancialAtom recordVitals = NursingAllFinancialAtom(
    id: 'record_vitals',
    label: 'Record vitals / checklist vitals',
    financialClass: NursingAllFinancialClass.notBilled,
    requirement: NursingAllAtomPermissions.recordVitals,
    auditCode: 'NOT_BILLED',
  );

  static const NursingAllFinancialAtom administerMedication =
      NursingAllFinancialAtom(
        id: 'administer_medication',
        label: 'Administer medication (MAR; charge on pharmacy order)',
        financialClass: NursingAllFinancialClass.notBilled,
        requirement: NursingAllAtomPermissions.administerMedication,
        auditCode: 'NOT_BILLED',
      );

  static const NursingAllFinancialAtom prescribe = NursingAllFinancialAtom(
    id: 'prescribe',
    label: 'Prescribe medication',
    financialClass: NursingAllFinancialClass.createCharge,
    requirement: NursingAllAtomPermissions.prescribe,
    billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
  );

  static const NursingAllFinancialAtom orderLab = NursingAllFinancialAtom(
    id: 'order_lab',
    label: 'Order lab',
    financialClass: NursingAllFinancialClass.createCharge,
    requirement: NursingAllAtomPermissions.orderLab,
    billingPath: 'createLabOrder → persistLabOrderBilling',
  );

  static const NursingAllFinancialAtom orderRadiology = NursingAllFinancialAtom(
    id: 'order_radiology',
    label: 'Order radiology',
    financialClass: NursingAllFinancialClass.createCharge,
    requirement: NursingAllAtomPermissions.orderRadiology,
    billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
  );

  static const NursingAllFinancialAtom escalate = NursingAllFinancialAtom(
    id: 'escalate',
    label: 'Escalate (urgent handover)',
    financialClass: NursingAllFinancialClass.notBilled,
    requirement: NursingAllAtomPermissions.escalate,
    auditCode: 'NOT_BILLED',
  );

  static const NursingAllFinancialAtom acknowledgeTransfer =
      NursingAllFinancialAtom(
        id: 'acknowledge_transfer',
        label: 'Acknowledge transfer (detail)',
        financialClass: NursingAllFinancialClass.notRequired,
        requirement: NursingAllAtomPermissions.acknowledgeTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const NursingAllFinancialAtom dischargeClearance =
      NursingAllFinancialAtom(
        id: 'discharge_clearance',
        label: 'Discharge clearance (clinical checklist note)',
        financialClass: NursingAllFinancialClass.defer,
        requirement: NursingAllAtomPermissions.dischargeClearance,
        billingPath:
            'updateDischargeClearance → isBillingSettledForPatient '
            '(billing_cleared from ledger)',
        auditCode: 'NOT_BILLED',
      );

  static const NursingAllFinancialAtom checklistOps = NursingAllFinancialAtom(
    id: 'checklist_ops',
    label: 'Admission checklist ops notes (identity/allergies/belongings/MD)',
    financialClass: NursingAllFinancialClass.notBilled,
    requirement: NursingAllAtomPermissions.checklistWrite,
    auditCode: 'NOT_BILLED',
  );

  static const NursingAllFinancialAtom billingPanel = NursingAllFinancialAtom(
    id: 'billing_panel',
    label: 'Detail billing clearance panel (parity read)',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.billingPanel,
    billingPath: 'Discharge status / Open billing → Billing SoR',
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom openBilling = NursingAllFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing workspace)',
    financialClass: NursingAllFinancialClass.defer,
    requirement: NursingAllAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const NursingAllFinancialAtom openIcu = NursingAllFinancialAtom(
    id: 'open_icu',
    label: 'Open ICU (navigate)',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.openIcu,
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom printSummary = NursingAllFinancialAtom(
    id: 'print_summary',
    label: 'Print nursing summary',
    financialClass: NursingAllFinancialClass.notRequired,
    requirement: NursingAllAtomPermissions.printSummary,
    auditCode: 'NOT_REQUIRED',
  );

  static const NursingAllFinancialAtom acceptHandover = NursingAllFinancialAtom(
    id: 'accept_handover',
    label: 'Accept handover',
    financialClass: NursingAllFinancialClass.notBilled,
    requirement: NursingAllAtomPermissions.acceptHandover,
    auditCode: 'NOT_BILLED',
  );

  static const NursingAllFinancialAtom procedures = NursingAllFinancialAtom(
    id: 'procedures',
    label: 'Record nursing procedure (clinical-request billing)',
    financialClass: NursingAllFinancialClass.createCharge,
    requirement: NursingAllAtomPermissions.write,
    billingPath: 'ClinicalProcedureActionDialog → clinical-request-billing',
    mounted: false,
  );

  static const NursingAllFinancialAtom consumables = NursingAllFinancialAtom(
    id: 'consumables',
    label: 'Ward consumables charge',
    financialClass: NursingAllFinancialClass.createCharge,
    requirement: NursingAllAtomPermissions.addNote,
    billingPath: 'persistConsumableBilling / persistNursingServiceBilling',
    mounted: false,
  );

  static const NursingAllFinancialAtom collectPayment = NursingAllFinancialAtom(
    id: 'collect_payment',
    label: 'Receive payment / cashier collect',
    financialClass: NursingAllFinancialClass.settle,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing receive-payment (not mounted on Nursing All)',
    mounted: false,
  );

  static const NursingAllFinancialAtom adjustRefund = NursingAllFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: NursingAllFinancialClass.adjust,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<NursingAllFinancialAtom> all = <NursingAllFinancialAtom>[
    tab,
    shiftContext,
    listChrome,
    emptyLoadingError,
    rowSelect,
    nextActionVitals,
    nextActionMedication,
    nextActionHandover,
    nextActionTransfer,
    nextActionDischarge,
    addNote,
    recordVitals,
    administerMedication,
    prescribe,
    orderLab,
    orderRadiology,
    escalate,
    acknowledgeTransfer,
    dischargeClearance,
    checklistOps,
    billingPanel,
    openBilling,
    openIcu,
    printSummary,
    acceptHandover,
    procedures,
    consumables,
    collectPayment,
    adjustRefund,
  ];

  /// Alias for [all] — inventory completeness checks.
  static List<NursingAllFinancialAtom> get atoms => all;

  static Iterable<NursingAllFinancialAtom> get mountedAtoms =>
      all.where((NursingAllFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<NursingAllFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (NursingAllFinancialAtom atom) =>
            atom.financialClass == NursingAllFinancialClass.createCharge ||
            atom.financialClass == NursingAllFinancialClass.settle ||
            atom.financialClass == NursingAllFinancialClass.adjust ||
            atom.financialClass == NursingAllFinancialClass.reverse ||
            atom.financialClass == NursingAllFinancialClass.defer,
      );

  static List<NursingAllFinancialAtom> get explicitNotBillableAtoms => all
      .where(
        (NursingAllFinancialAtom atom) =>
            atom.auditCode == 'NOT_BILLED' ||
            atom.auditCode == 'NOT_REQUIRED' ||
            atom.auditCode == 'NO_CHARGE',
      )
      .toList(growable: false);

  static bool forbidsInlineCashier(NursingAllFinancialClass actionClass) {
    return switch (actionClass) {
      NursingAllFinancialClass.settle ||
      NursingAllFinancialClass.adjust ||
      NursingAllFinancialClass.reverse => true,
      _ => false,
    };
  }

  /// Section chrome on this tab: sibling [AppWorkspaceDetailPanel]s under a
  /// Column in patient detail; worklist has no titled sections. Dialogs use
  /// single shells or embedded billing panels (not nested sections).
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

  static String summary() => billingOwnershipSummary;

  static const String billingOwnershipSummary =
      'Nursing All posts optional nursing-service charges via IPD '
      'add-nursing-note → persistNursingServiceBilling and clinical orders via '
      'clinical-request-billing. Open billing navigates Billing. No module cashier.';
}

/// Scope note for Nursing All billing-and-sections scan.
const String nursingAllBillingScopeNote =
    'Full nursing worklist: optional nursing-service notes, prescribe/lab/'
    'radiology via clinical-request-billing, MAR NOT_BILLED (charge on Rx), '
    'discharge clearance defers settle to Billing via Open billing.';
