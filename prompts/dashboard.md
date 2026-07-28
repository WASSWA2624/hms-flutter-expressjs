# Permission-Based Home Dashboard

Make the home dashboard **permission-driven**: each KPI card, queue item, alert, activity row, chart section, quick action, and shortcut renders only when the signed-in user holds **all** permissions listed for that component in `Dashboard.md`. Roles may still choose a default profile layout; they must not be the sole visibility gate.

## Context

- Surface: `HomePage` → `_HomeDashboardContent` → `RoleDashboardScaffold` (`home_page.dart`, `role_dashboard_scaffold.dart`).
- Data: `homeControllerProvider` → `GET /dashboard-workspace/workspace`; fallbacks from `homeDashboardProfiles`.
- Gap: `HomeActionDefinition` already uses `requiredPermissions` + `grantsAll`, but status cards, queue/alerts/activity, charts, and shortcuts lack per-widget gates from `Dashboard.md`. Profiles are role-ranked; custom roles only pick via `homeProfileForPermissions`.
- Backend `SUMMARY_METADATA_BY_PACK` in `backend/src/lib/dashboard/summary.js` is pack-level; `home_dashboard_dtos.dart` ignores per-card `required_permissions`. Align both with `Dashboard.md` rows.
- Keys: `AppPermissions` / `backend/src/config/permissions.js`. Rule: `grantsAll`. Follow `prompts/.cursor/prompt.mdc` and `.cursor/access/permissions.mdc`.

## Requirements

1. **Declare permissions on every dashboard atom.** Give each visible atom `List<AppPermission> requiredPermissions` (greeting chrome may stay ungated; empty permission lists must not silently mean “public” for KPIs/queues):
   - `HomeStatusCardTemplate` / `HomeStatusCard`
   - Queue / results / follow-up / alert / activity (typed catalog by `id` if API-only)
   - Trend/distribution blocks (e.g. `reports:read` when `Dashboard.md` maps charts to reports)
   - Keep action gates; add `requiredPermissions` on `HomeShortcutDefinition` (not route-only).
2. **Map every `Dashboard.md` persona row to concrete ids** in `home_dashboard_profiles.dart` / workspace payloads. Cover the full catalog:
   - System admin: overview/tenants/users/health/activity → `system:admin`; subscriptions → `subscriptions:read`; integrations → `integration:read`; security alerts → `compliance:read` + `break_glass:review`; audit → `compliance:read`; reports → `reports:read`
   - Tenant admin: facilities → `tenant:admin`; patients → `patient:read`; revenue → `billing:read`; clinical → `clinical:read`; HR → `hr:read`; roster → `roster:read`; operations → `operations:read`; facility performance → `reports:read`; subscription → `subscriptions:read`; compliance → `compliance:read`
   - Facility admin: admissions/waiting/beds → `patient:read`; emergency queue → `emergency:read`; revenue → `billing:read`; pharmacy → `pharmacy:read`; lab → `lab:read`; HR attendance → `hr:read`; equipment → `biomed:read`; operations → `operations:read`; reports → `reports:read`
   - Doctor: assigned/appointments/waiting/critical/notes → `clinical:read`; lab-awaiting → `lab:read`; radiology → `radiology:read`; prescriptions → `pharmacy:read`; emergency → `emergency:read`; schedule → `roster:read`
   - Nurse: assigned/vitals/tasks → `clinical:read`; meds → `pharmacy:read`; transfers → `patient:read`; emergency → `emergency:read`; lab requests → `lab:read`; shift → `roster:read`
   - Lab: pending/samples/critical/completed → `lab:read`; results pending validation → `lab:write`; equipment alerts → `biomed:read`
   - Pharmacy: queue/low-stock/expiring/controlled/dispensed → `pharmacy:read`; pending dispensing → `pharmacy:write`; billing pending → `billing:read`
   - Reception: appointments/walk-in/waiting → `patient:read`; registrations/admissions → `patient:write`; payments → `billing:read`; emergency arrivals → `emergency:read`
   - Billing: revenue/outstanding/claims/events → `billing:read`; pending approvals → `financial:approve`; refunds → `billing:write`; revenue trend → `reports:read`
   - Operations: facility/maintenance/security/utilities/tasks → `operations:read`; daily KPIs → `reports:read`
   - HR: staff/attendance/vacancies/leave → `hr:read`; roster status → `roster:read`; roster approvals → `roster:approve`; department staffing → `unit:read`
   - Biomed: due/breakdown/schedule/calibration/by-dept → `biomed:read`; work orders → `biomed:write`
   - Housekeeping: cleaning/rooms/isolation/waste/supplies → `operations:read`
   - Ambulance: active/dispatch/calls/trips → `emergency:read`; vehicle maintenance → `operations:read`
   - Patient portal: appointments → `patient:read`; history → `clinical:read`; lab → `lab:read`; radiology → `radiology:read`; prescriptions → `pharmacy:read`; bills → `billing:read`; messages → `communications:read`; profile → `profile:read`
   Multi-permission rows require **all** keys. Add template ids only when a real route/data source exists; otherwise skip and comment the gap—do not fake metrics.
