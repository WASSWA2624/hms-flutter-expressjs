import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalOverviewFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Overview (`/biomedical?panel=overview`).
@immutable
final class BiomedicalOverviewFinancialAtom {
  const BiomedicalOverviewFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalOverviewFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=overview`.
///
/// Scope: tab chrome, KPI-style worklist (open work orders / risk), detail
/// dialog, nested mutation / print dialogs opened from this tab. Overview is
/// read-heavy: list columns and summary badges are operational KPIs
/// (NOT_BILLED), not patient ledger balances. Internal maintenance / work-order
/// follow-ups stay NOT_BILLED. Patient-billable device usage or
/// implantable/consumable charges are not mounted here; if introduced they
/// must post via Billing (`clinical-request-billing` / receive-payment /
/// adjustment)—never a parallel cash ledger.
abstract final class BiomedicalOverviewBillingInventory {
  static const List<BiomedicalOverviewFinancialAtom> atoms =
      <BiomedicalOverviewFinancialAtom>[
        BiomedicalOverviewFinancialAtom(
          id: 'tab_navigate',
          label: 'Overview tab (biomed:read ∩ biomedical-engineering-suite)',
          financialClass: BiomedicalOverviewFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalOverviewFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'kpi_risk_status_columns',
          label: 'Risk / status list columns (KPI-style, not ledger)',
          financialClass: BiomedicalOverviewFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalOverviewFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalOverviewFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review record',
          financialClass: BiomedicalOverviewFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'next_action_work_order_follow_up',
          label: 'Next action Work order follow-up (start / return)',
          financialClass: BiomedicalOverviewFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (PM / WO / calibration / transfer / …)',
          financialClass: BiomedicalOverviewFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'nested_mutation_dialogs',
          label: 'Nested mutation dialogs (Schedule maintenance, Start WO, …)',
          financialClass: BiomedicalOverviewFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalOverviewFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Overview workbench sync',
          financialClass: BiomedicalOverviewFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'tab_strip_primary',
          label: 'Tab-strip primary create',
          financialClass: BiomedicalOverviewFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalOverviewFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalOverviewFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalOverviewFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalOverviewFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalOverviewFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalOverviewFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalOverviewFinancialClass.createCharge ||
            atom.financialClass == BiomedicalOverviewFinancialClass.settle ||
            atom.financialClass == BiomedicalOverviewFinancialClass.adjust ||
            atom.financialClass == BiomedicalOverviewFinancialClass.reverse ||
            atom.financialClass == BiomedicalOverviewFinancialClass.defer,
      );

  static Iterable<BiomedicalOverviewFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalOverviewFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalOverviewFinancialAtom atom) =>
        atom.financialClass == BiomedicalOverviewFinancialClass.notRequired ||
        atom.financialClass == BiomedicalOverviewFinancialClass.notBilled ||
        atom.financialClass == BiomedicalOverviewFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get overviewTabHasNoBillableActions =>
      billableClasses.every(
        (BiomedicalOverviewFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Overview financial scope for tests and audits.
const String biomedicalOverviewBillingScopeNote =
    'Biomedical Overview lists open work orders and KPI-style risk/status '
    'columns. Those KPIs are NOT_BILLED operational signals, not ledger '
    'balances. Internal maintenance / work-order mutations opened from detail '
    'or next-action stay NOT_BILLED. Patient-billable device usage or '
    'implantable/consumable charges are not mounted on this tab; collection '
    'and invoice issuance remain on the Billing module of record.';
