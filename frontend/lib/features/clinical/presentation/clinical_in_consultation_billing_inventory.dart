import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum ClinicalInConsultationFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Clinical In consultation
/// (`/clinical?section=in-consultation`).
@immutable
final class ClinicalInConsultationFinancialAtom {
  const ClinicalInConsultationFinancialAtom({
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
  final ClinicalInConsultationFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/clinical?section=in-consultation`.
///
/// Active consultation worklist with the richest nested action bar (same
/// encounter detail chrome as All). Billable order/procedure atoms post through
/// shared Billing (`clinical-request-billing`, receive-payment, adjustment)—
/// never a parallel cash ledger. Settle/adjust/refund stay on Billing
/// workspace; this tab creates/defers charges, shows payment status parity on
/// order panels, and opens Review billing / discharge Open billing.
abstract final class ClinicalInConsultationBillingInventory {
  static const ClinicalInConsultationFinancialAtom tab =
      ClinicalInConsultationFinancialAtom(
        id: 'tab',
        label: 'In consultation tab / count badge',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom listChrome =
      ClinicalInConsultationFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom emptyLoadingError =
      ClinicalInConsultationFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom rowSelect =
      ClinicalInConsultationFinancialAtom(
        id: 'row_select',
        label: 'Row select → encounter detail',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom nextActionReview =
      ClinicalInConsultationFinancialAtom(
        id: 'next_action_review',
        label: 'Next action Review / open encounter',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.nextActionReview,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom recordVitals =
      ClinicalInConsultationFinancialAtom(
        id: 'record_vitals',
        label: 'Record / edit vitals',
        financialClass: ClinicalInConsultationFinancialClass.notBilled,
        requirement: ClinicalInConsultationAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalInConsultationFinancialAtom addNote =
      ClinicalInConsultationFinancialAtom(
        id: 'add_note',
        label: 'Add clinical note',
        financialClass: ClinicalInConsultationFinancialClass.notBilled,
        requirement: ClinicalInConsultationAtomPermissions.addNote,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalInConsultationFinancialAtom addDiagnosis =
      ClinicalInConsultationFinancialAtom(
        id: 'add_diagnosis',
        label: 'Add / delete diagnosis',
        financialClass: ClinicalInConsultationFinancialClass.notBilled,
        requirement: ClinicalInConsultationAtomPermissions.addDiagnosis,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalInConsultationFinancialAtom requestLab =
      ClinicalInConsultationFinancialAtom(
        id: 'request_lab',
        label: 'Request / update lab (+ Review billing)',
        financialClass: ClinicalInConsultationFinancialClass.createCharge,
        requirement: ClinicalInConsultationAtomPermissions.requestLab,
        billingPath:
            'mergeClinicalRequestBilling → lab-order + clinical-request-billing',
      );

  static const ClinicalInConsultationFinancialAtom cancelLab =
      ClinicalInConsultationFinancialAtom(
        id: 'cancel_delete_lab',
        label: 'Cancel / delete lab order',
        financialClass: ClinicalInConsultationFinancialClass.reverse,
        requirement: ClinicalInConsultationAtomPermissions.nestedLabWrite,
        billingPath: 'reverseClinicalRequestBilling (lab-order)',
      );

  static const ClinicalInConsultationFinancialAtom requestRadiology =
      ClinicalInConsultationFinancialAtom(
        id: 'request_radiology',
        label: 'Request radiology (+ Review billing / pending bill-later)',
        financialClass: ClinicalInConsultationFinancialClass.createCharge,
        requirement: ClinicalInConsultationAtomPermissions.requestRadiology,
        billingPath:
            'mergeClinicalRequestBillingIntoRequestDetails → radiology-order',
      );

  static const ClinicalInConsultationFinancialAtom cancelRadiology =
      ClinicalInConsultationFinancialAtom(
        id: 'cancel_delete_radiology',
        label: 'Cancel / delete radiology order',
        financialClass: ClinicalInConsultationFinancialClass.reverse,
        requirement: ClinicalInConsultationAtomPermissions.nestedRadiologyWrite,
        billingPath: 'reverseClinicalRequestBilling (radiology-order)',
      );

  static const ClinicalInConsultationFinancialAtom prescribe =
      ClinicalInConsultationFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe (+ Review billing / pending bill-later)',
        financialClass: ClinicalInConsultationFinancialClass.createCharge,
        requirement: ClinicalInConsultationAtomPermissions.prescribe,
        billingPath: 'mergeClinicalRequestBilling → pharmacy-order',
      );

  static const ClinicalInConsultationFinancialAtom cancelPharmacy =
      ClinicalInConsultationFinancialAtom(
        id: 'cancel_delete_pharmacy',
        label: 'Cancel / delete pharmacy order',
        financialClass: ClinicalInConsultationFinancialClass.reverse,
        requirement: ClinicalInConsultationAtomPermissions.nestedPharmacyWrite,
        billingPath: 'reverseClinicalRequestBilling (pharmacy-order)',
      );

  static const ClinicalInConsultationFinancialAtom recordProcedure =
      ClinicalInConsultationFinancialAtom(
        id: 'record_procedure',
        label: 'Request procedure (+ Review billing / pending bill-later)',
        financialClass: ClinicalInConsultationFinancialClass.createCharge,
        requirement: ClinicalInConsultationAtomPermissions.recordProcedure,
        billingPath:
            'mergeClinicalRequestBilling → procedure + persistProcedureBilling',
      );

  static const ClinicalInConsultationFinancialAtom orderPaymentStatus =
      ClinicalInConsultationFinancialAtom(
        id: 'order_payment_status',
        label: 'Lab / radiology / pharmacy payment status chip (parity)',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.detail,
        billingPath: 'payment_status from clinical-request-billing snapshot',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom refer =
      ClinicalInConsultationFinancialAtom(
        id: 'refer',
        label: 'External referral',
        financialClass: ClinicalInConsultationFinancialClass.notBilled,
        requirement: ClinicalInConsultationAtomPermissions.refer,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalInConsultationFinancialAtom scheduleFollowUp =
      ClinicalInConsultationFinancialAtom(
        id: 'schedule_follow_up',
        label: 'Schedule follow-up',
        financialClass: ClinicalInConsultationFinancialClass.notBilled,
        requirement: ClinicalInConsultationAtomPermissions.followUp,
        auditCode: 'NOT_BILLED',
      );

  static const ClinicalInConsultationFinancialAtom requestAdmission =
      ClinicalInConsultationFinancialAtom(
        id: 'request_admission',
        label: 'Request admission (queue handoff; no charge at request)',
        financialClass: ClinicalInConsultationFinancialClass.defer,
        requirement: ClinicalInConsultationAtomPermissions.requestAdmission,
        billingPath:
            'ipd-flow request writes NOT_REQUIRED snapshot; '
            'persistAdmissionBilling on IPD start when billing present',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom disposition =
      ClinicalInConsultationFinancialAtom(
        id: 'disposition',
        label: 'Complete disposition (OPD; outstanding stays in Billing)',
        financialClass: ClinicalInConsultationFinancialClass.defer,
        requirement: ClinicalInConsultationAtomPermissions.disposition,
        billingPath:
            'Outstanding bill-later invoices remain in Billing / reception '
            'payment gate; IPD discharge uses clearance + Open billing',
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom dischargeOpenBilling =
      ClinicalInConsultationFinancialAtom(
        id: 'discharge_open_billing',
        label: 'Discharge planning → Open billing',
        financialClass: ClinicalInConsultationFinancialClass.defer,
        requirement:
            ClinicalInConsultationAtomPermissions.dischargeFinancialRead,
        billingPath: 'Navigate Billing workspace (no inline settle)',
      );

  static const ClinicalInConsultationFinancialAtom reviewBilling =
      ClinicalInConsultationFinancialAtom(
        id: 'review_billing',
        label: 'Review billing (lab / radiology / pharmacy / procedure)',
        financialClass: ClinicalInConsultationFinancialClass.createCharge,
        requirement: ClinicalInConsultationAtomPermissions.write,
        billingPath:
            'showClinicalRequestBillingDialog → ClinicalRequestBillingSubmit',
      );

  static const ClinicalInConsultationFinancialAtom printSummary =
      ClinicalInConsultationFinancialAtom(
        id: 'print_summary',
        label: 'Print consultation summary',
        financialClass: ClinicalInConsultationFinancialClass.notRequired,
        requirement: ClinicalInConsultationAtomPermissions.printSummary,
        auditCode: 'NOT_REQUIRED',
      );

  static const ClinicalInConsultationFinancialAtom collectPayment =
      ClinicalInConsultationFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: ClinicalInConsultationFinancialClass.settle,
        requirement:
            ClinicalInConsultationAtomPermissions.dischargeFinancialRead,
        billingPath:
            'Billing receive-payment / clinical-request pay-now '
            '(not mounted as cashier on In consultation)',
        mounted: false,
      );

  static const ClinicalInConsultationFinancialAtom adjustRefund =
      ClinicalInConsultationFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: ClinicalInConsultationFinancialClass.adjust,
        requirement:
            ClinicalInConsultationAtomPermissions.dischargeFinancialRead,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<ClinicalInConsultationFinancialAtom> all =
      <ClinicalInConsultationFinancialAtom>[
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

  static Iterable<ClinicalInConsultationFinancialAtom> get mountedAtoms =>
      all.where((ClinicalInConsultationFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<ClinicalInConsultationFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (ClinicalInConsultationFinancialAtom atom) =>
            atom.financialClass ==
                ClinicalInConsultationFinancialClass.createCharge ||
            atom.financialClass ==
                ClinicalInConsultationFinancialClass.settle ||
            atom.financialClass ==
                ClinicalInConsultationFinancialClass.adjust ||
            atom.financialClass ==
                ClinicalInConsultationFinancialClass.reverse ||
            atom.financialClass == ClinicalInConsultationFinancialClass.defer,
      );

  static bool forbidsInlineCashier(
    ClinicalInConsultationFinancialClass actionClass,
  ) {
    return switch (actionClass) {
      ClinicalInConsultationFinancialClass.settle ||
      ClinicalInConsultationFinancialClass.adjust ||
      ClinicalInConsultationFinancialClass.reverse ||
      ClinicalInConsultationFinancialClass.createCharge ||
      ClinicalInConsultationFinancialClass.defer => true,
      _ => false,
    };
  }
}

const String clinicalInConsultationBillingScopeNote =
    'Clinical In consultation is the active outpatient consultation worklist '
    'with the richest nested action bar. Lab, radiology, pharmacy, and '
    'procedure requests post request-time charges via clinical-request-billing '
    '(pending bill-later when Review billing is skipped). Order panels surface '
    'payment_status parity with Billing. Cancel/delete reverse Billing '
    'snapshots. Admission request audits NOT_REQUIRED; bed/admission fees post '
    'on IPD start. OPD disposition leaves outstanding bill-later balances in '
    'Billing / reception payment gate; discharge Open billing navigates Billing. '
    'Settle/adjust/refund are not cashiered on this tab.';
