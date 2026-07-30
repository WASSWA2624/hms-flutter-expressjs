import 'package:flutter/foundation.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum CommunicationsTemplatesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Communications Templates
/// (`/communications?panel=templates`).
@immutable
final class CommunicationsTemplatesFinancialAtom {
  const CommunicationsTemplatesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final CommunicationsTemplatesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/communications?panel=templates`.
///
/// Scope: tab chrome, template worklist, row → detail preview, and nested
/// dialogs opened from this tab. Templates is a **writer catalog / preview**
/// surface — active status and channel metadata are operational, not a patient
/// ledger. Create / Edit / Delete are permission-gated but not mounted yet
/// (preview-only detail). Paid SMS/notification commercial packages are tenant
/// SaaS charges on the subscriptions invoice path when present — never patient
/// clinical Billing, and never collected from this tab. Message send that
/// implies paid care delivery must not bypass patient Billing if later mounted.
abstract final class CommunicationsTemplatesBillingInventory {
  static const List<CommunicationsTemplatesFinancialAtom> atoms =
      <CommunicationsTemplatesFinancialAtom>[
        CommunicationsTemplatesFinancialAtom(
          id: 'tab_navigate',
          label:
              'Templates tab (communications:read ∩ notifications-communications)',
          financialClass: CommunicationsTemplatesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'search_filters_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: CommunicationsTemplatesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'empty_error_retry_loading',
          label: 'Empty / loading / error / retry states',
          financialClass: CommunicationsTemplatesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'template_status_display',
          label: 'Template active status / channel / variables (ops catalog)',
          financialClass: CommunicationsTemplatesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → template detail (preview)',
          financialClass: CommunicationsTemplatesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'detail_metadata_panel',
          label: 'Detail metadata (channel / subject / variables / status)',
          financialClass: CommunicationsTemplatesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'detail_preview_panel',
          label: 'Detail preview subject / body progressive disclosure',
          financialClass: CommunicationsTemplatesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'realtime_workspace_sync',
          label: 'Realtime / search refresh Templates list sync',
          financialClass: CommunicationsTemplatesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'tab_strip_new_message',
          label: 'Tab-strip New message / New group',
          financialClass: CommunicationsTemplatesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'create_update_template',
          label: 'Create / update template (when exposed)',
          financialClass: CommunicationsTemplatesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'delete_template',
          label: 'Delete template (when exposed; delete ∩ gated)',
          financialClass: CommunicationsTemplatesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'sms_notification_commercial_package',
          label:
              'Paid SMS / notification commercial package (tenant SaaS invoice)',
          financialClass: CommunicationsTemplatesFinancialClass.createCharge,
          // Reserved: subscriptions invoice path — must not post patient ledgers.
          auditCode: 'REQUIRES_SUBSCRIPTIONS_BILLING',
          mounted: false,
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'patient_clinical_charge_via_message',
          label:
              'Patient clinical charge implied by care-delivery message send',
          financialClass: CommunicationsTemplatesFinancialClass.createCharge,
          // Reserved: must post via Billing clinical-request-billing when mounted.
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: CommunicationsTemplatesFinancialClass.settle,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
        CommunicationsTemplatesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse / write-off',
          financialClass: CommunicationsTemplatesFinancialClass.adjust,
          auditCode: 'REQUIRES_BILLING',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<CommunicationsTemplatesFinancialAtom> get billableClasses =>
      atoms.where(
        (CommunicationsTemplatesFinancialAtom atom) =>
            atom.financialClass ==
                CommunicationsTemplatesFinancialClass.createCharge ||
            atom.financialClass ==
                CommunicationsTemplatesFinancialClass.settle ||
            atom.financialClass ==
                CommunicationsTemplatesFinancialClass.adjust ||
            atom.financialClass ==
                CommunicationsTemplatesFinancialClass.reverse ||
            atom.financialClass ==
                CommunicationsTemplatesFinancialClass.defer,
      );

  static Iterable<CommunicationsTemplatesFinancialAtom> get mountedAtoms =>
      atoms.where((CommunicationsTemplatesFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (CommunicationsTemplatesFinancialAtom atom) =>
        atom.financialClass ==
            CommunicationsTemplatesFinancialClass.notRequired ||
        atom.financialClass ==
            CommunicationsTemplatesFinancialClass.notBilled ||
        atom.financialClass == CommunicationsTemplatesFinancialClass.noCharge,
  );

  /// True when no mounted atom is classified as billable.
  static bool get templatesTabHasNoBillableActions => billableClasses.every(
    (CommunicationsTemplatesFinancialAtom atom) => !atom.mounted,
  );
}

/// Documents Templates financial scope for tests and audits.
const String communicationsTemplatesBillingScopeNote =
    'Communications Templates lists notification/message templates for writers '
    '(channel, subject, variables, active status, preview). Template catalog '
    'and preview stay NOT_BILLED internal ops (audited). Create / Edit / Delete '
    'are not mounted on this read-focused tab; when exposed they remain '
    'NOT_BILLED template CRUD and must not invent cashier logic. Paid '
    'SMS/notification commercial packages are tenant SaaS charges on the '
    'subscriptions invoice path when present — never collected or settled from '
    'this tab. Message send that implies paid care delivery must not bypass '
    'patient Billing.';
