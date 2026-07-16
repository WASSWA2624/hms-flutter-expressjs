# Standardize Clinical Screen (Tabs & Toolbar)

## Objective

Refactor the Clinical workspace (`/clinical`, `ClinicalWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

## Compliance Checklist (from prompt.md)

- [ ] No dedicated screen title/header
- [ ] Shared `AppTabStrip` at top with consistent vertical padding
- [ ] Toolbar immediately under tabs via `primaryAction` / `secondaryActions`
- [ ] All former header / more-menu actions relocated into the contextual toolbar
- [ ] Toolbar actions change with the active tab
- [ ] Every screen retains at least one toolbar button overall
- [ ] Tables expose only Filters and Settings inside the table area
- [ ] Consistent button labels (l10n) across tabs

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative layout contract.

Preserve all Clinical domain behavior (worklist scopes, section counts, realtime lab notices,
encounter detail dialog, `_ClinicalActionBar` / `ClinicalActionsPanel` encounter actions,
permissions, deep links, column defaults per section). Change **chrome/layout/labels** only
unless a small l10n string update is required for Filters/Settings compliance.

**Do not invent new tab/table/search/filter implementations.** Reuse shared components listed below.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
  - Public widget: `ClinicalWorkspacePage` (`initialQuery: ClinicalWorkspaceQuery?`)
  - Content: `_ClinicalWorkspaceContent` / `_ClinicalWorkspaceContentState`
  - Table body: `_ClinicalWorklistPanel` → `AppListTable<ClinicalWorklistEntry>`
  - Row dialog: `_openClinicalEntryDialog` → encounter detail + `_ClinicalActionBar`
  - Write gate (detail actions only): `_ClinicalWorkspaceContentState._writeRequirement`
    (`AppPermissions.clinicalWrite` | `systemAdmin`, module `encounters-vitals`)
- Detail panels helper: `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart`
- Controller: `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`
  - Provider: `clinicalWorkspaceControllerProvider`
  - Key APIs: `refresh()`, `applyScope(ClinicalQueueScope)`, `applySearch`, `applyWorklistFilters`,
    `selectEntry`, `changePage`, realtime sync / `clearRealtimeNotice`
- Domain / query: `frontend/lib/features/clinical/domain/entities/clinical_entities.dart`
  - `ClinicalWorkspaceQuery.fromUri` parses `section|tab`, `encounterId|encounter_id|encounter|id`,
    `panel`, `search|q`
  - `enum ClinicalWorkspaceSection { all, waitingReview, urgent, resultsReady, inConsultation, completed }`
  - `enum ClinicalQueueScope` (includes scopes mapped 1:1 from sections)
  - `_parseClinicalSection` aliases (keep all)
- Repository: `frontend/lib/features/clinical/domain/repositories/clinical_repository.dart`
  + `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart`
- Routes: `AppRoutes.clinical` path `/clinical` in `frontend/lib/app/router/app_routes.dart`
  - Builder in `frontend/lib/app/router/app_router.dart` already passes
    `ClinicalWorkspacePage(initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri))`
- Tests: `frontend/test/features/clinical/presentation/clinical_workspace_page_test.dart`
  (+ `clinical_workspace_controller_test.dart`, domain/DTO tests)

### Current widget tree (chrome)

1. `AsyncStateScaffold<ClinicalWorkspaceState>` (loading / retry only — not a screen title bar)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
3. `Column` → `AppTabStrip` → `SizedBox(height: theme.spacing.sm)` → `_ClinicalWorklistPanel` → `AppListTable`
4. **No** page-level `AppWorkspace(title: …)` wrapper today (already headerless like Reception)
5. **No** FAB / `PopupMenuButton` / overflow “more” menu for screen actions

### Tabs (validated against code + l10n)

| # | Tab label (EN / l10n key) | Enum `ClinicalWorkspaceSection` | Query `?section=` written by `_updateUrlForSection` | Accepted aliases in `_parseClinicalSection` | Count source | Count tone |
|---|---------------------------|----------------------------------|------------------------------------------------------|-----------------------------------------------|--------------|------------|
| 1 | All (`clinicalSectionAllLabel`) | `all` | *(omit / empty)* | default / unknown → `all` | `_pageTotal(state.worklist)` | `info` |
| 2 | Waiting review (`clinicalSectionWaitingReviewLabel`) | `waitingReview` | `waiting-review` | `waiting-review`, `waiting_review`, `waitingreview`, `review` | `state.waitingReviewCount` | `warning` |
| 3 | Urgent (`clinicalSectionUrgentLabel`) | `urgent` | `urgent` | `urgent` | `state.urgentCount` | `danger` |
| 4 | Results ready (`clinicalSectionResultsReadyLabel`) | `resultsReady` | `results-ready` | `results-ready`, `results_ready`, `resultsready`, `results` | `state.resultsReadyCount` | `info` |
| 5 | In consultation (`clinicalSectionInConsultationLabel`) | `inConsultation` | `in-consultation` | `in-consultation`, `in_consultation`, `inconsultation`, `consultation` | `state.inConsultationCount` | `warning` |
| 6 | Completed (`clinicalSectionCompletedLabel`) | `completed` | `completed` | `completed`, `closed`, `done` | `state.completedCount` | `info` |

Tab ids use `section.name` (`all`, `waitingReview`, …). Scope mapping via `_clinicalSectionScope`.

**Deep-link tab state is already URL-backed** via `?section=…` + `GoRouter.replace` in `_updateUrlForSection`, and inbound via `ClinicalWorkspaceQuery.fromUri` / `_applyRouteQuery`. Keep and strengthen; do **not** invent a second query key. Also preserve `search` / `encounterId` / `panel` deep-link handling.

### Current toolbar (critical gap)

- `AppTabStrip` is constructed **without** `primaryAction` or `secondaryActions`.
- Per `AppTabStrip` contract (`frontend/lib/shared/components/app_tab_strip.dart`), the toolbar row is **omitted** when both are empty → **screen is actionless** → violates prompt.md (“every screen must have at least one toolbar button”).
- Former `AppWorkspace` chrome (pre-tab refactor) exposed only **Refresh** via `appWorkspaceToolbarWithLabels(..., onRefresh: controller.refresh)` plus summary chips (those chips are now tabs). Refresh was **not** restored into the tab toolbar.

### Current table chrome (gaps)

- Search: `AppListTableSearch` with `clinicalSearchHint` / `clinicalSearchLabel` — keep.
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently **"Table settings"** (must become standardized **"Settings"**).
- Filters: `advancedFilterButtonLabel` / `advancedFilterTitle` use `l10n.clinicalFiltersLabel` → currently **"Clinical filters"** (must become standardized **"Filters"**).
- Filter plumbing already exists (`showAdvancedFilterButton: true`, `filterGroups`, `textFilters`, `onFilterChanged` → `applyWorklistFilters`) — keep; only labels change.
- No Refresh / export / overflow actions in table trailing today (good). Do not add them to the table.

### Concrete `prompt.md` gaps to close

1. **No tab toolbar at all** — restore Refresh (and contextual per-tab wiring) under `AppTabStrip`.
2. **Toolbar not contextual** — must build `primaryAction` / `secondaryActions` from active `ClinicalWorkspaceSection` (section `switch` / helper), even where several tabs share Refresh.
3. **Filters label** is `"Clinical filters"` — must be **"Filters"**.
4. **Settings label** is `"Table settings"` — must be **"Settings"** (shared key).
5. Do **not** reintroduce `AppWorkspace(title: l10n.clinicalTitle, …)` / `showHeader: true` / worklist `AppWorkspaceDetailPanel` title chrome.
6. Do **not** move `_ClinicalActionBar` / encounter dialog actions (Add note, Request lab, Prescribe, disposition, Print summary, etc.) into the screen toolbar — those are **row/detail-scoped**, not screen chrome.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative layout contract)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — headerless `ResponsivePage` + `AppTabStrip` + toolbar + `SizedBox(theme.spacing.sm)` + `AppListTable`
- `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`
  — **copy the pattern** of `_primaryActionForSection(...)` so toolbar rebuilds from the active section
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
  — sibling worklist + Filters/Settings + Refresh secondary pattern
- `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`
  — gated primary + per-tab toolbar emptiness rules
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, column visibility → Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `filterGroups` / `advancedFilterButtonLabel`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` defaults to `false`; do **not** reintroduce a titled header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — historical Refresh labeling via `commonRefreshActionLabel`
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart` — `showsToolbarActionLabels` (≥1200 / `xl+`)
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate` (for write-gated actions only; Refresh needs no write gate)

