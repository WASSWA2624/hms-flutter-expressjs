import 'package:flutter/foundation.dart';

/// Financial action classes aligned with
/// `prompts/billing-and-sections/_shared-rules.md`.
enum IcuBedBoardFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on ICU Bed board (`/icu?section=beds`).
@immutable
final class IcuBedBoardFinancialAtom {
  const IcuBedBoardFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
    this.billingPath,
  });

  final String id;
  final String label;
  final IcuBedBoardFinancialClass financialClass;
  final String auditCode;
  final bool mounted;

  /// Shared Billing entry when [financialClass] posts a ledger row.
  final String? billingPath;
}

/// Canonical inventory for `/icu?section=beds` (ICU ward occupancy).
///
/// Scope: tab chrome, Manage beds primary → Rooms & beds, ward filter chips,
/// available/occupied summary badges, bed rows (location / occupant / status),
/// Open IPD on occupied rows. This tab is a **read occupancy board**; bed CRUD
/// stays in Facility / Rooms & beds, and clinical mutations (assign bed,
/// transfers, orders, discharge readiness) live on other ICU tabs.
///
/// ICU bed/day, critical-care packages, transfer rate changes, and
/// discharge-ready financial gates are **not mounted here**. When those
/// actions run elsewhere they must post via shared Billing
/// (`persistAdmissionBilling` / clinical-request-billing / receive-payment /
/// adjustment / IPD discharge clearance)—never a parallel cash ledger on this
/// board. Settlement stays on the Billing workspace.
abstract final class IcuBedBoardBillingInventory {
  static const List<IcuBedBoardFinancialAtom> atoms =
      <IcuBedBoardFinancialAtom>[
        IcuBedBoardFinancialAtom(
          id: 'tab_navigate',
          label: 'Bed board tab / count badge (clinical|emergency:read ∩ icu)',
          financialClass: IcuBedBoardFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'manage_beds_primary',
          label: 'Manage beds → /rooms-beds (facility admin nested navigate)',
          financialClass: IcuBedBoardFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'ward_filters',
          label: 'Ward ChoiceChip filters',
          financialClass: IcuBedBoardFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'occupancy_summary_chips',
          label: 'Available / occupied summary badges (ops KPI, not ledger)',
          financialClass: IcuBedBoardFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'empty_loading_error_retry',
          label: 'Empty / loading / error / retry states',
          financialClass: IcuBedBoardFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'bed_row_read',
          label: 'Bed row (location / occupant / status)',
          financialClass: IcuBedBoardFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'open_ipd_occupied',
          label: 'Open IPD (occupied row navigate; no collect)',
          financialClass: IcuBedBoardFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'realtime_bed_board_sync',
          label: 'Post-load / refresh bed board sync',
          financialClass: IcuBedBoardFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IcuBedBoardFinancialAtom(
          id: 'icu_bed_day_charge',
          label: 'ICU bed/day charge (posts on admission / stay elsewhere)',
          financialClass: IcuBedBoardFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          billingPath:
              'persistAdmissionBilling / clinical-request-billing (not on bed-board)',
          mounted: false,
        ),
        IcuBedBoardFinancialAtom(
          id: 'critical_care_package',
          label: 'Critical-care package charge (Active ICU / orders elsewhere)',
          financialClass: IcuBedBoardFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'clinical-request-billing applyClinicalRequestBilling',
          mounted: false,
        ),
        IcuBedBoardFinancialAtom(
          id: 'transfer_rate_change',
          label: 'Transfer that changes bed/day rate (Transfers tab)',
          financialClass: IcuBedBoardFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'persistAdmissionBilling / IPD transfer billing',
          mounted: false,
        ),
        IcuBedBoardFinancialAtom(
          id: 'discharge_ready_financial_gate',
          label: 'Discharge-ready financial clearance gate (Discharge tab / IPD)',
          financialClass: IcuBedBoardFinancialClass.defer,
          auditCode: 'REQUIRES_BILLING',
          billingPath:
              'IPD discharge clearance + Billing outstanding / deferred status',
          mounted: false,
        ),
        IcuBedBoardFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: IcuBedBoardFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'Billing receive-payment',
          mounted: false,
        ),
        IcuBedBoardFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: IcuBedBoardFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'Billing adjustment / credit note',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<IcuBedBoardFinancialAtom> get billableClasses => atoms.where(
    (IcuBedBoardFinancialAtom atom) =>
        atom.financialClass == IcuBedBoardFinancialClass.createCharge ||
        atom.financialClass == IcuBedBoardFinancialClass.settle ||
        atom.financialClass == IcuBedBoardFinancialClass.adjust ||
        atom.financialClass == IcuBedBoardFinancialClass.reverse ||
        atom.financialClass == IcuBedBoardFinancialClass.defer,
  );

  static Iterable<IcuBedBoardFinancialAtom> get mountedAtoms =>
      atoms.where((IcuBedBoardFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IcuBedBoardFinancialAtom atom) =>
        atom.financialClass == IcuBedBoardFinancialClass.notRequired ||
        atom.financialClass == IcuBedBoardFinancialClass.notBilled ||
        atom.financialClass == IcuBedBoardFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get bedBoardTabHasNoBillableActions =>
      billableClasses.every((IcuBedBoardFinancialAtom atom) => !atom.mounted);
}

/// Documents Bed board financial scope for tests and audits.
const String icuBedBoardBillingScopeNote =
    'ICU Bed board is a read occupancy view over ICU wards. Ward filters, '
    'available/occupied KPIs, bed rows, Open IPD, and Manage beds stay '
    'NOT_REQUIRED / NOT_BILLED. ICU bed/day, critical-care packages, transfer '
    'rate changes, and discharge financial gates are not mounted here; they '
    'must post through persistAdmissionBilling / clinical-request-billing and '
    'IPD clearance elsewhere. Collection and invoice issuance remain on the '
    'Billing module of record—no module cashier on this tab.';
