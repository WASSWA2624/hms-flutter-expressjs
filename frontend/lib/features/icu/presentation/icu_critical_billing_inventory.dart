import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuCriticalFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Critical alerts
/// (`/icu?section=critical`).
@immutable
final class IcuCriticalFinancialAtom {
  const IcuCriticalFinancialAtom({
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
  final IcuCriticalFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=critical`.
///
/// Tab role: critical alert queue. Acknowledge alert is the stage next-action
/// (`NOT_BILLED`). Complementary surfaces reuse Active ICU billing paths: ICU
/// bed/day + critical-care package on stay start (`persistIcuStayBilling` /
/// facility fee via `icu-billing`), intensivist rounds via ward-round billing,
/// lab/radiology/pharmacy via clinical-request-billing. Transfers are logistics
/// (`NOT_REQUIRED`); discharge readiness defers settlement to IPD clearance /
/// Billing. Settle / adjust / refund stay on Billing — this tab never mounts a
/// parallel cashier.
abstract final class IcuCriticalBillingInventory {
  static const IcuCriticalFinancialAtom tab = IcuCriticalFinancialAtom(
    id: 'tab',
    label: 'Critical alerts tab / count badge',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom listChrome = IcuCriticalFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom emptyLoadingError =
      IcuCriticalFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IcuCriticalFinancialClass.notRequired,
        requirement: IcuCriticalAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuCriticalFinancialAtom alertColumn = IcuCriticalFinancialAtom(
    id: 'alert_column',
    label: 'Alert column / critical row highlight',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.alertColumn,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom rowSelect = IcuCriticalFinancialAtom(
    id: 'row_select',
    label: 'Row select → stay detail',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom nextActionAcknowledge =
      IcuCriticalFinancialAtom(
        id: 'next_action_acknowledge',
        label: 'Next action Acknowledge alert',
        financialClass: IcuCriticalFinancialClass.notBilled,
        requirement: IcuCriticalAtomPermissions.nextActionAcknowledge,
        auditCode: 'NOT_BILLED',
      );

  static const IcuCriticalFinancialAtom acknowledgeAlert =
      IcuCriticalFinancialAtom(
        id: 'acknowledge_alert',
        label: 'Acknowledge / resolve critical alert',
        financialClass: IcuCriticalFinancialClass.notBilled,
        requirement: IcuCriticalAtomPermissions.acknowledgeAlert,
        auditCode: 'NOT_BILLED',
      );

  static const IcuCriticalFinancialAtom raiseAlert = IcuCriticalFinancialAtom(
    id: 'raise_alert',
    label: 'Raise critical alert',
    financialClass: IcuCriticalFinancialClass.notBilled,
    requirement: IcuCriticalAtomPermissions.raiseAlert,
    auditCode: 'NOT_BILLED',
  );

  static const IcuCriticalFinancialAtom startStay = IcuCriticalFinancialAtom(
    id: 'start_stay',
    label: 'Start ICU stay (critical-care package + bed/day)',
    financialClass: IcuCriticalFinancialClass.createCharge,
    requirement: IcuCriticalAtomPermissions.startStay,
    billingPath:
        'start-icu-stay → buildIcuStayBilling + persistIcuStayBilling (ICU_STAY)',
  );

  static const IcuCriticalFinancialAtom assignBed = IcuCriticalFinancialAtom(
    id: 'assign_bed',
    label: 'Assign ICU bed (placement; charges on stay start)',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.assignBed,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom recordObservation =
      IcuCriticalFinancialAtom(
        id: 'record_observation',
        label: 'Record ICU observation',
        financialClass: IcuCriticalFinancialClass.notBilled,
        requirement: IcuCriticalAtomPermissions.recordObservation,
        auditCode: 'NOT_BILLED',
      );

  static const IcuCriticalFinancialAtom recordVitals = IcuCriticalFinancialAtom(
    id: 'record_vitals',
    label: 'Record vitals',
    financialClass: IcuCriticalFinancialClass.notBilled,
    requirement: IcuCriticalAtomPermissions.recordVitals,
    auditCode: 'NOT_BILLED',
  );

  static const IcuCriticalFinancialAtom roundNote = IcuCriticalFinancialAtom(
    id: 'round_note',
    label: 'ICU round / intensivist review',
    financialClass: IcuCriticalFinancialClass.createCharge,
    requirement: IcuCriticalAtomPermissions.round,
    billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
  );

  static const IcuCriticalFinancialAtom orderLab = IcuCriticalFinancialAtom(
    id: 'order_lab',
    label: 'Order lab',
    financialClass: IcuCriticalFinancialClass.createCharge,
    requirement: IcuCriticalAtomPermissions.orderLab,
    billingPath: 'createLabOrder → persistLabOrderBilling',
  );

  static const IcuCriticalFinancialAtom orderImaging = IcuCriticalFinancialAtom(
    id: 'order_imaging',
    label: 'Order imaging',
    financialClass: IcuCriticalFinancialClass.createCharge,
    requirement: IcuCriticalAtomPermissions.orderImaging,
    billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
  );

  static const IcuCriticalFinancialAtom prescribe = IcuCriticalFinancialAtom(
    id: 'prescribe',
    label: 'Prescribe medication',
    financialClass: IcuCriticalFinancialClass.createCharge,
    requirement: IcuCriticalAtomPermissions.prescribe,
    billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
  );

  static const IcuCriticalFinancialAtom requestTransfer =
      IcuCriticalFinancialAtom(
        id: 'request_transfer',
        label: 'Request / manage transfer (clinical logistics)',
        financialClass: IcuCriticalFinancialClass.notRequired,
        requirement: IcuCriticalAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuCriticalFinancialAtom markReadiness =
      IcuCriticalFinancialAtom(
        id: 'mark_readiness',
        label: 'Mark discharge readiness (gate; settle on clearance)',
        financialClass: IcuCriticalFinancialClass.defer,
        requirement: IcuCriticalAtomPermissions.markReadiness,
        billingPath:
            'plan-discharge → IPD finalizeDischarge isBillingSettledForPatient',
      );

  static const IcuCriticalFinancialAtom endStay = IcuCriticalFinancialAtom(
    id: 'end_stay',
    label: 'End ICU stay / step-down (no cashier; ledger stays open)',
    financialClass: IcuCriticalFinancialClass.notBilled,
    requirement: IcuCriticalAtomPermissions.endStay,
    auditCode: 'NOT_BILLED',
  );

  static const IcuCriticalFinancialAtom billingDeferredBadge =
      IcuCriticalFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge (ED handoff parity)',
        financialClass: IcuCriticalFinancialClass.defer,
        requirement: IcuCriticalAtomPermissions.detail,
        billingPath: 'emergency handoff persistAdmissionBilling / PENDING',
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuCriticalFinancialAtom openBilling = IcuCriticalFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (navigate Billing workspace)',
    financialClass: IcuCriticalFinancialClass.defer,
    requirement: IcuCriticalAtomPermissions.openBilling,
    billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
  );

  static const IcuCriticalFinancialAtom openDischargeClearance =
      IcuCriticalFinancialAtom(
        id: 'open_discharge_clearance',
        label: 'Open discharge clearance (IPD financial gate)',
        financialClass: IcuCriticalFinancialClass.defer,
        requirement: IcuCriticalAtomPermissions.openDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance',
      );

  static const IcuCriticalFinancialAtom openIpd = IcuCriticalFinancialAtom(
    id: 'open_ipd',
    label: 'Open IPD (navigate)',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.openIpd,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom printSummary = IcuCriticalFinancialAtom(
    id: 'print_summary',
    label: 'Print ICU stay summary',
    financialClass: IcuCriticalFinancialClass.notRequired,
    requirement: IcuCriticalAtomPermissions.printSummary,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuCriticalFinancialAtom collectPayment =
      IcuCriticalFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IcuCriticalFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Critical)',
        mounted: false,
      );

  static const IcuCriticalFinancialAtom adjustRefund = IcuCriticalFinancialAtom(
    id: 'adjust_refund',
    label: 'Adjust / refund / write-off / credit note',
    financialClass: IcuCriticalFinancialClass.adjust,
    requirement: billingWorkspaceWriteRequirement,
    billingPath: 'Billing adjustment / refund APIs',
    mounted: false,
  );

  static const List<IcuCriticalFinancialAtom> all = <IcuCriticalFinancialAtom>[
    tab,
    listChrome,
    emptyLoadingError,
    alertColumn,
    rowSelect,
    nextActionAcknowledge,
    acknowledgeAlert,
    raiseAlert,
    startStay,
    assignBed,
    recordObservation,
    recordVitals,
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

  static Iterable<IcuCriticalFinancialAtom> get mountedAtoms =>
      all.where((IcuCriticalFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<IcuCriticalFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IcuCriticalFinancialAtom atom) =>
            atom.financialClass == IcuCriticalFinancialClass.createCharge ||
            atom.financialClass == IcuCriticalFinancialClass.settle ||
            atom.financialClass == IcuCriticalFinancialClass.adjust ||
            atom.financialClass == IcuCriticalFinancialClass.reverse ||
            atom.financialClass == IcuCriticalFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final IcuCriticalFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  static bool isInlineCollectionForbidden(
    IcuCriticalFinancialClass actionClass,
  ) {
    return switch (actionClass) {
      IcuCriticalFinancialClass.settle ||
      IcuCriticalFinancialClass.adjust ||
      IcuCriticalFinancialClass.reverse => true,
      _ => false,
    };
  }

  static const String scopeNote =
      'Critical alert queue: acknowledge is NOT_BILLED. Stay package / bed-day '
      'posts via buildIcuStayBilling + persistIcuStayBilling; orders reuse '
      'clinical-request-billing. Open billing navigates Billing. No module cashier.';
}
