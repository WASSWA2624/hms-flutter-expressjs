import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IpdAdmissionQueueFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on IPD Admission Queue
/// (`/ipd` or `?section=admission-queue`).
@immutable
final class IpdAdmissionQueueFinancialAtom {
  const IpdAdmissionQueueFinancialAtom({
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
  final IpdAdmissionQueueFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/ipd?section=admission-queue`.
///
/// Pending admissions; Start admission primary. Admission fee / deposit /
/// bed-day setup posts via clinical-request-billing at start. Assign bed is
/// placement only (charges already posted or deferred on start). Clinical
/// orders / ward rounds from detail reuse shared billing helpers. Settle /
/// adjust / refund stay on the Billing workspace — this tab never mounts a
/// parallel cashier. Discharge clearance defers to Billing ledger gates.
abstract final class IpdAdmissionQueueBillingInventory {
  static const IpdAdmissionQueueFinancialAtom tab =
      IpdAdmissionQueueFinancialAtom(
        id: 'tab',
        label: 'Admission Queue tab / count badge',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom listChrome =
      IpdAdmissionQueueFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom emptyLoadingError =
      IpdAdmissionQueueFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom rowSelect =
      IpdAdmissionQueueFinancialAtom(
        id: 'row_select',
        label: 'Row select → admission detail',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom startAdmission =
      IpdAdmissionQueueFinancialAtom(
        id: 'start_admission',
        label: 'Start admission (fee + deposit + bed/day)',
        financialClass: IpdAdmissionQueueFinancialClass.createCharge,
        requirement: IpdAdmissionQueueAtomPermissions.startAdmission,
        billingPath:
            'ipd-flows/start → buildAdmissionBilling → persistAdmissionBilling',
      );

  static const IpdAdmissionQueueFinancialAtom approveAdmission =
      IpdAdmissionQueueFinancialAtom(
        id: 'approve_admission',
        label: 'Approve admission (workflow; charges on start)',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.approveAdmission,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom assignBed =
      IpdAdmissionQueueFinancialAtom(
        id: 'assign_bed',
        label: 'Assign bed (placement; charges on start)',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.assignBed,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom rejectAdmission =
      IpdAdmissionQueueFinancialAtom(
        id: 'reject_admission',
        label: 'Reject admission',
        financialClass: IpdAdmissionQueueFinancialClass.notBilled,
        requirement: IpdAdmissionQueueAtomPermissions.rejectAdmission,
        auditCode: 'NOT_BILLED',
      );

  static const IpdAdmissionQueueFinancialAtom requestTransfer =
      IpdAdmissionQueueFinancialAtom(
        id: 'request_transfer',
        label: 'Request transfer (rate change posts on complete)',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom manageTransfer =
      IpdAdmissionQueueFinancialAtom(
        id: 'manage_transfer',
        label: 'Manage transfer',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.manageTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom wardRound =
      IpdAdmissionQueueFinancialAtom(
        id: 'ward_round',
        label: 'Add ward round (+ optional doctor review fee)',
        financialClass: IpdAdmissionQueueFinancialClass.createCharge,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        billingPath: 'add-ward-round → persistWardRoundBilling',
      );

  static const IpdAdmissionQueueFinancialAtom nursingNote =
      IpdAdmissionQueueFinancialAtom(
        id: 'nursing_note',
        label: 'Add nursing note',
        financialClass: IpdAdmissionQueueFinancialClass.notBilled,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        auditCode: 'NOT_BILLED',
      );

  static const IpdAdmissionQueueFinancialAtom recordMedication =
      IpdAdmissionQueueFinancialAtom(
        id: 'record_medication',
        label: 'Record medication administration',
        financialClass: IpdAdmissionQueueFinancialClass.notBilled,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        auditCode: 'NOT_BILLED',
      );

  static const IpdAdmissionQueueFinancialAtom orderLab =
      IpdAdmissionQueueFinancialAtom(
        id: 'order_lab',
        label: 'Order lab',
        financialClass: IpdAdmissionQueueFinancialClass.createCharge,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        billingPath: 'clinical lab order → clinical-request-billing',
      );

  static const IpdAdmissionQueueFinancialAtom orderRadiology =
      IpdAdmissionQueueFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology',
        financialClass: IpdAdmissionQueueFinancialClass.createCharge,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        billingPath: 'clinical radiology order → clinical-request-billing',
      );

  static const IpdAdmissionQueueFinancialAtom prescribe =
      IpdAdmissionQueueFinancialAtom(
        id: 'prescribe',
        label: 'Order prescription',
        financialClass: IpdAdmissionQueueFinancialClass.createCharge,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        billingPath: 'clinical pharmacy order → clinical-request-billing',
      );

  static const IpdAdmissionQueueFinancialAtom requestTherapy =
      IpdAdmissionQueueFinancialAtom(
        id: 'request_therapy',
        label: 'Request therapy (referral; charge on physiotherapy)',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom planDischarge =
      IpdAdmissionQueueFinancialAtom(
        id: 'plan_discharge',
        label: 'Plan / manage discharge (Billing clearance gate)',
        financialClass: IpdAdmissionQueueFinancialClass.defer,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        billingPath:
            'discharge planning → isBillingSettledForPatient / Billing ledger',
      );

  static const IpdAdmissionQueueFinancialAtom insurancePanel =
      IpdAdmissionQueueFinancialAtom(
        id: 'insurance_panel',
        label: 'Insurance authorization panel (claims handoff)',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.billingPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom startIcuStay =
      IpdAdmissionQueueFinancialAtom(
        id: 'start_icu_stay',
        label: 'Start ICU stay (ICU billing path)',
        financialClass: IpdAdmissionQueueFinancialClass.createCharge,
        requirement: IpdAdmissionQueueAtomPermissions.clinicalWrite,
        billingPath: 'start-icu-stay → persistIcuStayBilling',
      );

  static const IpdAdmissionQueueFinancialAtom navigation =
      IpdAdmissionQueueFinancialAtom(
        id: 'navigation',
        label: 'Open ICU / Theater / Nursing / Physiotherapy',
        financialClass: IpdAdmissionQueueFinancialClass.notRequired,
        requirement: IpdAdmissionQueueAtomPermissions.navigation,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdAdmissionQueueFinancialAtom releaseBed =
      IpdAdmissionQueueFinancialAtom(
        id: 'release_bed',
        label: 'Release bed',
        financialClass: IpdAdmissionQueueFinancialClass.notBilled,
        requirement: IpdAdmissionQueueAtomPermissions.operationalWrite,
        auditCode: 'NOT_BILLED',
      );

  static const IpdAdmissionQueueFinancialAtom collectPayment =
      IpdAdmissionQueueFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IpdAdmissionQueueFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Admission Queue)',
        mounted: false,
      );

  static const IpdAdmissionQueueFinancialAtom adjustRefund =
      IpdAdmissionQueueFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: IpdAdmissionQueueFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<IpdAdmissionQueueFinancialAtom> all =
      <IpdAdmissionQueueFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        startAdmission,
        approveAdmission,
        assignBed,
        rejectAdmission,
        requestTransfer,
        manageTransfer,
        wardRound,
        nursingNote,
        recordMedication,
        orderLab,
        orderRadiology,
        prescribe,
        requestTherapy,
        planDischarge,
        insurancePanel,
        startIcuStay,
        navigation,
        releaseBed,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<IpdAdmissionQueueFinancialAtom> get mountedAtoms =>
      all.where((IpdAdmissionQueueFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<IpdAdmissionQueueFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IpdAdmissionQueueFinancialAtom atom) =>
            atom.financialClass ==
                IpdAdmissionQueueFinancialClass.createCharge ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.settle ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.adjust ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.reverse ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.defer,
      );

  static bool forbidsInlineCashier(IpdAdmissionQueueFinancialClass klass) {
    return klass == IpdAdmissionQueueFinancialClass.settle ||
        klass == IpdAdmissionQueueFinancialClass.adjust ||
        klass == IpdAdmissionQueueFinancialClass.reverse;
  }
}
