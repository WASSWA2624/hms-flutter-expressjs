import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum ClinicalUrgentFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Clinical Urgent (`/clinical?section=urgent`).
@immutable
final class ClinicalUrgentFinancialAtom {
  const ClinicalUrgentFinancialAtom({
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
  final ClinicalUrgentFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/clinical?section=urgent`.
///
/// Urgent outpatient encounters (`isUrgent` + non-terminal) reuse the same
/// encounter chrome as All / In consultation. Distinctive surfaces: Urgent tab
/// (danger count tone) and Urgent summary chips. Billable order/procedure
/// atoms post through shared Billing (`clinical-request-billing`,
/// receive-payment, adjustment)—never a parallel cash ledger. Settle/adjust/
/// refund stay on Billing workspace; this tab creates/defers charges and opens
/// Review billing / discharge Open billing.
abstract final class ClinicalUrgentBillingInventory {
  static const ClinicalUrgentFinancialAtom tab = ClinicalUrgentFinancialAtom(
    id: 'tab',
    label: 'Urgent tab / count badge',
    financialClass: ClinicalUrgentFinancialClass.notRequired,
    requirement: ClinicalUrgentAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const ClinicalUrgentFinancialAtom listChrome =
      ClinicalUrgentFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom emptyLoadingError =
      ClinicalUrgentFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom urgentChip =
      ClinicalUrgentFinancialAtom(
        id: 'urgent_chip',
        label: 'Urgent summary chip / badge (row + detail)',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.urgentChip,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom rowSelect =
      ClinicalUrgentFinancialAtom(
        id: 'row_select',
        label: 'Row select → encounter detail',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom nextActionReview =
      ClinicalUrgentFinancialAtom(
        id: 'next_action_review',
        label: 'Next action Review / open encounter',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.nextActionReview,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom recordVitals =
      ClinicalUrgentFinancialAtom(
        id: 'record_vitals',
        label: 'Record / edit vitals',
        financialClass: ClinicalUrgentFinancialClass.notBilled,
        requirement: ClinicalUrgentAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalUrgentFinancialAtom addNote = ClinicalUrgentFinancialAtom(
    id: 'add_note',
    label: 'Add clinical note',
    financialClass: ClinicalUrgentFinancialClass.notBilled,
    requirement: ClinicalUrgentAtomPermissions.addNote,
    auditCode: 'NOT_BILLED',
  );

  static const ClinicalUrgentFinancialAtom addDiagnosis =
      ClinicalUrgentFinancialAtom(
        id: 'add_diagnosis',
        label: 'Add / delete diagnosis',
        financialClass: ClinicalUrgentFinancialClass.notBilled,
        requirement: ClinicalUrgentAtomPermissions.addDiagnosis,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalUrgentFinancialAtom requestLab =
      ClinicalUrgentFinancialAtom(
        id: 'request_lab',
        label: 'Request / update lab (+ Review billing)',
        financialClass: ClinicalUrgentFinancialClass.createCharge,
        requirement: ClinicalUrgentAtomPermissions.requestLab,
        billingPath:
            'mergeClinicalRequestBilling → lab-order + clinical-request-billing',
      );

  static const ClinicalUrgentFinancialAtom cancelLab =
      ClinicalUrgentFinancialAtom(
        id: 'cancel_delete_lab',
        label: 'Cancel / delete lab order',
        financialClass: ClinicalUrgentFinancialClass.reverse,
        requirement: ClinicalUrgentAtomPermissions.nestedLabWrite,
        billingPath: 'reverseClinicalRequestBilling (lab-order)',
      );

  static const ClinicalUrgentFinancialAtom requestRadiology =
      ClinicalUrgentFinancialAtom(
        id: 'request_radiology',
        label: 'Request radiology (+ Review billing / pending bill-later)',
        financialClass: ClinicalUrgentFinancialClass.createCharge,
        requirement: ClinicalUrgentAtomPermissions.requestRadiology,
        billingPath:
            'mergeClinicalRequestBillingIntoRequestDetails → radiology-order',
      );

  static const ClinicalUrgentFinancialAtom cancelRadiology =
      ClinicalUrgentFinancialAtom(
        id: 'cancel_delete_radiology',
        label: 'Cancel / delete radiology order',
        financialClass: ClinicalUrgentFinancialClass.reverse,
        requirement: ClinicalUrgentAtomPermissions.nestedRadiologyWrite,
        billingPath: 'reverseClinicalRequestBilling (radiology-order)',
      );

  static const ClinicalUrgentFinancialAtom prescribe =
      ClinicalUrgentFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe (+ Review billing / pending bill-later)',
        financialClass: ClinicalUrgentFinancialClass.createCharge,
        requirement: ClinicalUrgentAtomPermissions.prescribe,
        billingPath: 'mergeClinicalRequestBilling → pharmacy-order',
      );

  static const ClinicalUrgentFinancialAtom cancelPharmacy =
      ClinicalUrgentFinancialAtom(
        id: 'cancel_delete_pharmacy',
        label: 'Cancel / delete pharmacy order',
        financialClass: ClinicalUrgentFinancialClass.reverse,
        requirement: ClinicalUrgentAtomPermissions.nestedPharmacyWrite,
        billingPath: 'reverseClinicalRequestBilling (pharmacy-order)',
      );

  static const ClinicalUrgentFinancialAtom recordProcedure =
      ClinicalUrgentFinancialAtom(
        id: 'record_procedure',
        label: 'Request procedure (+ Review billing / pending bill-later)',
        financialClass: ClinicalUrgentFinancialClass.createCharge,
        requirement: ClinicalUrgentAtomPermissions.recordProcedure,
        billingPath:
            'mergeClinicalRequestBilling → procedure + persistProcedureBilling',
      );

  static const ClinicalUrgentFinancialAtom orderPaymentStatus =
      ClinicalUrgentFinancialAtom(
        id: 'order_payment_status',
        label: 'Lab / radiology / pharmacy payment status chip (parity)',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.detail,
        billingPath: 'payment_status from clinical-request-billing snapshot',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom refer = ClinicalUrgentFinancialAtom(
    id: 'refer',
    label: 'External referral',
    financialClass: ClinicalUrgentFinancialClass.notBilled,
    requirement: ClinicalUrgentAtomPermissions.refer,
    auditCode: 'NOT_BILLED',
  );

  static const ClinicalUrgentFinancialAtom scheduleFollowUp =
      ClinicalUrgentFinancialAtom(
        id: 'schedule_follow_up',
        label: 'Schedule follow-up',
        financialClass: ClinicalUrgentFinancialClass.notBilled,
        requirement: ClinicalUrgentAtomPermissions.followUp,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalUrgentFinancialAtom requestAdmission =
      ClinicalUrgentFinancialAtom(
        id: 'request_admission',
        label: 'Request admission (queue handoff; fee deferred)',
        financialClass: ClinicalUrgentFinancialClass.defer,
        requirement: ClinicalUrgentAtomPermissions.requestAdmission,
        billingPath:
            'ipd-flow persistAdmissionBilling on IPD start when billing present',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom disposition =
      ClinicalUrgentFinancialAtom(
        id: 'disposition',
        label: 'Complete disposition (OPD; outstanding stays in Billing)',
        financialClass: ClinicalUrgentFinancialClass.defer,
        requirement: ClinicalUrgentAtomPermissions.disposition,
        billingPath:
            'Outstanding bill-later invoices remain in Billing / reception '
            'payment gate; IPD discharge uses clearance + Open billing',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom dischargeOpenBilling =
      ClinicalUrgentFinancialAtom(
        id: 'discharge_open_billing',
        label: 'Discharge planning → Open billing',
        financialClass: ClinicalUrgentFinancialClass.defer,
        requirement: ClinicalUrgentAtomPermissions.dischargeFinancialRead,
        billingPath: 'Navigate Billing workspace (no inline settle)',
      );

  static const ClinicalUrgentFinancialAtom reviewBilling =
      ClinicalUrgentFinancialAtom(
        id: 'review_billing',
        label: 'Review billing (lab / radiology / pharmacy / procedure)',
        financialClass: ClinicalUrgentFinancialClass.createCharge,
        requirement: ClinicalUrgentAtomPermissions.write,
        billingPath:
            'showClinicalRequestBillingDialog → ClinicalRequestBillingSubmit',
      );

  static const ClinicalUrgentFinancialAtom printSummary =
      ClinicalUrgentFinancialAtom(
        id: 'print_summary',
        label: 'Print consultation summary',
        financialClass: ClinicalUrgentFinancialClass.notRequired,
        requirement: ClinicalUrgentAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalUrgentFinancialAtom collectPayment =
      ClinicalUrgentFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: ClinicalUrgentFinancialClass.settle,
        requirement: ClinicalUrgentAtomPermissions.dischargeFinancialRead,
        billingPath:
            'Billing receive-payment / clinical-request pay-now '
            '(not mounted as cashier on Urgent)',
        mounted: false,
      );

  static const ClinicalUrgentFinancialAtom adjustRefund =
      ClinicalUrgentFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: ClinicalUrgentFinancialClass.adjust,
        requirement: ClinicalUrgentAtomPermissions.dischargeFinancialRead,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<ClinicalUrgentFinancialAtom> all =
      <ClinicalUrgentFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        urgentChip,
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
        orderPaymentStatus,
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

  static Iterable<ClinicalUrgentFinancialAtom> get mountedAtoms =>
      all.where((ClinicalUrgentFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<ClinicalUrgentFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (ClinicalUrgentFinancialAtom atom) =>
            atom.financialClass == ClinicalUrgentFinancialClass.createCharge ||
            atom.financialClass == ClinicalUrgentFinancialClass.settle ||
            atom.financialClass == ClinicalUrgentFinancialClass.adjust ||
            atom.financialClass == ClinicalUrgentFinancialClass.reverse ||
            atom.financialClass == ClinicalUrgentFinancialClass.defer,
      );

  static bool forbidsInlineCashier(ClinicalUrgentFinancialClass actionClass) {
    return switch (actionClass) {
      ClinicalUrgentFinancialClass.settle ||
      ClinicalUrgentFinancialClass.adjust ||
      ClinicalUrgentFinancialClass.reverse ||
      ClinicalUrgentFinancialClass.createCharge ||
      ClinicalUrgentFinancialClass.defer => true,
      _ => false,
    };
  }
}

const String clinicalUrgentBillingScopeNote =
    'Clinical Urgent is the isUrgent + non-terminal outpatient worklist. Lab, '
    'radiology, pharmacy, and procedure requests post request-time charges via '
    'clinical-request-billing (pending bill-later when Review billing is '
    'skipped). Order panels surface payment_status parity with Billing. '
    'Cancel/delete reverse Billing snapshots. Admission request defers '
    'bed/admission fees to ipd-flow start. OPD disposition leaves outstanding '
    'bill-later balances in Billing / reception payment gate; discharge Open '
    'billing navigates Billing. Settle/adjust/refund are not cashiered on this '
    'tab. Notes, vitals, diagnoses, refer, and schedule follow-up stay '
    'NOT_BILLED.';
