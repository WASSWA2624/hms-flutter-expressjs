import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum IntegrationsInteropFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Integrations Interop (`/integrations?…=interop`).
@immutable
final class IntegrationsInteropFinancialAtom {
  const IntegrationsInteropFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final IntegrationsInteropFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/integrations?section=interop`.
///
/// Scope: tab chrome, interop capability worklist (FHIR / HL7 / DICOM /
/// migration / readiness), next-actions (Run action / Use status logs → open
/// detail), readiness detail dialog, and nested dialogs opened from this tab.
/// Interop is a **readiness / probe desk** — status display and detail open are
/// internal ops and must not post patient Billing ledger rows. When backend
/// FHIR/HL7/DICOM/migration handlers later materialize clinical orders or
/// settlements, those payloads must invoke shared Billing (clinical-request
/// billing / receive-payment / adjustment) with idempotency — never a parallel
/// cash ledger on this tab. Webhook settlement acknowledgements stay on the
/// Webhooks tab / Billing engine, not here.
abstract final class IntegrationsInteropBillingInventory {
  static const List<IntegrationsInteropFinancialAtom> atoms =
      <IntegrationsInteropFinancialAtom>[
        IntegrationsInteropFinancialAtom(
          id: 'tab_navigate',
          label: 'Interop tab (integration:read ∩ integrations-core)',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'capability_status_display',
          label: 'Capability readiness / scope / updated columns (ops)',
          financialClass: IntegrationsInteropFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → interop readiness detail',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'next_action_run_available',
          label: 'Next action Run action (open detail)',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'next_action_use_status_logs',
          label: 'Next action Use status logs (open detail)',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'detail_readiness_panel',
          label: 'Detail readiness / unavailable-reason message',
          financialClass: IntegrationsInteropFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'detail_metadata_tiles',
          label: 'Detail reference / status / scope / last-event tiles',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close (dialog chrome)',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'run_probe_manage_gate',
          label: 'runProbe / update manage ∪ gate (not mounted in UI)',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Post-open list sync (no Interop mutation UI)',
          financialClass: IntegrationsInteropFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        IntegrationsInteropFinancialAtom(
          id: 'fhir_hl7_order_or_payment_payload',
          label:
              'FHIR/HL7 payload creating clinical order or payment settlement',
          financialClass: IntegrationsInteropFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request / receive-payment.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsInteropFinancialAtom(
          id: 'webhook_settlement_ack_without_ledger',
          label: 'Webhook settlement ack without Billing ledger entry',
          financialClass: IntegrationsInteropFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsInteropFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: IntegrationsInteropFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        IntegrationsInteropFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: IntegrationsInteropFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<IntegrationsInteropFinancialAtom> get billableClasses =>
      atoms.where(
        (IntegrationsInteropFinancialAtom atom) =>
            atom.financialClass ==
                IntegrationsInteropFinancialClass.createCharge ||
            atom.financialClass == IntegrationsInteropFinancialClass.settle ||
            atom.financialClass == IntegrationsInteropFinancialClass.adjust ||
            atom.financialClass == IntegrationsInteropFinancialClass.reverse ||
            atom.financialClass == IntegrationsInteropFinancialClass.defer,
      );

  static Iterable<IntegrationsInteropFinancialAtom> get mountedAtoms =>
      atoms.where((IntegrationsInteropFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (IntegrationsInteropFinancialAtom atom) =>
        atom.financialClass ==
            IntegrationsInteropFinancialClass.notRequired ||
        atom.financialClass == IntegrationsInteropFinancialClass.notBilled ||
        atom.financialClass == IntegrationsInteropFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get interopTabHasNoBillableActions => billableClasses.every(
    (IntegrationsInteropFinancialAtom atom) => !atom.mounted,
  );

  /// Manage / probe gates used by unauthorized-control checks.
  static bool canMutateInterop(AppAccessPolicy policy) {
    return IntegrationsInteropAtomPermissions.create.isAllowed(policy) ||
        IntegrationsInteropAtomPermissions.update.isAllowed(policy) ||
        IntegrationsInteropAtomPermissions.runProbe.isAllowed(policy) ||
        IntegrationsInteropAtomPermissions.delete.isAllowed(policy);
  }
}

/// Documents ledger isolation for this tab.
const String integrationsInteropBillingScopeNote =
    'Integrations Interop surfaces capability readiness probes only '
    '(NOT_BILLED / NOT_REQUIRED). Run action / Use status logs open readiness '
    'detail and must not mutate patient Billing ledgers. FHIR/HL7/DICOM/'
    'migration handlers that later create clinical orders or settlements must '
    'post via Billing clinical-request billing / receive-payment / adjustment '
    'with idempotency keys; webhook settlement acknowledgements require a '
    'Billing ledger entry and are not collected from this tab.';

/// True when every mounted atom is explicitly not billable to patient ledgers.
bool integrationsInteropTabHasNoBillableActions() {
  return IntegrationsInteropBillingInventory
          .allMountedAtomsExplicitlyNotBillable &&
      IntegrationsInteropBillingInventory.interopTabHasNoBillableActions;
}
