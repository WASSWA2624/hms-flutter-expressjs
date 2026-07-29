# Simplify Home Dashboard — Deep Deduplicate & Summary UI

Deeply scan every home/dashboard section and atom across personas, remove near-duplicate components or whole sections, and leave a permission-gated summary: readable KPIs, one management/worklist strip, enough quick links, no redundant create rows or explanatory fluff.

## Context

- Surface: `HomePage` → `_HomeDashboardContent` → `RoleDashboardScaffold` (status strip → quick actions → priority panel → charts). Priority panel hosts management empty strips, queues, alerts, results/follow-ups, and shortcuts.
- Catalogs: `homeDashboardProfiles`, `HomeActionDefinition`, `HomeShortcutDefinition`, `homeDashboardPriorityData`, `homeQueueTitle` / empty-section titles, l10n under `home*`.
- **Canonical example (tenant admin):** Quick actions expose Create facility / Create role / Create user. The same outcomes are reachable from Manage facilities / Manage roles and permissions / Manage users on the **Facility follow-up** strip. That Quick actions row is a near-duplicate → remove it when every remaining create intent is covered by a Manage hub. Rename **Facility follow-up** → **Facility management**. Drop the section description (e.g. “Create facilities, assign roles…”)—the dashboard is a summary, not a tutorial. Apply the same scan to platform (**Platform management**), facility, clinical, and department personas—not only tenant admin.
- Observed defects to fix while simplifying: KPI cards truncate labels/values (e.g. `Facilit…`, `Adopti…`, `U…` / currency); Quick links often show only 1–2 tiles when more authorized destinations exist.
- Permissions: `AppAccessPolicy.grantsAll`, `Dashboard.md`, `prompts/dashboard.md`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`. Unauthorized atoms must not render (no disabled tiles / routine “no access”).

## Requirements

1. **Inventory every visible section and atom per persona** (status strip, Quick actions, empty/management action strip, queue/alerts/results/follow-ups, Quick links/shortcuts, charts). For each action and shortcut id, record: visible label, section, destination (dialog/route/family), and `requiredPermissions`. Cover platform, organization/tenant, facility-command, clinical, department, task-first, workforce, and patient profiles that ship in `homeDashboardProfiles`.

2. **Define and remove near-duplicates.** Treat two controls as near-duplicates when they open the same dialog/route family, or when a **Create X** (or equally narrow next-step) is already reachable from a **Manage X** hub on the same dashboard. Prefer the **management hub** (or the richer worklist) and remove the redundant Quick actions entry—or the entire Quick actions section when, after permission filtering, no unique create/next-step remains. Do not keep two strips that list the same intents under different headers.

3. **One job per section.** After dedupe: KPIs summarize; one management/worklist strip owns admin/setup next steps; queues/alerts own attention items; Quick links own navigation; charts own trends. Collapse empty sections; never leave blank headers or empty Quick links chrome with zero tiles.

4. **Rename management empty-state titles** to summary language. Replace weak titles such as `Facility follow-up` with **Facility management** (keep platform copy aligned with **Platform management**). Localize via `app_en.arb` / generated l10n; drive titles from shared helpers (`homeQueueTitle` / empty section title), not one-off hardcodes when a profile pattern exists.

5. **Strip non-summary descriptions** from management/empty panels (`homePlatformManagementDescription`, profile `emptyMessage` shown as body under Manage buttons, and equivalents). Buttons already state the action. Keep empty copy only when it is the sole content of a true work queue with no management actions (clinical “nothing due” style)—not marketing blurbs above Manage rows.

6. **KPI / status cards must not hide information.** Audit `DashboardMetricStrip` / `_DashboardMetricCard` so value **and** label stay readable at desktop widths with up to the profile’s max KPI count (4–6). Fix type size, weight, layout, and flex so currency/ratio/percent strings and labels are not ellipsized into useless fragments (`U…`, `Facilit…`). No yellow/black overflow; use theme tokens; light and dark.

7. **Quick links minimum.** For each persona that shows shortcuts, show **at least 4** authorized tiles when the permission-filtered catalog can supply them; prefer **5** when more high-value destinations exist and layout caps allow. Raise `maxShortcutTiles` (and related caps, e.g. facility-command `2`) when authorized shortcuts exist below that floor. Never invent fake links; never show unauthorized routes. Gate with `requiredPermissions` + `canAccessShellRoute`.

8. **Preserve permission-based access.** Dedupe and copy changes must not weaken `grantsAll` filtering from `prompts/dashboard.md`. If removing Quick actions would eliminate the only authorized path because Manage hubs lack matching permission, keep the unique authorized action. Union across grants still applies (extra grants surface atoms without inventing roles).

9. **UI states.** Keep `AsyncStateScaffold` loading/error/retry. Empty-after-filter stays non-leaking. Responsive under `PageMaxWidth.dataHeavy`; mobile/tablet/desktop without overflow, clipping, or duplicate sections; supported light and dark themes.

10. **Tests** under `frontend/test/features/home/` (and shared dashboard tests as needed):
    - Tenant/platform: when Manage hubs cover Create intents, Quick actions section absent; Manage actions remain for granted permissions.
    - Unauthorized manage/create/shortcut ids absent; authorized remain.
    - Renamed Facility management (or platform equivalent) title present; management description body absent for that strip.
    - Metric strip: currency/ratio/long-label fixtures render without overflow or value/label clipping at a representative desktop width with 6 cards.
    - Shortcut count ≥ 4 when ≥ 4 authorized shortcuts exist for that profile.

## Constraints

- Scope: home feature, shared `dashboard/` widgets, home l10n keys for this surface, and home/dashboard tests. Do not redesign unrelated workspaces.
- Reuse existing action/shortcut catalogs, dialogs, and routes; do not invent parallel create flows or fake KPIs/links.
- Do not ship per-persona mini-apps; do not leave duplicate Create + Manage pairs after the audit.
- No disabled unauthorized controls; no routine “no access” banners for filtered widgets.
- Follow `prompts/.cursor/prompt.mdc` and permission rules; backend RBAC/ABAC remains authoritative.

## Acceptance Criteria

- Every persona’s home surface has been inventoried; near-duplicate Quick actions vs management hubs are removed where Manage already covers Create (requirements 1–3).
- Management strip titles use clear summary names (e.g. Facility management); redundant section descriptions are gone (requirements 4–5).
- Status cards show readable primary values and labels without overflow/clipping at supported desktop densities up to 6 KPIs (requirement 6).
- Quick links show at least four authorized tiles when the catalog permits; unauthorized tiles never appear (requirements 7–8).
- Permission filtering still matches `Dashboard.md` / `grantsAll`; tests in requirement 10 pass; loading/empty/error remain observable (requirement 9).

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
