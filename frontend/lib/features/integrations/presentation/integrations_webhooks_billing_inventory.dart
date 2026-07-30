import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum IntegrationsWebhooksFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Integrations Webhooks (`/integrations?…=webhooks`).
@immutable
final class IntegrationsWebhooksFinancialAtom {
  const IntegrationsWebhooksFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final IntegrationsWebhooksFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/integrations?section=webhooks`.
///
/// Scope: tab chrome, webhook subscription worklist, next-actions (Monitor
/// delivery / Enable webhook), detail (event / target / integration tiles),
/// Create webhook primary, Edit, Replay delivery, Enable / Disable, and nested
/// dialogs opened from this tab. Webhooks manage **outbound delivery
/// subscriptions** — create / edit / enable / replay are internal ops and must
/// not post patient Billing ledger rows. Event names such as
/// `payment.completed` are subscription metadata only. Interop payloads that
/// create clinical orders or payments, and inbound settlement acknowledgements,
/// must invoke shared Billing (clinical-request billing / receive-payment /
/// adjustment) with idempotency elsewhere — never acknowledge settlement from
/// this tab without a Billing ledger entry.
abstract final class IntegrationsWebhooksBillingInventory {
  static const List<IntegrationsWebhooksFinancialAtom> atoms =
      <IntegrationsWebhooksFinancialAtom>[
        IntegrationsWebhooksFinancialAtom(
          id: 'tab_navigate',
          label: 'Webhooks tab (integration:read ∩ integrations-core)',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → webhook detail',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'next_action_monitor_delivery',
          label: 'Next action Monitor delivery (active webhook)',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'next_action_enable_webhook',
          label: 'Next action Enable webhook (inactive)',
          financialClass: IntegrationsWebhooksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'create_webhook',
          label: 'Create webhook (tab-strip primary)',
          financialClass: IntegrationsWebhooksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'detail_event_target_tiles',
          label: 'Detail event / target host / integration tiles',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'detail_edit_webhook',
          label: 'Detail Edit webhook (+ form dialog)',
          financialClass: IntegrationsWebhooksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'detail_replay_webhook',
          label: 'Detail Replay webhook (+ confirm dialog)',
          financialClass: IntegrationsWebhooksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'detail_enable_disable',
          label: 'Detail Enable / Disable webhook',
          financialClass: IntegrationsWebhooksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close (dialog chrome)',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'payment_event_name_metadata',
          label:
              'Event name metadata (e.g. payment.completed) — subscription only',
          financialClass: IntegrationsWebhooksFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Post-mutation webhooks list sync (no billing balance)',
          financialClass: IntegrationsWebhooksFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'interop_order_payment_via_webhook_payload',
          label:
              'Interop / inbound payload creating clinical order or payment',
          financialClass: IntegrationsWebhooksFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request / receive-payment.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'webhook_settlement_ack_without_ledger',
          label:
              'Webhook acknowledging settlement without Billing ledger entry',
          financialClass: IntegrationsWebhooksFinancialClass.settle,
          // Reserved: settlement must post via Billing receive-payment / claims.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: IntegrationsWebhooksFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsWebhooksFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: IntegrationsWebhooksFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<IntegrationsWebhooksFinancialAtom> get billableClasses =>
      atoms.where(
        (IntegrationsWebhooksFinancialAtom atom) =>
            atom.financialClass ==
                IntegrationsWebhooksFinancialClass.createCharge ||
            atom.financialClass ==
                IntegrationsWebhooksFinancialClass.settle ||
            atom.financialClass ==
                IntegrationsWebhooksFinancialClass.adjust ||
            atom.financialClass ==
                IntegrationsWebhooksFinancialClass.reverse ||
            atom.financialClass == IntegrationsWebhooksFinancialClass.defer,
      );

  static Iterable<IntegrationsWebhooksFinancialAtom> get mountedAtoms =>
      atoms.where((IntegrationsWebhooksFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IntegrationsWebhooksFinancialAtom atom) =>
        atom.financialClass ==
            IntegrationsWebhooksFinancialClass.notRequired ||
        atom.financialClass == IntegrationsWebhooksFinancialClass.notBilled ||
        atom.financialClass == IntegrationsWebhooksFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get webhooksTabHasNoBillableActions => billableClasses.every(
    (IntegrationsWebhooksFinancialAtom atom) => !atom.mounted,
  );

  /// Create / edit / replay / enable gates used by unauthorized-control checks.
  static bool canMutateWebhooks(AppAccessPolicy policy) {
    return IntegrationsWebhooksAtomPermissions.create.isAllowed(policy) ||
        IntegrationsWebhooksAtomPermissions.update.isAllowed(policy) ||
        IntegrationsWebhooksAtomPermissions.replay.isAllowed(policy) ||
        IntegrationsWebhooksAtomPermissions.enable.isAllowed(policy);
  }
}

/// Documents ledger isolation for this tab.
const String integrationsWebhooksBillingScopeNote =
    'Integrations Webhooks manage outbound delivery subscriptions only '
    '(NOT_BILLED / NOT_REQUIRED). Create / edit / enable / replay deliver HTTP '
    'to a target URL and must not mutate patient Billing ledgers. Event names '
    'such as payment.completed are subscription metadata. Interop payloads that '
    'create clinical orders or payments, and settlement acknowledgements, must '
    'post via Billing clinical-request billing / receive-payment / adjustment '
    'with idempotency keys — never a parallel cash ledger or local paid flag on '
    'this tab.';

/// True when every mounted atom is explicitly not billable to patient ledgers.
bool integrationsWebhooksTabHasNoBillableActions() {
  return IntegrationsWebhooksBillingInventory
          .allMountedAtomsExplicitlyNotBillable &&
      IntegrationsWebhooksBillingInventory.webhooksTabHasNoBillableActions;
}
