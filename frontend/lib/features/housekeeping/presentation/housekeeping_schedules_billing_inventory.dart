import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HousekeepingSchedulesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Housekeeping Schedules
/// (`/housekeeping?section=schedules`).
@immutable
final class HousekeepingSchedulesFinancialAtom {
  const HousekeepingSchedulesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HousekeepingSchedulesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/housekeeping?section=schedules`.
///
/// Scope: tab chrome, schedules worklist, Create schedule primary, Review
/// schedule next-action, detail dialog (identity tiles only — no complementary
/// writes), nested create dialog, report summary. Recurring cleaning plans are
/// staff-only ops and stay NOT_BILLED. Patient-billable room turnover or
/// private-room cleaning surcharges are not mounted on this tab; when
/// configured they must post via Billing (`clinical-request-billing` /
/// receive-payment / adjustment)—never a parallel cash ledger.
abstract final class HousekeepingSchedulesBillingInventory {
  static const List<HousekeepingSchedulesFinancialAtom> atoms =
      <HousekeepingSchedulesFinancialAtom>[
        HousekeepingSchedulesFinancialAtom(
          id: 'tab_navigate',
          label:
              'Schedules tab (operations:read ∩ facilities-maintenance)',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'schedule_status_columns',
          label: 'Frequency / location list columns (ops KPI, not ledger)',
          financialClass: HousekeepingSchedulesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → schedule detail',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'create_schedule_primary',
          label: 'Create schedule (tab primary create)',
          financialClass: HousekeepingSchedulesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review schedule',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'detail_identity_tiles',
          label: 'Detail identity tiles (ref / location / status)',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'nested_create_dialog',
          label: 'Nested Create cleaning schedule dialog',
          financialClass: HousekeepingSchedulesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'report_summary',
          label: 'Report summary preview (ops counts export)',
          financialClass: HousekeepingSchedulesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Schedules worklist sync',
          financialClass: HousekeepingSchedulesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'patient_billable_room_turnover_surcharge',
          label:
              'Patient-billable room turnover / private-room cleaning surcharge',
          financialClass: HousekeepingSchedulesFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: HousekeepingSchedulesFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        HousekeepingSchedulesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: HousekeepingSchedulesFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HousekeepingSchedulesFinancialAtom> get billableClasses =>
      atoms.where(
        (HousekeepingSchedulesFinancialAtom atom) =>
            atom.financialClass ==
                HousekeepingSchedulesFinancialClass.createCharge ||
            atom.financialClass == HousekeepingSchedulesFinancialClass.settle ||
            atom.financialClass == HousekeepingSchedulesFinancialClass.adjust ||
            atom.financialClass == HousekeepingSchedulesFinancialClass.reverse ||
            atom.financialClass == HousekeepingSchedulesFinancialClass.defer,
      );

  static Iterable<HousekeepingSchedulesFinancialAtom> get mountedAtoms =>
      atoms.where((HousekeepingSchedulesFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HousekeepingSchedulesFinancialAtom atom) =>
        atom.financialClass == HousekeepingSchedulesFinancialClass.notRequired ||
        atom.financialClass == HousekeepingSchedulesFinancialClass.notBilled ||
        atom.financialClass == HousekeepingSchedulesFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get schedulesTabHasNoBillableActions => billableClasses.every(
    (HousekeepingSchedulesFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Schedules financial scope for tests and audits.
const String housekeepingSchedulesBillingScopeNote =
    'Housekeeping Schedules creates recurring staff cleaning plans. Create '
    'schedule stays NOT_BILLED internal ops. Report summary is NO_CHARGE ops '
    'telemetry. Patient-billable room turnover or private-room cleaning '
    'surcharges are not mounted on this tab; collection and invoice issuance '
    'remain on the Billing module of record.';
