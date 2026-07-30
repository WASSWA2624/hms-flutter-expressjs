import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum CommunicationsMessagesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Communications Messages
/// (`/communications?panel=inbox` / Messages tab).
@immutable
final class CommunicationsMessagesFinancialAtom {
  const CommunicationsMessagesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final CommunicationsMessagesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/communications` Messages (inbox) tab.
///
/// Scope: tab chrome, conversation list, thread view, New message / New group
/// primaries, compose / send / attach / reply, thread menu (favorite / flag /
/// mark read / archive), manage members, nested dialogs opened from this tab.
/// Staff inbox messaging stays NOT_BILLED. Paid SMS/notification packages and
/// patient clinical charges are not mounted here; if introduced they must post
/// via Billing (subscriptions commercial path or clinical-request-billing /
/// receive-payment / adjustment)—never a parallel cash ledger or local paid flag.
abstract final class CommunicationsMessagesBillingInventory {
  static const List<CommunicationsMessagesFinancialAtom> atoms =
      <CommunicationsMessagesFinancialAtom>[
        CommunicationsMessagesFinancialAtom(
          id: 'tab_navigate',
          label:
              'Messages tab (communications:read ∩ notifications-communications)',
          financialClass: CommunicationsMessagesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'search_filters_load_more',
          label: 'Search / message filters / Load more',
          financialClass: CommunicationsMessagesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: CommunicationsMessagesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'select_conversation_thread',
          label: 'Select conversation → thread',
          financialClass: CommunicationsMessagesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'thread_back_narrow',
          label: 'Thread back (narrow viewport)',
          financialClass: CommunicationsMessagesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'new_message_primary',
          label: 'New message (tab primary create)',
          financialClass: CommunicationsMessagesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'new_group_secondary',
          label: 'New group (tab secondary create)',
          financialClass: CommunicationsMessagesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'compose_send_attach_reply',
          label: 'Compose / Send / Attach / Reply',
          financialClass: CommunicationsMessagesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'thread_menu_favorite_flag_read_archive',
          label: 'Thread menu favorite / flag / mark read / archive',
          financialClass: CommunicationsMessagesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'manage_members',
          label: 'Manage members (add / remove)',
          financialClass: CommunicationsMessagesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'nested_mutation_dialogs',
          label: 'Nested dialogs (New message / New group / Manage members)',
          financialClass: CommunicationsMessagesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / post-mutation Messages inbox sync',
          financialClass: CommunicationsMessagesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'paid_sms_notification_package',
          label: 'Paid SMS / notification package (tenant commercial charge)',
          financialClass: CommunicationsMessagesFinancialClass.createCharge,
          // Reserved: must post via Billing / subscriptions invoice path when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'patient_clinical_charge_via_message',
          label:
              'Patient clinical charge implied by care-delivery message send',
          financialClass: CommunicationsMessagesFinancialClass.createCharge,
          // Reserved: must post via clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: CommunicationsMessagesFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsMessagesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: CommunicationsMessagesFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to Billing if mounted without wiring.
  static Iterable<CommunicationsMessagesFinancialAtom> get billableClasses =>
      atoms.where(
        (CommunicationsMessagesFinancialAtom atom) =>
            atom.financialClass ==
                CommunicationsMessagesFinancialClass.createCharge ||
            atom.financialClass ==
                CommunicationsMessagesFinancialClass.settle ||
            atom.financialClass ==
                CommunicationsMessagesFinancialClass.adjust ||
            atom.financialClass ==
                CommunicationsMessagesFinancialClass.reverse ||
            atom.financialClass ==
                CommunicationsMessagesFinancialClass.defer,
      );

  static Iterable<CommunicationsMessagesFinancialAtom> get mountedAtoms =>
      atoms.where((CommunicationsMessagesFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (CommunicationsMessagesFinancialAtom atom) =>
        atom.financialClass ==
            CommunicationsMessagesFinancialClass.notRequired ||
        atom.financialClass ==
            CommunicationsMessagesFinancialClass.notBilled ||
        atom.financialClass == CommunicationsMessagesFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get messagesTabHasNoBillableActions => billableClasses.every(
    (CommunicationsMessagesFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Messages financial scope for tests and audits.
const String communicationsMessagesBillingScopeNote =
    'Communications Messages is the staff inbox for internal threads. New '
    'message, New group, compose/send, thread menu, and manage members stay '
    'NOT_BILLED internal ops (audited). Paid SMS/notification packages and '
    'patient clinical charges are not mounted on this tab; collection and '
    'invoice issuance remain on the Billing module of record. Message send '
    'must not bypass patient Billing for paid care delivery.';
