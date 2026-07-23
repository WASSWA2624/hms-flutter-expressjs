# Tenant-scoped Tenants tab on `/admin/setup`

Show own-tenant detail/edit for scoped managers; keep full list CRUD for platform creators.

## Context

- Surface: Tenants desk tab (`ManageTenantsPanel` on `/admin/setup`).
- Platform creator: `canCreateTenant()` (elevated / `system:admin`).
- Scoped manager: `canManageTenant()` and not `canCreateTenant()`.
- Add is create-gated; scoped users still see the multi-tenant table.

## Requirements

1. If `canCreateTenant()`, keep the tenants table with Add, Edit, Delete, Restore, permanent delete, filter, settings, and row to Tenant details.
2. If scoped manager, do not render the table, Add, delete/restore/permanent-delete, or multi-tenant search/filter chrome.
3. For scoped managers, show the session tenant profile inline using existing Tenant details summary and tenant form/API fields.
4. Allow scoped edit via the existing edit-tenant form; omit create and delete.
5. Handle loading, empty (missing session tenant), error with Try again, validation, and success; refresh setup consumers after save.
6. Do not render unauthorized create/list/delete controls; backend RBAC stays authoritative.
7. Add tests: creators see table+Add; scoped see detail+Edit only; unauthorized actions absent.

## Constraints

- Reuse `canCreateTenant` / `canManageTenant`, tenant form, details summary, routes, and design-system components. No fields beyond the tenant contract. No unrelated refactors. Responsive; theme tokens for light/dark.

## Acceptance Criteria

- Creators retain full list CRUD (Req 1).
- Scoped managers get own-tenant details and edit only (Req 2-4).
- UI states and post-edit sync work; unauthorized chrome absent (Req 5-6).
- Tests prove both modes (Req 7).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/test/features/tenant_facility/`
