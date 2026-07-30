import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum IntegrationsApiKeysFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Integrations API keys (`/integrations?…=api-keys`).
@immutable
final class IntegrationsApiKeysFinancialAtom {
  const IntegrationsApiKeysFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final IntegrationsApiKeysFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/integrations?section=api-keys`.
///
/// Scope: tab chrome, API key worklist, next-actions, detail (masked secret /
/// rotation note / permissions), create + one-time secret reveal, enable /
/// disable, revoke, add/remove permission grants, and nested dialogs opened
/// from this tab. API keys are **developer credentials** — create / rotate /
/// revoke and permission grants (including `billing:*` codes) are internal
/// ops and must not post patient Billing ledger rows. Interop payloads that
/// create orders or payments must invoke Billing elsewhere (interop /
/// clinical-request paths); this tab never collects payment.
abstract final class IntegrationsApiKeysBillingInventory {
  static const List<IntegrationsApiKeysFinancialAtom> atoms =
      <IntegrationsApiKeysFinancialAtom>[
        IntegrationsApiKeysFinancialAtom(
          id: 'tab_navigate',
          label: 'API keys tab (integration:read ∩ integrations-core)',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → API key detail',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'next_action_rotate_or_monitor',
          label: 'Next action Rotate or monitor (healthy key)',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'next_action_review_key',
          label: 'Next action Review key (inactive / expired)',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'create_api_key',
          label: 'Create API key (tab-strip primary)',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'secret_reveal_write_only',
          label: 'One-time secret reveal (write-only copy)',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'detail_masked_secret',
          label: 'Detail masked secret panel',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'detail_rotation_note',
          label: 'Detail rotation guidance panel',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'detail_permissions_panel',
          label: 'Detail permissions grants panel',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'manage_permissions_add',
          label: 'Manage permissions → add grant',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'remove_permission_grant',
          label: 'Remove permission grant',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'billing_permission_grant_metadata',
          label: 'billing:* permission grant on API key (access metadata)',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'enable_disable_api_key',
          label: 'Enable / disable API key',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'revoke_api_key',
          label: 'Revoke / delete API key',
          financialClass: IntegrationsApiKeysFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Post-mutation API keys list sync',
          financialClass: IntegrationsApiKeysFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'interop_order_payment_via_api_key',
          label:
              'Interop payload creating clinical order / payment via API key',
          financialClass: IntegrationsApiKeysFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request / receive-payment.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: IntegrationsApiKeysFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsApiKeysFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: IntegrationsApiKeysFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<IntegrationsApiKeysFinancialAtom> get billableClasses =>
      atoms.where(
        (IntegrationsApiKeysFinancialAtom atom) =>
            atom.financialClass ==
                IntegrationsApiKeysFinancialClass.createCharge ||
            atom.financialClass == IntegrationsApiKeysFinancialClass.settle ||
            atom.financialClass == IntegrationsApiKeysFinancialClass.adjust ||
            atom.financialClass == IntegrationsApiKeysFinancialClass.reverse ||
            atom.financialClass == IntegrationsApiKeysFinancialClass.defer,
      );

  static Iterable<IntegrationsApiKeysFinancialAtom> get mountedAtoms =>
      atoms.where((IntegrationsApiKeysFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IntegrationsApiKeysFinancialAtom atom) =>
        atom.financialClass == IntegrationsApiKeysFinancialClass.notRequired ||
        atom.financialClass == IntegrationsApiKeysFinancialClass.notBilled ||
        atom.financialClass == IntegrationsApiKeysFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get apiKeysTabHasNoBillableActions => billableClasses.every(
    (IntegrationsApiKeysFinancialAtom atom) => !atom.mounted,
  );

  /// Create / manage / revoke gates used by unauthorized-control checks.
  static bool canMutateApiKeys(AppAccessPolicy policy) {
    return IntegrationsApiKeysAtomPermissions.create.isAllowed(policy) ||
        IntegrationsApiKeysAtomPermissions.update.isAllowed(policy) ||
        IntegrationsApiKeysAtomPermissions.delete.isAllowed(policy);
  }
}

/// Documents ledger isolation for this tab.
const String integrationsApiKeysBillingScopeNote =
    'Integrations API keys manage developer credentials and permission grants '
    'only (NOT_BILLED / NOT_REQUIRED). Granting billing:* scopes is access '
    'metadata and must not mutate patient Billing ledgers. Clinical orders or '
    'payments authorized by an API key must post via Billing clinical-request '
    'billing / receive-payment / adjustment paths (interop handlers), never a '
    'parallel cash ledger on this tab.';

/// True when every mounted atom is explicitly not billable to patient ledgers.
bool integrationsApiKeysTabHasNoBillableActions() {
  return IntegrationsApiKeysBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      IntegrationsApiKeysBillingInventory.apiKeysTabHasNoBillableActions;
}
