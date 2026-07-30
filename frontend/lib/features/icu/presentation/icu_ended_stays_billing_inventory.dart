import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuEndedStaysFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Ended stays (`/icu?section=ended`).
@immutable
final class IcuEndedStaysFinancialAtom {
  const IcuEndedStaysFinancialAtom({
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
  final IcuEndedStaysFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=ended`.
///
/// Historical ICU stays overlay on (often still-open) IPD admissions. Prefer
/// read-only: stage next-action is **Open IPD**. Bed/day and critical-care
/// package charges post at stay start via `persistIcuStayBilling`; intensivist
/// rounds / clinical orders reuse ward-round and clinical-request billing when
/// complementary writes remain eligible. Settle / adjust / refund stay on the
/// Billing workspace — this tab never mounts a parallel cashier. End-stay
/// itself is absent once the stay is ended (`NOT_BILLED` historical record).
abstract final class IcuEndedStaysBillingInventory {
  static const IcuEndedStaysFinancialAtom tab = IcuEndedStaysFinancialAtom(
    id: 'tab',
    label: 'Ended stays tab / count badge',
    financialClass: IcuEndedStaysFinancialClass.notRequired,
    requirement: IcuEndedStaysAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuEndedStaysFinancialAtom listChrome =
      IcuEndedStaysFinancialAtom(
        id: 'list_chrome',
        label: 'Search / filters / columns / pagination',
        financialClass: IcuEndedStaysFinancialClass.notRequired,
        requirement: IcuEndedStaysAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuEndedStaysFinancialAtom emptyLoadingError =
      IcuEndedStaysFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IcuEndedStaysFinancialClass.notRequired,
        requirement: IcuEndedStaysAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuEndedStaysFinancialAtom rowSelect =
      IcuEndedStaysFinancialAtom(
        id: 'row_select',
        label: 'Row select → stay detail',
        financialClass: IcuEndedStaysFinancialClass.notRequired,
        requirement: IcuEndedStaysAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuEndedStaysFinancialAtom nextActionOpenIpd =
      IcuEndedStaysFinancialAtom(
        id: 'next_action_open_ipd',
        label: 'Next action Open IPD (navigate)',
        financialClass: IcuEndedStaysFinancialClass.notRequired,
        requirement: IcuEndedStaysAtomPermissions.nextActionOpenIpd,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuEndedStaysFinancialAtom historicalStayCharges =
      IcuEndedStaysFinancialAtom(
        id: 'historical_stay_charges',
        label: 'Historical ICU bed/day + critical-care package (SoR in Billing)',
        financialClass: IcuEndedStaysFinancialClass.createCharge,
        requirement: IcuEndedStaysAtomPermissions.detail,
        billingPath:
            'start-icu-stay → persistIcuStayBilling (ICU_STAY / ICU_STAY_START)',
      );

  static const IcuEndedStaysFinancialAtom startStay =
      IcuEndedStaysFinancialAtom(
        id: 'start_stay',
        label: 'Restart ICU stay when eligible (package + bed/day)',
        financialClass: IcuEndedStaysFinancialClass.createCharge,
        requirement: IcuEndedStaysAtomPermissions.startStay,
        billingPath: 'start-icu-stay → persistIcuStayBilling (ICU_STAY)',
      );

  static const IcuEndedStaysFinancialAtom roundNote =
      IcuEndedStaysFinancialAtom(
        id: 'round_note',
        label: 'ICU round / intensivist review (complementary write)',
        financialClass: IcuEndedStaysFinancialClass.createCharge,
        requirement: IcuEndedStaysAtomPermissions.round,
        billingPath: 'add-ward-round → persistWardRoundBilling (WARD_ROUND)',
      );

  static const IcuEndedStaysFinancialAtom orderLab =
      IcuEndedStaysFinancialAtom(
        id: 'order_lab',
        label: 'Order lab (when encounter present)',
        financialClass: IcuEndedStaysFinancialClass.createCharge,
        requirement: IcuEndedStaysAtomPermissions.orderLab,
        billingPath: 'createLabOrder → persistLabOrderBilling',
      );

  static const IcuEndedStaysFinancialAtom orderImaging =
      IcuEndedStaysFinancialAtom(
        id: 'order_imaging',
        label: 'Order imaging (when encounter present)',
        financialClass: IcuEndedStaysFinancialClass.createCharge,
        requirement: IcuEndedStaysAtomPermissions.orderImaging,
        billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
      );

  static const IcuEndedStaysFinancialAtom prescribe =
      IcuEndedStaysFinancialAtom(
        id: 'prescribe',
        label: 'Prescribe medication (when encounter present)',
        financialClass: IcuEndedStaysFinancialClass.createCharge,
        requirement: IcuEndedStaysAtomPermissions.prescribe,
        billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
      );

  static const IcuEndedStaysFinancialAtom markReadiness =
      IcuEndedStaysFinancialAtom(
        id: 'mark_readiness',
        label: 'Mark discharge readiness (gate; settle on clearance)',
        financialClass: IcuEndedStaysFinancialClass.defer,
        requirement: IcuEndedStaysAtomPermissions.markReadiness,
        billingPath:
            'plan-discharge → IPD finalizeDischarge isBillingSettledForPatient',
      );

  static const IcuEndedStaysFinancialAtom requestTransfer =
      IcuEndedStaysFinancialAtom(
        id: 'request_transfer',
        label: 'Request / manage transfer (clinical logistics)',
        financialClass: IcuEndedStaysFinancialClass.notRequired,
        requirement: IcuEndedStaysAtomPermissions.requestTransfer,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuEndedStaysFinancialAtom endStay = IcuEndedStaysFinancialAtom(
    id: 'end_stay',
    label: 'End ICU stay (absent once ended)',
    financialClass: IcuEndedStaysFinancialClass.notBilled,
    requirement: IcuEndedStaysAtomPermissions.endStay,
    auditCode: 'NOT_BILLED',
    mounted: false,
  );

  static const IcuEndedStaysFinancialAtom billingDeferredBadge =
      IcuEndedStaysFinancialAtom(
        id: 'billing_deferred_badge',
        label: 'Billing deferred badge (ED handoff parity)',
        financialClass: IcuEndedStaysFinancialClass.defer,
        requirement: IcuEndedStaysAtomPermissions.detail,
        billingPath: 'emergency handoff persistAdmissionBilling / PENDING',
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuEndedStaysFinancialAtom openBilling =
      IcuEndedStaysFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (navigate Billing workspace)',
        financialClass: IcuEndedStaysFinancialClass.defer,
        requirement: IcuEndedStaysAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (no inline settle)',
      );

  static const IcuEndedStaysFinancialAtom openDischargeClearance =
      IcuEndedStaysFinancialAtom(
        id: 'open_discharge_clearance',
        label: 'Open discharge clearance (IPD financial gate)',
        financialClass: IcuEndedStaysFinancialClass.defer,
        requirement: IcuEndedStaysAtomPermissions.openDischargeClearance,
        billingPath: 'IPD panel=discharge → billing clearance',
      );

  static const IcuEndedStaysFinancialAtom openIpd = IcuEndedStaysFinancialAtom(
    id: 'open_ipd',
    label: 'Open IPD (navigate)',
    financialClass: IcuEndedStaysFinancialClass.notRequired,
    requirement: IcuEndedStaysAtomPermissions.openIpd,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuEndedStaysFinancialAtom printSummary =
      IcuEndedStaysFinancialAtom(
        id: 'print_summary',
        label: 'Print ICU stay summary',
        financialClass: IcuEndedStaysFinancialClass.noCharge,
        requirement: IcuEndedStaysAtomPermissions.printSummary,
        auditCode: 'NO_CHARGE',
      );

  static const IcuEndedStaysFinancialAtom recordObservation =
      IcuEndedStaysFinancialAtom(
        id: 'record_observation',
        label: 'Record observation (absent without active stay)',
        financialClass: IcuEndedStaysFinancialClass.notBilled,
        requirement: IcuEndedStaysAtomPermissions.recordObservation,
        auditCode: 'NOT_BILLED',
        mounted: false,
      );

  static const IcuEndedStaysFinancialAtom collectPayment =
      IcuEndedStaysFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IcuEndedStaysFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (not mounted on Ended stays)',
        mounted: false,
      );

  static const IcuEndedStaysFinancialAtom adjustRefund =
      IcuEndedStaysFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund / write-off / credit note',
        financialClass: IcuEndedStaysFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const List<IcuEndedStaysFinancialAtom> atoms =
      <IcuEndedStaysFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        nextActionOpenIpd,
        historicalStayCharges,
        startStay,
        roundNote,
        orderLab,
        orderImaging,
        prescribe,
        markReadiness,
        requestTransfer,
        endStay,
        billingDeferredBadge,
        openBilling,
        openDischargeClearance,
        openIpd,
        printSummary,
        recordObservation,
        collectPayment,
        adjustRefund,
      ];

  static Iterable<IcuEndedStaysFinancialAtom> get mountedAtoms =>
      atoms.where((IcuEndedStaysFinancialAtom atom) => atom.mounted);

  /// Mounted atoms that must post through shared Billing paths.
  static Iterable<IcuEndedStaysFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IcuEndedStaysFinancialAtom atom) =>
            atom.financialClass == IcuEndedStaysFinancialClass.createCharge ||
            atom.financialClass == IcuEndedStaysFinancialClass.settle ||
            atom.financialClass == IcuEndedStaysFinancialClass.adjust ||
            atom.financialClass == IcuEndedStaysFinancialClass.reverse ||
            atom.financialClass == IcuEndedStaysFinancialClass.defer,
      );

  static bool get allBillableAtomsWireThroughBilling {
    for (final IcuEndedStaysFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  static bool forbidsInlineCashier(IcuEndedStaysFinancialClass actionClass) {
    return switch (actionClass) {
      IcuEndedStaysFinancialClass.settle ||
      IcuEndedStaysFinancialClass.adjust ||
      IcuEndedStaysFinancialClass.reverse ||
      IcuEndedStaysFinancialClass.createCharge => true,
      _ => false,
    };
  }

  static String summary() =>
      'Ended stays is historical / prefer read-only. Open billing navigates '
      'Billing with patient_id. Package / round / order charges post through '
      'clinical-request-billing. No module cashier.';
}
