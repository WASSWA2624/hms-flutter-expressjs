import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum DischargeFollowUpsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Discharge Follow-ups
/// (`/discharge?section=follow-ups`).
@immutable
final class DischargeFollowUpsFinancialAtom {
  const DischargeFollowUpsFinancialAtom({
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
  final DischargeFollowUpsFinancialClass financialClass;
  final AccessRequirement requirement;

  /// Shared Billing / clinical-request-billing entry — null when not-billable.
  final String? billingPath;
  final String? auditCode;
  final bool mounted;
}

/// Canonical inventory for `/discharge?section=follow-ups`.
///
/// Tab role: post-discharge IPD callback worklist ([FollowUpWorklistPanel]
/// scoped `encounterType: IPD`). Mark completed and reschedule stay
/// `NOT_BILLED` ops (status/schedule only). Financial clearance, pharmacy
/// returns, outstanding balances, waivers, and final invoices are **not**
/// mounted here — they complete on Pending clearance / All / Billing before
/// discharge closure. If visit charges or payment UX are introduced, they must
/// post via Billing (`clinical-request-billing` / receive-payment /
/// adjustment)—never a parallel cash ledger. Planning / clearance / pharmacy /
/// invoice detail UI is not reachable from this tab.
abstract final class DischargeFollowUpsBillingInventory {
  static const DischargeFollowUpsFinancialAtom tab =
      DischargeFollowUpsFinancialAtom(
        id: 'tab_navigate',
        label: 'Follow-ups tab / count badge',
        financialClass: DischargeFollowUpsFinancialClass.notRequired,
        requirement: DischargeFollowUpsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeFollowUpsFinancialAtom listChrome =
      DischargeFollowUpsFinancialAtom(
        id: 'search_columns',
        label: 'Search / clear / columns / table settings',
        financialClass: DischargeFollowUpsFinancialClass.notRequired,
        requirement: DischargeFollowUpsAtomPermissions.listChrome,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeFollowUpsFinancialAtom emptyLoadingError =
      DischargeFollowUpsFinancialAtom(
        id: 'empty_error_retry_loading',
        label: 'Empty / loading / error / retry states',
        financialClass: DischargeFollowUpsFinancialClass.notRequired,
        requirement: DischargeFollowUpsAtomPermissions.empty,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeFollowUpsFinancialAtom rowSelect =
      DischargeFollowUpsFinancialAtom(
        id: 'row_select_detail',
        label: 'Row select → Follow-up detail dialog',
        financialClass: DischargeFollowUpsFinancialClass.notRequired,
        requirement: DischargeFollowUpsAtomPermissions.rowSelect,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeFollowUpsFinancialAtom detailClose =
      DischargeFollowUpsFinancialAtom(
        id: 'detail_close_readonly',
        label: 'Detail Close (read-only footer)',
        financialClass: DischargeFollowUpsFinancialClass.notRequired,
        requirement: DischargeFollowUpsAtomPermissions.close,
        auditCode: 'NOT_REQUIRED',
      );

  static const DischargeFollowUpsFinancialAtom markCompleted =
      DischargeFollowUpsFinancialAtom(
        id: 'detail_mark_completed',
        label: 'Mark completed (callback worklist complete)',
        financialClass: DischargeFollowUpsFinancialClass.notBilled,
        requirement: DischargeFollowUpsAtomPermissions.markCompleted,
        auditCode: 'NOT_BILLED',
      );

  static const DischargeFollowUpsFinancialAtom reschedule =
      DischargeFollowUpsFinancialAtom(
        id: 'detail_reschedule',
        label: 'Reschedule follow-up',
        financialClass: DischargeFollowUpsFinancialClass.notBilled,
        requirement: DischargeFollowUpsAtomPermissions.reschedule,
        auditCode: 'NOT_BILLED',
      );

  static const DischargeFollowUpsFinancialAtom saveFollowUp =
      DischargeFollowUpsFinancialAtom(
        id: 'nested_save_follow_up',
        label: 'Save follow-up (nested reschedule dialog)',
        financialClass: DischargeFollowUpsFinancialClass.notBilled,
        requirement: DischargeFollowUpsAtomPermissions.saveFollowUp,
        auditCode: 'NOT_BILLED',
      );

  static const DischargeFollowUpsFinancialAtom realtimeListSync =
      DischargeFollowUpsFinancialAtom(
        id: 'realtime_list_sync',
        label: 'Post-mutation Follow-ups list refresh',
        financialClass: DischargeFollowUpsFinancialClass.notRequired,
        requirement: DischargeFollowUpsAtomPermissions.tab,
        auditCode: 'NOT_REQUIRED',
      );

  /// Navigate-only affordance reserved for outstanding post-discharge balances.
  /// Not mounted — Billing workspace remains system of record.
  static const DischargeFollowUpsFinancialAtom openBilling =
      DischargeFollowUpsFinancialAtom(
        id: 'open_billing',
        label: 'Open billing (settle / invoice / waive / refund)',
        financialClass: DischargeFollowUpsFinancialClass.settle,
        requirement: DischargeFollowUpsAtomPermissions.tab,
        billingPath: 'AppRoutes.billing?patient_id=… (Billing workspace)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const DischargeFollowUpsFinancialAtom followUpVisitCharge =
      DischargeFollowUpsFinancialAtom(
        id: 'follow_up_visit_charge',
        label: 'Follow-up visit / consult charge on complete',
        financialClass: DischargeFollowUpsFinancialClass.createCharge,
        requirement: DischargeFollowUpsAtomPermissions.write,
        billingPath:
            'clinical-request-billing upsertClinicalRequestBilling (when mounted)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const DischargeFollowUpsFinancialAtom collectPayment =
      DischargeFollowUpsFinancialAtom(
        id: 'collect_payment',
        label: 'Collect payment / receive payment',
        financialClass: DischargeFollowUpsFinancialClass.settle,
        requirement: DischargeFollowUpsAtomPermissions.write,
        billingPath: 'Billing receive-payment (facility billingPaymentMethods)',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const DischargeFollowUpsFinancialAtom issueInvoiceAdjustRefund =
      DischargeFollowUpsFinancialAtom(
        id: 'issue_invoice_adjust_refund',
        label: 'Issue invoice / adjust / refund / reverse / write-off',
        financialClass: DischargeFollowUpsFinancialClass.adjust,
        requirement: DischargeFollowUpsAtomPermissions.write,
        billingPath: 'Billing adjustment / credit-note / refund paths',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const DischargeFollowUpsFinancialAtom pharmacyReturn =
      DischargeFollowUpsFinancialAtom(
        id: 'pharmacy_return',
        label: 'Pharmacy return / reverse dispense',
        financialClass: DischargeFollowUpsFinancialClass.reverse,
        requirement: DischargeFollowUpsAtomPermissions.write,
        billingPath: 'Pharmacy + Billing reverse / credit linked to original',
        auditCode: 'REQUIRES_BILLING',
        mounted: false,
      );

  static const List<DischargeFollowUpsFinancialAtom> atoms =
      <DischargeFollowUpsFinancialAtom>[
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
        collectPayment,
        issueInvoiceAdjustRefund,
        pharmacyReturn,
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static List<DischargeFollowUpsFinancialAtom> get billableAtoms => atoms
      .where(
        (DischargeFollowUpsFinancialAtom atom) =>
            atom.financialClass ==
                DischargeFollowUpsFinancialClass.createCharge ||
            atom.financialClass == DischargeFollowUpsFinancialClass.settle ||
            atom.financialClass == DischargeFollowUpsFinancialClass.adjust ||
            atom.financialClass == DischargeFollowUpsFinancialClass.reverse ||
            atom.financialClass == DischargeFollowUpsFinancialClass.defer,
      )
      .toList(growable: false);

  static List<DischargeFollowUpsFinancialAtom> get mountedAtoms => atoms
      .where((DischargeFollowUpsFinancialAtom atom) => atom.mounted)
      .toList(growable: false);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (DischargeFollowUpsFinancialAtom atom) =>
        atom.financialClass == DischargeFollowUpsFinancialClass.notRequired ||
        atom.financialClass == DischargeFollowUpsFinancialClass.notBilled ||
        atom.financialClass == DischargeFollowUpsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get followUpsTabHasNoBillableActions =>
      billableAtoms.every((DischargeFollowUpsFinancialAtom atom) => !atom.mounted);

  /// Inline collect/issue/refund is forbidden on this tab — Billing owns it.
  static bool isInlineCollectionForbidden(
    DischargeFollowUpsFinancialClass financialClass,
  ) {
    return financialClass == DischargeFollowUpsFinancialClass.settle ||
        financialClass == DischargeFollowUpsFinancialClass.adjust ||
        financialClass == DischargeFollowUpsFinancialClass.reverse;
  }
}

/// Documents Follow-ups financial scope for tests and audits.
const String dischargeFollowUpsBillingScopeNote =
    'Discharge Follow-ups is a post-discharge IPD scheduled callback worklist '
    '(FollowUpWorklistPanel, encounterType IPD). Mark completed and reschedule '
    'stay NOT_BILLED ops that update follow-up status/schedule only. Financial '
    'clearance, pharmacy returns, outstanding balances, waivers, and final '
    'invoices complete via the Billing module before discharge closure on other '
    'desk tabs — never duplicated here. Visit/consult charges and payment '
    'collection are not mounted; they must use clinical-request-billing / '
    'receive-payment when introduced.';
