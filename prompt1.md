# Task: HR Workforce Dashboard — informative, clickable, action-free landing

## Goal

Redesign the **Workforce dashboard** (home landing for `AppRole.hr`) so HR managers get a **read-only operational snapshot** at a glance: KPI figures, charts, queue preview, alerts, and activity — with **no mutation shortcuts** on the dashboard itself. Every metric and chart segment should **deep-link** into the HR workspace (`/hr`) or Reports with the correct pre-filter, not open create/edit dialogs from home.

Mutations (add staff, approve leave, publish roster, etc.) stay in **`/hr`** — staff directory, work queues, and staff-detail modals.

**Prerequisite:** HR workspace at `/hr` is functional ([prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md)).

## Context

The HR dashboard is not a separate route. It is the **role-specific home profile** rendered by the shared home feature.

| Area | Current implementation |
| --- | --- |
| Page shell | `frontend/lib/features/home/presentation/pages/home_page.dart` — `_HomeDashboardContent`, `_HomeHeroPanel`, `_HomeStatusStrip`, `_HomeQuickActions`, `_HomeMainGrid` |
| HR profile config | `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` — `AppRole.hr` profile (`homeTitle: 'Workforce dashboard'`, 6 status cards, 7 quick actions, 2 shortcuts) |
| Data | `GET /dashboard-workspace/workspace` via `home_repository_impl.dart`; HR metrics assembled in `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js` (`ROLE_PACKS.HR`) and card templates in `backend/src/lib/dashboard/summary.js` |
| HR deep links | `/hr?queue=LEAVE_REQUESTS`, `?queue=ROSTER_DRAFTS`, `?queue=UNASSIGNED_SHIFTS`, `?queue=PAYROLL_DRAFTS`, etc. — see `hr_workspace_page.dart` / `HrQueue` enum |
| Design refs | `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`, [prompts/07-home-dashboard-module-prompt.md](./prompts/07-home-dashboard-module-prompt.md) |

**Reference screenshots (current UI at `127.0.0.1:5201`, HR role):**

1. Hero banner (“Manage staff profiles, leave, shifts, rosters, and staffing gaps”) is **narrow** (~760px) while the page is full width.
2. **Quick actions** row (Run report, Add staff profile, Review leave, Create shift, Publish roster, Approve roster, Update my profile) **navigates away** to `/hr`, `/reports`, or `/profile` — wrong for a summary dashboard.
3. **Today at a glance** KPI strip is good structurally but cards are **not clickable** (no navigation affordance).
4. Charts render but show **empty/flat data** (staffing coverage trend at zero; workforce mix donut: “No distribution data is available yet”).
5. **Workforce action queue** empty state still shows mutation buttons (“Add staff profile”, “Publish roster”).
6. Bottom **Shortcuts** (“HR”, “Reports”) duplicate sidebar navigation.
7. Sidebar HR badge shows **“1”** while queue panel says **“No HR tasks are pending”** — counts must align.

## Problems

### 1. Dashboard behaves like an action launcher, not an insight surface

Quick actions and empty-state buttons push HR users into workflows that belong in `/hr`. The dashboard should answer “what is happening?” not “what should I create?”.

### 2. Hero context panel does not use available width

`_HomeHeroPanel` wraps subtitle text in `ConstrainedBox(maxWidth: 760)`, leaving unused horizontal space on desktop. For HR, facility/tenant context and the “Updated …” badge should span the full content width.

### 3. KPI cards are static

`_HomeMetricCard` has no `onTap` / route mapping. HR expects: tap **Active staff profiles** → staff directory; tap **Shifts today** → today’s shift view; tap **Pending leave approvals** → leave queue; etc.

### 4. Metrics are incomplete for HR operations

Current six cards (`active_staff`, `shifts_today`, `pending_leaves`, `staffing_backlog`, `unassigned_shifts`, `attendance_rate`) miss insights HR routinely needs:

- Staff **on leave today**
- **Attended / checked-in** vs scheduled today
- **Missed / no-show** shifts
- **Payroll**: pending vs processed (current period)

Backend HR pack already computes leave trend and leave status distribution; attendance is approximated from unassigned shifts — extend deliberately where data exists.

### 5. Too much prose, not enough visual density

Section descriptions, empty-state paragraphs, and action buttons add text noise. Prefer compact figures, sparklines, and chart legends over explanatory copy.

### 6. HR-specific chrome should not affect other roles

