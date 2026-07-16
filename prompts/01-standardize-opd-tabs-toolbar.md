# Standardize OPD Screen (Tabs & Toolbar)

## Objective

Refactor the OPD workspace (`/opd`, `OpdWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

Preserve all OPD domain behavior (worklist composition, triage urgency, billing display,
row-action dialogs, realtime refresh, deep links). Change **chrome/layout/labels** only unless
a small l10n string update is required for Filters/Settings compliance.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
  - Public widget: `OpdWorkspacePage`
  - Content state: `_OpdWorkspaceContent` / `_OpdWorkspaceContentState`
  - Body: `_OpdWorkspaceBody` → `_OpdMainTable` → `AppListTable<_OpdTableItem>`
- Controller: `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
  - Provider: `opdWorkspaceControllerProvider`
  - Refresh API: `OpdWorkspaceController.refresh()`
- Entities / routing query: `frontend/lib/features/opd/domain/entities/opd_entities.dart`
  - `enum OpdWorkspaceSection { all, arrivals, queue, triage, active }`
  - `OpdWorkspaceQuery.fromUri` (keys: `section`/`tab`, `id`/`flow`/`flowId`/`encounter`, `panel`/`stage`/`filter`/`queue`, `search`/`q`/`patient`)
- Routes: `AppRoutes.opd` path `/opd` in `frontend/lib/app/router/app_routes.dart`
  - Router builder: `frontend/lib/app/router/app_router.dart` → `OpdWorkspacePage(initialQuery: OpdWorkspaceQuery.fromUri(state.uri))`
- Encounter start flow: `openOpdWorkspaceEncounterFlow` in `frontend/lib/shared/opd_actions/opd_encounter_flow.dart`
- Permission / icon: `opdEncounterPermissionRequirement`, `opdEncounterIcon` in `frontend/lib/shared/components/opd_encounter_dialog.dart`
- Front-desk row actions requirement: `opdFrontDeskActionRequirement` in `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- Tests: `frontend/test/features/opd/presentation/opd_workspace_page_test.dart` (+ other `frontend/test/features/opd/**`)

### Current widget tree (data state)

1. `AsyncStateScaffold<OpdWorkspaceState>` (loading chrome only — not a persistent screen title bar)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
3. `Column` → `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + `_OpdWorkspaceBody`
4. `_OpdMainTable` → `AppListTable` with search + advanced filters + column visibility

**No** `AppWorkspace` title header, **no** FAB, **no** `PopupMenuButton` / more-menu for screen actions.

### Tabs (validated against code + l10n)

| # | Tab label (EN) | Enum | Query `?section=` | Tab id (`AppTabItem.id`) | Count source |
|---|----------------|------|-------------------|--------------------------|--------------|
| 1 | All worklist (`opdSectionAllLabel`) | `OpdWorkspaceSection.all` | *(omit / empty)* | `all` | `allItems.length` |
| 2 | Arrivals (`opdSectionArrivalsLabel`) | `OpdWorkspaceSection.arrivals` | `arrivals` | `arrivals` | `state.arrivalCount` |
| 3 | Queue (`opdSectionQueueLabel`) | `OpdWorkspaceSection.queue` | `queue` | `queue` | `state.queueCount` |
| 4 | Triage (`opdSectionTriageLabel`) | `OpdWorkspaceSection.triage` | `triage` | `triage` | `state.triageQueueCount` |
| 5 | Active (`opdSectionActiveLabel`) | `OpdWorkspaceSection.active` | `active` | `active` | `summaryCounts.activeOpd` / `activeFlowCount` |

URL update helper: `_opdSectionQueryValue` + `_updateUrlForSection` already uses `GoRouter.replace` with `AppRoutes.opd.location(queryParameters: {if tab.isNotEmpty 'section': tab})`.

### Current toolbar (gap)

- `AppTabStrip.primaryAction` is **identical on every tab**: gated `AppTabToolbarPrimary` labeled `l10n.opdStartWalkInAction` ("Start OPD encounter"), icon `opdEncounterIcon`, calling `openOpdWorkspaceEncounterFlow(...)`.
- `secondaryActions` is **not set** (defaults to `[]`).
- Toolbar is therefore **not section-driven** (fails prompt.md contextual-toolbar rule structurally, even though one button exists).

### Current table chrome (gap)

- Settings label already uses `l10n.commonTableSettingsActionLabel` ("Table settings") — keep this shared key.
- Filters button uses `advancedFilterButtonLabel: l10n.opdFilterAction` → **"Filter OPD table"** — **non-compliant**. Must be the standardized label **"Filters"**.
- Dialog title uses `advancedFilterTitle: l10n.opdFiltersLabel` → "OPD filters". Align button (and preferably title) to **"Filters"** via l10n.
- No other table header action buttons beyond search / Filters / Settings — good; keep it that way.
- Row selection opens `_OpdPatientActionsDialog` / `FlowActionsDialog` — **row-local**, must remain dialogs (do not promote Check-in / Prioritize / Move queue / etc. into the tab toolbar).

### Concrete `prompt.md` gaps

1. Table Filters button label is not **"Filters"**.
2. Toolbar actions are not computed from the active `OpdWorkspaceSection` (no per-tab config / no `secondaryActions`).
3. No explicit Refresh affordance in the tab toolbar (controller already has `refresh()`; shell may poll, but screen-level toolbar should expose Refresh as a secondary action for consistency with other standardized workspaces).
4. Optional hardening: document/assert no `AppWorkspace(showHeader: true)` / titled header is introduced while aligning with Reception’s headerless chrome.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative layout contract)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — headerless `ResponsivePage` + `AppTabStrip` + `primaryAction` + `SizedBox(theme.spacing.sm)` + `AppListTable`
- `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`
  — **copy the pattern** of `_primaryActionForSection(...)` so toolbar rebuilds from the active section
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` defaults to `false`; do **not** reintroduce a titled header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — `commonRefreshActionLabel` via `appWorkspaceToolbarWithLabels` / `l10n.commonRefreshActionLabel`
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All worklist | `/opd` (no `section`) | Combined arrivals + queue + triage + active worklist | **Start OPD encounter** (`opdStartWalkInAction`) gated by `opdEncounterPermissionRequirement` → `openOpdWorkspaceEncounterFlow` | **Refresh** (`commonRefreshActionLabel`) → `opdWorkspaceControllerProvider.notifier.refresh()` |
| Arrivals | `/opd?section=arrivals` | Appointment arrivals category (`ARRIVAL`) | Same **Start OPD encounter** primary | **Refresh** |
| Queue | `/opd?section=queue` | Visit-queue entries (`QUEUE`) | Same **Start OPD encounter** primary | **Refresh** |
| Triage | `/opd?section=triage` | Triage queue flows (`TRIAGE`) | Same **Start OPD encounter** primary | **Refresh** |
| Active | `/opd?section=active` | Active OPD flows (`ACTIVE_FLOW`) | Same **Start OPD encounter** primary | **Refresh** |

**Rules for contextual toolbar implementation**

- Build toolbar from `_section` on every rebuild (mirror Physiotherapy’s `_primaryActionForSection`).
- Pass `primaryAction:` and `secondaryActions:` into `AppTabStrip` from a helper such as `_opdToolbarForSection(BuildContext, WidgetRef, OpdWorkspaceSection, OpdWorkspaceState)`.
- Even where primary label is currently the same across tabs, the helper **must** switch on `OpdWorkspaceSection` so future section-specific actions stay localized.
- Do **not** invent new domain create/update APIs.
- Do **not** move row dialog actions (check-in, prioritize, move queue, flow actions) into the toolbar.
- Screen must never be actionless: at least Start OPD encounter **or** Refresh must remain visible; with the table above, both exist on every tab.

### Routing

- Keep `/opd` and `OpdWorkspaceQuery` as-is.
- Preserve aliases already parsed in `_parseOpdSection` (`appointments`→arrivals, `desk-queue`→queue, `flows`/`encounters`→active, etc.).
- Preserve `panel` / `search` / `flowId` deep-link behavior in `_applyRouteQuery`.
- Tab switches must continue to call `_updateUrlForSection`.
- No router file changes required unless tests need an extra deep-link case.

### Page Layout

Precise widget tree after refactor:

1. `AsyncStateScaffold<OpdWorkspaceState>` (unchanged loading/retry)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` — **preferred**, matching Reception
   - Do **not** wrap with a titled `AppWorkspace` header.
   - If you introduce `AppWorkspace`, it **must** use `showHeader: false` and must not render a screen title/toolbar above the tabs.
3. `Column(crossAxisAlignment: stretch)`:
   1. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction:, secondaryActions:)`
   2. `SizedBox(height: theme.spacing.sm)` (keep Reception spacing)
   3. Body: existing `_OpdWorkspaceBody` / `_OpdMainTable` / `AppListTable`
4. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

Reuse (do not replace):

- `opdWorkspaceControllerProvider` / `OpdWorkspaceController.refresh()`
- `OpdWorkspaceState`, `_tableItems`, `_OpdTableFilter`, section filtering via `_opdSectionCategory`
- `openOpdWorkspaceEncounterFlow(context, ref, state)`
- Realtime / adaptive polling already inside the controller — keep intact
- Permission gates: `AppAccessActionGate` + `opdEncounterPermissionRequirement` for Start encounter; Refresh needs no write gate

## Implementation Steps

1. **Normalize Filters label (l10n)** — Files: `frontend/lib/l10n/app_en.arb` (+ regenerate / update generated localizations if the project expects it)
   - Change `opdFilterAction` English value from `"Filter OPD table"` to `"Filters"`.
   - Change `opdFiltersLabel` English value from `"OPD filters"` to `"Filters"` (dialog title / advanced filter title).
   - Keep key names (`opdFilterAction`, `opdFiltersLabel`) to avoid wide renames; only the user-visible strings must become **"Filters"**.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (shared Settings affordance).

2. **Make tab toolbar section-driven** — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
   - In `_OpdWorkspaceContentState.build`, replace the inline `primaryAction:` block with a helper that returns widgets from `_section`.
   - Wire:
     - `primaryAction`: `AppAccessActionGate(requirement: opdEncounterPermissionRequirement, builder: ... AppTabToolbarPrimary(label: l10n.opdStartWalkInAction, icon: opdEncounterIcon, semanticLabel: l10n.opdStartWalkInAction, tooltip: l10n.opdStartEncounterTooltip, ... openOpdWorkspaceEncounterFlow ...))`
     - `secondaryActions`: `[AppTabToolbarAction(label: l10n.commonRefreshActionLabel, icon: Icons.refresh, isLoading: state.isRefreshingAppointments || state.isRefreshingQueue || state.isRefreshingFlows || state.isRefreshingTriageQueue, onPressed: () { unawaited(ref.read(opdWorkspaceControllerProvider.notifier).refresh()); })]`
   - Use a `switch (_section)` (or map) even if cases currently share the same primary, so the toolbar is explicitly contextual.
   - Ensure switching tabs (`_handleTabChanged`) rebuilds toolbar immediately via existing `setState`.

3. **Keep table chrome limited to Filters + Settings** — File: same page (`_OpdMainTable`)
   - Confirm `advancedFilterButtonLabel: l10n.opdFilterAction` now resolves to **"Filters"**.
   - Confirm `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
   - Do not add Refresh / Start encounter / export / overflow actions into `AppListTableSearch` trailing actions.
   - Leave search field in the table (search is not a forbidden table control; Filters + Settings are the only **action buttons** required by `prompt.md`).

4. **Do not relocate row actions** — Keep `_OpdPatientActionsDialog`, `QueueActionsDialog`, `FlowActionsDialog`, `WorkflowActionButton` as-is.

5. **Tests** — File: `frontend/test/features/opd/presentation/opd_workspace_page_test.dart`
   - Keep existing tab URL / deep-link / mobile tests.
   - Add/extend assertions:
     - `AppTabToolbarPrimary` present (Start OPD encounter).
     - Refresh secondary visible (`find.text('Refresh')` or `commonRefreshActionLabel`).
     - After tapping Arrivals / Queue / Triage / Active, toolbar still shows Start + Refresh (section-driven rebuild).
     - Filters button shows text **"Filters"** (when labels are visible at desktop width `1440`).
     - No screen title widget asserting an OPD page header string beyond loading state.
   - Update any assertions that expected `"Filter OPD table"`.

6. **Format / analyze / test** — run verification commands below from `frontend/`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/components.dart` | Worklist; Filters + Settings only in table chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Headerless page shell (Reception pattern) |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Start OPD encounter |
| `AsyncStateScaffold` | shared components barrel | Loading / error / retry |
| `openOpdWorkspaceEncounterFlow` | `package:hosspi_hms/shared/opd_actions/opd_actions.dart` | Primary toolbar handler |
| `opdEncounterPermissionRequirement` / `opdEncounterIcon` | `package:hosspi_hms/shared/components/opd_encounter_dialog.dart` | Permission + icon |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Mobile/tablet/desktop behavior via existing `ResponsivePage` / `AppListTable` |

**Forbidden:** new custom tab bars, new screen header widgets, new table action buttons besides Filters/Settings, new overflow/more menus for screen actions, duplicate refresh FABs.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` | Section-driven `primaryAction` / `secondaryActions`; keep headerless layout |
| `frontend/lib/l10n/app_en.arb` | `opdFilterAction` → `"Filters"`; `opdFiltersLabel` → `"Filters"` |
| `frontend/lib/l10n/app_localizations_en.dart` (and any generated siblings if required by repo workflow) | Sync generated strings after arb change |
| `frontend/test/features/opd/presentation/opd_workspace_page_test.dart` | Toolbar + Filters label assertions |

### Create

| File | Change |
|------|--------|
| *(none required)* | Prefer in-file private helpers over new widgets unless extraction is necessary for clarity |

### Delete

| File | Change |
|------|--------|
| *(none expected)* | Only delete code that becomes dead after toolbar extraction (unused private widgets/imports) |

## Cleanup: Remove Stale Code

- [ ] Remove any leftover commented header / title / FAB / more-menu code if present after edits
- [ ] Ensure no duplicate Refresh controls appear both in a header and under tabs
- [ ] Ensure unused imports are removed
- [ ] Do not leave a second toolbar above `AppTabStrip`

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome / l10n standardization only.

## Responsive Design Requirements

Follow existing `ResponsivePage` + `AppListTable` behavior (do not invent new breakpoints):

- Desktop (≥1200px / `AppBreakpoint.xl+`, tests use `1440`): full tab labels, toolbar primary + secondary with labels, table with Filters + Settings labels visible.
- Tablet (600–1199px / `md`–`lg`): horizontal-scrolling `AppTabStrip`; toolbar wraps via `AppTabStrip`’s `Wrap`; table may compact action labels per `showsToolbarActionLabels` / search-bar rules — keep actions reachable.
- Mobile (`<600`): drawer/shell navigation elsewhere; OPD body uses `mobileItemBuilder` (`_OpdTableMobileRow`); tabs remain at top; toolbar remains under tabs; no FAB.

## Verification Steps

Run from `frontend/`:

```bash
dart format lib/features/opd lib/l10n test/features/opd
dart analyze --fatal-infos lib/features/opd test/features/opd
flutter test test/features/opd/
flutter test test/shared/
```

If the repo uses code generation for l10n, run the project’s standard gen-l10n command before analyze/test.

## Testing Requirements

- [ ] Tab switch updates URL (`section=arrivals|queue|triage|active`; All clears `section`) and rebuilds toolbar from `_section`
- [ ] Deep link `/opd?section=triage` opens Triage tab
- [ ] Per-tab toolbar shows that tab’s configured actions (Start OPD encounter + Refresh on every tab per table above)
- [ ] Table chrome has only Filters + Settings action buttons (plus search field)
- [ ] Filters button label is exactly **Filters**
- [ ] No screen title/header chrome remains (no `AppWorkspace` title bar)
- [ ] At least one toolbar button exists on the screen
- [ ] Permissions still gate Start OPD encounter via `AppAccessActionGate` / `opdEncounterPermissionRequirement`
- [ ] Row actions still open dialogs; domain refresh/realtime still work
- [ ] Responsive layouts still work (desktop + mobile tests)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` + `secondaryActions` driven by `OpdWorkspaceSection`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Table Filters label is **Filters**; Settings uses `commonTableSettingsActionLabel`
- [ ] Domain logic preserved (worklist, deep links, dialogs, permissions, realtime)
- [ ] Analyze clean; tests pass; stale chrome code removed
