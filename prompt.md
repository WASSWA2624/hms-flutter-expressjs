# Fix: Super Admin cannot load permissions when creating a role

## Problem

On **Create Role** (`Access Admin`), the Permissions section shows:

> **Permission catalog unavailable**  
> Permissions could not be loaded for this tenant. Contact your administrator or try again after refreshing.

This blocks role creation entirely — Save is disabled because no permissions can be selected.

## Observed context

| Item | Value |
|------|-------|
| Environment | Local dev — `http://127.0.0.1:5201` |
| User | **Platform Demo** (`super.admin@hosspi.com`) |
| Role | **Platform Administrator** — badges: Super Admin, Administrator |
| Entry point | Dashboard quick action **Create role** (also reproducible from Access Admin workspace) |
| UI state | Role name / description fields render; **no tenant selector** is visible; permissions picker is replaced by the error banner |

## Expected behavior

1. **Super Admin** users must be able to create roles and assign the full canonical permission catalog, regardless of their own session tenant.
2. When no tenant context is selected, the dialog should **require a tenant picker** (same pattern as **Create facility** with `requireTenantPicker: true`).
3. After a tenant is selected, permissions for that tenant should load and display in `AppPermissionAssignmentPicker`.
4. If the tenant’s permission catalog is missing in the database, the backend should **auto-sync** it (`ensureTenantAccessCatalog`) before returning reference data.
5. Save should succeed once name + at least one permission + tenant are provided.

## Likely root cause (investigate)

Permissions are **tenant-scoped** in the DB. The create-role flow loads lookups once via `getReferenceData(tenantId)`:

- **Frontend:** `openAccessAdminCreateRoleDialog` → `_loadAccessAdminPermissionLookups` → `role_mutation_dialog.dart` shows the error when `permissionLookups` is empty.
- **Backend:** `access-admin-workspace.service.js` → `getReferenceData` → `resolveWorkspaceScope` → `maybeSyncTenantAccessCatalog` → `findLookups`.
- Super Admin scope resolution (`tenant-facility-workspace.repository.js`) requires a `tenant_id`; if the session carries one implicitly, the tenant picker is skipped but that tenant may have an **empty or unsynced** permission catalog.
- Permissions are **not reloaded** when the tenant picker value changes in `role_mutation_dialog.dart`.

## Tasks

1. **Reproduce** as Super Admin from Dashboard → Create role. Capture the `/access-admin-workspace/reference-data` request/response (tenantId param, permissions array length, HTTP status).
2. **Diagnose** why `permissionLookups` is empty:
   - Missing / failed catalog sync for the resolved tenant?
   - Wrong tenant resolved from session vs. query?
   - API error swallowed in `_loadAccessAdminPermissionLookups` (`failure: (_) => []`)?
3. **Fix backend** if needed: ensure `ensureTenantAccessCatalog` runs reliably for the resolved tenant and returns the full catalog from `backend/src/config/permissions.js`.
4. **Fix frontend UX** for Super Admin:
   - Always show tenant picker when user is Super Admin and no explicit tenant is chosen.
   - Reload permission lookups when tenant selection changes.
   - Replace the generic “catalog unavailable” dead-end with a retry action or clearer message (e.g. “Select a tenant to load permissions”).
5. **Verify** end-to-end: Super Admin can create a role with permissions for any tenant; tenant/facility admins are unaffected.

## Key files

| Layer | Path |
|-------|------|
| UI dialog | `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart` |
| Dialog orchestration | `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart` |
| Dashboard entry | `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` |
| Reference-data API | `backend/src/modules/access-admin-workspace/services/access-admin-workspace.service.js` |
| Catalog sync | `backend/src/lib/authorization/permission-catalog-sync.js` |
| Canonical permissions | `backend/src/config/permissions.js` |
| Scope resolution | `backend/src/modules/tenant-facility-workspace/repositories/tenant-facility-workspace.repository.js` |

## Acceptance criteria

- [ ] Super Admin sees a tenant selector (when no tenant is pre-selected) and a populated permission list after selection.
- [ ] No “Permission catalog unavailable” error under normal dev data / after catalog sync.
- [ ] Role creation saves successfully with selected permissions.
- [ ] Existing tests updated; add coverage for Super Admin + tenant picker + permission reload if missing.
