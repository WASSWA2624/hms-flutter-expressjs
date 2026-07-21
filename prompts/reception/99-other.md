# Scope Setup Nav and Tab Workspace by Admin Level

Replace Guided setup on `/admin/setup` with role-scoped `AppTabStrip` tables; rename shell nav by admin level. Follow `prompts/.cursor/prompt.mdc`.

## Context

`TenantFacilitySetupPage` uses locked Guided setup plus manage dialogs. Nav says Tenant setup.

**Platform admin:** elevated access across tenants, facilities, admins.
**Tenant admin:** one tenant and its facilities/structure/access.
**Facility admin:** one facility; no tenant catalog.

**Setup tabs:** Tenants, Branches, Facility, Departments, Units, Wards, Rooms, Beds, Roles, Permissions, Users—each an `AppListTable` from existing CRUD.

## Requirements

1. Shell nav: Platform / Tenant / Facility setup by admin level; short label stays Setup when constrained.
2. Refactor page to `AppTabStrip` with those tabs; Guided setup is not primary.
3. Authorized tabs only: platform → Tenants + rest; tenant → Tenants (own only) + rest; facility → omit Tenants, show Facility + rest.
4. Each tab hosts matching table/CRUD from existing manage flows; scope to caller tenant/facility; backend authoritative.
5. Preserve loading, empty, error, success, validation, busy, permission states; sync after mutations; omit unauthorized UI.

## Constraints

- Reuse setup page, manage lists/dialogs, access-admin roles/users, `AppTabStrip`, `AppListTable`, access policy, routes, l10n, design-system; no parallel path.
- Do not invent permissions or change RBAC/ABAC.
- Support themes and viewports.

## Acceptance Criteria

- R1: Nav label matches admin level.
- R2–R3: Tab workspace; unauthorized tabs/rows absent.
- R4–R5: Existing CRUD reused; states/sync intact; unauthorized UI absent.
- Update setup tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/`
- `frontend/lib/features/access_admin/`
- `frontend/lib/app/router/app_router.dart`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
