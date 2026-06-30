# Task: HR Workforce dashboard — in-place modal quick actions

## Goal

Fix the **Workforce dashboard** (`/` for HR role) so **Today at a glance** metric cards open the correct **HR modal dialogs in place** — maximized by default — instead of navigating to `/hr`. Dashboard quick actions must stay on the dashboard; nested modals (staff detail, approve leave, override shift, etc.) must stack on top without route changes.

Also polish the **hero context strip** (subtitle, facility line, last-updated badge): full width on desktop, role-aware facility visibility, hidden on compact breakpoints, and shorter copy on small screens.

Move **Open HR workspace** from buried empty-state panels into the dashboard **header toolbar**, visible by default (not only when the action queue is empty).

**Prerequisites:** `AppDialog` resize and true viewport maximize ([prompt2.md](./prompt2.md)). Reuse existing HR panels — do not duplicate workflows.

**Implementation principle:** Extend **shared domain types, widgets, and public feature APIs** — do not patch behavior only inside private `home_page.dart` / `hr_workspace_page.dart` helpers. Every UX change in this prompt must land in a reusable global or feature-level function that `/hr` and `/` both call.

## Context

| Area | Location |
| --- | --- |
| Workforce dashboard UI | `frontend/lib/features/home/presentation/pages/home_page.dart` — `_HomeHeroPanel`, `_HomeStatusStrip`, `_HomeMetricCard` |
| HR metric routing (current) | `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart` — cards resolve to `AppRoutes.hr` + `?queue=` |
| HR profile & card targets | `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` — `AppRole.hr` profile, `metricRouteTargets` |
| HR work-queue dialog | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — `_showWorkQueueDialog`, `_HrWorkQueuePanel`, `_applyQueueAndShow` |
| HR queue tabs & filters | `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart`, `HrQueue` in `hr_entities.dart` |
| HR mutations / nested dialogs | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart`, `hr_access_dialogs.dart` |
| Controller & data | `hr_workspace_controller.dart`, `hr_repository_impl.dart` |
| Open HR workspace (current) | `home_dashboard_profiles.dart` — `showEmptyWorkspaceLink: true`; rendered in `_PrimaryQueuePanel` / `_QuietState` via `homeOpenHrWorkspaceLink` |
| Dashboard toolbar | `home_page.dart` — `AppWorkspaceHeader` → `appWorkspaceToolbarWithLabels` (`primary` / `secondary` slots) |

**Reference screenshots (`127.0.0.1:5201`):**

- Workforce dashboard with eight **Today at a glance** cards and a narrow hero strip (“Operational snapshot…”, “DemoCare General Hospital \| Hospital”, “Updated Jun 30, 15:12”).
- Clicking a card (e.g. **Missed shifts today**) navigates to `/hr?queue=OVERDUE_SHIFTS` instead of opening the **Work queues** modal on the dashboard.
- **Work queues** modal already exists on `/hr` with tabs: Leave requests, Swap requests, Roster drafts, Unassigned shifts, Payroll drafts; **Overdue shifts** appears when deep-linked (`?queue=OVERDUE_SHIFTS`).
- **Open HR workspace** appears only inside the **Workforce action queue** empty state (and trend/distribution quiet states) — below the fold, easy to miss. Toolbar currently shows only **Refresh**.

## Problems

### 1. Metric cards route away from the dashboard

`_HomeMetricCard` calls `_goToRoute(context, AppRoutes.hr, …)` via `homeMetricNavigation`. HR quick actions are meant to be **modal-first** on the dashboard, not shell navigation.

### 2. Existing HR dialogs are not reusable from Home

`_showWorkQueueDialog`, staff directory table, and queue pre-selection live inside `hr_workspace_page.dart` as private methods/widgets. Home cannot invoke them without extraction.

### 3. Hero context strip layout and visibility

- Strip does not span the full content width (subtitle + facility line sit in a `Wrap` beside the badge instead of a full-width row).
- Facility name/type (`DemoCare General Hospital | Hospital`) shows for all HR users; it should appear only for **super admin** and **tenant admin** roles.
- Strip should be **hidden on small screens** (`< md` breakpoint per `layouts.mdc`).
- On compact widths, dashboard copy (card labels, section titles, hero subtitle) should use shorter text or tighter typography.

### 4. “Open HR workspace” is not in the toolbar

`showEmptyWorkspaceLink` gates an `AppButton.tertiary` inside `_EmptyQueueState` and link copy in `_QuietState` (trend/distribution empty charts). Users must scroll to the action-queue panel to find it. It should be a persistent toolbar action next to **Refresh**, matching how `/hr` exposes primary actions in `appWorkspaceToolbarWithLabels` `secondary`.

### 5. Logic is trapped in page-private widgets

`_HomeHeroPanel`, `_HomeMetricCard`, `_QuietState`, and HR dialog shells are private to large page files. Without extracting shared APIs, Home and HR will drift (duplicate dialogs, inconsistent maximize behavior, repeated permission checks).

## Global implementation standards (mandatory)

Follow `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, and `layouts.mdc`. **Do not** copy HR panels into `home_page.dart` or add HR-only inline dialog classes.

