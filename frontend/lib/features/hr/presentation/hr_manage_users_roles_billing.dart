import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';

/// Financial action classes aligned with `prompts/billing-and-sections/_shared-rules.md`.
enum HrManageUsersRolesFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBilled,
  notRequired,
  noCharge,
}

/// One financially relevant atom on Manage users and roles (`access`).
class HrManageUsersRolesFinancialAtom {
  const HrManageUsersRolesFinancialAtom({
    required this.id,
    required this.label,
    required this.financialClass,
    required this.auditCode,
    this.mounted = true,
  });

  final String id;
  final String label;
  final HrManageUsersRolesFinancialClass financialClass;
  final String auditCode;
  final bool mounted;
}

/// Canonical inventory for `/hr?section=access` (Manage users and roles).
///
/// Scope: embedded access panel chrome, Staff/Roles/Permissions worklists,
/// user/role/permission detail dialogs, create/edit/assign/remove mutations,
/// and staff onboarding opened from Create staff. Patient/clinical revenue
/// stays on Billing. Staff compensation and consultation-fee catalog values
/// configured at onboarding are payroll/price setup — not patient ledger posts.
/// Granting `billing:*` rights is access metadata only.
abstract final class HrManageUsersRolesBillingInventory {
  static const List<HrManageUsersRolesFinancialAtom> atoms =
      <HrManageUsersRolesFinancialAtom>[
        HrManageUsersRolesFinancialAtom(
          id: 'tab_navigate',
          label: 'Manage users and roles tab',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'hr_activity',
          label: 'HR activity (workspace secondary, removed)',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
          mounted: false,
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'panel_toggle',
          label: 'Panel toggle (Staff / Roles / Permissions)',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'search_filter_columns_pagination_refresh',
          label: 'Search / filters / columns / pagination / Refresh',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'empty_error_retry_tenant_required',
          label: 'Empty / error / retry / tenant-required states',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'row_select_user_detail',
          label: 'Row select → user detail',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'row_select_role_detail',
          label: 'Row select → role detail',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'row_select_permission_detail',
          label: 'Row select → permission detail / edit',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'detail_close',
          label: 'Detail Close',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'create_staff_onboarding',
          label: 'Create staff (onboarding dialog)',
          financialClass: HrManageUsersRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'onboarding_compensation_catalog',
          label: 'Onboarding compensation rate (staff payroll catalog)',
          financialClass: HrManageUsersRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'onboarding_consultation_fee_catalog',
          label: 'Onboarding consultation fee (price catalog for later Billing)',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'create_role',
          label: 'Create role',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'create_permission',
          label: 'Create permission (incl. billing:* catalog codes)',
          financialClass: HrManageUsersRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'edit_user',
          label: 'Edit user / sync roles & direct permissions',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'edit_role',
          label: 'Edit role',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'edit_permission',
          label: 'Edit permission description',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'assign_role_permissions',
          label: 'Assign role permissions (incl. billing:* grants)',
          financialClass: HrManageUsersRolesFinancialClass.notBilled,
          auditCode: 'NOT_BILLED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'add_remove_user_role',
          label: 'Add / remove user role',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'add_remove_direct_permission',
          label: 'Add / remove direct permission',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'open_staff_profile',
          label: 'Open staff profile (navigate)',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'realtime_access_list_sync',
          label: 'Post-mutation access list reload',
          financialClass: HrManageUsersRolesFinancialClass.notRequired,
          auditCode: 'NOT_REQUIRED',
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'collect_payment',
          label: 'Collect payment / receive payment',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'issue_invoice_adjust_refund',
          label: 'Issue invoice / adjust / refund / reverse',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
        HrManageUsersRolesFinancialAtom(
          id: 'patient_charge_from_access',
          label: 'Create patient charge from access admin',
          financialClass: HrManageUsersRolesFinancialClass.noCharge,
          auditCode: 'NO_CHARGE',
          mounted: false,
        ),
      ];

  /// Atoms that would post to patient Billing if mounted without wiring.
  static Iterable<HrManageUsersRolesFinancialAtom> get billableClasses => atoms
      .where(
        (HrManageUsersRolesFinancialAtom atom) =>
            atom.financialClass ==
                HrManageUsersRolesFinancialClass.createCharge ||
            atom.financialClass == HrManageUsersRolesFinancialClass.settle ||
            atom.financialClass == HrManageUsersRolesFinancialClass.adjust ||
            atom.financialClass == HrManageUsersRolesFinancialClass.reverse ||
            atom.financialClass == HrManageUsersRolesFinancialClass.defer,
      );

  static Iterable<HrManageUsersRolesFinancialAtom> get mountedAtoms =>
      atoms.where((HrManageUsersRolesFinancialAtom atom) => atom.mounted);

  static bool get allMountedAtomsExplicitlyNotBillable => mountedAtoms.every(
    (HrManageUsersRolesFinancialAtom atom) =>
        atom.financialClass == HrManageUsersRolesFinancialClass.notRequired ||
        atom.financialClass == HrManageUsersRolesFinancialClass.notBilled ||
        atom.financialClass == HrManageUsersRolesFinancialClass.noCharge,
  );

  static bool canMutateAccess(AppAccessPolicy policy) {
    return canCreateHrAccess(policy) ||
        canUpdateHrAccess(policy) ||
        canDeleteHrAccess(policy);
  }
}

/// Documents ledger isolation for this tab.
const String hrManageUsersRolesBillingScopeNote =
    'Manage users and roles adjusts identity and RBAC only. Staff compensation '
    'and consultation-fee fields are payroll/price catalog (NOT_BILLED / '
    'NOT_REQUIRED); patient charges post later via Billing clinical-request '
    'paths. Granting billing permissions must not mutate historical patient '
    'Billing ledgers.';

/// True when every mounted atom is explicitly not billable to patient ledgers.
bool hrManageUsersRolesTabHasNoBillableActions() {
  return HrManageUsersRolesBillingInventory.allMountedAtomsExplicitlyNotBillable &&
      HrManageUsersRolesBillingInventory.billableClasses.isEmpty;
}
