import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum IntegrationsIntegrationsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Integrations workspace Integrations
/// (`/integrations?section=integrations`).
@immutable
final class IntegrationsIntegrationsFinancialAtom {
  const IntegrationsIntegrationsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final IntegrationsIntegrationsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/integrations?section=integrations`.
///
/// Scope: tab chrome, integration worklist, next-actions, detail panels,
/// create/configure/test/sync/enable dialogs opened from this tab. This is an
/// ops connector desk — create/configure/test/sync/enable are connector CRUD,
/// not patient cash. Enum value `BILLING` is connector taxonomy (HL7|FHIR|LAB|
/// RADIOLOGY|BILLING|OTHER), not patient ledger posting. Related webhook events
/// (e.g. `payment.completed`) shown read-only must not acknowledge settlement
/// without a Billing ledger entry — that handoff belongs to Billing / webhook
/// delivery handlers, not this tab's UI. Soft-delete exists on the API but is
/// not mounted on this tab.
abstract final class IntegrationsIntegrationsBillingInventory {
  static const List<IntegrationsIntegrationsFinancialAtom> atoms =
      <IntegrationsIntegrationsFinancialAtom>[
        IntegrationsIntegrationsFinancialAtom(
          id: 'tab_navigate',
          label:
              'Integrations tab (integration:read ∩ integrations-core)',
          financialClass: IntegrationsIntegrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: IntegrationsIntegrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: IntegrationsIntegrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'create_integration_primary',
          label: 'Create integration primary (connector CRUD)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → integration detail',
          financialClass: IntegrationsIntegrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'next_action_review_failure',
          label: 'Next-action review_failure → test connection',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'next_action_enable',
          label: 'Next-action enable → toggle status',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'next_action_monitor',
          label: 'Next-action monitor → sync now',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_configure',
          label: 'Detail Configure (create/update connector)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_test_connection',
          label: 'Detail Test connection',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_sync_now',
          label: 'Detail Sync now',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_enable_disable',
          label: 'Detail Enable / Disable',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_metadata_tiles',
          label: 'Detail metadata tiles (ref / status / scope / last event)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_config_summary_panel',
          label: 'Configuration AppCollapsibleSection (sibling)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_related_webhooks_panel',
          label: 'Related webhooks AppCollapsibleSection (read-only sibling)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'detail_related_logs_panel',
          label: 'Related logs AppCollapsibleSection (read-only sibling)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'create_configure_form',
          label:
              'Create/Configure form (name, type incl. BILLING taxonomy, status, config_json)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'confirm_test_sync_enable_dialogs',
          label: 'Confirm dialogs (test / sync / enable·disable)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Post-mutation list/detail refresh (no billing balance)',
          financialClass: IntegrationsIntegrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'delete_integration',
          label: 'Delete integration (API soft-delete; not mounted on tab)',
          financialClass: IntegrationsIntegrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'interop_order_payment_payload',
          label:
              'Interop payload that creates clinical orders or payments',
          financialClass: IntegrationsIntegrationsFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'webhook_settlement_ack_without_ledger',
          label:
              'Webhook acknowledging settlement without Billing ledger entry',
          financialClass: IntegrationsIntegrationsFinancialClass.settle,
          // Reserved: settlement must post via Billing receive-payment / claims.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: IntegrationsIntegrationsFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsIntegrationsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: IntegrationsIntegrationsFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<IntegrationsIntegrationsFinancialAtom> get billableClasses =>
      atoms.where(
        (IntegrationsIntegrationsFinancialAtom atom) =>
            atom.financialClass ==
                IntegrationsIntegrationsFinancialClass.createCharge ||
            atom.financialClass ==
                IntegrationsIntegrationsFinancialClass.settle ||
            atom.financialClass ==
                IntegrationsIntegrationsFinancialClass.adjust ||
            atom.financialClass ==
                IntegrationsIntegrationsFinancialClass.reverse ||
            atom.financialClass ==
                IntegrationsIntegrationsFinancialClass.defer,
      );

  static Iterable<IntegrationsIntegrationsFinancialAtom> get mountedAtoms =>
      atoms.where((IntegrationsIntegrationsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IntegrationsIntegrationsFinancialAtom atom) =>
        atom.financialClass ==
            IntegrationsIntegrationsFinancialClass.notRequired ||
        atom.financialClass ==
            IntegrationsIntegrationsFinancialClass.notBilled ||
        atom.financialClass == IntegrationsIntegrationsFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get integrationsTabHasNoBillableActions => billableClasses.every(
    (IntegrationsIntegrationsFinancialAtom atom) => !atom.mounted,
  );

  static String summary() {
    final int billed = mountedAtoms
        .where(
          (IntegrationsIntegrationsFinancialAtom atom) =>
              atom.auditCode == 'NOT_BILLED',
        )
        .length;
    final int required = mountedAtoms
        .where(
          (IntegrationsIntegrationsFinancialAtom atom) =>
              atom.auditCode == 'NOT_REQUIRED',
        )
        .length;
    return 'Integrations tab: $billed NOT_BILLED, $required NOT_REQUIRED; '
        'no mounted billable atoms';
  }
}

/// Documents Integrations tab financial scope for tests and audits.
const String integrationsIntegrationsBillingScopeNote =
    'Integrations tab lists connectors (create/configure/test/sync/enable). '
    'All mounted mutations stay NOT_BILLED internal ops (audited). Enum type '
    'BILLING is connector taxonomy, not patient ledger posting. Related '
    'webhook events shown read-only must not acknowledge settlement without a '
    'Billing ledger entry. Interop payloads that create orders/payments and '
    'cash collection/adjust/refund stay unmounted and REQUIRES_BILLING — reuse '
    'Billing clinical-request-billing / receive-payment when later exposed. '
    'Delete soft-delete is API-only and NOT_BILLED when exposed.';
