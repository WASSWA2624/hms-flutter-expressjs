# Simplify Home Dashboard — Deduplicate Sections & Tighten Summary UI

Deeply audit every home/dashboard section across personas, remove near-duplicate actions and chrome, and keep the surface a concise permission-gated summary: clear KPIs, one management/worklist strip, enough quick links, no redundant create rows or explanatory fluff.

## Context

- Surface: `HomePage` → `_HomeDashboardContent` → `RoleDashboardScaffold` (`summary badges` → `quick actions` → `priority panel` → `charts`).
- Profiles/actions: `homeDashboardProfiles`, `HomeActionDefinition`, `HomeShortcutDefinition`, `homeDashboardPriorityData`, `homeQueueTitle` / empty-section titles.
- Example of the intended outcome (tenant / platform admin pattern): **Quick actions** such as Create facility / Create role / Create user duplicate workflows already reachable from **Manage facilities / Manage roles and permissions / Manage users** in the management strip → drop the duplicate Quick actions row when every create action is covered by a manage hub. Rename poor titles (e.g. `Facility follow-up` → **Facility management**). Drop section **descriptions** on summary management panels. Fix KPI cards that truncate/hide values (e.g. currency). Raise **Quick links** to a useful minimum when permissions allow.
- Permissions: `AppAccessPolicy.grantsAll`, `Dashboard.md`, `prompts/dashboard.md`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`. Unauthorized atoms must not render (no disabled tiles / routine “no access”).

## Requirements

1. **Inventory every visible section and atom per persona** (status strip, quick actions, empty/management action strip, queue/alerts/results/follow-ups, shortcuts/quick links, charts). For each action/shortcut id, record label, section, destination (dialog/route), and `requiredPermissions`.

2. **Define and remove near-duplicates.** Treat two controls as near-duplicates when they open the same dialog/route family or when a “Create X” action is already reachable from a “Manage X” hub on the same dashboard. Prefer keeping the **management hub** (or the richer worklist) and remove the redundant Quick actions entry or entire Quick actions section when, after filtering by permissions, no unique create/next-step remains. Apply the same rule across personas (platform, tenant, facility, clinical, department)—do not only fix one role.

3. **One job per section.** After dedupe, the dashboard should not show two action strips that list the same intents. Collapse empty sections; do not leave blank headers. Keep true attention surfaces (queues, alerts, results) when they have items or a purposeful empty management strip.

4. **Rename management empty-state titles** to summary language. Replace weak titles such as `Facility follow-up` with **Facility management** (and align platform copy with **Platform management**). Localize via `app_en.arb` / generated l10n; drive titles from shared helpers (`homeQueueTitle` / empty section title), not one-off hardcodes where a profile already has a pattern.

5. **Strip non-summary descriptions** from management/empty panels (e.g. `homePlatformManagementDescription`, profile `emptyMessage` shown as body copy under the management strip). The dashboard must not narrate what the buttons already say. Keep empty copy only when it is the sole content of a true work queue with no management actions (clinical “nothing due” style)—not marketing blurbs above Manage buttons.

6. **KPI / status cards must not hide information.** Audit `DashboardMetricStrip` / `_DashboardMetricCard` for overflow, ellipsis that swallows currency/ratio values, and type that is too large for the strip. Ensure value + label remain readable at desktop widths with up to the profile’s max KPI count (4–6); use theme tokens; no yellow/black overflow; no clipping of primary values. Prefer fitting text (size/weight/layout) over hiding it.

7. **Quick links minimum.** For each persona that shows shortcuts, aim for **at least 4** authorized tiles when the permission-filtered catalog can supply them; prefer **5** when more high-value destinations exist and `maxShortcutTiles` allows. Raise caps that force fewer than 4 (e.g. facility-command `2`) when authorized shortcuts exist. Never invent fake links; never show unauthorized routes. Shortcuts remain gated by `requiredPermissions` + `canAccessShellRoute`.

8. **Preserve permission-based access.** Dedupe and copy changes must not weaken `grantsAll` filtering from `prompts/dashboard.md`. Removing a Quick actions section must not remove the only authorized path if Manage hubs lack the matching permission—then keep the unique authorized action. Union across grants still applies.

9. **UI states.** Keep `AsyncStateScaffold` loading/error/retry. Empty-after-filter stays non-leaking (no access-denied chrome). Responsive under `PageMaxWidth.dataHeavy`; light and dark; mobile/tablet/desktop without overflow or duplicate sections.

10. **Tests** under `frontend/test/features/home/` (and shared dashboard tests as needed):
    - Tenant/platform: when Manage hubs cover Create intents, Quick actions section absent; Manage actions remain for granted permissions.
    - Unauthorized manage/create/shortcut ids absent; authorized remain.
    - Facility management (or renamed) title present; management description body absent for that strip.
    - Metric strip: currency/ratio fixtures render without overflow/clip of the value at a representative desktop width.
    - Shortcut count ≥ 4 when ≥ 4 authorized shortcuts exist for that profile.

## Constraints

- Scope: home feature, shared `dashboard/` widgets, home l10n keys used by the home surface, and home/dashboard tests. Do not redesign unrelated workspaces.
- Reuse existing action/shortcut catalogs, dialogs, and routes; do not invent parallel create flows.
- Do not ship per-persona mini-apps; do not fake KPIs or links without routes/data.
- No disabled unauthorized controls; no routine “no access” banners for filtered widgets.
- Follow `prompts/.cursor/prompt.mdc` and permission rules; keep backend RBAC/ABAC authoritative.

## Acceptance Criteria

- Every persona’s home surface has been audited; near-duplicate Quick actions vs management hubs are removed where Manage already covers Create (requirement 2–3).
- Management strip titles use clear summary names (e.g. Facility management); redundant section descriptions are gone (requirement 4–5).
- Status cards show full primary values without overflow/clipping at supported desktop densities (requirement 6).
- Quick links show at least four authorized tiles when the catalog permits; unauthorized tiles never appear (requirement 7–8).
- Permission filtering still matches `Dashboard.md` / `grantsAll`; tests in requirement 10 pass; loading/empty/error remain observable.

## Relevant Files

- `Dashboard.md`, `prompts/dashboard.md`
- `frontend/lib/features/home/presentation/pages/home_page.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_mapper.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_layout.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_access.dart`
- `frontend/lib/shared/dashboard/` (`role_dashboard_scaffold.dart`, `dashboard_metric_strip.dart`, `dashboard_priority_panel.dart`)
- `frontend/lib/l10n/app_en.arb` (home dashboard strings)
- `frontend/test/features/home/`
- `.cursor/access/permissions.mdc`
