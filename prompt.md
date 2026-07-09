# Fix Role & Permission Catalog — Load, Seed, and Assign

## Context

The **Create Role** dialog (`showRoleMutationDialog`) shows **0 of 0 permissions** (see screenshot). Bulk actions and grouped checkboxes render, but the catalog is empty, so role creation always fails validation: *"Select at least one permission for this role."*

**Current data flow**
- UI: `AppPermissionAssignmentPicker` ← `permissionLookups` from Access Admin workspace state
- API: `access-admin-workspace` → `findLookups()` → `prisma.permission.findMany({ where: { tenant_id } })`
- **Canonical source of truth (code):** `backend/src/config/permissions.js`
  - `PERMISSIONS` — stable keys (`patient:read`, `clinical:write`, `hr:read`, …)
  - `ROLE_PERMISSIONS` — system role templates (Doctor, Nurse, Lab Tech, HR, etc.)

**Gap:** The UI depends on **tenant-scoped DB rows** in `permission` / `role`, but those rows are not guaranteed to exist. Seeding (`seed-access-pack.js`) only inserts permissions referenced by demo roles — not the full catalog — and may not have run for the active tenant.

---

## Goal

Make the Create/Edit Role flow fully functional by ensuring the **full permission catalog** and **system roles** are available in the database (synced from `permissions.js`), while supporting **custom tenant roles** with flexible permission assignment.

---

## Requirements

### 1. Backend — sync catalog from `permissions.js`

- Add a **permission sync** step (seeder, startup hook, or admin endpoint) that upserts every value in `PERMISSIONS` into the `permission` table for each tenant.
  - Use `name` = permission key (e.g. `patient:read`).
  - Idempotent: safe to re-run; no duplicates per `(tenant_id, name)`.
- Seed **system roles** from `ROLE_PERMISSIONS` / `ROLES` (Doctor, Nurse, Lab Tech, Tenant Admin, etc.) with their default `role_permission` mappings.
  - Mark or distinguish system roles from custom roles if the schema supports it; otherwise document naming convention (e.g. uppercase codes).
- Ensure `findLookups()` returns the synced permissions for the resolved tenant scope.
- Add/update tests in `access-admin-workspace.service.test.js` verifying non-empty permission lookups after sync.

### 2. Backend — custom roles (dynamic)

- Keep roles in the `role` table (tenant-scoped) — **do not hardcode custom roles in code**.
- Create/update role endpoints must persist `name`, `description`, and `permission_ids` via `role_permission`.
- Authorization continues to use permission **keys** from `permissions.js`; DB stores tenant instances mapped to those keys.

### 3. Frontend — resilient permission loading

- In `access_admin_dialogs.dart` / `role_mutation_dialog.dart`, ensure `permissionLookups` is populated before opening Create Role (refresh lookups if empty).
- If lookups are still empty after refresh, show a **clear error banner** (e.g. *"Permission catalog not available for this tenant. Contact your administrator."*) instead of stacked empty states.
- Deduplicate status copy when catalog is empty — hide *"No permissions selected"* / *"No permissions match your search"* when `total == 0`.

### 4. Frontend — picker UX polish (`AppPermissionAssignmentPicker`)

- Keep grouped **checkbox** selection by module prefix (`patient`, `clinical`, `hr`, …).
- Replace text-link bulk actions with consistent controls:
  - **Global:** master checkbox or toggle for *Select all* / *Clear all* (in addition to or replacing secondary buttons).
  - **Per group:** tri-state group header checkbox (none · partial · all) with select/clear group behavior.
- Show meaningful summary: `{selected} of {total} selected` only when `total > 0`.
- Pre-check permissions in **edit** mode from existing `role_permission` data.
- Responsive layout: scrollable groups, touch-friendly on mobile, two-column groups on tablet/desktop.

### 5. Dialog polish

- Cancel button retains icon (`Icons.close_outlined`); Save retains save icon.
- `showRoleMutationDialog` remains the single reusable entry point for role create/edit across Access Admin (and HR where applicable).

---

## Data reference (`permissions.js`)

| Export | Purpose |
|--------|---------|
| `PERMISSIONS` | Full catalog (~60 keys across modules: profile, patient, clinical, lab, hr, mortuary, tenant/facility/system admin, …) |
| `ROLE_PERMISSIONS` | Default permission sets per system role |
| `ROLE_PERMISSION_TEMPLATES` | Alias roles inheriting from base roles |

All new permissions must be added to `permissions.js` first, then synced to DB.

---

## Acceptance criteria

- [ ] Create Role shows the full permission catalog (non-zero total) for a seeded tenant.
- [ ] User can select permissions via grouped checkboxes; global and per-group select/clear work.
- [ ] System roles (Doctor, Nurse, Lab Tech, etc.) exist in DB with correct default permissions.
- [ ] User can create a **custom role** with any combination of permissions; role is persisted and reusable.
- [ ] Edit role pre-selects assigned permissions.
- [ ] Empty catalog shows one actionable error state, not misleading "0 of 0" + search miss messages.
- [ ] No regressions in Access Admin role create/edit or authorization checks.

---

## Implementation notes

- Run permission sync via existing seeder pipeline (`seed-access-pack.js`) or dedicated script; re-run for dev tenants after deploy.
- No Prisma schema change expected unless adding `is_system` flag to `role` — only add migration if needed.
- Frontend labels: continue using `permissionCatalogLabelForCode()` for display names.

---

## Out of scope

- Renaming permission keys or changing ABAC middleware logic.
- Redesigning unrelated Access Admin panels.
