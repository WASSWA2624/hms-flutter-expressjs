import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuActiveFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Active (`/icu` or `?section=active`).
@immutable
final class IcuActiveFinancialAtom {
  const IcuActiveFinancialAtom({
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
  final IcuActiveFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry point — null when
  /// not-billable chrome or navigation only.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=active`.
///
/// Active ICU stays overlay on IPD admissions. ICU bed/day and critical-care
/// package charges post on stay start via clinical-request-billing; intensivist
/// rounds reuse ward-round billing; lab/radiology/pharmacy orders reuse clinical
/// order billing. Settle / adjust / refund stay on the Billing workspace — this
/// tab never mounts a parallel cashier. Discharge clearance and final settlement
/// remain owned by IPD / Discharge / Billing.
abstract final class IcuActiveBillingInventory {
  static const IcuActiveFinancialAtom tab = IcuActiveFinancialAtom(
    id: 'tab',
    label: 'Active ICU tab / count badge',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom listChrome = IcuActiveFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom emptyLoadingError = IcuActiveFinancialAtom(
    id: 'empty_loading_error',
    label: 'Empty / loading / error / retry',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.empty,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom rowSelect = IcuActiveFinancialAtom(
    id: 'row_select',
    label: 'Row select → stay detail',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom startStay = IcuActiveFinancialAtom(
    id: 'start_stay',
    label: 'Start ICU stay (critical-care package + bed/day)',
    financialClass: IcuActiveFinancialClass.createCharge,
    requirement: IcuActiveIcuAtomPermissions.startStay,
    billingPath: 'start-icu-stay → persistIcuStayBilling (ICU_STAY)',
  );

  static const IcuActiveFinancialAtom assignBed = IcuActiveFinancialAtom(
    id: 'assign_bed',
    label: 'Assign ICU bed (placement; charges on stay start)',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.assignBed,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom recordObservation = IcuActiveFinancialAtom(
    id: 'record_observation',
    label: 'Record ICU observation',
    financialClass: IcuActiveFinancialClass.notBilled,
    requirement: IcuActiveIcuAtomPermissions.recordObservation,
    auditCode: 'NOT_BILLED',
  );

  static const IcuActiveFinancialAtom recordVitals = IcuActiveFinancialAtom(
    id: 'record_vitals',
    label: 'Record vitals',
    financialClass: IcuActiveFinancialClass.notBilled,
    requirement: IcuActiveIcuAtomPermissions.recordVitals,
    auditCode: 'NOT_BILLED',
  );

  static const IcuActiveFinancialAtom raiseAlert = IcuActiveFinancialAtom(
    id: 'raise_alert',
    label: 'Raise / acknowledge critical alert',
    financialClass: IcuActiveFinancialClass.notBilled,
    requirement: IcuActiveIcuAtomPermissions.raiseAlert,
    auditCode: 'NOT_BILLED',
  );

  static const IcuActiveFinancialAtom roundNote = IcuActiveFinancialAtom(
    id: 'round_note',
    label: 'ICU round / intensivist review',
    financialClass: IcuActiveFinancialClass.createCharge,
    requirement: IcuActiveIcuAtomPermissions.round,
    billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
  );

  static const IcuActiveFinancialAtom orderLab = IcuActiveFinancialAtom(
    id: 'order_lab',
    label: 'Order lab',
    financialClass: IcuActiveFinancialClass.createCharge,
    requirement: IcuActiveIcuAtomPermissions.orderLab,
    billingPath: 'createLabOrder → persistLabOrderBilling',
  );

  static const IcuActiveFinancialAtom orderImaging = IcuActiveFinancialAtom(
    id: 'order_imaging',
    label: 'Order imaging',
    financialClass: IcuActiveFinancialClass.createCharge,
    requirement: IcuActiveIcuAtomPermissions.orderImaging,
    billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
  );

  static const IcuActiveFinancialAtom prescribe = IcuActiveFinancialAtom(
    id: 'prescribe',
    label: 'Prescribe medication',
    financialClass: IcuActiveFinancialClass.createCharge,
    requirement: IcuActiveIcuAtomPermissions.prescribe,
    billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
  );

  static const IcuActiveFinancialAtom requestTransfer = IcuActiveFinancialAtom(
    id: 'request_transfer',
    label: 'Request / manage transfer (clinical logistics)',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.requestTransfer,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom markReadiness = IcuActiveFinancialAtom(
    id: 'mark_readiness',
    label: 'Mark discharge readiness (gate; settle on clearance)',
    financialClass: IcuActiveFinancialClass.defer,
    requirement: IcuActiveIcuAtomPermissions.markReadiness,
    billingPath:
        'plan-discharge → IPD finalizeDischarge isBillingSettledForPatient',
  );

  static const IcuActiveFinancialAtom endStay = IcuActiveFinancialAtom(
    id: 'end_stay',
    label: 'End ICU stay / step-down (no cashier; ledger stays open)',
    financialClass: IcuActiveFinancialClass.notBilled,
    requirement: IcuActiveIcuAtomPermissions.endStay,
    auditCode: 'NOT_BILLED',
  );

  static const IcuActiveFinancialAtom billingDeferredBadge =
      IcuActiveFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge (ED handoff parity)',
        financialClass: IcuActiveFinancialClass.defer,
        requirement: IcuActiveIcuAtomPermissions.detail,
        billingPath: 'emergency handoff persistAdmissionBilling / PENDING',
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuActiveFinancialAtom openBilling = IcuActiveFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing workspace)',
    financialClass: IcuActiveFinancialClass.defer,
    requirement: IcuActiveIcuAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const IcuActiveFinancialAtom openDischargeClearance =
      IcuActiveFinancialAtom(
        id: 'open_discharge_clearance',
        label: 'Open discharge clearance (IPD financial gate)',
        financialClass: IcuActiveFinancialClass.defer,
        requirement: IcuActiveIcuAtomPermissions.openDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance',
      );

  static const IcuActiveFinancialAtom openIpd = IcuActiveFinancialAtom(
    id: 'open_ipd',
    label: 'Open IPD (navigate)',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.openIpd,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom printSummary = IcuActiveFinancialAtom(
    id: 'print_summary',
    label: 'Print ICU stay summary',
    financialClass: IcuActiveFinancialClass.notRequired,
    requirement: IcuActiveIcuAtomPermissions.printSummary,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuActiveFinancialAtom collectPayment = IcuActiveFinancialAtom(
    id: 'collect_payment',
    label: 'Receive payment / cashier collect',
    financialClass: IcuActiveFinancialClass.settle,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing receive-payment (not mounted on Active ICU)',
    mounted: false,
  );

  static const IcuActiveFinancialAtom adjustRefund = IcuActiveFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: IcuActiveFinancialClass.adjust,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<IcuActiveFinancialAtom> all = <IcuActiveFinancialAtom>[
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

  static Iterable<IcuActiveFinancialAtom> get mountedAtoms =>
      all.where((IcuActiveFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<IcuActiveFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IcuActiveFinancialAtom atom) =>
            atom.financialClass == IcuActiveFinancialClass.createCharge ||
            atom.financialClass == IcuActiveFinancialClass.settle ||
            atom.financialClass == IcuActiveFinancialClass.adjust ||
            atom.financialClass == IcuActiveFinancialClass.reverse ||
            atom.financialClass == IcuActiveFinancialClass.defer,
      );

  static bool forbidsInlineCashier(IcuActiveFinancialClass actionClass) {
    return switch (actionClass) {
      IcuActiveFinancialClass.settle ||
      IcuActiveFinancialClass.adjust ||
      IcuActiveFinancialClass.reverse ||
      IcuActiveFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Active ICU posts stay package / bed-day and round charges through '
      'clinical-request-billing; clinical orders reuse lab/radiology/pharmacy '
      'billing. Open billing navigates Billing. No module cashier.';
}
