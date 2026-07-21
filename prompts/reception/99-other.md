# Scope Setup Nav and Tab Workspace by Admin Level

Replace Guided setup on `/admin/setup` with role-scoped `AppTabStrip` tables, and rename the shell nav by admin level. Follow `prompts/.cursor/prompt.mdc`.

## Context

`TenantFacilitySetupPage` uses a locked Guided setup wizard plus manage dialogs. Nav always says Tenant setup. Admins differ by scope:

**Platform admin:** elevated/system access across tenants, facilities, and admins.
**Tenant admin:** one tenant and its facilities/structure/access.
**Facility admin:** one facility; no tenant catalog.

**Setup tabs:** Tenants, Branches, Facility, Departments, Units, Wards, Rooms, Beds, Roles, Permissions, Users—each an `AppListTable` reusing existing manage-list CRUD.

## Requirements

1. Shell nav label: Platform setup (platform), Tenant setup (tenant), Facility setup (facility); short label stays Setup when constrained.
2. Refactor the page to `AppTabStrip` with those Setup tabs; Guided setup stepper is not primary navigation.
3. Authorized tabs only: platform → Tenants + rest; tenant → Tenants (own tenant only) + rest; facility → omit Tenants, show Facility + rest.
4. Each tab hosts matching table/CRUD from existing manage flows; scope rows to caller tenant/facility; backend remains authoritative.
5. Preserve loading, empty, error, success, validation, busy, permission states; sync after mutations; omit unauthorized UI.

## Constraints

- Reuse setup page, manage dialogs/lists, access-admin roles/users where present, `AppTabStrip`, `AppListTable`, access policy, routes, localization, design-system; no parallel path.
- Do not invent permissions or change RBAC/ABAC contracts.
- Support themes and viewports.

## Acceptance Criteria

- R1: Nav label matches admin level.
- R2–R3: Tab workspace; unauthorized tabs and out-of-scope rows absent.
- R4–R5: Tables reuse existing CRUD; states/sync intact; unauthorized UI absent.
- Update setup/nav/access tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/`
- `frontend/lib/features/access_admin/`
- `frontend/lib/app/router/app_router.dart`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
