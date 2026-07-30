import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalAnalyticsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Analytics (`/biomedical?panel=analytics`).
@immutable
final class BiomedicalAnalyticsFinancialAtom {
  const BiomedicalAnalyticsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalAnalyticsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=analytics`.
///
/// Scope: tab chrome, utilization worklist, detail dialog, nested mutation /
/// print dialogs opened from this tab. Utilization metrics are analytics
/// snapshots (NOT_BILLED), not ledger balances. Internal maintenance / WO
/// writes from detail stay NOT_BILLED. Patient-billable device usage or
/// implantable/consumable charges are not mounted here; if introduced they
/// must post via Billing (`clinical-request-billing` / receive-payment /
/// adjustment)—never a parallel cash ledger.
abstract final class BiomedicalAnalyticsBillingInventory {
  static const List<BiomedicalAnalyticsFinancialAtom> atoms =
      <BiomedicalAnalyticsFinancialAtom>[
        BiomedicalAnalyticsFinancialAtom(
          id: 'tab_navigate',
          label: 'Analytics tab (biomed:read ∩ + reports:read ∪)',
          financialClass: BiomedicalAnalyticsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalAnalyticsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalAnalyticsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'utilization_metric_display',
          label: 'Utilization snapshot / chart metric columns',
          financialClass: BiomedicalAnalyticsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalAnalyticsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review record',
          financialClass: BiomedicalAnalyticsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (PM / WO / calibration / transfer / …)',
          financialClass: BiomedicalAnalyticsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'nested_mutation_dialogs',
          label: 'Nested mutation dialogs (Schedule maintenance, Create WO, …)',
          financialClass: BiomedicalAnalyticsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalAnalyticsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Analytics workbench sync',
          financialClass: BiomedicalAnalyticsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'tab_strip_primary',
          label: 'Tab-strip primary create',
          financialClass: BiomedicalAnalyticsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalAnalyticsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalAnalyticsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalAnalyticsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalAnalyticsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalAnalyticsFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalAnalyticsFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalAnalyticsFinancialClass.createCharge ||
            atom.financialClass == BiomedicalAnalyticsFinancialClass.settle ||
            atom.financialClass == BiomedicalAnalyticsFinancialClass.adjust ||
            atom.financialClass == BiomedicalAnalyticsFinancialClass.reverse ||
            atom.financialClass == BiomedicalAnalyticsFinancialClass.defer,
      );

  static Iterable<BiomedicalAnalyticsFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalAnalyticsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalAnalyticsFinancialAtom atom) =>
        atom.financialClass == BiomedicalAnalyticsFinancialClass.notRequired ||
        atom.financialClass == BiomedicalAnalyticsFinancialClass.notBilled ||
        atom.financialClass == BiomedicalAnalyticsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get analyticsTabHasNoBillableActions =>
      billableClasses.every(
        (BiomedicalAnalyticsFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Analytics financial scope for tests and audits.
const String biomedicalAnalyticsBillingScopeNote =
    'Biomedical Analytics lists equipment utilization snapshots and charts. '
    'Utilization metrics are NOT_BILLED analytics, not ledger balances. '
    'Internal maintenance / work-order mutations opened from detail stay '
    'NOT_BILLED. Patient-billable device usage or implantable/consumable '
    'charges are not mounted on this tab; collection and invoice issuance '
    'remain on the Billing module of record.';
