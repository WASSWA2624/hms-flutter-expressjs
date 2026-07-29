import 'package:hosspi_hms/features/access_admin/presentation/access_admin_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum AccessAdminDirectoryFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Directory tab (`users` worklist).
class AccessAdminDirectoryFinancialAtom {
  const AccessAdminDirectoryFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final AccessAdminDirectoryFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/admin/access?panel=directory`.
///
/// Scope: tab chrome, users worklist, read-only detail dialog, create-user /
/// similarity nested dialogs opened from this tab. Patient/clinical revenue
/// stays on Billing; role/permission grants visible in detail do not mutate
/// historical ledgers.
abstract final class AccessAdminDirectoryBillingInventory {
  static const List<AccessAdminDirectoryFinancialAtom> atoms =
      <AccessAdminDirectoryFinancialAtom>[
        AccessAdminDirectoryFinancialAtom(
          id: 'tab_navigate',
          label: 'Directory tab',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'search_filter_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'empty_error_retry',
          label: 'Empty / error / retry states',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'row_select_user_detail',
          label: 'Row select → read-only user detail (roles / permissions preview)',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'create_user',
          label: 'Create user (tab primary + mutation dialog)',
          financialClass: AccessAdminDirectoryFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'create_user_similarity_review',
          label: 'Create user similarity review dialog',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'activate_deactivate',
          label: 'Activate / Deactivate user (next-action / mobile trailing)',
          financialClass: AccessAdminDirectoryFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'open_hr_profile',
          label: 'Open HR profile (staffProfileId navigation)',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'realtime_users_sync',
          label: 'Realtime users worklist sync',
          financialClass: AccessAdminDirectoryFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'edit_user',
          label: 'Edit user identity',
          financialClass: AccessAdminDirectoryFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'delete_user',
          label: 'Delete / restore user',
          financialClass: AccessAdminDirectoryFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'assign_roles_permissions',
          label: 'Assign roles / direct permissions (ManageUsers detail)',
          financialClass: AccessAdminDirectoryFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: AccessAdminDirectoryFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminDirectoryFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: AccessAdminDirectoryFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<AccessAdminDirectoryFinancialAtom> get billableClasses =>
      atoms.where(
        (AccessAdminDirectoryFinancialAtom atom) =>
            atom.financialClass ==
                AccessAdminDirectoryFinancialClass.createCharge ||
            atom.financialClass == AccessAdminDirectoryFinancialClass.settle ||
            atom.financialClass == AccessAdminDirectoryFinancialClass.adjust ||
            atom.financialClass == AccessAdminDirectoryFinancialClass.reverse ||
            atom.financialClass == AccessAdminDirectoryFinancialClass.defer,
      );

  /// Mounted atoms only (excludes reserved/future or off-tab paths).
  static Iterable<AccessAdminDirectoryFinancialAtom> get mountedAtoms =>
      atoms.where((AccessAdminDirectoryFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable =>
      mountedAtoms.every(
        (AccessAdminDirectoryFinancialAtom atom) =>
            atom.financialClass ==
                AccessAdminDirectoryFinancialClass.notRequired ||
            atom.financialClass == AccessAdminDirectoryFinancialClass.notBilled ||
            atom.financialClass == AccessAdminDirectoryFinancialClass.noCharge,
      );

  /// Write ∩ for Directory mutations; intersects workspace `canWrite`.
  static bool canMutateDirectory({
    required bool workspaceCanWrite,
    required bool policyAllowsWrite,
  }) {
    return policyAllowsWrite && workspaceCanWrite;
  }
}

/// Documents that Directory user ops are internal access administration.
///
/// Role/permission visibility in read-only detail must not alter historical
/// Billing records. Demo/seed financial data uses Billing factories elsewhere.
const String accessAdminDirectoryBillingScopeNote =
    'Directory user create and status changes are internal access '
    'administration (NOT_BILLED). Granting billing permissions via roles '
    'happens outside this tab’s read-only detail; historical patient ledgers '
    'remain on the Billing module of record.';

/// Convenience alias aligned with Permissions tab helper naming.
bool accessAdminDirectoryTabHasNoBillableActions() {
  return AccessAdminDirectoryBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      AccessAdminDirectoryBillingInventory.billableClasses.isEmpty;
}
