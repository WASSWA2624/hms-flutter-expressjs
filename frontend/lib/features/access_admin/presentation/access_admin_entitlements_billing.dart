import 'package:hosspi_hms/features/access_admin/presentation/access_admin_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum AccessAdminEntitlementsFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on the Entitlements tab (`module-entitlements`).
class AccessAdminEntitlementsFinancialAtom {
  const AccessAdminEntitlementsFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final AccessAdminEntitlementsFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/admin/access?panel=entitlements`.
///
/// Scope: tab chrome, worklist, read-only detail dialog, and nested flows
/// opened from this tab. Patient/clinical revenue stays on Billing; SaaS
/// subscription invoices stay on the subscriptions path.
abstract final class AccessAdminEntitlementsBillingInventory {
  static const List<AccessAdminEntitlementsFinancialAtom> atoms =
      <AccessAdminEntitlementsFinancialAtom>[
        AccessAdminEntitlementsFinancialAtom(
          id: 'tab_navigate',
          label: 'Entitlements tab',
          financialClass: AccessAdminEntitlementsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'search_filter_columns_pagination',
          label: 'Search / filters / columns / pagination',
          financialClass: AccessAdminEntitlementsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'empty_error_retry',
          label: 'Empty / error / retry states',
          financialClass: AccessAdminEntitlementsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'row_select_detail',
          label: 'Row select → read-only entitlement detail',
          financialClass: AccessAdminEntitlementsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: AccessAdminEntitlementsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'plan_status_display',
          label: 'Plan / active / denial display (subscription metadata)',
          financialClass: AccessAdminEntitlementsFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'realtime_entitlement_sync',
          label: 'Realtime module-entitlement list sync',
          financialClass: AccessAdminEntitlementsFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'create_entitlement',
          label: 'Create entitlement',
          financialClass: AccessAdminEntitlementsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'update_entitlement',
          label: 'Update entitlement',
          financialClass: AccessAdminEntitlementsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'delete_entitlement',
          label: 'Delete entitlement',
          financialClass: AccessAdminEntitlementsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: AccessAdminEntitlementsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        AccessAdminEntitlementsFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: AccessAdminEntitlementsFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<AccessAdminEntitlementsFinancialAtom> get billableClasses =>
      atoms.where(
        (AccessAdminEntitlementsFinancialAtom atom) =>
            atom.financialClass == AccessAdminEntitlementsFinancialClass.createCharge ||
            atom.financialClass == AccessAdminEntitlementsFinancialClass.settle ||
            atom.financialClass == AccessAdminEntitlementsFinancialClass.adjust ||
            atom.financialClass == AccessAdminEntitlementsFinancialClass.reverse ||
            atom.financialClass == AccessAdminEntitlementsFinancialClass.defer,
      );

  /// Mounted atoms only (excludes reserved/future write paths).
  static Iterable<AccessAdminEntitlementsFinancialAtom> get mountedAtoms =>
      atoms.where((AccessAdminEntitlementsFinancialAtom atom) => atom.mounted);

  /// True when every mounted atom is explicitly not billable to patient ledgers.
  static bool get allMountedAtomsExplicitlyNotBillable =>
      mountedAtoms.every(
        (AccessAdminEntitlementsFinancialAtom atom) =>
            atom.financialClass == AccessAdminEntitlementsFinancialClass.notRequired ||
            atom.financialClass == AccessAdminEntitlementsFinancialClass.notBilled ||
            atom.financialClass == AccessAdminEntitlementsFinancialClass.noCharge,
      );

  /// Write ∩ reserved for future mutations; none mounted on this tab today.
  static bool canMutateEntitlementsCatalog({
    required bool workspaceCanWrite,
    required bool policyAllowsWrite,
  }) {
    return policyAllowsWrite && workspaceCanWrite;
  }
}

/// Documents that Entitlements write chrome is intentionally absent.
///
/// See [AccessAdminEntitlementsAtomPermissions] and workspace panel gate
/// (`isEntitlementsPanel ? false : …` for `canWrite`).
const String accessAdminEntitlementsBillingScopeNote =
    'Module entitlements catalog is read-only; subscription commercial '
    'billing uses the subscriptions invoice path and must not corrupt '
    'patient ledgers. Role/entitlement visibility changes here do not '
    'mutate historical Billing records.';
