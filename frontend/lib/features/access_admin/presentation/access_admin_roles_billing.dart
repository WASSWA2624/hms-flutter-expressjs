/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum AccessAdminRolesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Roles tab (`roles` resource).
class AccessAdminRolesFinancialAtom {
  const AccessAdminRolesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final AccessAdminRolesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/admin/access?panel=roles`.
///
/// Scope: tab chrome, worklist, create/edit/delete dialogs, similarity review,
/// and read-only role detail on this tab. Permission sync/editor and lifecycle
/// restore/purge live on [ManageRolesPermissionsPanel] (other entry points).
/// Granting `billing:*` permissions adjusts access only — it must not mutate
/// patient Billing ledgers.
abstract final class AccessAdminRolesBillingInventory {
  static const List<AccessAdminRolesFinancialAtom> atoms =
      <AccessAdminRolesFinancialAtom>[
        AccessAdminRolesFinancialAtom(
          id: 'tab_navigate',
          label: 'Roles tab',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'search_filter_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'empty_error_retry',
          label: 'Empty / error / retry states',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'row_select_role_detail',
          label: 'Row select → role detail',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'create_role',
          label: 'Create role (primary + mutation dialog)',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'edit_role',
          label: 'Edit role (next-action + mutation dialog)',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'delete_role',
          label: 'Delete role (detail + confirm)',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'role_similarity_review',
          label: 'Similar-role review (create/edit)',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'role_permissions_display',
          label: 'Assigned permissions display (read-only detail)',
          financialClass: AccessAdminRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'sync_role_permissions',
          label: 'Sync role permissions (incl. billing:write grants)',
          financialClass: AccessAdminRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        AccessAdminRolesFinancialAtom(
          id: 'role_permissions_editor_dialog',
          label: 'Add / edit role permissions dialog',
          financialClass: AccessAdminRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
          mounted: false,
        ),
        AccessAdminRolesFinancialAtom(
          id: 'restore_role',
          label: 'Restore soft-deleted role',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminRolesFinancialAtom(
          id: 'permanent_delete_role',
          label: 'Permanent delete role',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminRolesFinancialAtom(
          id: 'realtime_role_list_sync',
          label: 'Realtime role list sync after mutation',
          financialClass: AccessAdminRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminRolesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminRolesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: AccessAdminRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<AccessAdminRolesFinancialAtom> get billableClasses => atoms
      .where(
        (AccessAdminRolesFinancialAtom atom) =>
            atom.financialClass == AccessAdminRolesFinancialClass.createCharge ||
            atom.financialClass == AccessAdminRolesFinancialClass.settle ||
            atom.financialClass == AccessAdminRolesFinancialClass.adjust ||
            atom.financialClass == AccessAdminRolesFinancialClass.reverse ||
            atom.financialClass == AccessAdminRolesFinancialClass.defer,
      );

  /// Mounted atoms only (excludes reserved/future financial paths).
  static Iterable<AccessAdminRolesFinancialAtom> get mountedAtoms =>
      atoms.where((AccessAdminRolesFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (AccessAdminRolesFinancialAtom atom) =>
        atom.financialClass == AccessAdminRolesFinancialClass.notRequired ||
        atom.financialClass == AccessAdminRolesFinancialClass.notBilled ||
        atom.financialClass == AccessAdminRolesFinancialClass.noCharge,
  );

  /// Write ∩ for role mutations; intersect with workspace `canWrite`.
  static bool canMutateRoles({
    required bool workspaceCanWrite,
    required bool policyAllowsWrite,
  }) {
    return policyAllowsWrite && workspaceCanWrite;
  }
}

/// Documents that role/permission changes do not alter historical Billing ledgers.
const String accessAdminRolesBillingScopeNote =
    'Role and permission assignment adjusts access only. Granting billing '
    'permissions must not mutate historical patient Billing ledgers; demo/seed '
    'financial data must use Billing factories, not orphan amounts on roles.';

/// True when every mounted Roles tab atom is explicitly not billable.
bool accessAdminRolesTabHasNoBillableActions() {
  return AccessAdminRolesBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      AccessAdminRolesBillingInventory.billableClasses.isEmpty;
}
