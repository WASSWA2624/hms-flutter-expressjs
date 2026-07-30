import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HousekeepingMaintenanceRequestsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Housekeeping Maintenance requests
/// (`/housekeeping?section=maintenance`).
@immutable
final class HousekeepingMaintenanceRequestsFinancialAtom {
  const HousekeepingMaintenanceRequestsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HousekeepingMaintenanceRequestsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/housekeeping?section=maintenance`.
///
/// Scope: tab chrome, open-request worklist, Request maintenance primary,
/// Triage / View next-actions, detail dialog (Complete / Cancel / Triage),
/// nested create / triage / cancel dialogs, report summary. Facility
/// maintenance tickets are staff-only ops and stay NOT_BILLED. Patient-billable
/// room turnover or private-room cleaning surcharges are not mounted on this
/// tab; when configured they must post via Billing (`clinical-request-billing`
/// / receive-payment / adjustment)—never a parallel cash ledger.
abstract final class HousekeepingMaintenanceRequestsBillingInventory {
  static const List<HousekeepingMaintenanceRequestsFinancialAtom> atoms =
      <HousekeepingMaintenanceRequestsFinancialAtom>[
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'tab_navigate',
          label:
              'Maintenance requests tab (operations:read ∩ facilities-maintenance)',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'open_request_status_columns',
          label: 'Status / asset list columns (ops KPI, not ledger)',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → request detail',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'request_maintenance_primary',
          label: 'Request maintenance (tab primary create)',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'next_action_triage',
          label: 'Next action Triage handoff',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'next_action_review',
          label: 'Next action View details',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'detail_complete_request',
          label: 'Detail Complete request',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'detail_cancel_request',
          label: 'Detail Cancel request',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'detail_triage_complementary',
          label: 'Detail Triage (complementary; omitted when next-action)',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'nested_mutation_dialogs',
          label:
              'Nested mutation dialogs (Request / Triage / Cancel request)',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'report_summary',
          label: 'Report summary preview (ops counts export)',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Maintenance worklist sync',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'patient_billable_room_turnover_surcharge',
          label:
              'Patient-billable room turnover / private-room cleaning surcharge',
          financialClass:
              HousekeepingMaintenanceRequestsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: HousekeepingMaintenanceRequestsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HousekeepingMaintenanceRequestsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: HousekeepingMaintenanceRequestsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HousekeepingMaintenanceRequestsFinancialAtom>
  get billableClasses => atoms.where(
    (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.createCharge ||
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.settle ||
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.adjust ||
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.reverse ||
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.defer,
  );

  static Iterable<HousekeepingMaintenanceRequestsFinancialAtom>
  get mountedAtoms => atoms.where(
    (HousekeepingMaintenanceRequestsFinancialAtom atom) => atom.mounted,
  );

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.notRequired ||
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.notBilled ||
        atom.financialClass ==
            HousekeepingMaintenanceRequestsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get maintenanceRequestsTabHasNoBillableActions =>
      billableClasses.every(
        (HousekeepingMaintenanceRequestsFinancialAtom atom) => !atom.mounted,
      );
}

/// Documents Maintenance requests financial scope for tests and audits.
const String housekeepingMaintenanceRequestsBillingScopeNote =
    'Housekeeping Maintenance requests creates and triages facility '
    'maintenance tickets. Request maintenance, Triage, Complete, and Cancel '
    'stay NOT_BILLED internal ops. Report summary is NO_CHARGE ops telemetry. '
    'Patient-billable room turnover or private-room cleaning surcharges are '
    'not mounted on this tab; collection and invoice issuance remain on the '
    'Billing module of record.';