## Target Architecture

### Tab Configuration

Clinical has **no** screen-level “create encounter” CTA (encounters arrive from OPD / triage / IPD). The only former screen-header action was **Refresh**. Restore it under the tabs and make the toolbar **section-driven**. Add light contextual secondaries that match each tab’s purpose (navigation only — no new APIs).

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All | `/clinical` (no `section`) | Full provider worklist | **Refresh** (`commonRefreshActionLabel`, icon `Icons.refresh`) → `clinicalWorkspaceControllerProvider.notifier.refresh()` then `_showFailureIfNeeded` | *(none)* |
| Waiting review | `/clinical?section=waiting-review` | Awaiting clinician review | **Refresh** (same) | **OPD** (`navigationOpdShortLabel`, icon `Icons.local_hospital_outlined`) → `context.go(AppRoutes.opd.location())` |
| Urgent | `/clinical?section=urgent` | Urgent encounters | **Refresh** (same) | **OPD** (same as Waiting review) |
| Results ready | `/clinical?section=results-ready` | Lab/imaging results ready | **Refresh** (same) | **Lab** (`navigationLabShortLabel`, icon `Icons.science_outlined`) → `context.go(AppRoutes.lab.location())` |
| In consultation | `/clinical?section=in-consultation` | Active consultation | **Refresh** (same) | **OPD** (same) |
| Completed | `/clinical?section=completed` | Completed / closed | **Refresh** (same) | **Discharge** (`navigationDischargeShortLabel`, icon `Icons.logout_outlined`) → `context.go(AppRoutes.discharge.location())` |

