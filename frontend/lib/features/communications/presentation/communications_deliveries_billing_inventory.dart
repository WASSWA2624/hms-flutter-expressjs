import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum CommunicationsDeliveriesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Communications Deliveries (`/communications?panel=deliveries`).
@immutable
final class CommunicationsDeliveriesFinancialAtom {
  const CommunicationsDeliveriesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final CommunicationsDeliveriesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/communications?panel=deliveries`.
///
/// Scope: tab chrome, delivery worklist, next-actions, detail dialog, and
/// nested flows opened from this tab. Deliveries is a **read-only delivery
/// log** — channel/status/attempt metadata is operational, not a patient
/// ledger. Open linked navigates to destination workspaces (Billing gates
/// live there). Paid SMS/notification commercial packages are tenant SaaS
/// charges on the subscriptions invoice path when present — never patient
/// clinical Billing, and never collected from this tab.
abstract final class CommunicationsDeliveriesBillingInventory {
  static const List<CommunicationsDeliveriesFinancialAtom> atoms =
      <CommunicationsDeliveriesFinancialAtom>[
        CommunicationsDeliveriesFinancialAtom(
          id: 'tab_navigate',
          label: 'Deliveries tab (communications:read ∩)',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'delivery_status_display',
          label: 'Delivery status / channel / attempt columns (ops log)',
          financialClass: CommunicationsDeliveriesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → delivery detail',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'next_action_view',
          label: 'Next action View delivery / View error',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'next_action_open_linked',
          label: 'Next action Open linked record (navigate)',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'detail_metadata_panel',
          label: 'Detail metadata / timestamps / provider',
          financialClass: CommunicationsDeliveriesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'detail_error_panel',
          label: 'Detail delivery error progressive disclosure',
          financialClass: CommunicationsDeliveriesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'detail_open_linked',
          label: 'Detail Open linked record (navigate)',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / search refresh Deliveries list sync',
          financialClass: CommunicationsDeliveriesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'tab_strip_new_message',
          label: 'Tab-strip New message / New group',
          financialClass: CommunicationsDeliveriesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'delivery_retry_resend',
          label: 'Retry / resend failed delivery',
          financialClass: CommunicationsDeliveriesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'sms_notification_commercial_package',
          label:
              'Paid SMS / notification commercial package (tenant SaaS invoice)',
          financialClass: CommunicationsDeliveriesFinancialClass.createCharge,
          // Reserved: subscriptions invoice path — must not post patient ledgers.
          auditCode: 'REQUIRES_SUBSCRIPTIONS_BILLING',
          mounted: false,
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'patient_clinical_charge_via_message',
          label:
              'Patient clinical charge implied by care-delivery message send',
          financialClass: CommunicationsDeliveriesFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: CommunicationsDeliveriesFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsDeliveriesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: CommunicationsDeliveriesFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<CommunicationsDeliveriesFinancialAtom> get billableClasses =>
      atoms.where(
        (CommunicationsDeliveriesFinancialAtom atom) =>
            atom.financialClass ==
                CommunicationsDeliveriesFinancialClass.createCharge ||
            atom.financialClass ==
                CommunicationsDeliveriesFinancialClass.settle ||
            atom.financialClass ==
                CommunicationsDeliveriesFinancialClass.adjust ||
            atom.financialClass ==
                CommunicationsDeliveriesFinancialClass.reverse ||
            atom.financialClass ==
                CommunicationsDeliveriesFinancialClass.defer,
      );

  static Iterable<CommunicationsDeliveriesFinancialAtom> get mountedAtoms =>
      atoms.where((CommunicationsDeliveriesFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (CommunicationsDeliveriesFinancialAtom atom) =>
        atom.financialClass ==
            CommunicationsDeliveriesFinancialClass.notRequired ||
        atom.financialClass ==
            CommunicationsDeliveriesFinancialClass.notBilled ||
        atom.financialClass == CommunicationsDeliveriesFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get deliveriesTabHasNoBillableActions => billableClasses.every(
    (CommunicationsDeliveriesFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Deliveries financial scope for tests and audits.
const String communicationsDeliveriesBillingScopeNote =
    'Communications Deliveries lists notification delivery attempts '
    '(channel, status, recipient, errors). Delivery status is NOT_BILLED '
    'operational telemetry, not a patient ledger balance. Open linked only '
    'navigates; Billing clearance stays on destination clinical / Billing '
    'workspaces. Paid SMS/notification commercial packages are tenant SaaS '
    'charges on the subscriptions invoice path when present — never collected '
    'or settled from this read-only tab.';