### Shared / global touchpoints

| Layer | Location | Required change |
| --- | --- | --- |
| **Dialog shell** | `frontend/lib/shared/components/app_dialog.dart`, `showAppDialog` | Ensure `initialMaximized` (or post-open maximize hook from prompt2) is used by all dashboard-origin HR modals — not a one-off `home_page` flag |
| **Workspace toolbar** | `frontend/lib/shared/layout/app_workspace_toolbar.dart` | Add or extend a reusable helper (e.g. workspace link / secondary action builder) if toolbar action composition is repeated; Home and `/hr` should share the same button pattern |
| **Home domain** | `frontend/lib/features/home/domain/entities/home_dashboard.dart` | Introduce typed action targets (e.g. `HomeMetricAction` / `HomeToolbarAction`) alongside `HomeMetricRouteTarget`; replace `showEmptyWorkspaceLink` with explicit toolbar action ids where possible |
| **Home profiles** | `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` | HR profile declares `metricActionTargets` + `toolbarActionIds` instead of relying on empty-state link flags |
| **Metric resolver** | `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart` | Extend globally: `homeMetricAction(…)` returns modal opener + permission gate; keep `homeMetricNavigation` for route-based profiles; add `resolveHrMetricModal(…)` mapping card id → `showHr*` entry |
| **Home hero** | **New** `frontend/lib/features/home/presentation/widgets/home_hero_panel.dart` | Extract `_HomeHeroPanel` + `homeDashboardContextLine(…)` (role-aware facility visibility, responsive hide) — used by `home_page.dart`, testable in isolation |
| **Home toolbar actions** | **New** `frontend/lib/features/home/presentation/widgets/home_toolbar_actions.dart` | `buildHomeToolbarSecondary(…)` — resolves profile toolbar actions (incl. **Open HR workspace**) with shared permission checks |
| **HR public dialog API** | **New** `frontend/lib/features/hr/presentation/widgets/hr_workspace_dialogs.dart` (or barrel export) | Public `showHrWorkQueueDialog`, `showHrStaffDirectoryDialog`, today-scoped list dialogs; **both** `hr_workspace_page.dart` and Home import these — page private `_showWorkQueueDialog` delegates here |
| **HR panels** | Existing `hr_queue_switcher.dart`, `hr_enhanced_dialogs.dart`, `hr_access_dialogs.dart` | Reuse as dialog content; no duplicated table/queue UI in Home feature |
| **i18n** | `frontend/lib/l10n/app_en.arb` | All new labels (compact card copy, toolbar strings) via l10n — no hard-coded Home-only strings |
| **Tests** | `home_metric_routes_test.dart`, new widget tests for extracted panels, HR dialog entry tests | Cover global resolvers and permission gates, not only page integration |

### Anti-patterns (reject in review)