Changes to quick actions, shortcuts, hero width, and metric interactivity must be **scoped to `AppRole.hr`** (or HR profile flags) so doctor, nurse, and admin dashboards keep their current quick-action patterns unless explicitly changed.

## Requirements

### 1. Remove action surfaces from the HR dashboard

For `AppRole.hr` profile only:

- Clear `quickActionIds` (or stop rendering `_HomeQuickActions` when the list is empty — verify other roles unaffected).
- Clear `shortcutIds` so `_ShortcutsSection` does not render.
- Clear `emptyActionIds` so `_EmptyStateInline` shows message only — **no buttons** in the workforce action queue empty state.
- Do **not** add replacement “Quick actions” elsewhere on the HR home page.

### 2. Full-width hero / context banner

- For HR, remove or raise the 760px constraint on `_HomeHeroPanel` so subtitle + facility line + refresh badge use the full `ResponsivePage` width.
- Keep typography compact: one subtitle line + one context line; no extra explanatory paragraphs.

Implementation options (pick smallest correct change):

- **Option A:** `HomeDashboardProfile` flag, e.g. `heroFullWidth: true`, read in `_HomeHeroPanel`.
- **Option B:** HR-only branch in `_HomeHeroPanel` when `dashboard.profile.role == AppRole.hr`.

### 3. Clickable KPI cards with HR deep links

Make `_HomeMetricCard` tappable when the profile defines a route target for the card id.

Add an HR metric → navigation map (frontend-only fallback; backend may later expose `route_target` per card):

| Card id | Label (current) | Navigate to |
| --- | --- | --- |
| `active_staff` | Active staff profiles | `/hr` — staff directory, active filter if supported |
| `shifts_today` | Shifts today | `/hr` — shifts/scheduling context for today |
| `pending_leaves` | Pending leave approvals | `/hr?queue=LEAVE_REQUESTS` |
| `staffing_backlog` | Staffing backlog | `/hr?queue=UNASSIGNED_SHIFTS` or open positions view |
| `unassigned_shifts` | Unassigned shifts | `/hr?queue=UNASSIGNED_SHIFTS` |
| `attendance_rate` | Attendance rate | `/hr` — shift attendance view for today |

**UX:**

- Entire card is tappable (`InkWell` / `Material` ripple); show subtle hover/focus and a chevron or “View” hint on wide layouts.
- `Semantics` button label: e.g. “Active staff profiles: 16. View staff directory.”
- Cards with `value == 0` remain tappable (empty lists are valid destinations).
- Respect `AppAccessPolicy` — hide navigation if user lacks `hr:read` / `hr-rosters` module.

Extend with new card ids (below) using the same pattern.

### 4. Expand HR KPI set (backend + frontend)

Add metrics that HR can act on from `/hr` after drilling in. Suggested additions (adjust ids/labels to match existing naming):

| Proposed id | Label | Source (indicative) |
| --- | --- | --- |
| `on_leave_today` | On leave today | `staff_leave` where `APPROVED` and today ∈ date range |
| `attended_today` | Attended today | shift assignments checked in / confirmed for today |
| `missed_shifts_today` | Missed shifts today | scheduled shifts with no check-in past grace window |
| `payroll_pending` | Payroll pending | open payroll runs / draft items in scope |
| `payroll_processed` | Payroll processed | completed payroll runs in current period |

**Backend:** extend `dashboard-widget.repository.js` HR pack + `summary.js` card templates; keep tenant/facility scope consistent with existing HR queries.

**Frontend:** extend `HomeStatusCardTemplate` list in `home_dashboard_profiles.dart` for `AppRole.hr`. Prefer **6–8 visible cards** in the strip; use responsive columns (existing `_HomeStatusStrip` layout). Drop or merge low-value cards if the strip overflows on tablet.

### 5. Charts — meaningful HR visuals, minimal caption text

Keep the existing two-chart row but ensure HR data populates when backend has records:

| Widget | Title (existing) | HR data intent |
| --- | --- | --- |
| `_HomeTrendPanel` | Staffing coverage trend | 7-day series: scheduled shifts, filled assignments, or leave volume — not flat zero when shifts exist |
| `_HomeDistributionPanel` | Workforce mix donut | Status mix: active / on leave / inactive staff, or leave status breakdown |

