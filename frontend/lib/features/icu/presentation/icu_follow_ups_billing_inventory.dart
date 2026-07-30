import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuFollowUpsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Follow-ups (`/icu?section=follow-ups`).
@immutable
final class IcuFollowUpsFinancialAtom {
  const IcuFollowUpsFinancialAtom({
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
  final IcuFollowUpsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/icu?section=follow-ups`.
///
/// Tab role: shared ICU scheduled-callback worklist (`FollowUpWorklistPanel`
/// scoped `encounterType: ICU`). Mark completed and reschedule stay
/// `NOT_BILLED` ops (status/schedule only). ICU bed/day, critical-care
/// packages, transfer logistics, and discharge-ready financial gates are
/// **not** mounted here — they post on Active ICU / Transfers / Discharge-ready
/// / Billing the same way as IPD, without cashier workflows on this tab. If
/// visit charges or payment UX are introduced, they must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger.
abstract final class IcuFollowUpsBillingInventory {
  static const IcuFollowUpsFinancialAtom tab = IcuFollowUpsFinancialAtom(
    id: 'tab_navigate',
    label: 'Follow-ups tab / count badge',
    financialClass: IcuFollowUpsFinancialClass.notRequired,
    requirement: IcuFollowUpsAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuFollowUpsFinancialAtom listChrome = IcuFollowUpsFinancialAtom(
    id: 'search_columns',
    label: 'Search / clear / columns / table settings',
    financialClass: IcuFollowUpsFinancialClass.notRequired,
    requirement: IcuFollowUpsAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuFollowUpsFinancialAtom emptyLoadingError =
      IcuFollowUpsFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: IcuFollowUpsFinancialClass.notRequired,
        requirement: IcuFollowUpsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IcuFollowUpsFinancialAtom rowSelect = IcuFollowUpsFinancialAtom(
    id: 'row_select_detail',
    label: 'Row select → Follow-up detail dialog',
    financialClass: IcuFollowUpsFinancialClass.notRequired,
    requirement: IcuFollowUpsAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuFollowUpsFinancialAtom detailClose = IcuFollowUpsFinancialAtom(
    id: 'detail_close_readonly',
    label: 'Detail Close (read-only footer)',
    financialClass: IcuFollowUpsFinancialClass.notRequired,
    requirement: IcuFollowUpsAtomPermissions.close,
    auditCode: 'NOT_REQUIRED',
  );

  static const IcuFollowUpsFinancialAtom markCompleted =
      IcuFollowUpsFinancialAtom(
        id: 'detail_mark_completed',
        label: 'Mark completed (callback worklist complete)',
        financialClass: IcuFollowUpsFinancialClass.notBilled,
        requirement: IcuFollowUpsAtomPermissions.markCompleted,
        auditCode: 'NOT_BILLED',
      );

  static const IcuFollowUpsFinancialAtom reschedule = IcuFollowUpsFinancialAtom(
    id: 'detail_reschedule',
    label: 'Reschedule follow-up',
    financialClass: IcuFollowUpsFinancialClass.notBilled,
    requirement: IcuFollowUpsAtomPermissions.reschedule,
    auditCode: 'NOT_BILLED',
  );

  static const IcuFollowUpsFinancialAtom saveFollowUp =
      IcuFollowUpsFinancialAtom(
        id: 'nested_save_follow_up',
        label: 'Save follow-up (nested reschedule dialog)',
        financialClass: IcuFollowUpsFinancialClass.notBilled,
        requirement: IcuFollowUpsAtomPermissions.saveFollowUp,
        auditCode: 'NOT_BILLED',
      );

  static const IcuFollowUpsFinancialAtom realtimeListSync =
      IcuFollowUpsFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation Follow-ups list refresh',
        financialClass: IcuFollowUpsFinancialClass.notRequired,
        requirement: IcuFollowUpsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only affordance reserved for outstanding ICU ledger balances.
  /// Not mounted — Billing workspace remains system of record.
  static const IcuFollowUpsFinancialAtom openBilling = IcuFollowUpsFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (settle / invoice / waive / refund)',
    financialClass: IcuFollowUpsFinancialClass.settle,
    requirement: IcuFollowUpsAtomPermissions.tab,
    billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const IcuFollowUpsFinancialAtom followUpVisitCharge =
      IcuFollowUpsFinancialAtom(
        id: 'follow_up_visit_charge',
        label: 'Follow-up visit / consult charge on complete',
        financialClass: IcuFollowUpsFinancialClass.createCharge,
        requirement: IcuFollowUpsAtomPermissions.write,
        billingPath:
            'clinical-request-billing upsertClinicalRequestBilling (when mounted)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IcuFollowUpsFinancialAtom icuBedDayPackage =
      IcuFollowUpsFinancialAtom(
        id: 'icu_bed_day_package',
        label: 'ICU bed/day + critical-care package charges',
        financialClass: IcuFollowUpsFinancialClass.createCharge,
        requirement: IcuFollowUpsAtomPermissions.write,
        billingPath:
            'start-icu-stay → persistIcuStayBilling (Active ICU; not this tab)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IcuFollowUpsFinancialAtom transferCharges =
      IcuFollowUpsFinancialAtom(
        id: 'transfer_charges',
        label: 'Transfer logistics / step-down charges',
        financialClass: IcuFollowUpsFinancialClass.createCharge,
        requirement: IcuFollowUpsAtomPermissions.write,
        billingPath: 'Transfers tab + clinical-request-billing (not this tab)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IcuFollowUpsFinancialAtom dischargeFinancialGate =
      IcuFollowUpsFinancialAtom(
        id: 'discharge_financial_gate',
        label: 'Discharge-ready financial clearance gate',
        financialClass: IcuFollowUpsFinancialClass.defer,
        requirement: IcuFollowUpsAtomPermissions.write,
        billingPath:
            'Discharge-ready / IPD finalizeDischarge isBillingSettledForPatient',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IcuFollowUpsFinancialAtom collectPayment =
      IcuFollowUpsFinancialAtom(
        id: 'collect_payment',
        label: 'Collect payment / receive payment',
        financialClass: IcuFollowUpsFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (facility billingPaymentMethods)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IcuFollowUpsFinancialAtom issueInvoiceAdjustRefund =
      IcuFollowUpsFinancialAtom(
        id: 'issue_invoice_adjust_refund',
        label: 'Issue invoice / adjust / refund / reverse / write-off',
        financialClass: IcuFollowUpsFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / credit-note / refund paths',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const List<IcuFollowUpsFinancialAtom> atoms =
      <IcuFollowUpsFinancialAtom>[
        tab,
        listChrome,
        emptyLoadingError,
        rowSelect,
        detailClose,
        markCompleted,
        reschedule,
        saveFollowUp,
        realtimeListSync,
        openBilling,
        followUpVisitCharge,
        icuBedDayPackage,
        transferCharges,
        dischargeFinancialGate,
        collectPayment,
        issueInvoiceAdjustRefund,
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static List<IcuFollowUpsFinancialAtom> get billableAtoms => atoms
      .where(
        (IcuFollowUpsFinancialAtom atom) =>
            atom.financialClass == IcuFollowUpsFinancialClass.createCharge ||
            atom.financialClass == IcuFollowUpsFinancialClass.settle ||
            atom.financialClass == IcuFollowUpsFinancialClass.adjust ||
            atom.financialClass == IcuFollowUpsFinancialClass.reverse ||
            atom.financialClass == IcuFollowUpsFinancialClass.defer,
      )
      .toList(growable: false);

  static List<IcuFollowUpsFinancialAtom> get mountedAtoms => atoms
      .where((IcuFollowUpsFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IcuFollowUpsFinancialAtom atom) =>
        atom.financialClass == IcuFollowUpsFinancialClass.notRequired ||
        atom.financialClass == IcuFollowUpsFinancialClass.notBilled ||
        atom.financialClass == IcuFollowUpsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get followUpsTabHasNoBillableActions =>
      billableAtoms.every((IcuFollowUpsFinancialAtom atom) => !atom.mounted);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    IcuFollowUpsFinancialClass financialClass,
  ) {
    return financialClass == IcuFollowUpsFinancialClass.settle ||
        financialClass == IcuFollowUpsFinancialClass.adjust ||
        financialClass == IcuFollowUpsFinancialClass.reverse ||
        financialClass == IcuFollowUpsFinancialClass.createCharge;
  }

  static String summary() =>
      'ICU Follow-ups is a shared callback worklist. Mark completed and '
      'reschedule stay NOT_BILLED. Bed/day, packages, transfers, discharge '
      'gates, and cashier settle live on Active ICU / Transfers / '
      'Discharge-ready / Billing — never duplicated here.';
}

/// Documents Follow-ups financial scope for tests and audits.
const String icuFollowUpsBillingScopeNote =
    'ICU Follow-ups is a shared ICU scheduled callback worklist '
    '(FollowUpWorklistPanel, encounterType ICU). Mark completed and reschedule '
    'stay NOT_BILLED ops that update follow-up status/schedule only. ICU '
    'bed/day, critical-care packages, transfer charges, and discharge-ready '
    'financial gates complete via Active ICU / Transfers / Discharge-ready and '
    'the Billing module — never duplicated here. Visit/consult charges and '
    'payment collection are not mounted; they must use clinical-request-billing '
    '/ receive-payment when introduced.';
