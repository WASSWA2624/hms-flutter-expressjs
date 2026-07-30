import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IpdTransfersFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on IPD Transfers (`/ipd?section=transfers`).
@immutable
final class IpdTransfersFinancialAtom {
  const IpdTransfersFinancialAtom({
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
  final IpdTransfersFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/ipd?section=transfers`.
///
/// Tab role: ward/bed transfer queue. Request / approve / start / cancel are
/// clinical logistics (`NOT_REQUIRED`). **COMPLETE** posts a bed/day rate
/// charge via `buildBedTransferBilling` → `persistAdmissionBilling` when the
/// destination ward rate differs (idempotent `BED_TRANSFER:{transferId}`).
/// Same-rate completes stay logistics-only. Complementary clinical orders /
/// ward rounds reuse clinical-request-billing. Settle / adjust / refund stay
/// on the Billing workspace — this tab never mounts a parallel cashier.
/// Discharge financial clearance defers to the Discharge / Billing gate.
abstract final class IpdTransfersBillingInventory {
  static const IpdTransfersFinancialAtom tab = IpdTransfersFinancialAtom(
    id: 'tab',
    label: 'Transfers tab / count badge',
    financialClass: IpdTransfersFinancialClass.notRequired,
    requirement: IpdTransfersAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdTransfersFinancialAtom listChrome = IpdTransfersFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: IpdTransfersFinancialClass.notRequired,
    requirement: IpdTransfersAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdTransfersFinancialAtom emptyLoadingError =
      IpdTransfersFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom rowSelect = IpdTransfersFinancialAtom(
    id: 'row_select',
    label: 'Row select → admission detail',
    financialClass: IpdTransfersFinancialClass.notRequired,
    requirement: IpdTransfersAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdTransfersFinancialAtom nextActionManageTransfer =
      IpdTransfersFinancialAtom(
        id: 'next_action_manage_transfer',
        label: 'Next action Manage transfer',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.nextActionManageTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom nextActionRequestTransfer =
      IpdTransfersFinancialAtom(
        id: 'next_action_request_transfer',
        label: 'Next action Request transfer',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.nextActionRequestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom requestTransfer =
      IpdTransfersFinancialAtom(
        id: 'request_transfer',
        label: 'Request transfer (request-transfer; no ledger)',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom manageTransferApproveStartCancel =
      IpdTransfersFinancialAtom(
        id: 'manage_transfer_approve_start_cancel',
        label: 'Manage transfer approve / start / cancel (logistics)',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.manageTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  /// COMPLETE with destination bed — create-charge when rate changes.
  static const IpdTransfersFinancialAtom completeTransferRateChange =
      IpdTransfersFinancialAtom(
        id: 'complete_transfer_rate_change',
        label: 'Complete transfer (bed/day when rate changes)',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.manageTransfer,
        billingPath:
            'update-transfer COMPLETE → buildBedTransferBilling → '
            'persistAdmissionBilling (BED_TRANSFER:{transferId})',
      );

  static const IpdTransfersFinancialAtom startAdmission =
      IpdTransfersFinancialAtom(
        id: 'start_admission',
        label: 'Start admission (toolbar; fee + deposit + bed/day)',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.startAdmission,
        billingPath:
            'ipd-flows/start → buildAdmissionBilling → persistAdmissionBilling',
      );

  static const IpdTransfersFinancialAtom approveAdmission =
      IpdTransfersFinancialAtom(
        id: 'approve_admission',
        label: 'Approve admission (workflow)',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.approveAdmission,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom assignBed = IpdTransfersFinancialAtom(
    id: 'assign_bed',
    label: 'Assign bed (placement; charges on start)',
    financialClass: IpdTransfersFinancialClass.notRequired,
    requirement: IpdTransfersAtomPermissions.assignBed,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdTransfersFinancialAtom releaseBed = IpdTransfersFinancialAtom(
    id: 'release_bed',
    label: 'Release bed',
    financialClass: IpdTransfersFinancialClass.notRequired,
    requirement: IpdTransfersAtomPermissions.releaseBed,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdTransfersFinancialAtom rejectAdmission =
      IpdTransfersFinancialAtom(
        id: 'reject_admission',
        label: 'Reject admission',
        financialClass: IpdTransfersFinancialClass.notBilled,
        requirement: IpdTransfersAtomPermissions.rejectAdmission,
        auditCode: 'NOT_BILLED',
      );

  static const IpdTransfersFinancialAtom wardRound = IpdTransfersFinancialAtom(
    id: 'ward_round',
    label: 'Add ward round (+ optional doctor review fee)',
    financialClass: IpdTransfersFinancialClass.createCharge,
    requirement: IpdTransfersAtomPermissions.wardRound,
    billingPath: 'add-ward-round → persistWardRoundBilling',
  );

  static const IpdTransfersFinancialAtom nursingNote = IpdTransfersFinancialAtom(
    id: 'nursing_note',
    label: 'Add nursing note',
    financialClass: IpdTransfersFinancialClass.notBilled,
    requirement: IpdTransfersAtomPermissions.recordNursingNote,
    auditCode: 'NOT_BILLED',
  );

  static const IpdTransfersFinancialAtom recordMedication =
      IpdTransfersFinancialAtom(
        id: 'record_medication',
        label: 'Record medication administration',
        financialClass: IpdTransfersFinancialClass.notBilled,
        requirement: IpdTransfersAtomPermissions.medication,
        auditCode: 'NOT_BILLED',
      );

  static const IpdTransfersFinancialAtom orderLab = IpdTransfersFinancialAtom(
    id: 'order_lab',
    label: 'Order lab',
    financialClass: IpdTransfersFinancialClass.createCharge,
    requirement: IpdTransfersAtomPermissions.orderLab,
    billingPath: 'clinical lab order → clinical-request-billing',
  );

  static const IpdTransfersFinancialAtom orderRadiology =
      IpdTransfersFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.orderRadiology,
        billingPath: 'clinical radiology order → clinical-request-billing',
      );

  static const IpdTransfersFinancialAtom orderPrescription =
      IpdTransfersFinancialAtom(
        id: 'order_prescription',
        label: 'Order prescription',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.orderPrescription,
        billingPath: 'clinical pharmacy order → clinical-request-billing',
      );

  static const IpdTransfersFinancialAtom requestTherapy =
      IpdTransfersFinancialAtom(
        id: 'request_therapy',
        label: 'Request therapy (handoff; charges on physiotherapy)',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.requestTherapy,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom startIcuStay = IpdTransfersFinancialAtom(
    id: 'start_icu_stay',
    label: 'Start ICU stay (package + bed/day)',
    financialClass: IpdTransfersFinancialClass.createCharge,
    requirement: IpdTransfersAtomPermissions.startIcuStay,
    billingPath: 'start-icu-stay → persistIcuStayBilling',
  );

  static const IpdTransfersFinancialAtom planOrManageDischarge =
      IpdTransfersFinancialAtom(
        id: 'plan_or_manage_discharge',
        label: 'Plan / manage discharge (clearance gate)',
        financialClass: IpdTransfersFinancialClass.defer,
        requirement: IpdTransfersAtomPermissions.planDischarge,
        billingPath:
            'Discharge finalizeDischarge → isBillingSettledForPatient',
      );

  static const IpdTransfersFinancialAtom insurancePanel =
      IpdTransfersFinancialAtom(
        id: 'insurance_billing_panel',
        label: 'Detail insurance / pre-auth panel',
        financialClass: IpdTransfersFinancialClass.defer,
        requirement: IpdTransfersAtomPermissions.billingPanel,
        billingPath: 'InsuranceAuthorizationPanel → claims / Billing',
      );

  static const IpdTransfersFinancialAtom openBilling = IpdTransfersFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing workspace)',
    financialClass: IpdTransfersFinancialClass.defer,
    requirement: IpdTransfersAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const IpdTransfersFinancialAtom navigation = IpdTransfersFinancialAtom(
    id: 'cross_module_navigation',
    label: 'Open ICU / Theater / Nursing / Physiotherapy',
    financialClass: IpdTransfersFinancialClass.notRequired,
    requirement: IpdTransfersAtomPermissions.navigation,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdTransfersFinancialAtom transferHistoryPanel =
      IpdTransfersFinancialAtom(
        id: 'transfer_history_panel',
        label: 'Detail transfers history section',
        financialClass: IpdTransfersFinancialClass.notRequired,
        requirement: IpdTransfersAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdTransfersFinancialAtom admissionDeposit =
      IpdTransfersFinancialAtom(
        id: 'admission_deposit',
        label: 'Admission deposit / prepayment (on start)',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.startAdmission,
        billingPath:
            'start → buildAdmissionBilling deposit line → persistAdmissionBilling',
      );

  static const IpdTransfersFinancialAtom bedDayOnStart =
      IpdTransfersFinancialAtom(
        id: 'bed_day_on_start',
        label: 'Bed / day on start admission',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.startAdmission,
        billingPath:
            'start → buildAdmissionBilling bed-day → persistAdmissionBilling',
      );

  static const IpdTransfersFinancialAtom consumables =
      IpdTransfersFinancialAtom(
        id: 'consumables',
        label: 'Ward consumables / supplies',
        financialClass: IpdTransfersFinancialClass.createCharge,
        requirement: IpdTransfersAtomPermissions.clinicalWrite,
        billingPath: 'persistConsumableBilling (not mounted on Transfers)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdTransfersFinancialAtom collectPayment =
      IpdTransfersFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IpdTransfersFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Transfers)',
        mounted: false,
      );

  static const IpdTransfersFinancialAtom adjustRefund =
      IpdTransfersFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: IpdTransfersFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<IpdTransfersFinancialAtom> all =
      <IpdTransfersFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionManageTransfer,
        nextActionRequestTransfer,
        requestTransfer,
        manageTransferApproveStartCancel,
        completeTransferRateChange,
        startAdmission,
        approveAdmission,
        assignBed,
        releaseBed,
        rejectAdmission,
        wardRound,
        nursingNote,
        recordMedication,
        orderLab,
        orderRadiology,
        orderPrescription,
        requestTherapy,
        startIcuStay,
        planOrManageDischarge,
        insurancePanel,
        openBilling,
        navigation,
        transferHistoryPanel,
        admissionDeposit,
        bedDayOnStart,
        consumables,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<IpdTransfersFinancialAtom> get mountedAtoms =>
      all.where((IpdTransfersFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<IpdTransfersFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IpdTransfersFinancialAtom atom) =>
            atom.financialClass == IpdTransfersFinancialClass.createCharge ||
            atom.financialClass == IpdTransfersFinancialClass.settle ||
            atom.financialClass == IpdTransfersFinancialClass.adjust ||
            atom.financialClass == IpdTransfersFinancialClass.reverse ||
            atom.financialClass == IpdTransfersFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final IpdTransfersFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool forbidsInlineCashier(IpdTransfersFinancialClass actionClass) {
    return switch (actionClass) {
      IpdTransfersFinancialClass.settle ||
      IpdTransfersFinancialClass.adjust ||
      IpdTransfersFinancialClass.reverse ||
      IpdTransfersFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'IPD Transfers posts bed/day on COMPLETE when the destination rate '
      'differs (BED_TRANSFER charge key). Request / approve / start / cancel '
      'stay NOT_REQUIRED logistics. Open billing navigates Billing. No module '
      'cashier.';
}

/// Documents Transfers financial scope for tests and audits.
const String ipdTransfersBillingScopeNote =
    'IPD Transfers is the ward/bed transfer logistics queue. COMPLETE posts '
    'through buildBedTransferBilling → persistAdmissionBilling when rates '
    'change (idempotent BED_TRANSFER:{transferId}). Same-rate completes and '
    'request/approve/start/cancel are NOT_REQUIRED. Complementary clinical '
    'orders and ward rounds reuse clinical-request-billing. Open billing '
    'navigates the Billing workspace. Settle / adjust / refund are not '
    'mounted — Billing owns payment. Discharge clearance remains on Discharge.';