- Short subtitle only (e.g. “Last 7 days”); remove long helper sentences.
- Empty states: single line + optional “Open HR workspace” text link to `/hr` — **not** action buttons.
- Chart segments clickable where feasible → same deep-link targets as related KPIs.

Verify `dashboard-workspace` returns non-empty `trend` / `distribution` for seeded demo data (`DemoCare General Hospital`).

### 6. Informative lower panels (keep, tighten)

Retain for HR:

- **Workforce action queue** — pending work items; rows already link via `_QueueRow` / `_goToRoute`.
- **Alerts and insights** — risk signals (coverage gaps, overdue approvals).
- **Recent activity** — compact timeline; icon + verb + entity + relative time; no multi-line descriptions.

Remove mutation CTAs from empty states (requirement 1). Optionally replace with a single tertiary “Open HR workspace” link.

### 7. Badge / queue count consistency

Ensure sidebar **Human resources** nav badge count matches dashboard queue preview total (same backend source or same `hr-workspace` work-item query). Fix whichever side is stale — do not show “1” in nav and “No HR tasks are pending” on home simultaneously.

### 8. i18n and theming

- New labels and semantics strings in `frontend/lib/l10n/app_en.arb`; run codegen.
- Support light/dark; reuse `AppContentPanel`, `AppSectionPanel`, existing chart widgets.
- No hardcoded English in widgets.

### 9. Scope boundaries

| In scope | Out of scope |
| --- | --- |
| HR home dashboard layout, KPIs, charts, deep links | Rewriting entire `home_page.dart` for all roles |
| HR metric queries in dashboard backend | New HR mutation flows (stay in `/hr`) |
| HR profile config in `home_dashboard_profiles.dart` | Modal dialog route support for home quick actions (removed for HR) |
| Tests for HR dashboard behavior | Unrelated settings or access-admin changes |

## Implementation notes

- Prefer **profile-driven** behavior (`HomeDashboardProfile` fields: `quickActionIds`, `shortcutIds`, `emptyActionIds`, optional `metricRouteTargets`, `heroFullWidth`) over hard-coded `if (role == hr)` scattered across `home_page.dart`.
- Extract HR-specific pieces to `frontend/lib/features/home/presentation/widgets/` if `home_page.dart` grows — e.g. `home_hr_metric_routes.dart`, `home_metric_card.dart`.
- Follow [prompts/07-home-dashboard-module-prompt.md](./prompts/07-home-dashboard-module-prompt.md): home **summarizes and routes**; `/hr` **executes** workflows.
- Realtime: subscribe to existing HR dashboard events in `home_controller.dart`; refresh KPIs and queue after HR mutations elsewhere.

## Acceptance criteria

- [ ] HR user lands on **Workforce dashboard** with **no Quick actions** section and **no Shortcuts** section.
- [ ] Hero/context banner spans **full content width** on desktop and tablet.
- [ ] Every KPI card in “Today at a glance” is **clickable** and navigates to the correct `/hr` (or Reports) destination with sensible pre-filters.
- [ ] Workforce action queue empty state shows **message only** — no Add staff / Publish roster buttons.
- [ ] At least **two charts** render with non-empty demo data when shifts/leaves/staff exist in seed data.
- [ ] New HR metrics (on leave, attendance, missed shifts, payroll summary) appear when backend supplies values; hidden gracefully when zero and no data source.
- [ ] Sidebar HR badge count **matches** dashboard pending-work count.
- [ ] Non-HR role dashboards unchanged (still show quick actions where configured).
- [ ] `flutter analyze` and `flutter test` pass; backend tests updated for new HR metric fields if added.

## Quality gate

From `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test test/app/app_test.dart
flutter test test/features/home/
```

From `backend/` when touching dashboard metrics:

```sh
npm test -- --testPathPattern="dashboard-widget|dashboard-workspace|dashboard/summary"
```

## Key file references

```
frontend/lib/features/home/
  presentation/pages/home_page.dart          # layout, KPI strip, charts, queue
  domain/entities/home_dashboard_profiles.dart  # AppRole.hr profile
  domain/entities/home_dashboard.dart        # HomeStatusCard, trend, distribution
  data/repositories/home_repository_impl.dart
  presentation/controllers/home_controller.dart

frontend/lib/features/hr/
  presentation/pages/hr_workspace_page.dart  # queue deep links, HrQueue

backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js
backend/src/lib/dashboard/summary.js
backend/src/modules/dashboard-workspace/services/dashboard-workspace.service.js
```
