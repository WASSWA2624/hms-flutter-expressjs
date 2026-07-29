/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum AccessAdminPermissionsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Permissions tab (`permissions`).
class AccessAdminPermissionsFinancialAtom {
  const AccessAdminPermissionsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final AccessAdminPermissionsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/admin/access?panel=permissions`.
///
/// Scope: tab chrome, worklist, read-only catalog detail dialog, and nested
/// flows opened from this tab. Permission catalog rows (including `billing:*`
/// codes) are metadata only — they must not mutate patient Billing ledgers.
/// Role/permission assignment that grants billing access lives on the Roles tab.
abstract final class AccessAdminPermissionsBillingInventory {
  static const List<AccessAdminPermissionsFinancialAtom> atoms =
      <AccessAdminPermissionsFinancialAtom>[
        AccessAdminPermissionsFinancialAtom(
          id: 'tab_navigate',
          label: 'Permissions tab',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'search_filter_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'empty_error_retry',
          label: 'Empty / error / retry states',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'row_select_catalog_detail',
          label: 'Row select → read-only permission detail',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'billing_permission_catalog_display',
          label: 'billing:* permission catalog row (e.g. billing:write)',
          financialClass: AccessAdminPermissionsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'permission_description_panel',
          label: 'Permission description detail panel',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'read_only_badge',
          label: 'Read-only catalog badge',
          financialClass: AccessAdminPermissionsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'realtime_permission_list_sync',
          label: 'Realtime permission catalog list sync',
          financialClass: AccessAdminPermissionsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'create_permission',
          label: 'Create permission',
          financialClass: AccessAdminPermissionsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'update_permission',
          label: 'Update permission',
          financialClass: AccessAdminPermissionsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'delete_permission',
          label: 'Delete permission',
          financialClass: AccessAdminPermissionsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: AccessAdminPermissionsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminPermissionsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: AccessAdminPermissionsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<AccessAdminPermissionsFinancialAtom> get billableClasses =>
      atoms.where(
        (AccessAdminPermissionsFinancialAtom atom) =>
            atom.financialClass ==
                AccessAdminPermissionsFinancialClass.createCharge ||
            atom.financialClass == AccessAdminPermissionsFinancialClass.settle ||
            atom.financialClass == AccessAdminPermissionsFinancialClass.adjust ||
            atom.financialClass ==
                AccessAdminPermissionsFinancialClass.reverse ||
            atom.financialClass == AccessAdminPermissionsFinancialClass.defer,
      );

  /// Mounted atoms only (excludes reserved/future write paths).
  static Iterable<AccessAdminPermissionsFinancialAtom> get mountedAtoms =>
      atoms.where((AccessAdminPermissionsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (AccessAdminPermissionsFinancialAtom atom) =>
        atom.financialClass ==
            AccessAdminPermissionsFinancialClass.notRequired ||
        atom.financialClass == AccessAdminPermissionsFinancialClass.notBilled ||
        atom.financialClass == AccessAdminPermissionsFinancialClass.noCharge,
  );

  /// Write ∩ reserved for future mutations; none mounted on this tab today.
  static bool canMutatePermissionsCatalog({
    required bool workspaceCanWrite,
    required bool policyAllowsWrite,
  }) {
    return policyAllowsWrite && workspaceCanWrite;
  }
}

/// Documents that Permissions catalog is read-only; billing permission rows are metadata.
const String accessAdminPermissionsBillingScopeNote =
    'Permission catalog is read-only metadata. Rows such as billing:write '
    'describe access rights only and must not mutate historical patient Billing '
    'ledgers. Role permission assignment that grants billing access lives on '
    'the Roles tab; demo/seed financial data must use Billing factories.';
