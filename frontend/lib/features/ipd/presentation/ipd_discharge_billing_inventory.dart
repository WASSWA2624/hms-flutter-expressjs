import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IpdDischargeFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on IPD Discharge (`/ipd?section=discharge`).
@immutable
final class IpdDischargeFinancialAtom {
  const IpdDischargeFinancialAtom({
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
  final IpdDischargeFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/ipd?section=discharge`.
///
/// Tab role: discharge planning handoff (`DISCHARGE_PLANNED`). Plan / manage
/// discharge is clinical (`NOT_BILLED`); finalize is **defer**-gated by
/// `assertBillingSettledForDischarge` (Billing ledger). Open billing navigates
/// to the Billing workspace for final bill, deposit refunds, outstanding
/// balance, waive/adjust — never an IPD cashier. Admission deposits (Start
/// admission), ward-round / clinical orders post via clinical-request-billing.
abstract final class IpdDischargeBillingInventory {
  static const IpdDischargeFinancialAtom tab = IpdDischargeFinancialAtom(
    id: 'tab',
    label: 'Discharge tab / count badge',
    financialClass: IpdDischargeFinancialClass.notRequired,
    requirement: IpdDischargeAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdDischargeFinancialAtom listChrome = IpdDischargeFinancialAtom(
    id: 'list_chrome',
    label: 'Search / filters / columns / pagination',
    financialClass: IpdDischargeFinancialClass.notRequired,
    requirement: IpdDischargeAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdDischargeFinancialAtom emptyLoadingError =
      IpdDischargeFinancialAtom(
        id: 'empty_loading_error',
        label: 'Empty / loading / error / retry',
        financialClass: IpdDischargeFinancialClass.notRequired,
        requirement: IpdDischargeAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdDischargeFinancialAtom rowSelect = IpdDischargeFinancialAtom(
    id: 'row_select',
    label: 'Row select → admission detail',
    financialClass: IpdDischargeFinancialClass.notRequired,
    requirement: IpdDischargeAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdDischargeFinancialAtom startAdmission =
      IpdDischargeFinancialAtom(
        id: 'start_admission',
        label: 'Start admission (deposit / bed charges)',
        financialClass: IpdDischargeFinancialClass.createCharge,
        requirement: IpdDischargeAtomPermissions.startAdmission,
        billingPath:
            'request-admission → persistAdmissionBilling (clinical-request-billing)',
      );

  static const IpdDischargeFinancialAtom nextActionManageDischarge =
      IpdDischargeFinancialAtom(
        id: 'next_action_manage_discharge',
        label: 'Next action Manage discharge (planning dialog)',
        financialClass: IpdDischargeFinancialClass.notBilled,
        requirement: IpdDischargeAtomPermissions.planOrManageDischarge,
        auditCode: 'NOT_BILLED',
      );

  static const IpdDischargeFinancialAtom planDischarge =
      IpdDischargeFinancialAtom(
        id: 'plan_discharge',
        label: 'Planning dialog Save plan',
        financialClass: IpdDischargeFinancialClass.notBilled,
        requirement: IpdDischargeAtomPermissions.planDischarge,
        auditCode: 'NOT_BILLED',
      );

  static const IpdDischargeFinancialAtom manageDischarge =
      IpdDischargeFinancialAtom(
        id: 'manage_discharge',
        label: 'Detail Manage discharge / finalize clearance',
        financialClass: IpdDischargeFinancialClass.defer,
        requirement: IpdDischargeAtomPermissions.manageDischarge,
        billingPath:
            'finalizeDischarge → assertBillingSettledForDischarge (Billing ledger)',
      );

  static const IpdDischargeFinancialAtom finalizeWithOverride =
      IpdDischargeFinancialAtom(
        id: 'finalize_override',
        label: 'Finalize with override_reason (defer unpaid clearance)',
        financialClass: IpdDischargeFinancialClass.defer,
        requirement: IpdDischargeAtomPermissions.update,
        billingPath: 'finalizeDischarge override_reason (audited defer)',
      );

  static const IpdDischargeFinancialAtom clearanceBillingStep =
      IpdDischargeFinancialAtom(
        id: 'clearance_billing_step',
        label: 'Clearance checklist billing step (parity read)',
        financialClass: IpdDischargeFinancialClass.notRequired,
        requirement: IpdDischargeAtomPermissions.billingPanel,
        billingPath:
            'Derived from Billing isBillingSettledForPatient / invoice parity',
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdDischargeFinancialAtom openBilling =
      IpdDischargeFinancialAtom(
        id: 'open_billing',
        label:
            'Open billing (final bill, refund deposits, settle outstanding)',
        financialClass: IpdDischargeFinancialClass.settle,
        requirement: IpdDischargeAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const IpdDischargeFinancialAtom planningOpenInvoiceResolve =
      IpdDischargeFinancialAtom(
        id: 'planning_open_invoice_resolve',
        label: 'Planning dialog Continue on open invoice → Billing',
        financialClass: IpdDischargeFinancialClass.settle,
        requirement: IpdDischargeAtomPermissions.openBilling,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
      );

  static const IpdDischargeFinancialAtom billingPanel =
      IpdDischargeFinancialAtom(
        id: 'billing_panel',
        label: 'Detail insurance / billing clearance read',
        financialClass: IpdDischargeFinancialClass.notRequired,
        requirement: IpdDischargeAtomPermissions.billingPanel,
        billingPath: 'GET invoices / claims auth (Billing SoR status)',
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdDischargeFinancialAtom releaseBed =
      IpdDischargeFinancialAtom(
        id: 'release_bed',
        label: 'Release bed (ops after planned discharge)',
        financialClass: IpdDischargeFinancialClass.notRequired,
        requirement: IpdDischargeAtomPermissions.releaseBed,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdDischargeFinancialAtom orderLab = IpdDischargeFinancialAtom(
    id: 'order_lab',
    label: 'Order lab (detail; active bed)',
    financialClass: IpdDischargeFinancialClass.createCharge,
    requirement: IpdDischargeAtomPermissions.orderLab,
    billingPath: 'createLabOrder → persistLabOrderBilling',
  );

  static const IpdDischargeFinancialAtom orderRadiology =
      IpdDischargeFinancialAtom(
        id: 'order_radiology',
        label: 'Order radiology (detail; active bed)',
        financialClass: IpdDischargeFinancialClass.createCharge,
        requirement: IpdDischargeAtomPermissions.orderRadiology,
        billingPath: 'createRadiologyOrder → persistRadiologyOrderBilling',
      );

  static const IpdDischargeFinancialAtom orderPrescription =
      IpdDischargeFinancialAtom(
        id: 'order_prescription',
        label: 'Order prescription (detail; active bed)',
        financialClass: IpdDischargeFinancialClass.createCharge,
        requirement: IpdDischargeAtomPermissions.orderPrescription,
        billingPath: 'createPharmacyOrder → persistPharmacyOrderBilling',
      );

  static const IpdDischargeFinancialAtom wardRound = IpdDischargeFinancialAtom(
    id: 'ward_round',
    label: 'Add ward round',
    financialClass: IpdDischargeFinancialClass.createCharge,
    requirement: IpdDischargeAtomPermissions.wardRound,
    billingPath: 'add-ward-round → persistWardRoundBilling',
  );

  static const IpdDischargeFinancialAtom medication =
      IpdDischargeFinancialAtom(
        id: 'medication',
        label: 'Record medication administration',
        financialClass: IpdDischargeFinancialClass.notBilled,
        requirement: IpdDischargeAtomPermissions.medication,
        auditCode: 'NOT_BILLED',
      );

  static const IpdDischargeFinancialAtom nursingNote =
      IpdDischargeFinancialAtom(
        id: 'nursing_note',
        label: 'Add nursing note (optional nursing service charge)',
        financialClass: IpdDischargeFinancialClass.createCharge,
        requirement: IpdDischargeAtomPermissions.recordNursingNote,
        billingPath:
            'add-nursing-note → persistNursingServiceBilling (when billed)',
      );

  static const IpdDischargeFinancialAtom collectPayment =
      IpdDischargeFinancialAtom(
        id: 'collect_payment',
        label: 'Receive payment / cashier collect',
        financialClass: IpdDischargeFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (facility billingPaymentMethods)',
        mounted: false,
      );

  static const IpdDischargeFinancialAtom adjustRefund =
      IpdDischargeFinancialAtom(
        id: 'adjust_refund',
        label: 'Adjust / refund unused deposit / write-off / credit note',
        financialClass: IpdDischargeFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / refund APIs',
        mounted: false,
      );

  static const IpdDischargeFinancialAtom issueInvoiceLocal =
      IpdDischargeFinancialAtom(
        id: 'issue_invoice_local',
        label: 'Issue invoice locally on Discharge tab (forbidden)',
        financialClass: IpdDischargeFinancialClass.settle,
        requirement: IpdDischargeAtomPermissions.openBilling,
        billingPath: 'Billing workspace only — no module cashier',
        mounted: false,
      );

  static const List<IpdDischargeFinancialAtom> atoms =
      <IpdDischargeFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        startAdmission,
        nextActionManageDischarge,
        planDischarge,
        manageDischarge,
        finalizeWithOverride,
        clearanceBillingStep,
        openBilling,
        planningOpenInvoiceResolve,
        billingPanel,
        releaseBed,
        orderLab,
        orderRadiology,
        orderPrescription,
        wardRound,
        medication,
        nursingNote,
        collectPayment,
        adjustRefund,
        issueInvoiceLocal,
      ];

  static List<IpdDischargeFinancialAtom> get billableAtoms => atoms
      .where(
        (IpdDischargeFinancialAtom atom) =>
            atom.financialClass == IpdDischargeFinancialClass.createCharge ||
            atom.financialClass == IpdDischargeFinancialClass.settle ||
            atom.financialClass == IpdDischargeFinancialClass.adjust ||
            atom.financialClass == IpdDischargeFinancialClass.reverse ||
            atom.financialClass == IpdDischargeFinancialClass.defer,
      )
      .toList(growable: false);

  static List<IpdDischargeFinancialAtom> get mountedAtoms => atoms
      .where((IpdDischargeFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  static Iterable<IpdDischargeFinancialAtom> get billableMounted =>
      mountedAtoms.where(
        (IpdDischargeFinancialAtom atom) =>
            atom.financialClass == IpdDischargeFinancialClass.createCharge ||
            atom.financialClass == IpdDischargeFinancialClass.settle ||
            atom.financialClass == IpdDischargeFinancialClass.adjust ||
            atom.financialClass == IpdDischargeFinancialClass.reverse ||
            atom.financialClass == IpdDischargeFinancialClass.defer,
      );

  /// Every mounted billable atom must navigate or post via a Billing path.
  static bool get allMountedBillableAtomsWireThroughBilling {
    for (final IpdDischargeFinancialAtom atom in billableMounted) {
      if (atom.billingPath == null || atom.billingPath!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    IpdDischargeFinancialClass financialClass,
  ) {
    return financialClass == IpdDischargeFinancialClass.settle ||
        financialClass == IpdDischargeFinancialClass.adjust ||
        financialClass == IpdDischargeFinancialClass.reverse;
  }

  static String summary() =>
      'IPD Discharge is a planning handoff. Plan stays NOT_BILLED; finalize is '
      'gated by Billing ledger settlement. Open billing navigates for final '
      'bill / deposit refund / outstanding balance. Clinical orders and Start '
      'admission post via clinical-request-billing. No module cashier.';
}

/// Documents Discharge financial scope for tests and audits.
const String ipdDischargeBillingScopeNote =
    'IPD Discharge (`/ipd?section=discharge`) lists DISCHARGE_PLANNED '
    'admissions. Manage discharge opens DischargePlanningDialog — plan is '
    'NOT_BILLED; finalize uses assertBillingSettledForDischarge / override '
    'deferral. Open billing navigates to Billing for settle / refund / '
    'adjust. Start admission deposits and ward-round / lab / radiology / Rx '
    'charges post via clinical-request-billing. Inline receive-payment and '
    'local invoice create are forbidden.';
