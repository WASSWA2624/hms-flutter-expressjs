# Instant UI Sync After Mutations — Performance Prompt

## Objective

Eliminate perceptible delay between frontend mutations (create/edit/delete via dialogs and quick actions) and the UI reflecting the new state. The dashboard and all workspaces must feel **instant**: summary cards, alerts, badges, queues, and lists update as soon as a mutation succeeds — not tens of seconds later.

---

## Problem (reproducible)

**Role:** Super Admin (platform scope)  
**Screen:** Home dashboard (`/`) — platform management profile

| Step | Action |
| ---- | ------ |
| 1 | Log in as Super Admin |
| 2 | On the dashboard, click **Create tenant** (Quick Actions) |
| 3 | Complete the create-tenant dialog and save |
| 4 | Observe the dashboard metric strip and Alerts panel |

**Observed (see attached screenshots):**

- **Tenants** card stays at `3 / 3` for ~30+ seconds, then updates to `4 / 4`
- **Alerts → Tenants Without Subscription** stays at `2`, then updates to `3`
- Other platform metrics (Facilities, Subscriptions, Entitlements) likely suffer the same lag after their respective quick actions

**Expected:** Metric cards, alerts, nav badges, and related lists update **immediately** (≤ 1 s perceived) after a successful save, without requiring navigation away or a manual refresh.

---

## Scope

This is an **app-wide** UX problem, not limited to the home dashboard. Apply the same instant-sync standard everywhere a user action mutates backend data and the UI must reflect it:

- Home dashboard (platform + tenant/facility profiles)
- Quick Actions and management dialogs (`create_tenant`, `create_facility`, `create_role`, `create_user`, etc.)
- Module workspaces (OPD, IPD, billing, HR, subscriptions, access admin, tenant/facility setup, …)
- Nav notification/workload badges

---

## Investigation starting points

Search the codebase for bottlenecks and gaps. Known areas to inspect:

| Area | Location | Suspected gap |
| ---- | -------- | ------------- |
| Post-mutation refresh | `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` — `homeRefreshDashboard`, `homeInvokeAction` | `ref.invalidate(homeControllerProvider)` runs on dialog close (`.then((_)`) regardless of success; full HTTP round-trip only |
| Dashboard realtime | `frontend/lib/features/home/presentation/controllers/home_controller.dart` | `_homeDashboardRealtimeEvents` has no tenant/platform/admin events |
| Realtime event catalog | `frontend/lib/core/realtime/realtime_events.dart`, `realtime_event_groups.dart` | No `tenant.created` / `tenant.updated` / platform-admin events |
| Backend fan-out | `backend/src/modules/tenant/`, `dashboard-workspace`, `dashboard-widget` | Tenant CRUD may not publish websocket events after mutation |
| Reference pattern (good) | `frontend/lib/core/workspace/workspace_sync_engine.dart`, `opd_realtime_delta_applier.dart` | OPD applies local deltas before HTTP fallback — dashboard lacks equivalent |
| Stale-while-revalidate | `frontend/lib/features/home/presentation/pages/home_page.dart` — `keepPreviousDataDuringRefresh: true` | May mask refresh in progress but can show stale counts until slow fetch completes |
| Platform metrics source | `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js`, `backend/src/lib/dashboard/summary.js` | Live Prisma counts for Super Admin — delay is likely frontend sync, not snapshot TTL |

---

## Required outcomes

### 1. Optimistic / immediate local updates

After a **successful** mutation, patch affected UI state locally before (or without waiting for) a full workspace reload:

- Increment/decrement dashboard metric cards (`tenants_active`, `subscriptions_active`, etc.)
- Update alert counts (`tenants_without_subscription`, …)
- Refresh only the affected provider slice — avoid blanket invalidation when a targeted patch suffices

Only refresh on mutation **success** (`saved == true`), not on cancel/dismiss.

### 2. Realtime propagation (multi-user + cross-widget)

For mutations that affect shared views:

- Emit websocket events from backend services on tenant, facility, role, user, and subscription CRUD
- Add matching entries to `RealtimeEvents` / `RealtimeEventGroups`
- Subscribe `homeControllerProvider` (and other affected controllers) to those events via `listenForRealtimeRefresh`

### 3. Fast HTTP fallback

When a full reload is unavoidable:

- Ensure `homeRefreshDashboard` / controller `invalidate` triggers an immediate fetch with no artificial debounce beyond existing 200 ms coalescing
- Profile and remove slow queries, redundant serial fetches, or blocking work in the mutation → refresh path
- Return mutation responses with enough summary deltas for the frontend to patch without a second heavy `GET /dashboard-workspace/workspace` when possible

### 4. Consistency with existing patterns

Reuse established infrastructure — do not invent parallel sync mechanisms:

- `listenForRealtimeRefresh` for event-driven invalidation
- `WorkspaceSyncEngine` + `RealtimeDelta` for local patching where applicable
- `homeRefreshDashboard(ref, request)` after successful modal actions
- Modal-first workflows per `frontend/.cursor/ui-patterns.mdc`

---

## Acceptance criteria

- [ ] Create tenant from dashboard Quick Actions → **Tenants** card and **Tenants Without Subscription** alert update within **1 second** of save success
- [ ] Same instant behavior for **Create facility**, **Create role**, and other platform quick actions on the Super Admin dashboard
- [ ] Cancelling a dialog does **not** trigger a dashboard reload
- [ ] A second browser/session sees the update via realtime within normal websocket latency
- [ ] No regressions to OPD/IPD/billing realtime sync (existing `WorkspaceSyncEngine` flows still pass tests)
- [ ] Responsive on mobile, tablet, and desktop — no layout shift during optimistic updates

---

## Quality gate

| Layer | Command |
| ----- | ------- |
| Frontend | `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` |
| Backend | Targeted `npm test` for touched modules (`tenant`, `dashboard-workspace`, `dashboard-widget`, realtime) |
| Manual | Reproduce the screenshot scenario on `127.0.0.1:5201` before and after — confirm sub-second update |

---

## Key files

```
frontend/lib/features/home/
frontend/lib/features/tenant_facility/
frontend/lib/features/access_admin/
frontend/lib/core/realtime/
frontend/lib/core/workspace/
backend/src/modules/tenant/
backend/src/modules/dashboard-workspace/
backend/src/modules/dashboard-widget/
backend/src/lib/dashboard/summary.js
prompts/07-home-dashboard-module-prompt.md
```