Notes:

- Implement via helpers such as `_clinicalPrimaryAction(...)` / `_clinicalSecondaryActions(...)` (or one `_clinicalToolbarForSection`) that **`switch` on `ClinicalWorkspaceSection`**. Do not pass a single hard-coded widget without a section switch.
- Use `AppTabToolbarPrimary` for Refresh (right-aligned primary) and `AppTabToolbarAction` for navigation secondaries.
- Pass `isLoading: state.isRefreshing` on the Refresh control.
- Refresh does **not** require `AppAccessActionGate`.
- Do **not** put Refresh / Lab / OPD / Discharge into `AppListTableSearch.trailingActions`.
- Do **not** invent a header “more” menu; every action is a visible toolbar button.
- Guarantee ≥1 toolbar button on every tab (Refresh primary covers this).

### Routing

- Keep `/clinical` registration in `app_router.dart` unchanged except if tests need it.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by `ClinicalWorkspaceQuery.fromUri` via `section|tab`).
- Canonical write values must remain:
  - *(empty for All)* | `waiting-review` | `urgent` | `results-ready` | `in-consultation` | `completed`
- Preserve aliases already accepted by `_parseClinicalSection`.
- On tab tap: keep `_handleTabChanged` → `setState` + `_updateUrlForSection` + clear search + `applyScope`.
- On deep link: keep `_applyRouteQuery` (section + search + encounterId selection).
- No new query parameter names.

### Page Layout

Precise widget tree after refactor:

1. `AsyncStateScaffold<ClinicalWorkspaceState>` (unchanged loading/retry / realtime snackbar listener)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` — **preferred**, matching Reception
   - Do **not** wrap with a titled `AppWorkspace` header.
   - If you introduce `AppWorkspace`, it **must** use `showHeader: false` and must not render a screen title/toolbar above the tabs.
3. `Column(crossAxisAlignment: stretch)`:
   1. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction:, secondaryActions:)`
   2. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm)
   3. Body: `_ClinicalWorklistPanel` → `AppListTable` with **only** Filters + Settings as table action buttons (plus search field)
4. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

Reuse (do not replace):

- `clinicalWorkspaceControllerProvider` / `ClinicalWorkspaceController.refresh()`
- `ClinicalWorkspaceState` counts, `query.scope`, `query.filters`, `worklist` pagination
- `_clinicalSectionScope`, `_clinicalSectionQueryValue`, `_updateUrlForSection`, `_handleTabChanged`
- `_openClinicalEntryDialog` + `_ClinicalActionBar` / shared `ClinicalActionsPanel` (stay dialog-local)
- Realtime notice listener in `ClinicalWorkspacePage.build` (LAB_RESULT_* snackbars)
- `_writeRequirement` for detail write actions only

## Implementation Steps

