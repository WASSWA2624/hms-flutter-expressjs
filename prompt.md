# Platform Tenant Lifecycle — Implementation Prompt

## Objective

Fix **Super Admin tenant lifecycle** so dashboard metrics, Manage Tenants, and the database stay in sync. Super admins must see **active tenants only** on the dashboard, and **all tenants (active + soft-deleted)** in Manage Tenants—with clear status, **Restore**, and **Permanent delete** actions.

**Observed state (screenshots + `hms_db.tenant`):**

| Surface | Current | Expected |
|--------|---------|----------|
| Dashboard tenant card | Drifts between **3/3** and **2/2** | **2 / 2** (active only: Demo Care, Fairbanks) |
| Manage Tenants list | Shows **C-Care** with active tenants | **5 rows** with a **Deleted** column; C-Care + 2× Testing marked deleted |
| DB | 5 rows; 3 have `deleted_at` set (`slug` suffixed `__deleted__<id>`) | Unchanged soft-delete model; UI reflects truth |
| Delete on stale row | **Not found** modal for already-deleted tenant | Idempotent soft delete or row removed; no false error |

Subscriptions (**1 / 2**) and **Tenants Without Subscription: 1** are correct for 2 active tenants—do not regress.

---

## Global Implementation Standards

Follow [`prompts/00-global-implementation-standards.md`](./prompts/00-global-implementation-standards.md) and:

- [`backend/.cursor/prisma.mdc`](./backend/.cursor/prisma.mdc) — soft delete via `deleted_at`; repositories filter by default
- [`backend/.cursor/module-creation.mdc`](./backend/.cursor/module-creation.mdc) — service → repository; audit on every mutation
- [`frontend/.cursor/instant_ui_sync.mdc`](./frontend/.cursor/instant_ui_sync.mdc) — optimistic patch + realtime reconcile; no stale counts
- [`frontend/.cursor/realtime_sync.mdc`](./frontend/.cursor/realtime_sync.mdc) — `RealtimeEventGroups.platformAdmin`
- [`frontend/.cursor/scope.mdc`](./frontend/.cursor/scope.mdc) — Super Admin platform scope only
- [`backend/.cursor/websockets.mdc`](./backend/.cursor/websockets.mdc) — publish scoped platform events

---

## Required Behavior

### Dashboard (Super Admin)

- Count **only** tenants where `deleted_at IS NULL`.
- Never include soft-deleted tenants in totals, charts, or alerts.
- After manage-dialog mutations, clear optimistic dashboard patches and refetch server metrics.

### Manage Tenants dialog

- List **all** tenants for Super Admin (`include_deleted=true` or dedicated query).
- Columns: `#`, name, slug, **Status** (Active / Deleted), actions.
- **Active row actions:** Edit, Soft delete (existing).
- **Deleted row actions:** **Restore**, **Permanent delete** (destructive confirm).
- Soft-deleted rows: visually distinct (muted row or badge); Edit disabled or read-only.
- Pagination/search must include deleted rows; default sort: active first, then name.
- No contradictory loading + empty states; `pageSize` per `platform_admin_list_config.dart`.

### Backend API (`/api/v1/tenants`)

| Action | Behavior |
|--------|----------|
| `GET /` | Query `include_deleted` (Super Admin only). Default `false` for dashboard consumers. |
| `DELETE /:id` | Soft delete (existing). **Idempotent** if already soft-deleted (`deleted_at` set). |
| `POST /:id/restore` | Clear `deleted_at`; restore original slug when safe; audit + realtime event. |
| `DELETE /:id/permanent` | Hard delete tenant graph (tenant, facilities, scoped data per FK/cascade rules) or documented cascade service; Super Admin only; audit before purge. |

- Resolve IDs by UUID, `human_friendly_id`, and slug (including deleted slug suffix).
- API `id` remains UUID; expose `display_id` separately (do not replace `id`).
- Publish `tenant.deleted`, `tenant.restored`, `tenant.permanently_deleted` (or extend existing platform events).

### Permanent delete safeguards

- Second confirmation with tenant name typed or explicit “PERMANENT DELETE” label.
- Block if active subscriptions or legal retention rules apply (return validation error with reason).
- Log audit entry **before** destructive purge.

---

## Scope — Files to Touch

**Backend:** `tenant.service.js`, `tenant.repository.js`, `tenant.routes.js`, `tenant.controller.js`, validation schemas, `resolve-entity-id.js` (include-deleted lookups), platform realtime publishers, targeted tests.

**Frontend:** `tenant_facility_management_dialogs.dart`, `tenant_facility_repository_impl.dart`, DTOs/entities, `home_controller.dart`, `home_dashboard_sync.dart`, `home_dashboard_optimistic_patch.dart`, `app_en.arb` strings.

**Out of scope:** Non–Super Admin tenant lists; subscription billing changes beyond metric accuracy.

---

## Acceptance Criteria

- [ ] Dashboard shows **2 / 2** tenants matching DB active count (Demo Care, Fairbanks).
- [ ] Manage Tenants shows **5** rows with correct **Deleted** status for C-Care and both Testing records.
- [ ] Soft delete removes tenant from dashboard immediately; row remains in manage list as Deleted.
- [ ] **Restore** clears `deleted_at`, restores slug, row returns to Active; dashboard increments.
- [ ] **Permanent delete** removes tenant from DB and manage list; irreversible after confirm.
- [ ] Delete on already-deleted tenant succeeds (idempotent) or row disappears—no **Not found** error for visible stale data.
- [ ] Realtime/optimistic updates keep dashboard cards and manage list aligned without full-page reload.
- [ ] Responsive UI on mobile, tablet, desktop; localized strings; destructive actions use `AppConfirmActionDialog`.
- [ ] Backend tenant tests + `flutter analyze` on touched files pass.

---

## Verification

1. Compare phpMyAdmin `tenant` table (`deleted_at`, `slug`) with Manage Tenants and dashboard cards.
2. Soft delete → restore → permanent delete on a test tenant end-to-end.
3. Hard refresh / hot restart after deploy; confirm C-Care does not appear as active anywhere.
