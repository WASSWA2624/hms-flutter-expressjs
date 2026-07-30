import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum BiomedicalComplianceFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Biomedical Compliance (`/biomedical?panel=compliance`).
@immutable
final class BiomedicalComplianceFinancialAtom {
  const BiomedicalComplianceFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final BiomedicalComplianceFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/biomedical?panel=compliance`.
///
/// Scope: tab chrome, compliance worklist (calibration / downtime / recalls),
/// detail dialog, nested mutation / print dialogs opened from this tab.
/// Recalls and downtime are internal ops (NOT_BILLED). Calibration and safety
/// logs are compliance evidence (NOT_BILLED). Internal maintenance / WO writes
/// from detail stay NOT_BILLED. Patient-billable device usage or
/// implantable/consumable charges are not mounted here; if introduced they
/// must post via Billing (`clinical-request-billing` / receive-payment /
/// adjustment)—never a parallel cash ledger.
abstract final class BiomedicalComplianceBillingInventory {
  static const List<BiomedicalComplianceFinancialAtom> atoms =
      <BiomedicalComplianceFinancialAtom>[
        BiomedicalComplianceFinancialAtom(
          id: 'tab_navigate',
          label: 'Compliance tab (biomed:read ∩)',
          financialClass: BiomedicalComplianceFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: BiomedicalComplianceFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: BiomedicalComplianceFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'record_calibration_primary',
          label: 'Record calibration (tab primary)',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → asset detail (Registry / Readiness)',
          financialClass: BiomedicalComplianceFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'next_action_review_record',
          label: 'Next action Review record (read-only)',
          financialClass: BiomedicalComplianceFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'next_action_review_compliance',
          label: 'Next action Review compliance (calibration / safety)',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'next_action_close_downtime',
          label: 'Next action Return to service / Close downtime',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'next_action_acknowledge_recall',
          label: 'Next action Review recall / Acknowledge recall',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'detail_calibration_safety_downtime',
          label: 'Detail Record calibration / safety / Report downtime',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'detail_close_downtime_acknowledge_recall',
          label: 'Detail Close downtime / Acknowledge recall',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'detail_internal_maintenance_writes',
          label:
              'Detail complementary writes (PM / WO / transfer / disposal / …)',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'nested_mutation_dialogs',
          label:
              'Nested mutation dialogs (calibration / downtime / recall / WO)',
          financialClass: BiomedicalComplianceFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'print_report',
          label: 'Print asset report (evidence export)',
          financialClass: BiomedicalComplianceFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Compliance workbench sync',
          financialClass: BiomedicalComplianceFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'patient_billable_device_usage',
          label:
              'Patient-billable device usage / implantable / consumable charge',
          financialClass: BiomedicalComplianceFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: BiomedicalComplianceFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        BiomedicalComplianceFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: BiomedicalComplianceFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<BiomedicalComplianceFinancialAtom> get billableClasses =>
      atoms.where(
        (BiomedicalComplianceFinancialAtom atom) =>
            atom.financialClass ==
                BiomedicalComplianceFinancialClass.createCharge ||
            atom.financialClass == BiomedicalComplianceFinancialClass.settle ||
            atom.financialClass == BiomedicalComplianceFinancialClass.adjust ||
            atom.financialClass == BiomedicalComplianceFinancialClass.reverse ||
            atom.financialClass == BiomedicalComplianceFinancialClass.defer,
      );

  static Iterable<BiomedicalComplianceFinancialAtom> get mountedAtoms =>
      atoms.where((BiomedicalComplianceFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (BiomedicalComplianceFinancialAtom atom) =>
        atom.financialClass ==
            BiomedicalComplianceFinancialClass.notRequired ||
        atom.financialClass == BiomedicalComplianceFinancialClass.notBilled ||
        atom.financialClass == BiomedicalComplianceFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get complianceTabHasNoBillableActions =>
      billableClasses.every(
        (BiomedicalComplianceFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Compliance financial scope for tests and audits.
const String biomedicalComplianceBillingScopeNote =
    'Biomedical Compliance lists calibration due, critical downtime, and '
    'active recalls. These are internal compliance / ops events (NOT_BILLED), '
    'not patient ledger balances. Calibration, safety, downtime, and recall '
    'mutations stay NOT_BILLED. Internal maintenance / work-order mutations '
    'opened from detail stay NOT_BILLED. Patient-billable device usage or '
    'implantable/consumable charges are not mounted on this tab; collection '
    'and invoice issuance remain on the Billing module of record.';
