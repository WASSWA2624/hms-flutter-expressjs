import 'package:hosspi_hms/features/access_admin/presentation/access_admin_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum AccessAdminDemoFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Demo tab (`demo-users`).
class AccessAdminDemoFinancialAtom {
  const AccessAdminDemoFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final AccessAdminDemoFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/admin/access?panel=demo`.
///
/// Scope: tab chrome, worklist, detail dialog, create-user / similarity
/// nested flows, and backend handlers they invoke. Demo user provisioning
/// and credential resets are access-administration operations — they must not
/// post to patient Billing ledgers or alter historical invoice rows when roles
/// include `billing:*` grants.
abstract final class AccessAdminDemoBillingInventory {
  static const List<AccessAdminDemoFinancialAtom> atoms =
      <AccessAdminDemoFinancialAtom>[
        AccessAdminDemoFinancialAtom(
          id: 'tab_navigate',
          label: 'Demo tab',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'search_filter_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'empty_error_retry',
          label: 'Empty / error / retry states',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → demo user detail',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'create_user',
          label: 'Create demo user (tab primary + mutation dialog)',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'create_user_similarity_review',
          label: 'Create-user similarity review dialog',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'activate_deactivate',
          label: 'Activate / Deactivate (next-action / mobile trailing)',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'reset_demo_password',
          label: 'Reset demo password',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'open_hr_profile',
          label: 'Open HR profile (linked staff)',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'role_permissions_display',
          label: 'Assigned roles / effective permissions display',
          financialClass: AccessAdminDemoFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'realtime_demo_sync',
          label: 'Realtime demo-users worklist sync',
          financialClass: AccessAdminDemoFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDemoFinancialAtom(
          id: 'delete_user',
          label: 'Delete demo user',
          financialClass: AccessAdminDemoFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminDemoFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: AccessAdminDemoFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminDemoFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: AccessAdminDemoFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<AccessAdminDemoFinancialAtom> get billableClasses => atoms
      .where(
        (AccessAdminDemoFinancialAtom atom) =>
            atom.financialClass ==
                AccessAdminDemoFinancialClass.createCharge ||
            atom.financialClass == AccessAdminDemoFinancialClass.settle ||
            atom.financialClass == AccessAdminDemoFinancialClass.adjust ||
            atom.financialClass == AccessAdminDemoFinancialClass.reverse ||
            atom.financialClass == AccessAdminDemoFinancialClass.defer,
      );

  /// Mounted atoms only (excludes reserved/future financial paths).
  static Iterable<AccessAdminDemoFinancialAtom> get mountedAtoms =>
      atoms.where((AccessAdminDemoFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable =>
      mountedAtoms.every(
        (AccessAdminDemoFinancialAtom atom) =>
            atom.financialClass == AccessAdminDemoFinancialClass.notRequired ||
            atom.financialClass == AccessAdminDemoFinancialClass.notBilled ||
            atom.financialClass == AccessAdminDemoFinancialClass.noCharge,
      );

  /// Write ∩ for Demo mutations; same gate as Directory.
  static bool canMutateDemoUsers({
    required bool workspaceCanWrite,
    required bool policyAllowsWrite,
  }) {
    return policyAllowsWrite && workspaceCanWrite;
  }
}

/// Documents that Demo provisioning must not touch patient Billing ledgers.
///
/// Role grants that include `billing:*` are access metadata only on this tab;
/// historical invoice/payment rows remain unchanged. Seed/demo financial data
/// must use Billing factories when clinical scenarios need amounts — not
/// orphan fields on access-admin DTOs.
const String accessAdminDemoBillingScopeNote =
    'Demo user administration (create, status, password reset) is access '
    'provisioning. Displaying billing permissions in effective grants does '
    'not mutate patient Billing ledgers. No payment collection or invoice '
    'issue occurs on this tab.';

/// Convenience alias aligned with Directory tab helper naming.
bool accessAdminDemoTabHasNoBillableActions() {
  return AccessAdminDemoBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      AccessAdminDemoBillingInventory.billableClasses.isEmpty;
}
