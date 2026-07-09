# Fix: Super Admin Create Role — tenant picker and permissions blocked

## Problem

From the **Dashboard → Create role** quick action (also reproducible in Access Admin), the **Create Role** dialog opens but is unusable:

1. **Orange banner:** “Tenant context required” — “Unable to load tenants. Check your connection and try again.”
2. **Blue banner:** “Select a tenant” — “Choose a tenant above to load the available permissions for that organization.”
3. **No tenant dropdown** is rendered (tenant list is empty), so role name, description, and permissions remain disabled.

Role creation is blocked end-to-end.

## Context

| Item | Value |
|------|-------|
| Environment | Local dev — `http://127.0.0.1:5201` |
| User | **Platform Demo** (`super.admin@hosspi.com`) |
| Roles | Super Admin, Administrator |
| Dashboard | Shows **3 / 3 Tenants** — data exists; Create role flow does not surface it |

## Expected behavior

Super Admin / Platform Admin users operate **across tenants** and must be able to create roles without a pre-bound session tenant:

1. **Tenant selection** — Show a searchable tenant picker populated with all accessible tenants (same data the dashboard already displays).
2. **Optional facility scope** — When a role is tenant- or facility-scoped, allow selecting the target facility after tenant selection.
3. **Permission catalog** — After tenant selection, load permissions from the database (auto-sync via `ensureTenantAccessCatalog` if missing), and render them in `AppPermissionAssignmentPicker` with search, module grouping, and bulk select.
4. **Progressive enablement** — Enable name/description fields once a tenant is selected; enable Save when name + ≥1 permission + tenant are set.
5. **No dead-ends** — Replace empty-state banners with actionable UI (picker, retry, or clear guidance). Do not require the Super Admin’s own session tenant.

## Likely causes (investigate)

- `_loadAccessAdminTenantOptions` calls `getReferenceData()` without `tenantId`; API failure or empty `tenants` array is swallowed (`failure: (_) => []`).
- Backend `getReferenceData` for Super Admin in `tenant_context_required` state should return tenants via `findLookups(null, includeAllTenants: true)` but may not be reached or may return an empty list.
- Dashboard entry (`showAccessAdminCreateRoleDialog`) may bootstrap workspace state that lacks tenant lookups before opening the dialog.
- Permissions are tenant-scoped; they must reload when the tenant picker changes (`loadPermissionsForTenant` in `role_mutation_dialog.dart`).

## Tasks

1. **Reproduce** as Super Admin: Dashboard → Create role. Inspect `GET /access-admin-workspace/reference-data` (status, `tenants` length, `permissions` length).
2. **Fix tenant loading** so Super Admin always receives a populated tenant list when no tenant is pre-selected.
3. **Fix permission loading** — sync catalog for the selected tenant, reload on tenant change, surface API errors with retry instead of silent empty arrays.
4. **Align UX** with **Create facility** (`requireTenantPicker: true` pattern in `home_dashboard_actions.dart`).
5. **Verify** tenant/facility admins are unaffected; update/add tests for Super Admin + tenant picker + permission reload.

## Key files

| Layer | Path |
|-------|------|
| Role dialog UI | `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart` |
| Dialog orchestration | `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart` |
| Dashboard entry | `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` |
| Permission picker | `frontend/lib/shared/components/app_permission_assignment_picker.dart` |
| Reference-data API | `backend/src/modules/access-admin-workspace/services/access-admin-workspace.service.js` |
| Catalog sync | `backend/src/lib/authorization/permission-catalog-sync.js` |
| Canonical permissions | `backend/src/config/permissions.js` |

## Acceptance criteria

- [ ] Super Admin sees a populated, searchable tenant picker when opening Create role from the dashboard.
- [ ] Selecting a tenant loads and displays the full permission catalog (searchable, grouped).
- [ ] Role saves successfully with name, tenant, and selected permissions.
- [ ] No “Unable to load tenants” or “Select a tenant above” dead-end when tenants exist in the system.
- [ ] Tests cover Super Admin create-role flow with tenant selection and permission reload.