1. **Normalize Filters + Settings labels (l10n)** — Files: `frontend/lib/l10n/app_en.arb` (+ regenerate / update generated localizations if the project expects it)
   - Change `clinicalFiltersLabel` English value from `"Clinical filters"` to `"Filters"`.
   - Keep the key name `clinicalFiltersLabel`; only the user-visible string must become **"Filters"**.
   - Change shared `commonTableSettingsActionLabel` English value from `"Table settings"` to `"Settings"` (affects all workspaces intentionally — required standardization).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` and `advancedFilterButtonLabel: l10n.clinicalFiltersLabel` wiring in the page.

2. **Add section-driven tab toolbar** — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
   - In `_ClinicalWorkspaceContentState.build`, pass `primaryAction:` and `secondaryActions:` into `AppTabStrip`.
   - Implement helpers that switch on `_section` per the Tab Configuration table above.
   - Refresh handler pattern:
     ```dart
     onPressed: state.isRefreshing
         ? null
         : () async {
             final AppFailure? failure = await ref
                 .read(clinicalWorkspaceControllerProvider.notifier)
                 .refresh();
             if (context.mounted) {
               _showFailureIfNeeded(context, failure);
             }
           }
     ```
   - Navigation secondaries use `context.go(AppRoutes.*.location())` (page already imports `go_router` + `app_routes.dart`).
   - Ensure tab changes (`_handleTabChanged` → `setState`) immediately rebuild the toolbar.

3. **Keep table chrome limited to Filters + Settings** — File: same page (`_ClinicalWorklistPanel` / `_worklistSearch`)
   - Confirm Filters button text resolves to **"Filters"**.
   - Confirm Settings resolves to **"Settings"**.
   - Do not add Refresh / navigation into table trailing actions.
   - Leave search field in the table (search is not a forbidden table control).

4. **Do not relocate encounter/detail actions** — Keep `_ClinicalActionBar`, lab/radiology/pharmacy cancel-delete row actions, print summary, disposition dialogs, discharge planning dialog inside the encounter dialog/panels.

5. **Tests** — File: `frontend/test/features/clinical/presentation/clinical_workspace_page_test.dart`
   - Keep existing tab URL / deep-link / column / search tests.
   - Add/extend assertions (use desktop width e.g. `1440` so toolbar labels show per `showsToolbarActionLabels`):
     - Refresh primary visible (`find.text('Refresh')` / `commonRefreshActionLabel`).
     - After tapping Waiting review / Urgent / In consultation, secondary **OPD** is visible.
     - After tapping Results ready, secondary **Lab** is visible.
     - After tapping Completed, secondary **Discharge** is visible.
     - On All, Refresh present and no OPD/Lab/Discharge secondaries required.
     - Filters button shows **"Filters"** (not “Clinical filters”).
     - Settings affordance shows **"Settings"** (not “Table settings”) when labels visible.
     - No screen title asserting `clinicalTitle` / `clinicalWorklistTitle` as page header chrome.
   - Update any assertions that expected `"Clinical filters"` or `"Table settings"`.

6. **Format / analyze / test** — run verification commands below from `frontend/`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Filters + Settings only in table chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Only if needed with `showHeader: false`; prefer staying on `ResponsivePage` |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Detail write actions only (already used); not required for Refresh |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Toolbar label visibility / responsive checks |
| `AsyncStateScaffold` | shared components | Loading / error / retry (unchanged) |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` — wire `primaryAction` / `secondaryActions`; section toolbar helpers |
| Modify | `frontend/lib/l10n/app_en.arb` — `clinicalFiltersLabel` → `"Filters"`; `commonTableSettingsActionLabel` → `"Settings"` |
| Modify | Generated l10n outputs if required by project workflow (`app_localizations*.dart`) |
| Modify | `frontend/test/features/clinical/presentation/clinical_workspace_page_test.dart` — toolbar / label / contextual assertions |
| Do not delete | Detail panels, controller, entities, repository, dialog helpers |

## Cleanup: Remove Stale Code

- [ ] Ensure no reintroduction of page-level `AppWorkspace(title: l10n.clinicalTitle, …)` / summary-notification header chips
- [ ] Ensure no duplicate Refresh control in table trailing / FAB / PopupMenu
- [ ] Ensure no orphaned “Queue scope” / old scope chip UI (tests already expect `Queue scope` absent)
- [ ] Do not leave unused toolbar helper stubs
- [ ] After l10n string changes, remove any test hard-codes of `"Clinical filters"` / `"Table settings"` for this screen

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter chrome/layout/l10n refactor only.

## Responsive Design Requirements

- Desktop (≥1024px / especially ≥1200 `xl` where `showsToolbarActionLabels` is true): tab strip + labeled Refresh primary + labeled contextual secondaries; full table with Filters + Settings labels visible.
- Tablet (600–1023px): same structure; toolbar may icon-prefer / hide text labels per `AppTabStrip` / breakpoint helpers — actions must still be tappable.
- Mobile (<600px): tabs + toolbar remain above content; table uses existing `mobileItemBuilder` (`_clinicalWorklistMobileItemBuilder`); no separate mobile-only header title bar.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/clinical/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`?section=…`) and toolbar actions
- [ ] Deep link (`/clinical?section=urgent`, etc.) opens correct tab and scopes fetch
- [ ] Per-tab toolbar shows only that tab’s actions (All vs Results ready vs Completed secondaries differ)
- [ ] Table chrome has only Filters + Settings as action buttons (plus search)
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on every tab (Refresh)
- [ ] Permissions still gate write actions inside encounter dialog (`_ClinicalActionBar`)
- [ ] Responsive layouts still work; realtime notice snackbars still work

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Filters label is **"Filters"**; Settings label is **"Settings"**
- [ ] Domain logic preserved (scopes, counts, dialogs, realtime, deep links)
- [ ] Analyze clean; tests pass; stale chrome removed
