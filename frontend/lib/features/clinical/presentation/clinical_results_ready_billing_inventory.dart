import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum ClinicalResultsReadyFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Clinical Results ready
/// (`/clinical?section=results-ready`).
@immutable
final class ClinicalResultsReadyFinancialAtom {
  const ClinicalResultsReadyFinancialAtom({
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
  final ClinicalResultsReadyFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/clinical?section=results-ready`.
///
/// Lab/imaging results-ready worklist reuses outpatient encounter chrome.
/// Distinctive surfaces: results-ready chips, Results timeline, lab / radiology
/// order panels. Billable order/procedure atoms post through shared Billing
/// (`clinical-request-billing`, receive-payment, adjustment)—never a parallel
/// cash ledger. Settle/adjust/refund stay on Billing workspace; this tab only
/// creates/defers charges and opens Review billing / discharge Open billing.
abstract final class ClinicalResultsReadyBillingInventory {
  static const ClinicalResultsReadyFinancialAtom tab =
      ClinicalResultsReadyFinancialAtom(
        id: 'tab',
        label: 'Results ready tab / count badge',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom listChrome =
      ClinicalResultsReadyFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom emptyLoadingError =
      ClinicalResultsReadyFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom resultsReadyChip =
      ClinicalResultsReadyFinancialAtom(
        id: 'results_ready_chip',
        label: 'Results-ready summary chip / badge',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.resultsReadyChip,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom rowSelect =
      ClinicalResultsReadyFinancialAtom(
        id: 'row_select',
        label: 'Row select → encounter detail',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom nextActionReview =
      ClinicalResultsReadyFinancialAtom(
        id: 'next_action_review',
        label: 'Next action Review / REVIEW_RESULTS',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.nextActionReview,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom resultsTimeline =
      ClinicalResultsReadyFinancialAtom(
        id: 'results_timeline',
        label: 'Results chronology (lab / imaging preview)',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.resultsTimeline,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom labResultsPanel =
      ClinicalResultsReadyFinancialAtom(
        id: 'lab_results_panel',
        label: 'Detail Lab orders / results panel (read)',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.labResultsPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom radiologyResultsPanel =
      ClinicalResultsReadyFinancialAtom(
        id: 'radiology_results_panel',
        label: 'Detail Radiology orders / results panel (read)',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.radiologyResultsPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom recordVitals =
      ClinicalResultsReadyFinancialAtom(
        id: 'record_vitals',
        label: 'Record / edit vitals',
        financialClass: ClinicalResultsReadyFinancialClass.notBilled,
        requirement: ClinicalResultsReadyAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalResultsReadyFinancialAtom addNote =
      ClinicalResultsReadyFinancialAtom(
        id: 'add_note',
        label: 'Add clinical note',
        financialClass: ClinicalResultsReadyFinancialClass.notBilled,
        requirement: ClinicalResultsReadyAtomPermissions.addNote,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalResultsReadyFinancialAtom addDiagnosis =
      ClinicalResultsReadyFinancialAtom(
        id: 'add_diagnosis',
        label: 'Add / delete diagnosis',
        financialClass: ClinicalResultsReadyFinancialClass.notBilled,
        requirement: ClinicalResultsReadyAtomPermissions.addDiagnosis,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalResultsReadyFinancialAtom requestLab =
      ClinicalResultsReadyFinancialAtom(
        id: 'request_lab',
        label: 'Request / update lab (+ Review billing)',
        financialClass: ClinicalResultsReadyFinancialClass.createCharge,
        requirement: ClinicalResultsReadyAtomPermissions.requestLab,
        billingPath:
            'mergeClinicalRequestBilling → lab-order + clinical-request-billing',
      );

  static const ClinicalResultsReadyFinancialAtom cancelLab =
      ClinicalResultsReadyFinancialAtom(
        id: 'cancel_delete_lab',
        label: 'Cancel / delete lab order',
        financialClass: ClinicalResultsReadyFinancialClass.reverse,
        requirement: ClinicalResultsReadyAtomPermissions.nestedLabWrite,
        billingPath: 'reverseClinicalRequestBilling (lab-order)',
      );

  static const ClinicalResultsReadyFinancialAtom requestRadiology =
      ClinicalResultsReadyFinancialAtom(
        id: 'request_radiology',
        label: 'Request radiology (+ Review billing / pending bill-later)',
        financialClass: ClinicalResultsReadyFinancialClass.createCharge,
        requirement: ClinicalResultsReadyAtomPermissions.requestRadiology,
        billingPath:
            'mergeClinicalRequestBillingIntoRequestDetails → radiology-order',
      );

  static const ClinicalResultsReadyFinancialAtom cancelRadiology =
      ClinicalResultsReadyFinancialAtom(
        id: 'cancel_delete_radiology',
        label: 'Cancel / delete radiology order',
        financialClass: ClinicalResultsReadyFinancialClass.reverse,
        requirement: ClinicalResultsReadyAtomPermissions.nestedRadiologyWrite,
        billingPath: 'reverseClinicalRequestBilling (radiology-order)',
      );

  static const ClinicalResultsReadyFinancialAtom prescribe =
      ClinicalResultsReadyFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe (+ Review billing / pending bill-later)',
        financialClass: ClinicalResultsReadyFinancialClass.createCharge,
        requirement: ClinicalResultsReadyAtomPermissions.prescribe,
        billingPath: 'mergeClinicalRequestBilling → pharmacy-order',
      );

  static const ClinicalResultsReadyFinancialAtom cancelPharmacy =
      ClinicalResultsReadyFinancialAtom(
        id: 'cancel_delete_pharmacy',
        label: 'Cancel / delete pharmacy order',
        financialClass: ClinicalResultsReadyFinancialClass.reverse,
        requirement: ClinicalResultsReadyAtomPermissions.nestedPharmacyWrite,
        billingPath: 'reverseClinicalRequestBilling (pharmacy-order)',
      );

  static const ClinicalResultsReadyFinancialAtom recordProcedure =
      ClinicalResultsReadyFinancialAtom(
        id: 'record_procedure',
        label: 'Request procedure (+ Review billing / pending bill-later)',
        financialClass: ClinicalResultsReadyFinancialClass.createCharge,
        requirement: ClinicalResultsReadyAtomPermissions.recordProcedure,
        billingPath:
            'mergeClinicalRequestBilling → procedure + persistProcedureBilling',
      );

  static const ClinicalResultsReadyFinancialAtom refer =
      ClinicalResultsReadyFinancialAtom(
        id: 'refer',
        label: 'External referral',
        financialClass: ClinicalResultsReadyFinancialClass.notBilled,
        requirement: ClinicalResultsReadyAtomPermissions.refer,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalResultsReadyFinancialAtom scheduleFollowUp =
      ClinicalResultsReadyFinancialAtom(
        id: 'schedule_follow_up',
        label: 'Schedule follow-up',
        financialClass: ClinicalResultsReadyFinancialClass.notBilled,
        requirement: ClinicalResultsReadyAtomPermissions.followUp,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalResultsReadyFinancialAtom requestAdmission =
      ClinicalResultsReadyFinancialAtom(
        id: 'request_admission',
        label: 'Request admission (queue handoff)',
        financialClass: ClinicalResultsReadyFinancialClass.defer,
        requirement: ClinicalResultsReadyAtomPermissions.requestAdmission,
        billingPath: 'ipd-flow persistAdmissionBilling when billing present',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom disposition =
      ClinicalResultsReadyFinancialAtom(
        id: 'disposition',
        label: 'Complete disposition (non-admission)',
        financialClass: ClinicalResultsReadyFinancialClass.notBilled,
        requirement: ClinicalResultsReadyAtomPermissions.disposition,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalResultsReadyFinancialAtom dischargeOpenBilling =
      ClinicalResultsReadyFinancialAtom(
        id: 'discharge_open_billing',
        label: 'Discharge planning → Open billing',
        financialClass: ClinicalResultsReadyFinancialClass.defer,
        requirement: ClinicalResultsReadyAtomPermissions.dischargeFinancialRead,
        billingPath: 'Navigate Billing workspace (no inline settle)',
      );

  static const ClinicalResultsReadyFinancialAtom reviewBilling =
      ClinicalResultsReadyFinancialAtom(
        id: 'review_billing',
        label: 'Review billing (lab / radiology / pharmacy / procedure)',
        financialClass: ClinicalResultsReadyFinancialClass.createCharge,
        requirement: ClinicalResultsReadyAtomPermissions.write,
        billingPath:
            'showClinicalRequestBillingDialog → ClinicalRequestBillingSubmit',
      );

  static const ClinicalResultsReadyFinancialAtom printSummary =
      ClinicalResultsReadyFinancialAtom(
        id: 'print_summary',
        label: 'Print consultation summary',
        financialClass: ClinicalResultsReadyFinancialClass.notRequired,
        requirement: ClinicalResultsReadyAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalResultsReadyFinancialAtom collectPayment =
      ClinicalResultsReadyFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: ClinicalResultsReadyFinancialClass.settle,
        requirement: ClinicalResultsReadyAtomPermissions.dischargeFinancialRead,
        billingPath:
            'Billing receive-payment (not mounted as cashier on Results ready)',
        mounted: false,
      );

  static const ClinicalResultsReadyFinancialAtom adjustRefund =
      ClinicalResultsReadyFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: ClinicalResultsReadyFinancialClass.adjust,
        requirement: ClinicalResultsReadyAtomPermissions.dischargeFinancialRead,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<ClinicalResultsReadyFinancialAtom> all =
      <ClinicalResultsReadyFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        resultsReadyChip,
        rowSelect,
        nextActionReview,
        resultsTimeline,
        labResultsPanel,
        radiologyResultsPanel,
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

  static Iterable<ClinicalResultsReadyFinancialAtom> get mountedAtoms =>
      all.where((ClinicalResultsReadyFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<ClinicalResultsReadyFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (ClinicalResultsReadyFinancialAtom atom) =>
            atom.financialClass ==
                ClinicalResultsReadyFinancialClass.createCharge ||
            atom.financialClass == ClinicalResultsReadyFinancialClass.settle ||
            atom.financialClass == ClinicalResultsReadyFinancialClass.adjust ||
            atom.financialClass == ClinicalResultsReadyFinancialClass.reverse ||
            atom.financialClass == ClinicalResultsReadyFinancialClass.defer,
      );

  /// True when every mounted billable atom documents a shared Billing path.
  static bool get allBillableMountedUseSharedBilling => billableMounted.every(
    (ClinicalResultsReadyFinancialAtom atom) =>
        atom.billingPath != null && atom.billingPath!.trim().isNotEmpty,
  );

  static bool forbidsInlineCashier(ClinicalResultsReadyFinancialClass actionClass) {
    return switch (actionClass) {
      ClinicalResultsReadyFinancialClass.settle ||
      ClinicalResultsReadyFinancialClass.adjust => true,
      _ => false,
    };
  }
}

const String clinicalResultsReadyBillingScopeNote =
    'Clinical Results ready is the lab/imaging results-ready worklist. Lab, '
    'radiology, pharmacy, and procedure requests post request-time charges via '
    'clinical-request-billing (pending bill-later when Review billing is '
    'skipped). Cancel/delete reverse Billing snapshots. Discharge Open billing '
    'navigates the Billing module; settle/adjust/refund are not cashiered here. '
    'Results timeline and lab/radiology panels are read-only NOT_REQUIRED. '
    'Notes, vitals, diagnoses, refer, and schedule follow-up stay NOT_BILLED.';
