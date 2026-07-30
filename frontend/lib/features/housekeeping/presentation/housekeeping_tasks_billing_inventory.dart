import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HousekeepingTasksFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Housekeeping Tasks (`/housekeeping?section=tasks`).
@immutable
final class HousekeepingTasksFinancialAtom {
  const HousekeepingTasksFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
    this.billingPath,
  });

  final String id;
  final String label;
  final HousekeepingTasksFinancialClass financialClass;
  final String auditCode;
  final bool mounted;

  /// Shared Billing entry when [financialClass] posts a ledger row.
  final String? billingPath;
}

/// Canonical inventory for `/housekeeping?section=tasks`.
///
/// Scope: tab chrome, task worklist, Create task primary, Assign / Start /
/// Complete next-actions, detail dialog (Assign / Start / Complete / Cancel),
/// nested create / assign / cancel dialogs, report summary. Staff-only cleaning
/// tasks stay NOT_BILLED. Patient-billable room turnover or private-room
/// cleaning surcharges post via Billing (`housekeeping-billing` →
/// clinical-request-billing) when facility fee + patient context exist on
/// Complete — never a parallel cash ledger. Settlement stays on Billing.
abstract final class HousekeepingTasksBillingInventory {
  static const List<HousekeepingTasksFinancialAtom> atoms =
      <HousekeepingTasksFinancialAtom>[
        HousekeepingTasksFinancialAtom(
          id: 'tab_navigate',
          label: 'Tasks tab (operations:read ∩ facilities-maintenance)',
          financialClass: HousekeepingTasksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: HousekeepingTasksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'status_assignee_columns',
          label: 'Status / assignee list columns (ops KPI, not ledger)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: HousekeepingTasksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → task detail',
          financialClass: HousekeepingTasksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'create_task_primary',
          label: 'Create task (tab primary create)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'next_action_assign',
          label: 'Next action Assign',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'next_action_start',
          label: 'Next action Start',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'next_action_complete',
          label:
              'Next action Complete (staff-only NOT_BILLED; surcharge posts Billing when configured)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          billingPath: 'housekeeping-billing.maybeBillCompletedHousekeepingTask',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'next_action_review',
          label: 'Next action View details',
          financialClass: HousekeepingTasksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'detail_assign',
          label: 'Detail Assign (complementary; omitted when next-action)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'detail_start',
          label: 'Detail Start (complementary; omitted when next-action)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'detail_complete',
          label: 'Detail Complete (complementary; omitted when next-action)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          billingPath: 'housekeeping-billing.maybeBillCompletedHousekeepingTask',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'detail_cancel',
          label: 'Detail Cancel task',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'nested_mutation_dialogs',
          label: 'Nested mutation dialogs (Create / Assign / Cancel)',
          financialClass: HousekeepingTasksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'report_summary',
          label: 'Report summary preview (ops counts export)',
          financialClass: HousekeepingTasksFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Tasks worklist sync',
          financialClass: HousekeepingTasksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingTasksFinancialAtom(
          id: 'patient_billable_room_turnover_surcharge',
          label: 'Patient-billable room turnover cleaning surcharge',
          financialClass: HousekeepingTasksFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'housekeeping-billing.persistHousekeepingTaskBilling',
          mounted: false,
        ),
        HousekeepingTasksFinancialAtom(
          id: 'private_room_cleaning_surcharge',
          label: 'Private-room cleaning surcharge (facility-configured)',
          financialClass: HousekeepingTasksFinancialClass.createCharge,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'housekeeping-billing.persistHousekeepingTaskBilling',
          mounted: false,
        ),
        HousekeepingTasksFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: HousekeepingTasksFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'Billing receive-payment',
          mounted: false,
        ),
        HousekeepingTasksFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: HousekeepingTasksFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          billingPath: 'Billing adjustment / credit note',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HousekeepingTasksFinancialAtom> get billableClasses =>
      atoms.where(
        (HousekeepingTasksFinancialAtom atom) =>
            atom.financialClass ==
                HousekeepingTasksFinancialClass.createCharge ||
            atom.financialClass == HousekeepingTasksFinancialClass.settle ||
            atom.financialClass == HousekeepingTasksFinancialClass.adjust ||
            atom.financialClass == HousekeepingTasksFinancialClass.reverse ||
            atom.financialClass == HousekeepingTasksFinancialClass.defer,
      );

  static Iterable<HousekeepingTasksFinancialAtom> get mountedAtoms =>
      atoms.where((HousekeepingTasksFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HousekeepingTasksFinancialAtom atom) =>
        atom.financialClass == HousekeepingTasksFinancialClass.notRequired ||
        atom.financialClass == HousekeepingTasksFinancialClass.notBilled ||
        atom.financialClass == HousekeepingTasksFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get tasksTabHasNoBillableActions => billableClasses.every(
    (HousekeepingTasksFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Tasks financial scope for tests and audits.
const String housekeepingTasksBillingScopeNote =
    'Housekeeping Tasks creates and completes facility cleaning work. Create, '
    'Assign, Start, Cancel, and staff-only Complete stay NOT_BILLED. Report '
    'summary is NO_CHARGE ops telemetry. Patient-billable room turnover or '
    'private-room cleaning surcharges post through housekeeping-billing → '
    'clinical-request-billing when facility fee and patient context exist on '
    'Complete; collection and invoice issuance remain on the Billing module '
    'of record.';