3. **Filter before render** via one shared helper beside `homeDashboardMetrics` / `homeDashboardPriorityData`:
   - Keep atoms only if `policy.grantsAll(requiredPermissions)`
   - Clear `RoleDashboardLayout` metric/priority/chart flags when filtered lists are empty
   - Apply to API cards and `fallbackStatusCards()`
   - Invoke from `_HomeDashboardContent` (and DTO/`mergeHomeDashboardForProfile` if needed to keep unauthorized ids out of state)
4. **Union across grants, not roles.** Clinical grants + `reports:read` show clinical widgets and reports UI without a new `AppRole`. Missing `billing:read` hides revenue KPIs only. Prefer filtering the permission-allowed **superset** over swapping whole role profiles when grants diverge from the ranked role.
5. **Parse backend metadata when present.** Map `required_permissions` from `status_strip` in `HomeStatusCardDto` and prefer them; else use the frontend catalog. Re-check with session `AppAccessPolicy`; backend stays authoritative for values.
6. **UI states.** Keep `AsyncStateScaffold` loading/error/retry. If every KPI/queue/alert/action/shortcut is filtered out, use existing empty workspace copy—no “access denied”. Success: only authorized atoms, live or fallback. No disabled/grey unauthorized tiles.
7. **Layout.** Collapse empty sections; no blank strips or duplicate headers. Responsive under `PageMaxWidth.dataHeavy`; theme tokens; light and dark.
8. **Deep links.** `homeMetricNavigation` / `homeMetricAction` must still pass `canAccessShellRoute` and card permissions; never navigate from a hidden card.
9. **Tests** in `frontend/test/features/home/` (assert by card/action **id**):
   - `clinical:read` + `lab:read` only → clinical/lab present; billing/pharmacy/radiology absent
   - `billing:read` without `financial:approve` → revenue/outstanding present; pending-approvals absent
   - Facility-admin pack minus `billing:read` → non-billing present; revenue absent
   - Clinical + `reports:read` → reports/trend surfaces when mapped
   - Actions/shortcuts: unauthorized ids absent; authorized remain

## Constraints

- Reuse `AppAccessPolicy`, `AppPermissions`, `AccessRequirement`/`AppAccessGate` only if a widget wrapper is clearer than list filtering; do not invent a second permission vocabulary.
- Do not ship separate `/dashboard-*` apps per persona in `Dashboard.md`.
- No disabled unauthorized controls; no routine “no access” banners for filtered widgets.
- Scope: home feature, shared dashboard widgets, home DTOs/mapper/actions, and home tests. Touch backend dashboard summary only if needed to emit per-card `required_permissions` consistent with `Dashboard.md`.
- Do not invent new clinical/billing modules solely to fill catalog rows.

## Acceptance Criteria

- Every implemented `Dashboard.md` component on home declares permissions matching that doc (all-of semantics).
- Missing any required permission ⇒ component absent from tree; holding all ⇒ component present when data/state allows.
- Extra `reports:read` (or equivalent mapped grant) surfaces the matching reports/performance UI without a new role.
- Revoking `billing:read` removes only billing/revenue atoms; other authorized atoms remain.
- Fallback and API paths both respect the same filter; unauthorized metric values never appear in loading→ready transitions.
- New/updated tests fail if unauthorized ids render and pass for the fixtures in requirement 9.
- Empty-after-filter, loading, and workspace-error states remain observable and non-leaking.

## Relevant Files

- `Dashboard.md`
- `frontend/lib/features/home/domain/entities/home_dashboard.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_scope.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_layout.dart`
- `frontend/lib/features/home/presentation/pages/home_page.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_mapper.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart`
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`
- `frontend/lib/features/home/data/dtos/home_dashboard_dtos.dart`
- `frontend/lib/shared/dashboard/`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/core/permissions/permission_providers.dart`
- `backend/src/lib/dashboard/summary.js`
- `frontend/test/features/home/`
- `.cursor/access/permissions.mdc`
