# Platform Admin Dashboard — Data Integrity & Sync Prompt

## Objective

Fix the **Super Admin platform dashboard** and its management dialogs so counts, lists, mutations, and deletes are accurate, consistent across frontend/backend/database, and update instantly via realtime sync.

**Observed issues (screenshots, `127.0.0.1:5201`):**

| Surface | Symptom |
| ------- | ------- |
| Platform dashboard | Summary cards (e.g. **4/4 Tenants**, **1 Facility**, **1/2 Subscriptions**, **0 Entitlements**) may not reflect actual records |
| Manage Tenants | List shows 4 tenants; **Delete** on *C-Care* or *Testing* returns **"Not found — The item is not available."** inside the delete modal |
| Manage Facilities | Only **1** facility listed while multiple tenants exist; tenants without a facility should not be possible |
| Manage Roles & Permissions | Brief **loading spinner + "No records"** together, then only **1** role; incomplete vs expected seed data |
| Manage Users | Pagination **1–12 / 18**; table should support larger page sizes (up to **100**) with smooth in-dialog scrolling |

**Source of truth:**

1. [app-write-up.mdc](.cursor/app-write-up.mdc) — platform admin scope, tenant/facility bootstrap
2. [prompts/07-home-dashboard-module-prompt.md](prompts/07-home-dashboard-module-prompt.md) — dashboard workspace
3. [prompts/03-tenant-facility-module-prompt.md](prompts/03-tenant-facility-module-prompt.md) — tenant/facility CRUD
4. [prompts/04-access-admin-module-prompt.md](prompts/04-access-admin-module-prompt.md) — users/roles admin
5. [prompts/02-subscriptions-module-prompt.md](prompts/02-subscriptions-module-prompt.md) — subscription health metrics

**Central rule:** platform admin surfaces are the control plane. Every count on the dashboard must match list APIs; every row action must use the same identifier the backend delete/update endpoints resolve; mutations must patch UI immediately and reconcile through `RealtimeEventGroups.platformAdmin`.

---

## Global Implementation Standards

Follow [prompts/00-global-implementation-standards.md](prompts/00-global-implementation-standards.md). Mandatory highlights for this work:

- [`instant_ui_sync.mdc`](frontend/.cursor/instant_ui_sync.mdc) — optimistic Riverpod patches + scoped realtime events; no full-page refetch when a local delta is correct
- [`realtime_sync.mdc`](frontend/.cursor/realtime_sync.mdc) — `RealtimeEventGroups.platformAdmin`, `WorkspaceSyncEngine`, reconnect coverage
- [`ui-patterns.mdc`](frontend/.cursor/ui-patterns.mdc) + [`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc) — `AppListTable` pagination, loading/empty/error states
- [`ui-feedback.mdc`](frontend/.cursor/ui-feedback.mdc) — never show contradictory loading + empty states
- Modal-first management dialogs; responsive on mobile, tablet, desktop

---

## Root-Cause Hypotheses (verify before fixing)

1. **Delete 404 on users/roles** — access-admin list serializes **human-friendly IDs** (`USR-…`, `ROLE-…`) but `DELETE /users/:id` and `DELETE /roles/:id` resolve **UUID only** (tenant/facility already use `resolveEntityId`).
2. **Delete 404 on tenants** — list `id` may be stale, slug/UUID mismatch, or optimistic/local list out of sync with backend soft-delete state.
3. **Dashboard metric drift** — `GET /dashboard-workspace/workspace` super-admin metrics (`summary.js`) not reconciled after CRUD or realtime events; optimistic patches incomplete for facilities/subscriptions/entitlements.
4. **Missing default facility** — tenant creation does not enforce a default facility; facility count lags tenant count.
5. **Under-sized list pages** — platform management dialogs hard-code `pageSize = 12`; user expects up to `AppPageRequest.maxPageSize` (**100**) with scrollable table body.
6. **Incomplete realtime on manage dialogs** — tenants/facilities have `PlatformManagementListSync`; users/roles manage dialogs do not.

---

## Scope — Required Changes

### 1. Identifier & delete consistency

- Align list DTOs, detail views, and delete/update calls on a single resolvable identifier per entity.
- Backend: extend `user.service` / `role.service` delete (and update where needed) to use `resolveEntityId` like tenant/facility.
- Frontend: pass UUID for mutations when available; never send display ID to endpoints that expect UUID unless backend resolves both.
- `AppConfirmActionDialog`: on 404, distinguish stale list row (remove locally + refresh) from genuine not-found; do not leave error banner stacked with confirmation after successful retry.

### 2. Dashboard metric accuracy

- Ensure super-admin cards (`tenants_active`, `facilities_active`, `subscriptions_health`, `module_entitlement_issues`) match:
  - Manage Tenants / Facilities / Users / Roles list totals
  - Backend `dashboard-workspace` raw metrics
- Extend `HomeDashboardOptimisticPatch` and `home_dashboard_sync.dart` to cover facility create/delete, subscription changes, and entitlement issues — not only tenant active/deleted.
- Invalidate or patch `homeControllerProvider` after every platform management mutation.

### 3. Default facility on tenant creation

- On tenant create (registration bootstrap and **Create tenant** dialog), auto-provision a **default facility** (e.g. `{tenantName} Main Facility`) unless the user explicitly adds one in the same flow.
- Backend transaction: tenant + default facility + audit + realtime events atomically.
- Backfill script or migration hook for existing tenants missing a facility (seed/demo data included).

### 4. Management list UX (global for platform admin dialogs)

Apply consistently to **Manage Tenants**, **Manage Facilities**, **Manage Roles & Permissions**, and **Manage Users**:

| Setting | Current | Target |
| ------- | ------- | ------ |
| Page size | `12` | `AppPageRequest.maxPageSize` (**100**) or shared `platformAdminListPageSize` constant |
| Table body | Fixed height, paginate only | Bounded `Expanded` + vertical scroll within dialog; pagination footer pinned |
| Loading vs empty | Can overlap | Show spinner **or** empty state, never both |
| Search | Server-side debounced | Preserve; reset to page 0 on query change |

Reuse `AppListTable` patterns from [`ui-patterns.mdc`](frontend/.cursor/ui-patterns.mdc); do not fork table behavior per dialog.

### 5. Realtime & instant UI on all manage dialogs

- Wire `PlatformManagementListSync` (or access-admin equivalent) for users and roles manage dialogs.
- Subscribe to `RealtimeEventGroups.platformAdmin` events: `tenantCreated/Updated/Deleted`, `facilityCreated/Updated/Deleted`, user/role lifecycle events.
- After delete success: remove row locally, patch dashboard cards, publish/consume realtime — same pattern as tenant delete in `tenant_facility_management_dialogs.dart`.

---

## Current State (read before changing code)

| Area | Location | Notes |
| ---- | -------- | ----- |
| Dashboard UI | `frontend/lib/features/home/` | `home_page.dart`, `home_dashboard_profiles.dart`, `home_dashboard_mapper.dart` |
| Dashboard sync | `home_dashboard_sync.dart`, `home_dashboard_optimistic_patch.dart` | Tenant-focused patches today |
| Manage Tenants/Facilities | `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart` | `pageSize = 12`, tenant realtime sync |
| Manage Users/Roles | `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart` | Friendly ID delete bug |
| Delete modal | `frontend/lib/shared/actions/app_action_dialogs.dart` | `AppConfirmActionDialog` → `errorNotFoundMessage` |
| Pagination | `frontend/lib/shared/data/app_pagination.dart` | `maxPageSize = 100` |
| List table | `frontend/lib/shared/components/app_list_table.dart` | Scroll + pagination footer |
| Realtime group | `frontend/lib/core/realtime/realtime_event_groups.dart` | `platformAdmin` |
| Backend dashboard | `backend/src/modules/dashboard-workspace/`, `backend/src/lib/dashboard/summary.js` | Super-admin metric definitions |
| Backend CRUD | `backend/src/modules/tenant/`, `facility/`, `user/`, `role/` | Tenant/facility use `resolveEntityId` |
| Access-admin API | `backend/src/modules/access-admin-workspace/` | Serializes `human_friendly_id` as `id` |

---

## Acceptance Criteria

- [ ] Platform dashboard cards match live list totals after create/edit/delete without manual refresh.
- [ ] Delete tenant, facility, user, and role from manage dialogs succeeds for every visible row; no false **"Not found"** errors.
- [ ] New tenant always has at least one default facility; facility count ≥ active tenant count (excluding explicitly deactivated).
- [ ] Manage dialogs load up to **100** rows per page; table body scrolls inside the modal on all breakpoints.
- [ ] Loading spinner and empty state are mutually exclusive.
- [ ] Realtime events from another session update lists and dashboard cards within seconds.
- [ ] Optimistic UI patches reconcile correctly on reconnect (`WorkspaceSyncEngine`).
- [ ] All user-visible strings localized in `app_en.arb`; destructive deletes use `destructive: true` on confirm dialogs.

---

## Quality Gate

From `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` (touched modules):

```sh
npm test -- --testPathPattern="tenant|facility|user|role|dashboard-workspace|access-admin"
```

Add targeted widget tests for delete-id resolution and dashboard metric reconciliation after CRUD.

---

## Key File References

```
frontend/lib/features/home/
frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart
frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart
frontend/lib/shared/actions/app_action_dialogs.dart
frontend/lib/shared/data/app_pagination.dart
frontend/lib/shared/components/app_list_table.dart
frontend/lib/shared/management/platform_management_list_sync.dart
frontend/lib/core/realtime/realtime_event_groups.dart

backend/src/modules/dashboard-workspace/
backend/src/lib/dashboard/summary.js
backend/src/modules/tenant/
backend/src/modules/facility/
backend/src/modules/user/
backend/src/modules/role/
backend/src/modules/access-admin-workspace/
```

**Related prompts:** [07-home-dashboard](prompts/07-home-dashboard-module-prompt.md), [03-tenant-facility](prompts/03-tenant-facility-module-prompt.md), [04-access-admin](prompts/04-access-admin-module-prompt.md), [02-subscriptions](prompts/02-subscriptions-module-prompt.md), [33-demo-seed](prompts/33-demo-seed-module-prompt.md)
