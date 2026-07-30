import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum ClinicalAllFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Clinical All (`/clinical?section=all`).
@immutable
final class ClinicalAllFinancialAtom {
  const ClinicalAllFinancialAtom({
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
  final ClinicalAllFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/clinical?section=all` (outpatient clinical
/// worklist). Billable order/procedure atoms post through shared Billing
/// (`clinical-request-billing`, receive-payment, adjustment)—never a parallel
/// cash ledger. Settle/adjust/refund stay on Billing workspace; this tab only
/// creates/defers charges and opens Review billing / discharge Open billing.
abstract final class ClinicalAllBillingInventory {
  static const ClinicalAllFinancialAtom tab = ClinicalAllFinancialAtom(
    id: 'tab',
    label: 'All tab / count badge',
    financialClass: ClinicalAllFinancialClass.notRequired,
    requirement: ClinicalAllAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClinicalAllFinancialAtom listChrome = ClinicalAllFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: ClinicalAllFinancialClass.notRequired,
    requirement: ClinicalAllAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClinicalAllFinancialAtom emptyLoadingError =
      ClinicalAllFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: ClinicalAllFinancialClass.notRequired,
        requirement: ClinicalAllAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalAllFinancialAtom rowSelect = ClinicalAllFinancialAtom(
    id: 'row_select',
    label: 'Row select → encounter detail',
    financialClass: ClinicalAllFinancialClass.notRequired,
    requirement: ClinicalAllAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClinicalAllFinancialAtom nextActionReview =
      ClinicalAllFinancialAtom(
        id: 'next_action_review',
        label: 'Next action Review / open encounter',
        financialClass: ClinicalAllFinancialClass.notRequired,
        requirement: ClinicalAllAtomPermissions.nextActionReview,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalAllFinancialAtom recordVitals = ClinicalAllFinancialAtom(
    id: 'record_vitals',
    label: 'Record / edit vitals',
    financialClass: ClinicalAllFinancialClass.notBilled,
    requirement: ClinicalAllAtomPermissions.recordVitals,
    auditCode: 'NOT_BILLED',
  );

  static const ClinicalAllFinancialAtom addNote = ClinicalAllFinancialAtom(
    id: 'add_note',
    label: 'Add clinical note',
    financialClass: ClinicalAllFinancialClass.notBilled,
    requirement: ClinicalAllAtomPermissions.addNote,
    auditCode: 'NOT_BILLED',
  );

  static const ClinicalAllFinancialAtom addDiagnosis = ClinicalAllFinancialAtom(
    id: 'add_diagnosis',
    label: 'Add / delete diagnosis',
    financialClass: ClinicalAllFinancialClass.notBilled,
    requirement: ClinicalAllAtomPermissions.addDiagnosis,
    auditCode: 'NOT_BILLED',
  );

  static const ClinicalAllFinancialAtom requestLab = ClinicalAllFinancialAtom(
    id: 'request_lab',
    label: 'Request / update lab (+ Review billing)',
    financialClass: ClinicalAllFinancialClass.createCharge,
    requirement: ClinicalAllAtomPermissions.requestLab,
    billingPath: 'mergeClinicalRequestBilling → lab-order + clinical-request-billing',
  );

  static const ClinicalAllFinancialAtom cancelLab = ClinicalAllFinancialAtom(
    id: 'cancel_delete_lab',
    label: 'Cancel / delete lab order',
    financialClass: ClinicalAllFinancialClass.reverse,
    requirement: ClinicalAllAtomPermissions.nestedLabWrite,
    billingPath: 'reverseClinicalRequestBilling (lab-order)',
  );

  static const ClinicalAllFinancialAtom requestRadiology =
      ClinicalAllFinancialAtom(
        id: 'request_radiology',
        label: 'Request radiology (+ Review billing / pending bill-later)',
        financialClass: ClinicalAllFinancialClass.createCharge,
        requirement: ClinicalAllAtomPermissions.requestRadiology,
        billingPath:
            'mergeClinicalRequestBillingIntoRequestDetails → radiology-order',
      );

  static const ClinicalAllFinancialAtom cancelRadiology =
      ClinicalAllFinancialAtom(
        id: 'cancel_delete_radiology',
        label: 'Cancel / delete radiology order',
        financialClass: ClinicalAllFinancialClass.reverse,
        requirement: ClinicalAllAtomPermissions.nestedRadiologyWrite,
        billingPath: 'reverseClinicalRequestBilling (radiology-order)',
      );

  static const ClinicalAllFinancialAtom prescribe = ClinicalAllFinancialAtom(
    id: 'prescribe',
    label: 'Prescribe (+ Review billing / pending bill-later)',
    financialClass: ClinicalAllFinancialClass.createCharge,
    requirement: ClinicalAllAtomPermissions.prescribe,
    billingPath: 'mergeClinicalRequestBilling → pharmacy-order',
  );

  static const ClinicalAllFinancialAtom cancelPharmacy =
      ClinicalAllFinancialAtom(
        id: 'cancel_delete_pharmacy',
        label: 'Cancel / delete pharmacy order',
        financialClass: ClinicalAllFinancialClass.reverse,
        requirement: ClinicalAllAtomPermissions.nestedPharmacyWrite,
        billingPath: 'reverseClinicalRequestBilling (pharmacy-order)',
      );

  static const ClinicalAllFinancialAtom recordProcedure =
      ClinicalAllFinancialAtom(
        id: 'record_procedure',
        label: 'Request procedure (+ Review billing / pending bill-later)',
        financialClass: ClinicalAllFinancialClass.createCharge,
        requirement: ClinicalAllAtomPermissions.recordProcedure,
        billingPath: 'mergeClinicalRequestBilling → procedure + persistProcedureBilling',
      );

  static const ClinicalAllFinancialAtom refer = ClinicalAllFinancialAtom(
    id: 'refer',
    label: 'External referral',
    financialClass: ClinicalAllFinancialClass.notBilled,
    requirement: ClinicalAllAtomPermissions.refer,
    auditCode: 'NOT_BILLED',
  );

  static const ClinicalAllFinancialAtom scheduleFollowUp =
      ClinicalAllFinancialAtom(
        id: 'schedule_follow_up',
        label: 'Schedule follow-up',
        financialClass: ClinicalAllFinancialClass.notBilled,
        requirement: ClinicalAllAtomPermissions.followUp,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalAllFinancialAtom requestAdmission =
      ClinicalAllFinancialAtom(
        id: 'request_admission',
        label: 'Request admission (queue handoff)',
        financialClass: ClinicalAllFinancialClass.defer,
        requirement: ClinicalAllAtomPermissions.requestAdmission,
        billingPath: 'ipd-flow persistAdmissionBilling when billing present',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalAllFinancialAtom disposition =
      ClinicalAllFinancialAtom(
        id: 'disposition',
        label: 'Complete disposition (non-admission)',
        financialClass: ClinicalAllFinancialClass.notBilled,
        requirement: ClinicalAllAtomPermissions.disposition,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalAllFinancialAtom dischargeOpenBilling =
      ClinicalAllFinancialAtom(
        id: 'discharge_open_billing',
        label: 'Discharge planning → Open billing',
        financialClass: ClinicalAllFinancialClass.defer,
        requirement: ClinicalAllAtomPermissions.dischargeFinancialRead,
        billingPath: 'Navigate Billing workspace (no inline settle)',
      );

  static const ClinicalAllFinancialAtom reviewBilling =
      ClinicalAllFinancialAtom(
        id: 'review_billing',
        label: 'Review billing (lab / radiology / pharmacy / procedure)',
        financialClass: ClinicalAllFinancialClass.createCharge,
        requirement: ClinicalAllAtomPermissions.write,
        billingPath: 'showClinicalRequestBillingDialog → ClinicalRequestBillingSubmit',
      );

  static const ClinicalAllFinancialAtom printSummary =
      ClinicalAllFinancialAtom(
        id: 'print_summary',
        label: 'Print consultation summary',
        financialClass: ClinicalAllFinancialClass.notRequired,
        requirement: ClinicalAllAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalAllFinancialAtom collectPayment =
      ClinicalAllFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: ClinicalAllFinancialClass.settle,
        requirement: ClinicalAllAtomPermissions.dischargeFinancialRead,
        billingPath: 'Billing receive-payment (not mounted as cashier on All)',
        mounted: false,
      );

  static const ClinicalAllFinancialAtom adjustRefund =
      ClinicalAllFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: ClinicalAllFinancialClass.adjust,
        requirement: ClinicalAllAtomPermissions.dischargeFinancialRead,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<ClinicalAllFinancialAtom> all = <ClinicalAllFinancialAtom>[
    tab,
    listChrome,
    emptyLoadingError,
    rowSelect,
    nextActionReview,
    recordVitals,
    addNote,
    addDiagnosis,
    requestLab,
    cancelLab,
    requestRadiology,
    cancelRadiology,
    prescribe,
    cancelPharmacy,
    recordProcedure,
    refer,
    scheduleFollowUp,
    requestAdmission,
    disposition,
    dischargeOpenBilling,
    reviewBilling,
    printSummary,
    collectPayment,
    adjustRefund,
  ];

  static Iterable<ClinicalAllFinancialAtom> get mountedAtoms =>
      all.where((ClinicalAllFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<ClinicalAllFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (ClinicalAllFinancialAtom atom) =>
            atom.financialClass == ClinicalAllFinancialClass.createCharge ||
            atom.financialClass == ClinicalAllFinancialClass.settle ||
            atom.financialClass == ClinicalAllFinancialClass.adjust ||
            atom.financialClass == ClinicalAllFinancialClass.reverse ||
            atom.financialClass == ClinicalAllFinancialClass.defer,
      );

  static bool forbidsInlineCollection(ClinicalAllFinancialClass actionClass) {
    return switch (actionClass) {
      ClinicalAllFinancialClass.settle ||
      ClinicalAllFinancialClass.adjust ||
      ClinicalAllFinancialClass.reverse ||
      ClinicalAllFinancialClass.createCharge ||
      ClinicalAllFinancialClass.defer => true,
      _ => false,
    };
  }
}

const String clinicalAllBillingScopeNote =
    'Clinical All is the outpatient clinical worklist. Lab, radiology, '
    'pharmacy, and procedure requests post request-time charges via '
    'clinical-request-billing (pending bill-later when Review billing is '
    'skipped). Cancel/delete reverse Billing snapshots. Discharge Open billing '
    'navigates the Billing module; settle/adjust/refund are not cashiered here. '
    'Admission queue handoff defers bed/admission fees to ipd-flow when billing '
    'is supplied. Notes, vitals, diagnoses, refer, and schedule follow-up stay '
    'NOT_BILLED.';
