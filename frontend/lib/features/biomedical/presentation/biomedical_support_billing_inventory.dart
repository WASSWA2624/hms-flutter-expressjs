import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalSupportFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Support (`/biomedical?panel=support`).
@immutable
final class BiomedicalSupportFinancialAtom {
  const BiomedicalSupportFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalSupportFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=support`.
///
/// Scope: tab chrome, vendor/service-provider worklist, Report fault primary,
/// detail dialog (Log incident + complementary writes), nested fault /
/// incident / mutation / print dialogs opened from this tab. Vendor tickets,
/// fault reports, and incident logs are internal support ops (NOT_BILLED).
/// Internal maintenance / WO writes from detail stay NOT_BILLED.
/// Patient-billable device usage or implantable/consumable charges are not
/// mounted here; if introduced they must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger.
abstract final class BiomedicalSupportBillingInventory {
  static const List<BiomedicalSupportFinancialAtom> atoms =
      <BiomedicalSupportFinancialAtom>[
        BiomedicalSupportFinancialAtom(
          id: 'tab_navigate',
          label: 'Support tab (biomed:read ∩ biomedical-engineering-suite)',
          financialClass: BiomedicalSupportFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalSupportFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalSupportFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'vendor_ticket_list_columns',
          label: 'Vendor / service-provider list columns (ops, not ledger)',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'report_fault_primary',
          label: 'Report fault (tab primary → WO + optional incident)',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalSupportFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review record',
          financialClass: BiomedicalSupportFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'detail_log_incident',
          label: 'Detail Log incident',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (PM / WO / transfer / calibration / …)',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'nested_fault_report_dialog',
          label: 'Nested Report fault dialog',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'nested_incident_dialog',
          label: 'Nested Log incident dialog',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'nested_mutation_dialogs',
          label: 'Nested mutation dialogs (Schedule maintenance, Create WO, …)',
          financialClass: BiomedicalSupportFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalSupportFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Support workbench sync',
          financialClass: BiomedicalSupportFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalSupportFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalSupportFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalSupportFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalSupportFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalSupportFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalSupportFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalSupportFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalSupportFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalSupportFinancialClass.createCharge ||
            atom.financialClass == BiomedicalSupportFinancialClass.settle ||
            atom.financialClass == BiomedicalSupportFinancialClass.adjust ||
            atom.financialClass == BiomedicalSupportFinancialClass.reverse ||
            atom.financialClass == BiomedicalSupportFinancialClass.defer,
      );

  static Iterable<BiomedicalSupportFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalSupportFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalSupportFinancialAtom atom) =>
        atom.financialClass == BiomedicalSupportFinancialClass.notRequired ||
        atom.financialClass == BiomedicalSupportFinancialClass.notBilled ||
        atom.financialClass == BiomedicalSupportFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get supportTabHasNoBillableActions => billableClasses.every(
    (BiomedicalSupportFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Support financial scope for tests and audits.
const String biomedicalSupportBillingScopeNote =
    'Biomedical Support lists vendor / service-provider tickets and opens '
    'fault-report and incident workflows. Those are internal support ops '
    '(NOT_BILLED), not patient ledger balances. Report fault creates an '
    'internal work order (and optional incident) that stays NOT_BILLED. '
    'Internal maintenance / work-order mutations opened from detail stay '
    'NOT_BILLED. Patient-billable device usage or implantable/consumable '
    'charges are not mounted on this tab; collection and invoice issuance '
    'remain on the Billing module of record.';
