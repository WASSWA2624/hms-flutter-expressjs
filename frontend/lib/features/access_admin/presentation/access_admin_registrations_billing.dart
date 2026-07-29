import 'package:hosspi_hms/features/access_admin/presentation/access_admin_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum AccessAdminRegistrationsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Registrations tab (`registration-follow-ups`).
class AccessAdminRegistrationsFinancialAtom {
  const AccessAdminRegistrationsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final AccessAdminRegistrationsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/admin/access?panel=registrations`.
///
/// Scope: tab chrome, worklist, registration detail dialog, and nested flows
/// opened from this tab. Patient/clinical revenue stays on Billing; SaaS
/// trial provisioning on activate uses the subscriptions onboarding path.
abstract final class AccessAdminRegistrationsBillingInventory {
  static const List<AccessAdminRegistrationsFinancialAtom> atoms =
      <AccessAdminRegistrationsFinancialAtom>[
        AccessAdminRegistrationsFinancialAtom(
          id: 'tab_navigate',
          label: 'Registrations tab',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'search_filter_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'empty_error_retry',
          label: 'Empty / error / retry states',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'row_select_registration_detail',
          label: 'Row select → registration detail',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'activate_registration',
          label: 'Activate registration (next-action / mobile trailing)',
          financialClass: AccessAdminRegistrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'reject_registration',
          label: 'Reject registration (detail)',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'provision_trial_subscription',
          label: 'Backend trial subscription provisioning (activate side-effect)',
          financialClass: AccessAdminRegistrationsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'realtime_registration_sync',
          label: 'Realtime registration worklist sync',
          financialClass: AccessAdminRegistrationsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'create_user',
          label: 'Create user primary',
          financialClass: AccessAdminRegistrationsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'create_role',
          label: 'Create role primary',
          financialClass: AccessAdminRegistrationsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: AccessAdminRegistrationsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminRegistrationsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: AccessAdminRegistrationsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<AccessAdminRegistrationsFinancialAtom> get billableClasses =>
      atoms.where(
        (AccessAdminRegistrationsFinancialAtom atom) =>
            atom.financialClass ==
                AccessAdminRegistrationsFinancialClass.createCharge ||
            atom.financialClass ==
                AccessAdminRegistrationsFinancialClass.settle ||
            atom.financialClass ==
                AccessAdminRegistrationsFinancialClass.adjust ||
            atom.financialClass ==
                AccessAdminRegistrationsFinancialClass.reverse ||
            atom.financialClass == AccessAdminRegistrationsFinancialClass.defer,
      );

  /// Mounted atoms only (excludes reserved/future write paths).
  static Iterable<AccessAdminRegistrationsFinancialAtom> get mountedAtoms =>
      atoms.where((AccessAdminRegistrationsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable =>
      mountedAtoms.every(
        (AccessAdminRegistrationsFinancialAtom atom) =>
            atom.financialClass ==
                AccessAdminRegistrationsFinancialClass.notRequired ||
            atom.financialClass ==
                AccessAdminRegistrationsFinancialClass.notBilled ||
            atom.financialClass == AccessAdminRegistrationsFinancialClass.noCharge,
      );
}

/// Documents that Registrations activate uses subscriptions onboarding, not
/// patient Billing ledgers. Role grants from activation do not mutate historical
/// billing records.
const String accessAdminRegistrationsBillingScopeNote =
    'Pending tenant registrations are elevated-only access-administration '
    'workflows. Activate provisions a SaaS trial via the subscriptions '
    'onboarding path; reject updates user status only. No patient invoice, '
    'payment, or adjustment is collected on this tab.';

/// True when Registrations tab has no patient-ledger billable actions.
bool accessAdminRegistrationsTabHasNoPatientBillableActions() {
  return AccessAdminRegistrationsBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      AccessAdminRegistrationsBillingInventory.billableClasses.isEmpty;
}

/// Write ∩ for Registrations mutations (activate / reject).
bool accessAdminRegistrationsCanMutate({
  required bool workspaceCanWrite,
  required bool policyAllowsWrite,
}) {
  return policyAllowsWrite && workspaceCanWrite;
}
