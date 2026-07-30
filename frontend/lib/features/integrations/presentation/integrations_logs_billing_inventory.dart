import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum IntegrationsLogsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Integrations Logs (`/integrations?…=logs`).
@immutable
final class IntegrationsLogsFinancialAtom {
  const IntegrationsLogsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final IntegrationsLogsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/integrations?section=logs`.
///
/// Scope: tab chrome, delivery/audit log worklist, next-actions (Review /
/// Replay or escalate), sanitized log detail, Replay confirm dialog, and
/// nested dialogs opened from this tab. Logs is a **read-only delivery/audit
/// desk** — list/detail and Replay create audit copies only and must not post
/// patient Billing ledger rows. Interop payloads that create clinical orders
/// or payments, and webhook settlement acknowledgements, must invoke shared
/// Billing (clinical-request billing / receive-payment / adjustment) with
/// idempotency elsewhere — never a parallel cash ledger on this tab.
abstract final class IntegrationsLogsBillingInventory {
  static const List<IntegrationsLogsFinancialAtom> atoms =
      <IntegrationsLogsFinancialAtom>[
        IntegrationsLogsFinancialAtom(
          id: 'tab_navigate',
          label: 'Logs tab (integration:read ∩ integrations-core)',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → sanitized log detail',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'next_action_review',
          label: 'Next action Review (healthy log)',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'next_action_replay_or_escalate',
          label: 'Next action Replay or escalate (attention log)',
          financialClass: IntegrationsLogsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'detail_metadata_tiles',
          label: 'Detail reference / status / scope / last-event tiles',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'detail_sanitized_log_panel',
          label: 'Detail sanitized log AppMessagePanel (tone chrome)',
          financialClass: IntegrationsLogsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'detail_replay_action',
          label: 'Detail Replay log (+ confirm dialog)',
          financialClass: IntegrationsLogsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close (dialog chrome)',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Post-replay logs list sync (no billing balance)',
          financialClass: IntegrationsLogsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsLogsFinancialAtom(
          id: 'interop_order_payment_via_log_replay',
          label:
              'Replay / interop payload creating clinical order or payment',
          financialClass: IntegrationsLogsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request / receive-payment.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsLogsFinancialAtom(
          id: 'webhook_settlement_ack_without_ledger',
          label:
              'Webhook acknowledging settlement without Billing ledger entry',
          financialClass: IntegrationsLogsFinancialClass.settle,
          // Reserved: settlement must post via Billing receive-payment / claims.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsLogsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: IntegrationsLogsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsLogsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: IntegrationsLogsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<IntegrationsLogsFinancialAtom> get billableClasses =>
      atoms.where(
        (IntegrationsLogsFinancialAtom atom) =>
            atom.financialClass ==
                IntegrationsLogsFinancialClass.createCharge ||
            atom.financialClass == IntegrationsLogsFinancialClass.settle ||
            atom.financialClass == IntegrationsLogsFinancialClass.adjust ||
            atom.financialClass == IntegrationsLogsFinancialClass.reverse ||
            atom.financialClass == IntegrationsLogsFinancialClass.defer,
      );

  static Iterable<IntegrationsLogsFinancialAtom> get mountedAtoms =>
      atoms.where((IntegrationsLogsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IntegrationsLogsFinancialAtom atom) =>
        atom.financialClass == IntegrationsLogsFinancialClass.notRequired ||
        atom.financialClass == IntegrationsLogsFinancialClass.notBilled ||
        atom.financialClass == IntegrationsLogsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get logsTabHasNoBillableActions => billableClasses.every(
    (IntegrationsLogsFinancialAtom atom) => !atom.mounted,
  );

  /// Replay / manage gates used by unauthorized-control checks.
  static bool canReplayLogs(AppAccessPolicy policy) {
    return IntegrationsLogsAtomPermissions.replay.isAllowed(policy);
  }
}

/// Documents ledger isolation for this tab.
const String integrationsLogsBillingScopeNote =
    'Integrations Logs surfaces delivery/audit records only '
    '(NOT_BILLED / NOT_REQUIRED). Replay creates an audited log copy and must '
    'not mutate patient Billing ledgers. Interop payloads that create clinical '
    'orders or payments, and webhook settlement acknowledgements, must post via '
    'Billing clinical-request billing / receive-payment / adjustment with '
    'idempotency keys — never a parallel cash ledger or local paid flag on '
    'this tab.';

/// True when every mounted atom is explicitly not billable to patient ledgers.
bool integrationsLogsTabHasNoBillableActions() {
  return IntegrationsLogsBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      IntegrationsLogsBillingInventory.logsTabHasNoBillableActions;
}
