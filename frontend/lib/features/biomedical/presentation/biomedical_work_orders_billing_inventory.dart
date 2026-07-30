import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalWorkOrdersFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Work orders
/// (`/biomedical?panel=work-orders`).
@immutable
final class BiomedicalWorkOrdersFinancialAtom {
  const BiomedicalWorkOrdersFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalWorkOrdersFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=work-orders`.
///
/// Scope: tab chrome, open work-order worklist, Create work order primary,
/// Start / Return next-actions, detail dialog (Update WO + complementary
/// writes), nested mutation / print dialogs opened from this tab. Internal
/// maintenance work orders stay NOT_BILLED. Patient-billable device usage or
/// implantable/consumable charges are not mounted here; if introduced they
/// must post via Billing (`clinical-request-billing` / receive-payment /
/// adjustment)—never a parallel cash ledger.
abstract final class BiomedicalWorkOrdersBillingInventory {
  static const List<BiomedicalWorkOrdersFinancialAtom> atoms =
      <BiomedicalWorkOrdersFinancialAtom>[
        BiomedicalWorkOrdersFinancialAtom(
          id: 'tab_navigate',
          label: 'Work orders tab (biomed:read ∩ biomedical-engineering-suite)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalWorkOrdersFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'risk_status_columns',
          label: 'Risk / status list columns (ops KPI, not ledger)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalWorkOrdersFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'create_work_order_primary',
          label: 'Create work order (tab primary create)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review record',
          financialClass: BiomedicalWorkOrdersFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'next_action_start_work_order',
          label: 'Next action Work order follow-up (start)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'next_action_return_to_service',
          label: 'Next action Return to service',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'detail_update_work_order',
          label: 'Detail Update work order',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'detail_start_return_status_gated',
          label: 'Detail Start / Return WO (status-gated, not next-action)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (transfer / PM / calibration / …)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'nested_mutation_dialogs',
          label:
              'Nested mutation dialogs (Create / Update / Start / Return WO, …)',
          financialClass: BiomedicalWorkOrdersFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalWorkOrdersFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Work orders workbench sync',
          financialClass: BiomedicalWorkOrdersFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalWorkOrdersFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalWorkOrdersFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalWorkOrdersFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalWorkOrdersFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalWorkOrdersFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalWorkOrdersFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalWorkOrdersFinancialClass.createCharge ||
            atom.financialClass ==
                BiomedicalWorkOrdersFinancialClass.settle ||
            atom.financialClass ==
                BiomedicalWorkOrdersFinancialClass.adjust ||
            atom.financialClass ==
                BiomedicalWorkOrdersFinancialClass.reverse ||
            atom.financialClass == BiomedicalWorkOrdersFinancialClass.defer,
      );

  static Iterable<BiomedicalWorkOrdersFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalWorkOrdersFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalWorkOrdersFinancialAtom atom) =>
        atom.financialClass ==
            BiomedicalWorkOrdersFinancialClass.notRequired ||
        atom.financialClass == BiomedicalWorkOrdersFinancialClass.notBilled ||
        atom.financialClass == BiomedicalWorkOrdersFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get workOrdersTabHasNoBillableActions =>
      billableClasses.every(
        (BiomedicalWorkOrdersFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Work orders financial scope for tests and audits.
const String biomedicalWorkOrdersBillingScopeNote =
    'Biomedical Work orders creates and tracks internal equipment maintenance '
    'tickets. Create work order, Start, Update, and Return to service stay '
    'NOT_BILLED internal ops. Complementary maintenance writes from detail '
    'stay NOT_BILLED. Patient-billable device usage or implantable/consumable '
    'charges are not mounted on this tab; collection and invoice issuance '
    'remain on the Billing module of record.';