- Duplicating `_HrWorkQueuePanel`, staff directory table, or queue switcher inside `home_page.dart`
- HR card `onTap` handlers with inline `showDialog` + copied `AppDialog` config
- Leaving `showEmptyWorkspaceLink` / `_QuietState` workspace links in place after toolbar ships
- `/hr` and Home calling different code paths for the same work-queue or staff-directory dialog

## Requirements

### 1. Replace HR card navigation with in-place modals

For `AppRole.hr` profile cards only, change tap behavior from `context.go('/hr…')` to opening the appropriate dialog **on the current route** via **`homeMetricAction` / `resolveHrMetricModal`** (global resolver in `home_metric_routes.dart`) — `_HomeMetricCard` must call the shared resolver, not embed HR logic.

| Card ID | Expected modal | Pre-selection / filter |
| --- | --- | --- |
| `active_staff` | Staff directory dialog (reuse HR directory table) | Status = Active |
| `shifts_today` | Shifts dialog or work-queue view | Shifts scheduled for today |
| `pending_leaves` | **Work queues** (maximized) | Tab: `LEAVE_REQUESTS` |
| `on_leave_today` | Staff / leave dialog | Staff on approved leave today |
| `unassigned_shifts` | **Work queues** (maximized) | Tab: `UNASSIGNED_SHIFTS` |
| `attended_today` | Attendance / shifts dialog | Shifts marked attended today |
| `missed_shifts_today` | **Work queues** (maximized) | Tab: `OVERDUE_SHIFTS` |
| `payroll_pending` | **Work queues** (maximized) | Tab: `PAYROLL_DRAFTS` |

**Modal rules:**

- Open with `showAppDialog` + `AppDialog`, **`initialMaximized: true`** (or equivalent from prompt2).
- Call `hrWorkspaceControllerProvider.notifier.applyQueue(…)` (or equivalent filter API) **before** showing the dialog when a queue tab is required.
- Nested actions (staff detail, approve leave, override shift, payroll preview, staff access) must use existing `showHr*` helpers and remain modal-stacked — **no `context.go` to `/hr`** from dashboard-origin dialogs.
- Permission-gate each card the same way `homeMetricNavigation` does today (`hrRead` / `rosterRead` + `hr` module entitlement). Non-actionable cards render without chevron and are not tappable.

### 2. Extract reusable HR dialog entry points

Refactor minimally into **`hr_workspace_dialogs.dart`** (public feature API) — prefer public `showHr…` functions over copying UI. **`hr_workspace_page.dart` must delegate** to the same functions Home uses:

- `showHrWorkQueueDialog(BuildContext, WidgetRef, {HrQueue? initialQueue, bool maximize = true})`
- `showHrStaffDirectoryDialog(…)` for **Active staff profiles** — reuse directory table widgets (extract from page if still private)
- Add today-scoped helpers only where no dialog exists yet (`shifts_today`, `on_leave_today`, `attended_today`); wire them to existing HR data queries and table components

Keep `/hr` behavior unchanged: deep links (`?queue=`, `?id=`, `?search=`) continue to work on the HR workspace route.

### 3. Hero context strip — layout and responsive rules

Extract to **`home_hero_panel.dart`** and **`homeDashboardContextLine(…)`** (role-aware facility line). Update the shared widget (HR profile uses `heroFullWidth: true`):

| Breakpoint | Behavior |
| --- | --- |
| **≥ md** | Full-width row: subtitle on the left (expanded), updated badge aligned right; facility context on its own line below subtitle when shown |
| **< md** | Hide the entire hero panel (`SizedBox.shrink`) |
| **All sizes** | Facility name/type in `homeDashboardContextLine(…)` only when `AppRole.superAdmin` or `AppRole.tenantAdmin`; omit for HR and other facility-scoped roles |

**Small-screen copy (dashboard body, not hero):**

- Prefer abbreviated card labels via `app_en.arb` compact variants or `maxLines: 1` + shorter l10n keys where labels wrap awkwardly.
- Keep **Today at a glance** section title; shorten only if needed for readability on phones.

