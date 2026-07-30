import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IpdFollowUpsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on IPD Follow-ups (`/ipd?section=follow-ups`).
@immutable
final class IpdFollowUpsFinancialAtom {
  const IpdFollowUpsFinancialAtom({
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
  final IpdFollowUpsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/ipd?section=follow-ups`.
///
/// Tab role: shared IPD scheduled-callback worklist (`FollowUpWorklistPanel`
/// scoped `encounterType: IPD`). Mark completed and reschedule stay
/// `NOT_BILLED` ops (status/schedule only). Admission deposits, bed/day,
/// transfer rate changes, consumables, and discharge financial clearance are
/// **not** mounted here — they post on Admission queue / Active / Transfers /
/// Discharge / Billing. No Start admission on this tab. If visit charges or
/// payment UX are introduced, they must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger.
abstract final class IpdFollowUpsBillingInventory {
  static const IpdFollowUpsFinancialAtom tab = IpdFollowUpsFinancialAtom(
    id: 'tab_navigate',
    label: 'Follow-ups tab / count badge',
    financialClass: IpdFollowUpsFinancialClass.notRequired,
    requirement: IpdFollowUpsAtomPermissions.tab,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdFollowUpsFinancialAtom listChrome = IpdFollowUpsFinancialAtom(
    id: 'search_columns',
    label: 'Search / clear / columns / table settings',
    financialClass: IpdFollowUpsFinancialClass.notRequired,
    requirement: IpdFollowUpsAtomPermissions.listChrome,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdFollowUpsFinancialAtom emptyLoadingError =
      IpdFollowUpsFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: IpdFollowUpsFinancialClass.notRequired,
        requirement: IpdFollowUpsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const IpdFollowUpsFinancialAtom rowSelect = IpdFollowUpsFinancialAtom(
    id: 'row_select_detail',
    label: 'Row select → Follow-up detail dialog',
    financialClass: IpdFollowUpsFinancialClass.notRequired,
    requirement: IpdFollowUpsAtomPermissions.rowSelect,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdFollowUpsFinancialAtom detailClose = IpdFollowUpsFinancialAtom(
    id: 'detail_close_readonly',
    label: 'Detail Close (read-only footer)',
    financialClass: IpdFollowUpsFinancialClass.notRequired,
    requirement: IpdFollowUpsAtomPermissions.close,
    auditCode: 'NOT_REQUIRED',
  );

  static const IpdFollowUpsFinancialAtom markCompleted =
      IpdFollowUpsFinancialAtom(
        id: 'detail_mark_completed',
        label: 'Mark completed (callback worklist complete)',
        financialClass: IpdFollowUpsFinancialClass.notBilled,
        requirement: IpdFollowUpsAtomPermissions.markCompleted,
        auditCode: 'NOT_BILLED',
      );

  static const IpdFollowUpsFinancialAtom reschedule = IpdFollowUpsFinancialAtom(
    id: 'detail_reschedule',
    label: 'Reschedule follow-up',
    financialClass: IpdFollowUpsFinancialClass.notBilled,
    requirement: IpdFollowUpsAtomPermissions.reschedule,
    auditCode: 'NOT_BILLED',
  );

  static const IpdFollowUpsFinancialAtom saveFollowUp =
      IpdFollowUpsFinancialAtom(
        id: 'nested_save_follow_up',
        label: 'Save follow-up (nested reschedule dialog)',
        financialClass: IpdFollowUpsFinancialClass.notBilled,
        requirement: IpdFollowUpsAtomPermissions.saveFollowUp,
        auditCode: 'NOT_BILLED',
      );

  static const IpdFollowUpsFinancialAtom realtimeListSync =
      IpdFollowUpsFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation Follow-ups list refresh',
        financialClass: IpdFollowUpsFinancialClass.notRequired,
        requirement: IpdFollowUpsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only affordance reserved for outstanding IPD ledger balances.
  /// Not mounted — Billing workspace remains system of record.
  static const IpdFollowUpsFinancialAtom openBilling = IpdFollowUpsFinancialAtom(
    id: 'open_billing',
    label: 'Open billing (settle / invoice / waive / refund)',
    financialClass: IpdFollowUpsFinancialClass.settle,
    requirement: IpdFollowUpsAtomPermissions.tab,
    billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const IpdFollowUpsFinancialAtom followUpVisitCharge =
      IpdFollowUpsFinancialAtom(
        id: 'follow_up_visit_charge',
        label: 'Follow-up visit / consult charge on complete',
        financialClass: IpdFollowUpsFinancialClass.createCharge,
        requirement: IpdFollowUpsAtomPermissions.write,
        billingPath:
            'clinical-request-billing upsertClinicalRequestBilling (when mounted)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdFollowUpsFinancialAtom admissionDeposit =
      IpdFollowUpsFinancialAtom(
        id: 'admission_deposit',
        label: 'Admission deposit / prepayment',
        financialClass: IpdFollowUpsFinancialClass.settle,
        requirement: IpdFollowUpsAtomPermissions.write,
        billingPath:
            'Start admission / Admission queue → Billing receive-payment '
            '(not this tab)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdFollowUpsFinancialAtom bedDayCharge = IpdFollowUpsFinancialAtom(
    id: 'bed_day_charge',
    label: 'Bed / day charges',
    financialClass: IpdFollowUpsFinancialClass.createCharge,
    requirement: IpdFollowUpsAtomPermissions.write,
    billingPath:
        'Active patients / assign bed → clinical-request-billing (not this tab)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const IpdFollowUpsFinancialAtom transferRateChange =
      IpdFollowUpsFinancialAtom(
        id: 'transfer_rate_change',
        label: 'Transfer that changes bed rate',
        financialClass: IpdFollowUpsFinancialClass.createCharge,
        requirement: IpdFollowUpsAtomPermissions.write,
        billingPath:
            'Transfers tab + clinical-request-billing rate delta (not this tab)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdFollowUpsFinancialAtom consumables = IpdFollowUpsFinancialAtom(
    id: 'consumables',
    label: 'Ward consumables / supplies charge',
    financialClass: IpdFollowUpsFinancialClass.createCharge,
    requirement: IpdFollowUpsAtomPermissions.write,
    billingPath:
        'Active patients / nursing clinical-request-billing (not this tab)',
    auditCode: 'REQUIRES_BILLING',
    mounted: false,
  );

  static const IpdFollowUpsFinancialAtom dischargeFinancialClearance =
      IpdFollowUpsFinancialAtom(
        id: 'discharge_financial_clearance',
        label: 'Discharge financial clearance gate',
        financialClass: IpdFollowUpsFinancialClass.defer,
        requirement: IpdFollowUpsAtomPermissions.write,
        billingPath:
            'Discharge tab finalizeDischarge isBillingSettledForPatient',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdFollowUpsFinancialAtom collectPayment =
      IpdFollowUpsFinancialAtom(
        id: 'collect_payment',
        label: 'Collect payment / receive payment',
        financialClass: IpdFollowUpsFinancialClass.settle,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing receive-payment (facility billingPaymentMethods)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const IpdFollowUpsFinancialAtom issueInvoiceAdjustRefund =
      IpdFollowUpsFinancialAtom(
        id: 'issue_invoice_adjust_refund',
        label: 'Issue invoice / adjust / refund / reverse / write-off',
        financialClass: IpdFollowUpsFinancialClass.adjust,
        requirement: billingWorkspaceWriteRequirement,
        billingPath: 'Billing adjustment / credit-note / refund paths',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const List<IpdFollowUpsFinancialAtom> atoms =
      <IpdFollowUpsFinancialAtom>[
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
        admissionDeposit,
        bedDayCharge,
        transferRateChange,
        consumables,
        dischargeFinancialClearance,
        collectPayment,
        issueInvoiceAdjustRefund,
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static List<IpdFollowUpsFinancialAtom> get billableAtoms => atoms
      .where(
        (IpdFollowUpsFinancialAtom atom) =>
            atom.financialClass == IpdFollowUpsFinancialClass.createCharge ||
            atom.financialClass == IpdFollowUpsFinancialClass.settle ||
            atom.financialClass == IpdFollowUpsFinancialClass.adjust ||
            atom.financialClass == IpdFollowUpsFinancialClass.reverse ||
            atom.financialClass == IpdFollowUpsFinancialClass.defer,
      )
      .toList(growable: false);

  static List<IpdFollowUpsFinancialAtom> get mountedAtoms => atoms
      .where((IpdFollowUpsFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IpdFollowUpsFinancialAtom atom) =>
        atom.financialClass == IpdFollowUpsFinancialClass.notRequired ||
        atom.financialClass == IpdFollowUpsFinancialClass.notBilled ||
        atom.financialClass == IpdFollowUpsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get followUpsTabHasNoBillableActions =>
      billableAtoms.every((IpdFollowUpsFinancialAtom atom) => !atom.mounted);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    IpdFollowUpsFinancialClass financialClass,
  ) {
    return financialClass == IpdFollowUpsFinancialClass.settle ||
        financialClass == IpdFollowUpsFinancialClass.adjust ||
        financialClass == IpdFollowUpsFinancialClass.reverse ||
        financialClass == IpdFollowUpsFinancialClass.createCharge;
  }

  static String summary() =>
      'IPD Follow-ups is a shared callback worklist. Mark completed and '
      'reschedule stay NOT_BILLED. Deposits, bed/day, transfers, consumables, '
      'discharge clearance, and cashier settle live on Admission queue / '
      'Active / Transfers / Discharge / Billing — never duplicated here.';
}

/// Documents Follow-ups financial scope for tests and audits.
const String ipdFollowUpsBillingScopeNote =
    'IPD Follow-ups is a shared IPD scheduled callback worklist '
    '(FollowUpWorklistPanel, encounterType IPD). Mark completed and reschedule '
    'stay NOT_BILLED ops that update follow-up status/schedule only. Admission '
    'deposits, bed/day charges, transfer rate changes, consumables, and '
    'discharge financial clearance complete via Admission queue / Active / '
    'Transfers / Discharge and the Billing module — never duplicated here. '
    'Visit/consult charges and payment collection are not mounted; they must '
    'use clinical-request-billing / receive-payment when introduced. No Start '
    'admission on this tab.';
