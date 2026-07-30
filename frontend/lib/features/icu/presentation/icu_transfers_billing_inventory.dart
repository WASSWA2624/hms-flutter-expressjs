import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuTransfersFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Transfers (`/icu?section=transfers`).
@immutable
final class IcuTransfersFinancialAtom {
  const IcuTransfersFinancialAtom({
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
  final IcuTransfersFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=transfers`.
///
/// Tab role: ICU transfer queue. **Request / Manage transfer** are clinical
/// logistics (`request-transfer` / `update-transfer`) — no patient ledger post
/// and no module cashier. ICU bed/day and critical-care package charges post on
/// stay start via `persistIcuStayBilling`; intensivist rounds reuse ward-round
/// billing; lab/radiology/pharmacy orders reuse clinical-request-billing.
/// Settle / adjust / refund stay on the Billing workspace. Discharge clearance
/// and final settlement remain owned by IPD / Discharge / Billing.
abstract final class IcuTransfersBillingInventory {
  static const IcuTransfersFinancialAtom tab = IcuTransfersFinancialAtom(
    id: 'tab',
    label: 'Transfers tab / count badge',
    financialClass: IcuTransfersFinancialClass.notRequired,
    requirement: IcuTransfersAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuTransfersFinancialAtom listChrome = IcuTransfersFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: IcuTransfersFinancialClass.notRequired,
    requirement: IcuTransfersAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuTransfersFinancialAtom transferColumn =
      IcuTransfersFinancialAtom(
        id: 'transfer_column',
        label: 'Transfer status column',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.transferColumn,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom emptyLoadingError =
      IcuTransfersFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom rowSelect = IcuTransfersFinancialAtom(
    id: 'row_select',
    label: 'Row select → stay detail',
    financialClass: IcuTransfersFinancialClass.notRequired,
    requirement: IcuTransfersAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuTransfersFinancialAtom nextActionManageTransfer =
      IcuTransfersFinancialAtom(
        id: 'next_action_manage_transfer',
        label: 'Next action Manage transfer (clinical logistics)',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.nextActionManageTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom nextActionRequestTransfer =
      IcuTransfersFinancialAtom(
        id: 'next_action_request_transfer',
        label: 'Next action Request transfer (clinical logistics)',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.nextActionRequestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom requestTransfer =
      IcuTransfersFinancialAtom(
        id: 'request_transfer',
        label: 'Request transfer (request-transfer; no ledger)',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom manageTransfer =
      IcuTransfersFinancialAtom(
        id: 'manage_transfer',
        label: 'Manage transfer (approve/start/complete/cancel)',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.manageTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom startStay = IcuTransfersFinancialAtom(
    id: 'start_stay',
    label: 'Start ICU stay (critical-care package + bed/day)',
    financialClass: IcuTransfersFinancialClass.createCharge,
    requirement: IcuTransfersAtomPermissions.startStay,
    billingPath: 'start-icu-stay → persistIcuStayBilling (ICU_STAY)',
  );

  static const IcuTransfersFinancialAtom assignBed = IcuTransfersFinancialAtom(
    id: 'assign_bed',
    label: 'Assign ICU bed (placement; charges on stay start)',
    financialClass: IcuTransfersFinancialClass.notRequired,
    requirement: IcuTransfersAtomPermissions.assignBed,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuTransfersFinancialAtom recordObservation =
      IcuTransfersFinancialAtom(
        id: 'record_observation',
        label: 'Record ICU observation',
        financialClass: IcuTransfersFinancialClass.notBilled,
        requirement: IcuTransfersAtomPermissions.recordObservation,
        auditCode: 'NOT_BILLED',
      );

  static const IcuTransfersFinancialAtom recordVitals =
      IcuTransfersFinancialAtom(
        id: 'record_vitals',
        label: 'Record vitals',
        financialClass: IcuTransfersFinancialClass.notBilled,
        requirement: IcuTransfersAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const IcuTransfersFinancialAtom raiseAlert = IcuTransfersFinancialAtom(
    id: 'raise_alert',
    label: 'Raise / acknowledge critical alert',
    financialClass: IcuTransfersFinancialClass.notBilled,
    requirement: IcuTransfersAtomPermissions.raiseAlert,
    auditCode: 'NOT_BILLED',
  );

  static const IcuTransfersFinancialAtom roundNote = IcuTransfersFinancialAtom(
    id: 'round_note',
    label: 'ICU round / intensivist review',
    financialClass: IcuTransfersFinancialClass.createCharge,
    requirement: IcuTransfersAtomPermissions.round,
    billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
  );

  static const IcuTransfersFinancialAtom orderLab = IcuTransfersFinancialAtom(
    id: 'order_lab',
    label: 'Order lab',
    financialClass: IcuTransfersFinancialClass.createCharge,
    requirement: IcuTransfersAtomPermissions.orderLab,
    billingPath: 'createLabOrder → persistLabOrderBilling',
  );

  static const IcuTransfersFinancialAtom orderImaging =
      IcuTransfersFinancialAtom(
        id: 'order_imaging',
        label: 'Order imaging',
        financialClass: IcuTransfersFinancialClass.createCharge,
        requirement: IcuTransfersAtomPermissions.orderImaging,
        billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
      );

  static const IcuTransfersFinancialAtom prescribe = IcuTransfersFinancialAtom(
    id: 'prescribe',
    label: 'Prescribe medication',
    financialClass: IcuTransfersFinancialClass.createCharge,
    requirement: IcuTransfersAtomPermissions.prescribe,
    billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
  );

  static const IcuTransfersFinancialAtom markReadiness =
      IcuTransfersFinancialAtom(
        id: 'mark_readiness',
        label: 'Mark discharge readiness (gate; settle on clearance)',
        financialClass: IcuTransfersFinancialClass.defer,
        requirement: IcuTransfersAtomPermissions.markReadiness,
        billingPath:
            'plan-discharge → IPD finalizeDischarge isBillingSettledForPatient',
      );

  static const IcuTransfersFinancialAtom endStay = IcuTransfersFinancialAtom(
    id: 'end_stay',
    label: 'End ICU stay / step-down (no cashier; ledger stays open)',
    financialClass: IcuTransfersFinancialClass.notBilled,
    requirement: IcuTransfersAtomPermissions.endStay,
    auditCode: 'NOT_BILLED',
  );

  static const IcuTransfersFinancialAtom billingDeferredBadge =
      IcuTransfersFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge (ED handoff parity)',
        financialClass: IcuTransfersFinancialClass.defer,
        requirement: IcuTransfersAtomPermissions.detail,
        billingPath: 'emergency handoff persistAdmissionBilling / PENDING',
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom openBilling = IcuTransfersFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing workspace)',
    financialClass: IcuTransfersFinancialClass.defer,
    requirement: IcuTransfersAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const IcuTransfersFinancialAtom openDischargeClearance =
      IcuTransfersFinancialAtom(
        id: 'open_discharge_clearance',
        label: 'Open discharge clearance (IPD financial gate)',
        financialClass: IcuTransfersFinancialClass.defer,
        requirement: IcuTransfersAtomPermissions.openDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance',
      );

  static const IcuTransfersFinancialAtom openIpd = IcuTransfersFinancialAtom(
    id: 'open_ipd',
    label: 'Open IPD (navigate)',
    financialClass: IcuTransfersFinancialClass.notRequired,
    requirement: IcuTransfersAtomPermissions.openIpd,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuTransfersFinancialAtom printSummary =
      IcuTransfersFinancialAtom(
        id: 'print_summary',
        label: 'Print ICU stay summary',
        financialClass: IcuTransfersFinancialClass.noCharge,
        requirement: IcuTransfersAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const IcuTransfersFinancialAtom transferPanel =
      IcuTransfersFinancialAtom(
        id: 'transfer_panel',
        label: 'Detail Transfer / discharge / stay history panel',
        financialClass: IcuTransfersFinancialClass.notRequired,
        requirement: IcuTransfersAtomPermissions.detail,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuTransfersFinancialAtom collectPayment =
      IcuTransfersFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IcuTransfersFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Transfers)',
        mounted: false,
      );

  static const IcuTransfersFinancialAtom adjustRefund =
      IcuTransfersFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: IcuTransfersFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<IcuTransfersFinancialAtom> all =
      <IcuTransfersFinancialAtom>[
        tab,
        listChrome,
        transferColumn,
        emptyLoadingError,
        rowSelect,
        nextActionManageTransfer,
        nextActionRequestTransfer,
        requestTransfer,
        manageTransfer,
        startStay,
        assignBed,
        recordObservation,
        recordVitals,
        raiseAlert,
        roundNote,
        orderLab,
        orderImaging,
        prescribe,
        markReadiness,
        endStay,
        billingDeferredBadge,
        openBilling,
        openDischargeClearance,
        openIpd,
        printSummary,
        transferPanel,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<IcuTransfersFinancialAtom> get mountedAtoms =>
      all.where((IcuTransfersFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<IcuTransfersFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IcuTransfersFinancialAtom atom) =>
            atom.financialClass == IcuTransfersFinancialClass.createCharge ||
            atom.financialClass == IcuTransfersFinancialClass.settle ||
            atom.financialClass == IcuTransfersFinancialClass.adjust ||
            atom.financialClass == IcuTransfersFinancialClass.reverse ||
            atom.financialClass == IcuTransfersFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final IcuTransfersFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden — Billing owns payment.
  static bool forbidsInlineCashier(IcuTransfersFinancialClass actionClass) {
    return switch (actionClass) {
      IcuTransfersFinancialClass.settle ||
      IcuTransfersFinancialClass.adjust ||
      IcuTransfersFinancialClass.reverse ||
      IcuTransfersFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'ICU Transfers posts stay package / bed-day and round charges through '
      'clinical-request-billing when those complementary actions run; request / '
      'manage transfer stay NOT_REQUIRED logistics. Open billing navigates '
      'Billing. No module cashier.';
}

/// Documents Transfers financial scope for tests and audits.
const String icuTransfersBillingScopeNote =
    'ICU Transfers is the transfer logistics queue. Request / manage transfer '
    'are NOT_REQUIRED clinical logistics (no patient ledger). Complementary '
    'start-stay, rounds, and clinical orders post via persistIcuStayBilling / '
    'persistWardRoundBilling / clinical-request-billing. Open billing navigates '
    'the Billing workspace with patient_id. Settle / adjust / refund are not '
    'mounted — Billing owns payment.';
