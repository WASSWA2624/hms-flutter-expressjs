import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum CommunicationsNotificationsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Communications Notifications
/// (`/communications?panel=notifications`).
@immutable
final class CommunicationsNotificationsFinancialAtom {
  const CommunicationsNotificationsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final CommunicationsNotificationsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/communications?panel=notifications`.
///
/// Scope: tab chrome, notification worklist, next-actions (mark read/unread /
/// view), detail dialog (open linked, archive confirm), delivery-history
/// disclosure, and nested flows opened from this tab. Notifications is a
/// **notification center** — read-state and archive are internal ops, not
/// patient ledger mutations. Open linked navigates to destination workspaces
/// (Billing gates live there). Paid SMS/notification commercial packages are
/// tenant SaaS charges on the subscriptions invoice path when present — never
/// patient clinical Billing, and never collected from this tab.
abstract final class CommunicationsNotificationsBillingInventory {
  static const List<CommunicationsNotificationsFinancialAtom> atoms =
      <CommunicationsNotificationsFinancialAtom>[
        CommunicationsNotificationsFinancialAtom(
          id: 'tab_navigate',
          label:
              'Notifications tab (communications:read ∩ notifications-communications)',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'notification_status_display',
          label: 'Read / priority / delivery status columns (ops)',
          financialClass: CommunicationsNotificationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → notification detail',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'next_action_mark_read_unread',
          label: 'Next action Mark read / Mark unread',
          financialClass: CommunicationsNotificationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'next_action_view',
          label: 'Next action View notification (read-only)',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'detail_metadata_panel',
          label: 'Detail metadata / context / timestamps',
          financialClass: CommunicationsNotificationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'detail_delivery_history',
          label: 'Detail delivery history progressive disclosure',
          financialClass: CommunicationsNotificationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'detail_open_linked',
          label: 'Detail Open linked record (navigate)',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'detail_archive',
          label: 'Detail Archive (confirm)',
          financialClass: CommunicationsNotificationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Notifications list sync',
          financialClass: CommunicationsNotificationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'tab_strip_new_message',
          label: 'Tab-strip New message / New group',
          financialClass: CommunicationsNotificationsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'sms_notification_commercial_package',
          label:
              'Paid SMS / notification commercial package (tenant SaaS invoice)',
          financialClass: CommunicationsNotificationsFinancialClass.createCharge,
          // Reserved: subscriptions invoice path — must not post patient ledgers.
          auditCode: 'REQUIRES_SUBSCRIPTIONS_BILLING',
          mounted: false,
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'patient_clinical_charge_via_notification',
          label:
              'Patient clinical charge implied by care-delivery notification action',
          financialClass: CommunicationsNotificationsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: CommunicationsNotificationsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsNotificationsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: CommunicationsNotificationsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<CommunicationsNotificationsFinancialAtom>
  get billableClasses => atoms.where(
    (CommunicationsNotificationsFinancialAtom atom) =>
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.createCharge ||
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.settle ||
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.adjust ||
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.reverse ||
        atom.financialClass == CommunicationsNotificationsFinancialClass.defer,
  );

  static Iterable<CommunicationsNotificationsFinancialAtom> get mountedAtoms =>
      atoms.where(
        (CommunicationsNotificationsFinancialAtom atom) => atom.mounted,
      );

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (CommunicationsNotificationsFinancialAtom atom) =>
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.notRequired ||
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.notBilled ||
        atom.financialClass ==
            CommunicationsNotificationsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get notificationsTabHasNoBillableActions => billableClasses.every(
    (CommunicationsNotificationsFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Notifications financial scope for tests and audits.
const String communicationsNotificationsBillingScopeNote =
    'Communications Notifications is the in-app notification center. Mark '
    'read/unread and archive stay NOT_BILLED internal ops (audited). Delivery '
    'and read status are NOT_BILLED operational telemetry, not a patient ledger '
    'balance. Open linked only navigates; Billing clearance stays on destination '
    'clinical / Billing workspaces. Paid SMS/notification commercial packages '
    'are tenant SaaS charges on the subscriptions invoice path when present — '
    'never collected or settled from this tab.';
