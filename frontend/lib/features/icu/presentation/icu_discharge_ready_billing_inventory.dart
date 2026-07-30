import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuDischargeReadyFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Discharge ready
/// (`/icu?section=discharge`).
@immutable
final class IcuDischargeReadyFinancialAtom {
  const IcuDischargeReadyFinancialAtom({
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
  final IcuDischargeReadyFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=discharge` (step-down / discharge ready).
///
/// Tab role: patients approaching step-down. **Mark readiness** is a clinical
/// gate (`plan-discharge`) that defers settlement to IPD discharge clearance /
/// Billing — it must not invent a parallel cash ledger. ICU bed/day and
/// critical-care package charges post on stay start via
/// `persistIcuStayBilling`; intensivist rounds reuse ward-round billing;
/// lab/radiology/pharmacy orders reuse clinical-request-billing. Settle /
/// adjust / refund stay on the Billing workspace — this tab never mounts a
/// cashier. **Open discharge clearance** hands off to IPD financial gates.
abstract final class IcuDischargeReadyBillingInventory {
  static const IcuDischargeReadyFinancialAtom tab =
      IcuDischargeReadyFinancialAtom(
        id: 'tab',
        label: 'Discharge ready tab / count badge',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom listChrome =
      IcuDischargeReadyFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom emptyLoadingError =
      IcuDischargeReadyFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom rowSelect =
      IcuDischargeReadyFinancialAtom(
        id: 'row_select',
        label: 'Row select → stay detail',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom nextActionMarkReadiness =
      IcuDischargeReadyFinancialAtom(
        id: 'next_action_mark_readiness',
        label: 'Next action Mark readiness (clinical gate)',
        financialClass: IcuDischargeReadyFinancialClass.defer,
        requirement: IcuDischargeReadyAtomPermissions.nextActionMarkReadiness,
        billingPath:
            'plan-discharge → IPD finalizeDischarge isBillingSettledForPatient',
      );

  static const IcuDischargeReadyFinancialAtom nextActionOpenClearance =
      IcuDischargeReadyFinancialAtom(
        id: 'next_action_open_clearance',
        label: 'Next action Open discharge clearance',
        financialClass: IcuDischargeReadyFinancialClass.defer,
        requirement:
            IcuDischargeReadyAtomPermissions.nextActionOpenDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance / Billing ledger',
      );

  static const IcuDischargeReadyFinancialAtom markReadiness =
      IcuDischargeReadyFinancialAtom(
        id: 'mark_readiness',
        label: 'Detail Mark readiness (plan-discharge; no collect)',
        financialClass: IcuDischargeReadyFinancialClass.defer,
        requirement: IcuDischargeReadyAtomPermissions.markReadiness,
        billingPath:
            'plan-discharge → clearance summary_ready; settle on finalize',
      );

  static const IcuDischargeReadyFinancialAtom startStay =
      IcuDischargeReadyFinancialAtom(
        id: 'start_stay',
        label: 'Start ICU stay (critical-care package + bed/day)',
        financialClass: IcuDischargeReadyFinancialClass.createCharge,
        requirement: IcuDischargeReadyAtomPermissions.startStay,
        billingPath: 'start-icu-stay → persistIcuStayBilling (ICU_STAY)',
      );

  static const IcuDischargeReadyFinancialAtom assignBed =
      IcuDischargeReadyFinancialAtom(
        id: 'assign_bed',
        label: 'Assign ICU bed (placement; charges on stay start)',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.assignBed,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom recordObservation =
      IcuDischargeReadyFinancialAtom(
        id: 'record_observation',
        label: 'Record ICU observation',
        financialClass: IcuDischargeReadyFinancialClass.notBilled,
        requirement: IcuDischargeReadyAtomPermissions.recordObservation,
        auditCode: 'NOT_BILLED',
      );

  static const IcuDischargeReadyFinancialAtom recordVitals =
      IcuDischargeReadyFinancialAtom(
        id: 'record_vitals',
        label: 'Record vitals',
        financialClass: IcuDischargeReadyFinancialClass.notBilled,
        requirement: IcuDischargeReadyAtomPermissions.recordVitals,
        auditCode: 'NOT_BILLED',
      );

  static const IcuDischargeReadyFinancialAtom raiseAlert =
      IcuDischargeReadyFinancialAtom(
        id: 'raise_alert',
        label: 'Raise / acknowledge critical alert',
        financialClass: IcuDischargeReadyFinancialClass.notBilled,
        requirement: IcuDischargeReadyAtomPermissions.raiseAlert,
        auditCode: 'NOT_BILLED',
      );

  static const IcuDischargeReadyFinancialAtom roundNote =
      IcuDischargeReadyFinancialAtom(
        id: 'round_note',
        label: 'ICU round / intensivist review',
        financialClass: IcuDischargeReadyFinancialClass.createCharge,
        requirement: IcuDischargeReadyAtomPermissions.round,
        billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
      );

  static const IcuDischargeReadyFinancialAtom orderLab =
      IcuDischargeReadyFinancialAtom(
        id: 'order_lab',
        label: 'Order lab',
        financialClass: IcuDischargeReadyFinancialClass.createCharge,
        requirement: IcuDischargeReadyAtomPermissions.orderLab,
        billingPath: 'createLabOrder → persistLabOrderBilling',
      );

  static const IcuDischargeReadyFinancialAtom orderImaging =
      IcuDischargeReadyFinancialAtom(
        id: 'order_imaging',
        label: 'Order imaging',
        financialClass: IcuDischargeReadyFinancialClass.createCharge,
        requirement: IcuDischargeReadyAtomPermissions.orderImaging,
        billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
      );

  static const IcuDischargeReadyFinancialAtom prescribe =
      IcuDischargeReadyFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe medication',
        financialClass: IcuDischargeReadyFinancialClass.createCharge,
        requirement: IcuDischargeReadyAtomPermissions.prescribe,
        billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
      );

  static const IcuDischargeReadyFinancialAtom requestTransfer =
      IcuDischargeReadyFinancialAtom(
        id: 'request_transfer',
        label: 'Request / manage transfer (clinical logistics)',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom endStay =
      IcuDischargeReadyFinancialAtom(
        id: 'end_stay',
        label: 'End ICU stay / step-down (ledger stays open)',
        financialClass: IcuDischargeReadyFinancialClass.notBilled,
        requirement: IcuDischargeReadyAtomPermissions.endStay,
        auditCode: 'NOT_BILLED',
      );

  static const IcuDischargeReadyFinancialAtom billingDeferredBadge =
      IcuDischargeReadyFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge (ED handoff parity)',
        financialClass: IcuDischargeReadyFinancialClass.defer,
        requirement: IcuDischargeReadyAtomPermissions.detail,
        billingPath: 'emergency handoff persistAdmissionBilling / PENDING',
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom openBilling =
      IcuDischargeReadyFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: IcuDischargeReadyFinancialClass.settle,
        requirement: IcuDischargeReadyAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const IcuDischargeReadyFinancialAtom openDischargeClearance =
      IcuDischargeReadyFinancialAtom(
        id: 'open_discharge_clearance',
        label: 'Open discharge clearance (IPD financial gate)',
        financialClass: IcuDischargeReadyFinancialClass.defer,
        requirement: IcuDischargeReadyAtomPermissions.openDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance',
      );

  static const IcuDischargeReadyFinancialAtom openIpd =
      IcuDischargeReadyFinancialAtom(
        id: 'open_ipd',
        label: 'Open IPD (navigate)',
        financialClass: IcuDischargeReadyFinancialClass.notRequired,
        requirement: IcuDischargeReadyAtomPermissions.openIpd,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuDischargeReadyFinancialAtom printSummary =
      IcuDischargeReadyFinancialAtom(
        id: 'print_summary',
        label: 'Print ICU stay summary',
        financialClass: IcuDischargeReadyFinancialClass.noCharge,
        requirement: IcuDischargeReadyAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const IcuDischargeReadyFinancialAtom collectPayment =
      IcuDischargeReadyFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IcuDischargeReadyFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Discharge ready)',
        mounted: false,
      );

  static const IcuDischargeReadyFinancialAtom adjustRefund =
      IcuDischargeReadyFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: IcuDischargeReadyFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<IcuDischargeReadyFinancialAtom> all =
      <IcuDischargeReadyFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionMarkReadiness,
        nextActionOpenClearance,
        markReadiness,
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
        endStay,
        billingDeferredBadge,
        openBilling,
        openDischargeClearance,
        openIpd,
        printSummary,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<IcuDischargeReadyFinancialAtom> get mountedAtoms =>
      all.where((IcuDischargeReadyFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post / navigate through shared Billing paths.
  static Iterable<IcuDischargeReadyFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IcuDischargeReadyFinancialAtom atom) =>
            atom.financialClass ==
                IcuDischargeReadyFinancialClass.createCharge ||
            atom.financialClass == IcuDischargeReadyFinancialClass.settle ||
            atom.financialClass == IcuDischargeReadyFinancialClass.adjust ||
            atom.financialClass == IcuDischargeReadyFinancialClass.reverse ||
            atom.financialClass == IcuDischargeReadyFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final IcuDischargeReadyFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  static bool forbidsInlineCashier(IcuDischargeReadyFinancialClass actionClass) {
    return switch (actionClass) {
      IcuDischargeReadyFinancialClass.settle ||
      IcuDischargeReadyFinancialClass.adjust ||
      IcuDischargeReadyFinancialClass.reverse ||
      IcuDischargeReadyFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Discharge ready defers settlement to IPD clearance / Billing; stay '
      'package, rounds, and clinical orders post via clinical-request-billing. '
      'No module cashier.';
}
