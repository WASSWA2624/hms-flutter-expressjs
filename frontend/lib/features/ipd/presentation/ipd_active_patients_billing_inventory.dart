import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IpdActivePatientsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on IPD Active Patients (`/ipd?section=active`).
@immutable
final class IpdActivePatientsFinancialAtom {
  const IpdActivePatientsFinancialAtom({
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
  final IpdActivePatientsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/ipd?section=active`.
///
/// Tab role: current inpatients. Admission deposits, bed/day, transfer rate
/// changes, ward-round / clinical orders, and nursing service charges post
/// through clinical-request-billing. Discharge clearance defers settlement to
/// Billing / finalizeDischarge. Settle / adjust / refund stay on the Billing
/// workspace — this tab never mounts a parallel cashier.
abstract final class IpdActivePatientsBillingInventory {
  static const IpdActivePatientsFinancialAtom tab =
      IpdActivePatientsFinancialAtom(
        id: 'tab',
        label: 'Active Patients tab / count badge',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom listChrome =
      IpdActivePatientsFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom emptyLoadingError =
      IpdActivePatientsFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom rowSelect =
      IpdActivePatientsFinancialAtom(
        id: 'row_select',
        label: 'Row select → admission detail',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom startAdmission =
      IpdActivePatientsFinancialAtom(
        id: 'start_admission',
        label: 'Start admission (fee / deposit / bed-day)',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.startAdmission,
        billingPath:
            'startIpdFlow → buildAdmissionBilling → persistAdmissionBilling '
            '(ADMISSION_START)',
      );

  static const IpdActivePatientsFinancialAtom assignBed =
      IpdActivePatientsFinancialAtom(
        id: 'assign_bed',
        label: 'Assign bed (placement + bed/day when not yet charged)',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.assignBed,
        billingPath:
            'assignBed → buildBedDayBilling → persistAdmissionBilling '
            '(BED_ASSIGN)',
      );

  static const IpdActivePatientsFinancialAtom releaseBed =
      IpdActivePatientsFinancialAtom(
        id: 'release_bed',
        label: 'Release bed (placement; no cashier)',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.releaseBed,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom approveAdmission =
      IpdActivePatientsFinancialAtom(
        id: 'approve_admission',
        label: 'Approve admission request',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.approveAdmission,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom rejectAdmission =
      IpdActivePatientsFinancialAtom(
        id: 'reject_admission',
        label: 'Reject admission request',
        financialClass: IpdActivePatientsFinancialClass.notBilled,
        requirement: IpdActivePatientsAtomPermissions.rejectAdmission,
        auditCode: 'NOT_BILLED',
      );

  static const IpdActivePatientsFinancialAtom requestTransfer =
      IpdActivePatientsFinancialAtom(
        id: 'request_transfer',
        label: 'Request transfer (clinical logistics)',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom manageTransfer =
      IpdActivePatientsFinancialAtom(
        id: 'manage_transfer',
        label: 'Manage transfer approve/start/cancel (logistics)',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.manageTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom transferRateChange =
      IpdActivePatientsFinancialAtom(
        id: 'transfer_rate_change',
        label: 'Complete transfer that changes bed/day rate',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.manageTransfer,
        billingPath:
            'updateTransfer COMPLETE → buildBedTransferBilling → '
            'persistAdmissionBilling (BED_TRANSFER:…)',
      );

  static const IpdActivePatientsFinancialAtom wardRound =
      IpdActivePatientsFinancialAtom(
        id: 'ward_round',
        label: 'Add ward round (optional fee)',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.wardRound,
        billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
      );

  static const IpdActivePatientsFinancialAtom nursingNote =
      IpdActivePatientsFinancialAtom(
        id: 'nursing_note',
        label: 'Add nursing note (optional service charge)',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.recordNursingNote,
        billingPath:
            'add-nursing-note → persistNursingServiceBilling (NURSING)',
      );

  static const IpdActivePatientsFinancialAtom medicationAdmin =
      IpdActivePatientsFinancialAtom(
        id: 'medication_admin',
        label: 'Record medication administration (clinical; charge on Rx)',
        financialClass: IpdActivePatientsFinancialClass.notBilled,
        requirement: IpdActivePatientsAtomPermissions.medication,
        auditCode: 'NOT_BILLED',
      );

  static const IpdActivePatientsFinancialAtom orderLab =
      IpdActivePatientsFinancialAtom(
        id: 'order_lab',
        label: 'Order lab',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.orderLab,
        billingPath: 'createLabOrder → persistLabOrderBilling',
      );

  static const IpdActivePatientsFinancialAtom orderRadiology =
      IpdActivePatientsFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.orderRadiology,
        billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
      );

  static const IpdActivePatientsFinancialAtom orderPrescription =
      IpdActivePatientsFinancialAtom(
        id: 'order_prescription',
        label: 'Order prescription',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.orderPrescription,
        billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
      );

  static const IpdActivePatientsFinancialAtom requestTherapy =
      IpdActivePatientsFinancialAtom(
        id: 'request_therapy',
        label: 'Request therapy (referral; charge in physiotherapy)',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.requestTherapy,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom startIcuStay =
      IpdActivePatientsFinancialAtom(
        id: 'start_icu_stay',
        label: 'Start ICU stay (critical-care package + bed/day)',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.startIcuStay,
        billingPath:
            'start-icu-stay → buildIcuStayBilling → persistIcuStayBilling',
      );

  static const IpdActivePatientsFinancialAtom planDischarge =
      IpdActivePatientsFinancialAtom(
        id: 'plan_discharge',
        label: 'Plan / manage discharge (financial clearance gate)',
        financialClass: IpdActivePatientsFinancialClass.defer,
        requirement: IpdActivePatientsAtomPermissions.planOrManageDischarge,
        billingPath:
            'showDischargePlanningDialog → finalizeDischarge '
            'isBillingSettledForPatient',
      );

  static const IpdActivePatientsFinancialAtom openBilling =
      IpdActivePatientsFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: IpdActivePatientsFinancialClass.defer,
        requirement: IpdActivePatientsAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const IpdActivePatientsFinancialAtom insuranceAuth =
      IpdActivePatientsFinancialAtom(
        id: 'insurance_auth',
        label: 'Insurance authorization panel (claims read; not invoice SoR)',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.billingPanel,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom navigation =
      IpdActivePatientsFinancialAtom(
        id: 'navigation',
        label: 'Open ICU / Theater / Nursing / Physiotherapy',
        financialClass: IpdActivePatientsFinancialClass.notRequired,
        requirement: IpdActivePatientsAtomPermissions.navigation,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdActivePatientsFinancialAtom consumables =
      IpdActivePatientsFinancialAtom(
        id: 'consumables',
        label: 'Ward consumables charge (via nursing / clinical-request)',
        financialClass: IpdActivePatientsFinancialClass.createCharge,
        requirement: IpdActivePatientsAtomPermissions.recordNursingNote,
        billingPath: 'persistNursingServiceBilling / persistConsumableBilling',
        mounted: false,
      );

  static const IpdActivePatientsFinancialAtom collectPayment =
      IpdActivePatientsFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IpdActivePatientsFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Active)',
        mounted: false,
      );

  static const IpdActivePatientsFinancialAtom adjustRefund =
      IpdActivePatientsFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: IpdActivePatientsFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<IpdActivePatientsFinancialAtom> all =
      <IpdActivePatientsFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        startAdmission,
        assignBed,
        releaseBed,
        approveAdmission,
        rejectAdmission,
        requestTransfer,
        manageTransfer,
        transferRateChange,
        wardRound,
        nursingNote,
        medicationAdmin,
        orderLab,
        orderRadiology,
        orderPrescription,
        requestTherapy,
        startIcuStay,
        planDischarge,
        openBilling,
        insuranceAuth,
        navigation,
        consumables,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<IpdActivePatientsFinancialAtom> get mountedAtoms =>
      all.where((IpdActivePatientsFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<IpdActivePatientsFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IpdActivePatientsFinancialAtom atom) =>
            atom.financialClass ==
                IpdActivePatientsFinancialClass.createCharge ||
            atom.financialClass == IpdActivePatientsFinancialClass.settle ||
            atom.financialClass == IpdActivePatientsFinancialClass.adjust ||
            atom.financialClass == IpdActivePatientsFinancialClass.reverse ||
            atom.financialClass == IpdActivePatientsFinancialClass.defer,
      );

  static bool forbidsInlineCashier(IpdActivePatientsFinancialClass actionClass) {
    return switch (actionClass) {
      IpdActivePatientsFinancialClass.settle ||
      IpdActivePatientsFinancialClass.adjust ||
      IpdActivePatientsFinancialClass.reverse => true,
      _ => false,
    };
  }

  static String summary() =>
      'Active Patients posts admission deposit/fee/bed-day, assign-bed and '
      'transfer rate-change charges, ward rounds, nursing services, and '
      'clinical orders through clinical-request-billing. Open billing navigates '
      'Billing. Discharge clearance defers settlement. No module cashier.';
}

/// Documents Active Patients financial scope for tests and audits.
const String ipdActivePatientsBillingScopeNote =
    'IPD Active Patients is the current-inpatients board. Admission deposits, '
    'bed/day charges, transfer rate changes, ward-round/nursing/clinical-order '
    'charges post via clinical-request-billing / persistAdmissionBilling. '
    'Discharge financial clearance uses isBillingSettledForPatient. Settle / '
    'adjust / refund navigate to Billing — never a parallel cash ledger.';
