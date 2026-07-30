import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuAllFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU All (`/icu?section=all`).
@immutable
final class IcuAllFinancialAtom {
  const IcuAllFinancialAtom({
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
  final IcuAllFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=all` (unfiltered ICU board).
///
/// Same clinical actions as Active ICU across all stay stages. ICU bed/day and
/// critical-care package charges post on stay start via
/// `persistIcuStayBilling`; intensivist rounds reuse ward-round billing;
/// lab/radiology/pharmacy orders reuse clinical-request billing. Transfers are
/// clinical logistics (rate changes post elsewhere when bed/day changes).
/// Discharge readiness defers settlement to IPD clearance / Billing. Settle /
/// adjust / refund stay on the Billing workspace — this tab never mounts a
/// parallel cashier.
abstract final class IcuAllBillingInventory {
  static const IcuAllFinancialAtom tab = IcuAllFinancialAtom(
    id: 'tab',
    label: 'All ICU tab / count badge',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom listChrome = IcuAllFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom emptyLoadingError = IcuAllFinancialAtom(
    id: 'empty_loading_error',
    label: 'Empty / loading / error / retry',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.empty,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom rowSelect = IcuAllFinancialAtom(
    id: 'row_select',
    label: 'Row select → stay detail',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom startStay = IcuAllFinancialAtom(
    id: 'start_stay',
    label: 'Start ICU stay (critical-care package + bed/day)',
    financialClass: IcuAllFinancialClass.createCharge,
    requirement: IcuAllAtomPermissions.startStay,
    billingPath:
        'start-icu-stay → persistIcuStayBilling (ICU_STAY / ICU_STAY_START)',
  );

  static const IcuAllFinancialAtom assignBed = IcuAllFinancialAtom(
    id: 'assign_bed',
    label: 'Assign ICU bed (placement; charges on stay start)',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.assignBed,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom recordObservation = IcuAllFinancialAtom(
    id: 'record_observation',
    label: 'Record ICU observation',
    financialClass: IcuAllFinancialClass.notBilled,
    requirement: IcuAllAtomPermissions.recordObservation,
    auditCode: 'NOT_BILLED',
  );

  static const IcuAllFinancialAtom recordVitals = IcuAllFinancialAtom(
    id: 'record_vitals',
    label: 'Record vitals',
    financialClass: IcuAllFinancialClass.notBilled,
    requirement: IcuAllAtomPermissions.recordVitals,
    auditCode: 'NOT_BILLED',
  );

  static const IcuAllFinancialAtom raiseAlert = IcuAllFinancialAtom(
    id: 'raise_alert',
    label: 'Raise / acknowledge critical alert',
    financialClass: IcuAllFinancialClass.notBilled,
    requirement: IcuAllAtomPermissions.raiseAlert,
    auditCode: 'NOT_BILLED',
  );

  static const IcuAllFinancialAtom roundNote = IcuAllFinancialAtom(
    id: 'round_note',
    label: 'ICU round / intensivist review',
    financialClass: IcuAllFinancialClass.createCharge,
    requirement: IcuAllAtomPermissions.round,
    billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
  );

  static const IcuAllFinancialAtom orderLab = IcuAllFinancialAtom(
    id: 'order_lab',
    label: 'Order lab',
    financialClass: IcuAllFinancialClass.createCharge,
    requirement: IcuAllAtomPermissions.orderLab,
    billingPath: 'createLabOrder → persistLabOrderBilling',
  );

  static const IcuAllFinancialAtom orderImaging = IcuAllFinancialAtom(
    id: 'order_imaging',
    label: 'Order imaging',
    financialClass: IcuAllFinancialClass.createCharge,
    requirement: IcuAllAtomPermissions.orderImaging,
    billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
  );

  static const IcuAllFinancialAtom prescribe = IcuAllFinancialAtom(
    id: 'prescribe',
    label: 'Prescribe medication',
    financialClass: IcuAllFinancialClass.createCharge,
    requirement: IcuAllAtomPermissions.prescribe,
    billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
  );

  static const IcuAllFinancialAtom requestTransfer = IcuAllFinancialAtom(
    id: 'request_transfer',
    label: 'Request / manage transfer (clinical logistics)',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.requestTransfer,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom markReadiness = IcuAllFinancialAtom(
    id: 'mark_readiness',
    label: 'Mark discharge readiness (gate; settle on clearance)',
    financialClass: IcuAllFinancialClass.defer,
    requirement: IcuAllAtomPermissions.markReadiness,
    billingPath:
        'plan-discharge → IPD finalizeDischarge isBillingSettledForPatient',
  );

  static const IcuAllFinancialAtom endStay = IcuAllFinancialAtom(
    id: 'end_stay',
    label: 'End ICU stay / step-down (no cashier; ledger stays open)',
    financialClass: IcuAllFinancialClass.notBilled,
    requirement: IcuAllAtomPermissions.endStay,
    auditCode: 'NOT_BILLED',
  );

  static const IcuAllFinancialAtom billingDeferredBadge = IcuAllFinancialAtom(
    id: 'billing_deferred_badge',
    label: 'Billing deferred badge (ED handoff parity)',
    financialClass: IcuAllFinancialClass.defer,
    requirement: IcuAllAtomPermissions.detail,
    billingPath: 'emergency handoff persistAdmissionBilling / PENDING',
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom openBilling = IcuAllFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing workspace)',
    financialClass: IcuAllFinancialClass.defer,
    requirement: IcuAllAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const IcuAllFinancialAtom openDischargeClearance =
      IcuAllFinancialAtom(
        id: 'open_discharge_clearance',
        label: 'Open discharge clearance (IPD financial gate)',
        financialClass: IcuAllFinancialClass.defer,
        requirement: IcuAllAtomPermissions.openDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance',
      );

  static const IcuAllFinancialAtom openIpd = IcuAllFinancialAtom(
    id: 'open_ipd',
    label: 'Open IPD (navigate)',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.openIpd,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom printSummary = IcuAllFinancialAtom(
    id: 'print_summary',
    label: 'Print ICU stay summary',
    financialClass: IcuAllFinancialClass.notRequired,
    requirement: IcuAllAtomPermissions.printSummary,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuAllFinancialAtom collectPayment = IcuAllFinancialAtom(
    id: 'collect_payment',
    label: 'Receive payment / cashier collect',
    financialClass: IcuAllFinancialClass.settle,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing receive-payment (not mounted on All ICU)',
    mounted: false,
  );

  static const IcuAllFinancialAtom adjustRefund = IcuAllFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: IcuAllFinancialClass.adjust,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<IcuAllFinancialAtom> atoms = <IcuAllFinancialAtom>[
    tab,
    listChrome,
    emptyLoadingError,
    rowSelect,
    startStay,
    assignBed,
    recordObservation,
    recordVitals,
    raiseAlert,
    roundNote,
    orderLab,
    orderImaging,
    prescribe,
    requestTransfer,
    markReadiness,
    endStay,
    billingDeferredBadge,
    openBilling,
    openDischargeClearance,
    openIpd,
    printSummary,
    collectPayment,
    adjustRefund,
  ];

  static Iterable<IcuAllFinancialAtom> get mountedAtoms =>
      atoms.where((IcuAllFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<IcuAllFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IcuAllFinancialAtom atom) =>
            atom.financialClass == IcuAllFinancialClass.createCharge ||
            atom.financialClass == IcuAllFinancialClass.settle ||
            atom.financialClass == IcuAllFinancialClass.adjust ||
            atom.financialClass == IcuAllFinancialClass.reverse ||
            atom.financialClass == IcuAllFinancialClass.defer,
      );

  static bool forbidsInlineCashier(IcuAllFinancialClass actionClass) {
    return switch (actionClass) {
      IcuAllFinancialClass.settle ||
      IcuAllFinancialClass.adjust ||
      IcuAllFinancialClass.reverse => true,
      _ => false,
    };
  }

  static String summary() =>
      'All ICU board posts stay package / bed-day and round charges through '
      'clinical-request-billing; clinical orders reuse lab/radiology/pharmacy '
      'billing. Open billing navigates Billing. No module cashier.';
}
