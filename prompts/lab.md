# Refine Laboratory Workspace Tabs, Toolbar, Filters & Settings

Improve the Laboratory desk (`/lab`) so tab semantics, toolbar order, Next action readability, advanced filters, Follow-ups chrome, and Settings match how clinicians search and act on lab encounters.

## Context

- Surface: `LabWorkspacePage`; Follow-ups via `FollowUpWorklistPanel`.
- Current tabs (`section`): All (`worklist`/`all`), Pending (`collection`/`pending`), Critical, Completed today, Follow-ups.
- Gaps: All is first and not “patients with lab encounters”; Critical is today-scoped but unlabeled; Next action uses `labelSmall`; Entry status is unclear; toolbar is Filters → Create → Settings; Advanced Filters are only Queue/Payment/status; Follow-ups lacks Filters/Settings/Create; Settings is column-visibility only.
- Permissions: `lab_access.dart`, `prompts/ui-permissions/lab/*`, `.cursor/access/permissions.mdc`. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. **Tab labels, order, and scopes** (l10n + `LabDeskSection` / filter values / routes):
   - **Pending** — awaiting result entry (keep).
   - **Critical today** — critical results dated today (facility timezone); rename from Critical.
   - **Completed today** — keep.
   - **Follow-ups** — not-yet-completed scheduled follow-ups (keep).
   - **All patients** — last tab; only patients with laboratory encounters; badge = that count.
   - Keep legacy `section=all|worklist|critical|completed-today` aliases.
   - Align Critical-today badge with its filtered list (All may still show older Critical status).

2. **Columns (non–Follow-ups):** keep Patient (name + ID), Orders, Tests, Next action. Rename **Entry status** → **Status** (column, optional-column picker, advanced-filter group using `labEntryStatusColumnLabel`). No parallel status columns.

3. **Enlarge Next action** to at least `labelLarge` / `bodyMedium` (not `labelSmall`). Keep one-line ellipsis, theme color, and ≥ 48dp tap height on touch layouts.

4. **Toolbar order** after search: **Filters → Settings → Create Lab Order** (Create last). Omit Create when unauthorized.

5. **Comprehensive Advanced Filters** (reuse `AppSearchBar` groups; enable date filtering). Cover:
   - Date range (ordered / collected / resulted / completed as available)
   - Patient details (name, identifier, fields already on the matcher)
   - Queue / payment / Status (existing, renamed)
   - Test / result parameters (name/code, critical/abnormal flags when on summaries)
   - Apply / Clear / Close update the list and active-filter badge; prefer extending the lab workspace query over silent incomplete filters.

6. **Follow-ups parity:** search row exposes Filters, Settings, and Create Lab Order in the same order. Filters cover date/time, patient details, completion status. Create uses the same authorized create flow. Settings opens the same comprehensive entry (or scoped equivalent including columns).

7. **Comprehensive Settings** beyond columns: keep show/hide and widths; add lab-desk preferences already supported or trivially wired (default tab if stored, density/page size if the table supports it). Do not invent new backend preference stores. One dialog, Apply / Reset / Close, existing storage keys.

8. **UI states:** permission-filtered chrome, loading, empty, error/retry, filter validation, success after create/settings. Responsive; theme tokens; light and dark.

9. **Tests** in `frontend/test/features/lab/` (and Follow-up tests if shared):
   - Tab order ends with All patients; labels include Critical today / All patients.
   - Critical today excludes non-today criticals; other scopes keep intent.
   - Next action larger than `labelSmall`; Status present; Entry status absent from UI strings.
   - Toolbar Filters → Settings → Create when authorized; Create absent when not.
   - Advanced filters include date plus patient and test/result controls; Apply narrows the list.
   - Follow-ups shows Filters, Settings, Create when authorized.
   - Settings exposes more than columns alone.

## Constraints

- Scope: lab workspace UI, Follow-up panel only for lab chrome parity, lab l10n, lab query/API if filters need it, matching tests.
- Reuse `AppListTable`, `AppSearchBar` filters, create-order and column-visibility flows, `LabDeskSection` / `LabQueueScope`, `lab_access.dart`.
- Optional enhancements: none beyond justified filter/settings fields.
- Backend RBAC/ABAC authoritative; no disabled unauthorized controls; no routine “no access” banners.

## Acceptance Criteria

- AC1 (Req 1): Tabs are Pending → Critical today → Completed today → Follow-ups → All patients; All patients is lab-encounter-only; Critical today is today-scoped and count-aligned.
- AC2 (Req 2–3): Status replaces Entry status; Next action is clearly larger.
- AC3 (Req 4, 6): Toolbar order Filters → Settings → Create on worklist and Follow-ups when authorized.
- AC4 (Req 5–7): Filters and Settings meet the comprehensive bar; Apply/Clear/persist work; lists refresh.
- AC5 (Req 8–9): UI states hold; requirement 9 tests pass on representative viewports and themes.

## Relevant Files

- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
- `frontend/lib/features/lab/presentation/lab_access.dart`
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
- `frontend/lib/shared/follow_up/follow_up_worklist_panel.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/lab/`
- `prompts/ui-permissions/lab/`
- `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`
