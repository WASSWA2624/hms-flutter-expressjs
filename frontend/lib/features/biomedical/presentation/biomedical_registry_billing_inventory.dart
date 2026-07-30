import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalRegistryFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Registry (`/biomedical?panel=registry`).
@immutable
final class BiomedicalRegistryFinancialAtom {
  const BiomedicalRegistryFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalRegistryFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=registry` (default panel).
///
/// Scope: tab chrome, equipment-registry worklist, Register asset primary,
/// Review-record next-action, detail dialog (Edit asset + complementary
/// writes), nested mutation / print dialogs opened from this tab. Tab role is
/// register-asset primary: equipment create/update stays NOT_BILLED internal
/// ops. Internal maintenance / work orders from detail stay NOT_BILLED.
/// Patient-billable device usage or implantable/consumable charges are not
/// mounted here; if introduced they must post via Billing
/// (`clinical-request-billing` / receive-payment / adjustment)—never a
/// parallel cash ledger.
abstract final class BiomedicalRegistryBillingInventory {
  static const List<BiomedicalRegistryFinancialAtom> atoms =
      <BiomedicalRegistryFinancialAtom>[
        BiomedicalRegistryFinancialAtom(
          id: 'tab_navigate',
          label: 'Registry tab (biomed:read ∩ biomedical-engineering-suite)',
          financialClass: BiomedicalRegistryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalRegistryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalRegistryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalRegistryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'register_asset_primary',
          label: 'Register asset (tab primary create)',
          financialClass: BiomedicalRegistryFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review record',
          financialClass: BiomedicalRegistryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'detail_edit_asset',
          label: 'Detail Edit asset',
          financialClass: BiomedicalRegistryFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (transfer / PM / WO / calibration / …)',
          financialClass: BiomedicalRegistryFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'nested_mutation_dialogs',
          label:
              'Nested mutation dialogs (Register/Edit asset, Create WO, …)',
          financialClass: BiomedicalRegistryFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalRegistryFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Registry workbench sync',
          financialClass: BiomedicalRegistryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalRegistryFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalRegistryFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalRegistryFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalRegistryFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalRegistryFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalRegistryFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalRegistryFinancialClass.createCharge ||
            atom.financialClass == BiomedicalRegistryFinancialClass.settle ||
            atom.financialClass == BiomedicalRegistryFinancialClass.adjust ||
            atom.financialClass == BiomedicalRegistryFinancialClass.reverse ||
            atom.financialClass == BiomedicalRegistryFinancialClass.defer,
      );

  static Iterable<BiomedicalRegistryFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalRegistryFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalRegistryFinancialAtom atom) =>
        atom.financialClass == BiomedicalRegistryFinancialClass.notRequired ||
        atom.financialClass == BiomedicalRegistryFinancialClass.notBilled ||
        atom.financialClass == BiomedicalRegistryFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get registryTabHasNoBillableActions => billableClasses.every(
    (BiomedicalRegistryFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Registry financial scope for tests and audits.
const String biomedicalRegistryBillingScopeNote =
    'Biomedical Registry registers and maintains facility equipment assets. '
    'Register asset and Edit asset stay NOT_BILLED internal ops. '
    'Complementary work orders / maintenance opened from detail stay '
    'NOT_BILLED. Patient-billable device usage or implantable/consumable '
    'charges are not mounted on this tab; collection and invoice issuance '
    'remain on the Billing module of record.';
