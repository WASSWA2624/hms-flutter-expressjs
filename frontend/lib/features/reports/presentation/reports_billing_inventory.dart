import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum ReportsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Reports workspace (all panels).
@immutable
final class ReportsFinancialAtom {
  const ReportsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final ReportsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/reports` (catalog, delivery, compliance, schedules, timeline).
///
/// Scope: workspace chrome, worklists, detail dialogs, and nested run/schedule/
/// export dialogs opened from this tab. Patient/clinical revenue stays on Billing;
/// analytics KPI values here are read-only metrics, not ledger balances.
abstract final class ReportsBillingInventory {
  static const List<ReportsFinancialAtom> atoms = <ReportsFinancialAtom>[
    ReportsFinancialAtom(
      id: 'panel_navigate_filter',
      label: 'Panel filter / navigate (overview, catalog, delivery, compliance)',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    ReportsFinancialAtom(
      id: 'search_filters_columns_pagination',
      label: 'Search / advanced filters / columns / pagination',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    ReportsFinancialAtom(
      id: 'empty_error_retry_loading',
      label: 'Empty / loading / error / retry states',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    ReportsFinancialAtom(
      id: 'timeline_activity',
      label: 'Recent report activity timeline',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    ReportsFinancialAtom(
      id: 'schedules_panel',
      label: 'Schedules worklist (read)',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    ReportsFinancialAtom(
      id: 'row_select_detail',
      label: 'Row select → report/compliance preview detail',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
    ReportsFinancialAtom(
      id: 'kpi_value_display',
      label: 'KPI / metric value column (analytics snapshot)',
      financialClass: ReportsFinancialClass.notBilled,
      auditCode: 'NOT_BILLED',
    ),
    ReportsFinancialAtom(
      id: 'run_report',
      label: 'Run report definition',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'retry_run',
      label: 'Retry failed report run',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'cancel_run',
      label: 'Cancel queued report run',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'create_schedule',
      label: 'Create / update report schedule',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'pause_resume_schedule',
      label: 'Pause / resume schedule',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
      mounted: false,
    ),
    ReportsFinancialAtom(
      id: 'download_run',
      label: 'Download completed report run (evidence export)',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'print_report',
      label: 'Print report preview',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'export_compliance_evidence',
      label: 'Export / print compliance evidence',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
    ),
    ReportsFinancialAtom(
      id: 'collect_payment',
      label: 'Collect payment / receive payment',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
      mounted: false,
    ),
    ReportsFinancialAtom(
      id: 'issue_invoice_adjust_refund',
      label: 'Issue invoice / adjust / refund / reverse / write-off',
      financialClass: ReportsFinancialClass.noCharge,
      auditCode: 'NO_CHARGE',
      mounted: false,
    ),
    ReportsFinancialAtom(
      id: 'realtime_reports_sync',
      label: 'Realtime reports workspace list sync',
      financialClass: ReportsFinancialClass.notRequired,
      auditCode: 'NOT_REQUIRED',
    ),
  ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<ReportsFinancialAtom> get billableClasses => atoms.where(
    (ReportsFinancialAtom atom) =>
        atom.financialClass == ReportsFinancialClass.createCharge ||
        atom.financialClass == ReportsFinancialClass.settle ||
        atom.financialClass == ReportsFinancialClass.adjust ||
        atom.financialClass == ReportsFinancialClass.reverse ||
        atom.financialClass == ReportsFinancialClass.defer,
  );

  static Iterable<ReportsFinancialAtom> get mountedAtoms =>
      atoms.where((ReportsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (ReportsFinancialAtom atom) =>
        atom.financialClass == ReportsFinancialClass.notRequired ||
        atom.financialClass == ReportsFinancialClass.notBilled ||
        atom.financialClass == ReportsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable (create/settle/adjust/reverse/defer).
  static bool get reportsTabHasNoBillableActions =>
      billableClasses.every((ReportsFinancialAtom atom) => !atom.mounted);
}

const String reportsBillingScopeNote =
    'Reports workspace covers catalog, delivery, compliance, and analytics '
    'surfaces. Operational report runs and evidence exports do not create '
    'patient invoice lines; KPI values are analytics metrics, not ledger '
    'balances. Payment collection and invoice issuance remain on Billing.';