### 4. Move “Open HR workspace” to the dashboard toolbar

Implement via **`buildHomeToolbarSecondary`** (`home_toolbar_actions.dart`) and profile-level **`toolbarActionIds`** — not inline widget trees in `home_page.dart`.

For the HR workforce dashboard (`AppRole.hr` profile):

- Add **Open HR workspace** to `AppWorkspaceHeader` toolbar via `appWorkspaceToolbarWithLabels` `secondary` (or `primary` if that matches peer modules).
- Use `AppButton.secondary` with `Icons.open_in_new_outlined` (or existing `homeOpenHrWorkspaceLink` l10n) — same label and destination as today: `context.go(AppRoutes.hr)`.
- Show whenever the user has HR workspace access (`hr` module + `hrRead` / `rosterRead`), **independent of queue/trend empty state** — always visible on load.
- **Remove** duplicate links from:
  - `_EmptyQueueState` (`showWorkspaceLink` / `showEmptyWorkspaceLink`)
  - `_QuietState` in `_HomeTrendPanel` and `_HomeDistributionPanel` (`readOnlyInsights` HR workspace link)
- Keep `showEmptyWorkspaceLink` only if still needed for other behavior; otherwise deprecate or repurpose the flag so empty panels no longer render the link.

**Responsive toolbar rules:**

- On narrow widths, toolbar overflow menu must still expose **Open HR workspace** (do not hide behind refresh-only overflow).
- Compact label OK on xs if toolbar truncates (e.g. “HR workspace”) — add l10n compact variant only if required.

### 5. Do not regress other role dashboards

`homeMetricNavigation` route-based behavior for non-HR profiles stays as-is unless a profile explicitly opts into modal actions later. Do not add **Open HR workspace** to non-HR role toolbars.

## Acceptance criteria

- [ ] Tapping any HR **Today at a glance** card opens the correct modal on `/` — URL does not change to `/hr`.
- [ ] Work-queue modals open **maximized** with the correct tab pre-selected (verify: Missed shifts today → Overdue shifts with item actions).
- [ ] Nested HR actions from dashboard-origin modals work without leaving the dashboard.
- [ ] Hero strip spans full width on desktop; hidden below `md`; facility name hidden for non-admin roles.
- [ ] **Open HR workspace** appears in the dashboard header toolbar on load (no scroll required); removed from action-queue and chart empty states.
- [ ] Toolbar link navigates to `/hr`; still permission-gated for users without HR access.
- [ ] `/hr?queue=…` deep links still open the work-queue dialog on the HR workspace.
- [ ] `flutter analyze` and affected widget tests pass (`home_metric_routes_test.dart`, `home_hero_panel` tests, HR dialog entry tests).
- [ ] **No duplicated HR dialog UI** in `home_page.dart`; `/hr` and Home share `hr_workspace_dialogs.dart` entry points.
- [ ] Global resolvers (`homeMetricAction`, `homeDashboardContextLine`, `buildHomeToolbarSecondary`) exist and are covered by unit/widget tests.

## Key files to touch

### Shared / global

- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/layout/app_workspace_toolbar.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard.dart`
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`
- `frontend/lib/features/home/presentation/widgets/home_hero_panel.dart` **(new)**
- `frontend/lib/features/home/presentation/widgets/home_toolbar_actions.dart` **(new)**
- `frontend/lib/l10n/app_en.arb`

### Feature integration

- `frontend/lib/features/home/presentation/pages/home_page.dart` (wire shared widgets only)
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_workspace_dialogs.dart` **(new)**
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` (delegate to public `showHr*` APIs)
- `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart` (if overdue tab visibility needs alignment)

### Tests

- `frontend/test/features/home/presentation/widgets/home_metric_routes_test.dart`
- `frontend/test/features/home/presentation/widgets/home_hero_panel_test.dart` **(new, if extracted)**
- `frontend/test/features/hr/presentation/widgets/hr_workspace_dialogs_test.dart` **(new, if applicable)**
