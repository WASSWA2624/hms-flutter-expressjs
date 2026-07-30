import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalPreventiveFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Preventive (`/biomedical?panel=preventive`).
@immutable
final class BiomedicalPreventiveFinancialAtom {
  const BiomedicalPreventiveFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalPreventiveFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=preventive`.
///
/// Scope: tab chrome, maintenance-plan worklist, Schedule maintenance primary,
/// Perform maintenance next-action, detail dialog, nested mutation / print
/// dialogs opened from this tab. Internal preventive maintenance and
/// complementary work orders stay NOT_BILLED. Patient-billable device usage
/// or implantable/consumable charges are not mounted here; if introduced they
/// must post via Billing (`clinical-request-billing` / receive-payment /
/// adjustment)—never a parallel cash ledger.
abstract final class BiomedicalPreventiveBillingInventory {
  static const List<BiomedicalPreventiveFinancialAtom> atoms =
      <BiomedicalPreventiveFinancialAtom>[
        BiomedicalPreventiveFinancialAtom(
          id: 'tab_navigate',
          label: 'Preventive tab (biomed:read ∩)',
          financialClass: BiomedicalPreventiveFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalPreventiveFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalPreventiveFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalPreventiveFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'schedule_maintenance_primary',
          label: 'Schedule maintenance (tab primary create)',
          financialClass: BiomedicalPreventiveFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review record',
          financialClass: BiomedicalPreventiveFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'next_action_perform_maintenance',
          label: 'Next action Perform maintenance',
          financialClass: BiomedicalPreventiveFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (WO / transfer / calibration / …)',
          financialClass: BiomedicalPreventiveFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'nested_mutation_dialogs',
          label:
              'Nested mutation dialogs (Schedule maintenance, Create WO, …)',
          financialClass: BiomedicalPreventiveFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalPreventiveFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Preventive workbench sync',
          financialClass: BiomedicalPreventiveFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalPreventiveFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalPreventiveFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalPreventiveFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalPreventiveFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalPreventiveFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalPreventiveFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalPreventiveFinancialClass.createCharge ||
            atom.financialClass == BiomedicalPreventiveFinancialClass.settle ||
            atom.financialClass == BiomedicalPreventiveFinancialClass.adjust ||
            atom.financialClass == BiomedicalPreventiveFinancialClass.reverse ||
            atom.financialClass == BiomedicalPreventiveFinancialClass.defer,
      );

  static Iterable<BiomedicalPreventiveFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalPreventiveFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalPreventiveFinancialAtom atom) =>
        atom.financialClass == BiomedicalPreventiveFinancialClass.notRequired ||
        atom.financialClass == BiomedicalPreventiveFinancialClass.notBilled ||
        atom.financialClass == BiomedicalPreventiveFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get preventiveTabHasNoBillableActions =>
      billableClasses.every(
        (BiomedicalPreventiveFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Preventive financial scope for tests and audits.
const String biomedicalPreventiveBillingScopeNote =
    'Biomedical Preventive schedules and tracks internal equipment maintenance '
    'plans. Schedule maintenance and Perform maintenance stay NOT_BILLED '
    'internal ops. Complementary work orders opened from detail stay '
    'NOT_BILLED. Patient-billable device usage or implantable/consumable '
    'charges are not mounted on this tab; collection and invoice issuance '
    'remain on the Billing module of record.';
