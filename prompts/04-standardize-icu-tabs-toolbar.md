# Standardize ICU Screen (Tabs & Toolbar)

## Objective

Refactor the ICU workspace (`/icu`, `IcuWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.
**Preserve all ICU domain logic** (board scopes, bed board, detail dialogs, alerts, transfers,
discharge readiness, permissions, counts, deep links). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
  - `IcuWorkspacePage` → `AsyncStateScaffold` → `_IcuWorkspaceContent`
  - Board table: `_IcuBoardPanel` (`AppListTable<IcuPatientSummary>`)
  - Detail UI: `_IcuDetailPanel` / `_IcuActionPanel` (dialog-only — **do not move** into screen toolbar)
  - Dialogs / helpers live in the same page file (`_ObservationDialog`, `_VitalsDialog`,
    `_CriticalAlertDialog`, `_TransferRequestDialog`, `_ManageTransferDialog`,
    `_ReadinessDialog`, `_AssignBedDialog`, clinical order dialogs, print summary)
- Bed board: `frontend/lib/features/icu/presentation/widgets/icu_bed_board_panel.dart`
  - Widget: `IcuBedBoardPanel`
- Format helpers: `frontend/lib/features/icu/presentation/widgets/icu_format.dart`
- Controller: `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart`
  - Provider: `icuWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyScope(IcuBoardScope)`, `applySearch(String)`,
    `loadBedBoard()`, `selectBedWard(String?)`, `startIcuStay()`, `selectPatient*()`,
    mutation helpers for alerts / transfers / discharge / vitals / orders
- Domain: `frontend/lib/features/icu/domain/entities/icu_entities.dart`
  - Tabs: `IcuWorkspaceSection` (`active`, `critical`, `transfers`, `discharge`, `ended`, `all`, `beds`)
  - Scopes: `IcuBoardScope` (`active`, `critical`, `transfer`, `discharge`, `ended`, `all`)
  - Query: `IcuBoardQuery.fromUri` parses `section`, `id|admission|…`, `search|q`, `panel`
- Repository: `frontend/lib/features/icu/data/repositories/icu_repository_impl.dart`
- Routes: `AppRoutes.icu` path `/icu` in `frontend/lib/app/router/app_routes.dart`;
  builder in `frontend/lib/app/router/app_router.dart` passes `IcuBoardQuery.fromUri(state.uri)`
- Tests:
  - `frontend/test/features/icu/presentation/icu_workspace_page_test.dart`
  - `frontend/test/features/icu/presentation/icu_workspace_controller_test.dart`
  - `frontend/test/features/icu/data/icu_dtos_test.dart`

### Current widget tree (chrome)

```
AsyncStateScaffold<IcuWorkspaceState>
  └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
              ├── AppTabStrip(
              │     tabs: all IcuWorkspaceSection.values,
              │     primaryAction: Start ICU stay (gated) — omitted when section.isBedBoard,
              │     secondaryActions: <none>
              │   )
              ├── SizedBox(height: theme.spacing.sm)
              └── body:
                    ├── table tabs → _IcuBoardPanel → AppListTable
                    └── beds → IcuBedBoardPanel (AppWorkspaceDetailPanel title + description)
```

- **No page-level `AppWorkspace` title header** — uses `ResponsivePage` like Reception (acceptable
  equivalent to `AppWorkspace(showHeader: false)`).
- **Deep-link tab state is already URL-backed** via `?section=<IcuWorkspaceSection.name>`
  (`_updateUrlForSection` + `IcuBoardQuery.fromUri` → `initialQuery.section` →
  `_sectionFromQueryValue`). Default Active omits `section` from the URL (`tab != 'active'`).
- Focus deep links (`?id=` / `?panel=`) already open the stay detail dialog and focus panels.

### Confirmed tab inventory

| # | Tab label (l10n key → EN) | Enum `IcuWorkspaceSection` | Query `section=` | Board scope | Primary toolbar today |
|---|---------------------------|----------------------------|------------------|-------------|------------------------|
| 1 | Active ICU (`icuActiveIcuLabel`) | `active` | *(omitted)* / `active` | `IcuBoardScope.active` | **Start ICU stay** (`icuActionStartStay`) via `AppAccessActionGate` + `AppTabToolbarPrimary` |
| 2 | Critical alerts (`icuCriticalAlertsLabel`) | `critical` | `critical` | `IcuBoardScope.critical` | Same Start ICU stay |
| 3 | Transfers (`icuTransfersLabel`) | `transfers` | `transfers` | `IcuBoardScope.transfer` | Same Start ICU stay |
| 4 | Discharge ready (`icuDischargeReadyLabel`) | `discharge` | `discharge` | `IcuBoardScope.discharge` | Same Start ICU stay |
| 5 | Ended stays (`icuEndedStaysLabel`) | `ended` | `ended` | `IcuBoardScope.ended` | Same Start ICU stay |
| 6 | All ICU (`icuAllIcuLabel`) | `all` | `all` | `IcuBoardScope.all` | Same Start ICU stay |
| 7 | Bed board (`icuViewBedBoard`) | `beds` | `beds` | *(none — `toBoardScope()` returns null)* | **none** (`primaryAction: null`) |

Write gate for Start ICU stay (keep):

```dart
AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['icu-critical-care'],
)
```

Defined as `_IcuWorkspaceContent.writeRequirement`.

### Table chrome today

- Search via `AppListTableSearch` (`l10n.icuSearchHint`) → `controller.applySearch`
- Settings via `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` +
  `AppListTableColumnVisibilityController` (`columnVisibilityStorageKey: 'icu_board'`)
- **No** `filterGroups` / `textFilters` / `advancedFilterButtonLabel` → Filters button correctly
  absent until real filters exist
- No other table-header actions beyond Settings (compliant if Filters stay out unless wired)

### Concrete `prompt.md` gaps

1. **Bed board tab has an empty toolbar.** `primaryAction: null` and `secondaryActions` empty →
   `AppTabStrip` omits the toolbar row entirely on Bed board. Screen still has Start ICU stay on
   other tabs (satisfies “at least one button somewhere”), but Bed board is actionless. Peers
   (Emergency / Access Admin / IPD prompts) expose **Refresh** on every tab.
2. **No Refresh secondary** on any tab. Manual refresh exists only via `AsyncStateScaffold` retry /
   controller internals. Access Admin pattern: `AppTabToolbarAction` + `l10n.commonRefreshActionLabel`.
3. **Toolbar is only weakly contextual.** Start ICU stay is identical on all six patient-board tabs;
   only Bed board differs (by omitting it). Need an explicit per-tab matrix including universal
   Refresh, and Bed board must never be toolbar-empty.
4. **Bed board has dedicated title/header chrome.** `IcuBedBoardPanel` wraps content in
   `AppWorkspaceDetailPanel(title: l10n.icuBedBoardTitle, description: l10n.icuBedBoardDescription)`.
   That title row violates “no dedicated screen title/header” for the tab body (same gap as IPD
   bed board in `prompts/01-standardize-ipd-tabs-toolbar.md`).
5. **Start ICU stay in the screen toolbar is selection-gated**
   (`state.selectedDetail?.isEligibleToStartStay`) and is **duplicated** inside `_IcuActionPanel`
   in the stay detail dialog. Keep the existing board primary for patient tabs (do not invent a
   new board CTA), but do **not** move any other detail-dialog actions into the screen toolbar.
6. **Already compliant (do not regress):** no page title header; `AppTabStrip` under
   `ResponsivePage`; table limited to search + Settings; write actions gated; deep-link
   `?section=`; no screen-level overflow / FAB / more-menu.

### Preserve (do not relocate to tab toolbar)

- **Stay detail dialog actions** in `_IcuActionPanel` / `AppActionPanel` (Start stay, Record
  observation/vitals, Raise/Acknowledge alert, Round, Lab/Imaging/Prescribe, Assign bed,
  Request/Manage transfer, Mark readiness, Open discharge clearance, Open billing/IPD, End stay,
  Print summary) — patient-scoped; stay in the detail dialog.
- **Bed row Open IPD** icon button in `_IcuBedRow` — row-local navigation; keep.
- **Ward `ChoiceChip` filters** inside the bed board body — content filters, not screen header
  actions; keep in the bed board body (not a “more” menu).
- Permission gate `_IcuWorkspaceContent.writeRequirement` / `AppAccessActionGate`.
- Deep-link focus behavior (`id` + `panel` → `_openIcuDetailDialog` / `_openFocusPanel`).

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — canonical layout: `ResponsivePage` + `AppTabStrip` + `SizedBox(sm)` + `AppListTable`;
  `primaryAction` via `AppAccessActionGate` + `AppTabToolbarPrimary`; query-backed tabs
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
  — Refresh as `AppTabToolbarAction` in `secondaryActions` with `l10n.commonRefreshActionLabel`
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  — contextual `primaryAction` via `switch` on section (pattern reference)
- `prompts/01-standardize-ipd-tabs-toolbar.md` / `prompts/02-standardize-emergency-tabs-toolbar.md`
  — sibling screen standardization contracts (bed-board title removal + Refresh secondary)
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader: false` semantics; prefer keeping
  ICU on `ResponsivePage` like Reception (do **not** add a titled `AppWorkspace` header)
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Active ICU | `/icu` (default) or `/icu?section=active` | Active ICU stays (`IcuBoardScope.active`) | **Start ICU stay** — `AppTabToolbarPrimary` (`l10n.icuActionStartStay`, `Icons.play_circle_outline`) wrapped in `AppAccessActionGate(requirement: writeRequirement)`; enabled when `isAllowed && (state.selectedDetail?.isEligibleToStartStay ?? false) && !state.isSaving`; confirms via existing `_confirmAction` → `controller.startIcuStay` | **Refresh** — `AppTabToolbarAction` (`l10n.commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()` |
| Critical alerts | `/icu?section=critical` | Patients with critical alerts | Same **Start ICU stay** (gated) | Same **Refresh** → `controller.refresh()` |
| Transfers | `/icu?section=transfers` | Open / pending transfers | Same **Start ICU stay** (gated) | Same **Refresh** |
| Discharge ready | `/icu?section=discharge` | Discharge-planned / ready | Same **Start ICU stay** (gated) | Same **Refresh** |
| Ended stays | `/icu?section=ended` | Ended ICU stays | Same **Start ICU stay** (gated) | Same **Refresh** |
| All ICU | `/icu?section=all` | Full ICU board | Same **Start ICU stay** (gated) | Same **Refresh** |
| Bed board | `/icu?section=beds` | ICU ward bed occupancy | *none* (`primaryAction: null`) — do **not** show Start ICU stay on bed board (current behavior) | **Refresh** — `AppTabToolbarAction` → `controller.loadBedBoard()` (required so Bed board is not toolbar-empty). Optionally also call `controller.refresh()` if you want board counts refreshed; bed list must reload via `loadBedBoard`. |

**Rules for the matrix**

- Toolbar must rebuild when `_section` changes (`setState` already runs in `onTabTapped`).
- Do **not** move detail-dialog `_IcuActionPanel` items into the screen toolbar.
- Do **not** reintroduce a board-scope dropdown, FAB, or header more-menu.
- Screen must always expose at least one toolbar control overall (Start ICU stay + Refresh satisfy this; Bed board Refresh alone satisfies that tab).
- Bed board **must** show Refresh so the toolbar row is not omitted on that tab.

### Routing

- Keep `/icu` registration in `app_router.dart` / `AppRoutes.icu`.
- Keep query key **`section`** with values equal to `IcuWorkspaceSection.name`
  (`active|critical|transfers|discharge|ended|all|beds`).
- Keep `IcuBoardQuery.fromUri` keys: `section`; focus `id|admission|admissionId|admission_id`;
  `search|q`; `panel` → `IcuDetailPanel`.
- On tab tap: continue `GoRouter.replace` via `_updateUrlForSection` then `applyScope` /
  `loadBedBoard` as today. Default Active may omit `section` from the URL (current behavior).
- No new query param required — tab state is already deep-linkable. Confirm tests cover
  `?section=critical` and `?section=beds` (already present in `icu_workspace_page_test.dart`).

### Page Layout

Precise widget tree for `_IcuWorkspaceContent.build` (match Reception; do not add a title header):

1. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: SizedBox(width: infinity, child: Column(...)))`
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction:, secondaryActions:)`
3. `SizedBox(height: theme.spacing.sm)` — keep vertical rhythm identical to Reception
4. Body:
   - If `_section.isBedBoard` → `IcuBedBoardPanel(...)` **without** panel title/description/header actions
   - Else → `_IcuBoardPanel(...)` `AppListTable` with search + **only** Settings (and Filters
     only if you add real `filterGroups`/`textFilters`; label must be exactly **Filters** via an
     existing l10n key such as `nursingAdvancedFiltersLabel` — do **not** invent a third table
     action; prefer leaving Filters absent until wired)
5. No FAB / floating header actions / overflow more-menu for screen actions
6. Do **not** wrap with `AppWorkspace(showHeader: true)`. If you introduce `AppWorkspace`, it must
   be `showHeader: false` and must not duplicate the tab toolbar.

### Data & State Management

Reuse as-is (adjust only call sites for toolbar Refresh):

- Provider: `icuWorkspaceControllerProvider` in
  `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart`
- Methods: `refresh()`, `applyScope(IcuBoardScope)`, `applySearch(String)`, `loadBedBoard()`,
  `selectBedWard(String?)`, `startIcuStay()`, `selectPatient` / `selectPatientByDisplayId`
- Section → scope mapping: `IcuWorkspaceSectionX.toBoardScope()` (beds → `null`)
- Permissions: `_IcuWorkspaceContent.writeRequirement` for Start ICU stay
- Counts / tones: keep `_sectionCount` / `_sectionCountTone` / tab icons / labels as today

## Implementation Steps

1. **Add contextual toolbar builders on `_IcuWorkspaceContentState`** — File:
   `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Extract `_buildPrimaryAction(l10n, state, controller)` and `_buildSecondaryActions(...)`.
   - Primary: return the existing Start ICU stay `AppAccessActionGate` + `AppTabToolbarPrimary`
     when `!_section.isBedBoard`; return `null` for Bed board.
   - Secondary: always include Refresh `AppTabToolbarAction`:
     - Patient tabs → `() => unawaited(controller.refresh())`
     - Bed board → `() => unawaited(controller.loadBedBoard())`
   - Pass `primaryAction` / `secondaryActions` into `AppTabStrip`.
   - Import/use `AppTabToolbarAction` from `package:hosspi_hms/shared/components/components.dart`
     (already exported via `app_tab_strip.dart`).

2. **Remove Bed board dedicated title chrome** — File:
   `frontend/lib/features/icu/presentation/widgets/icu_bed_board_panel.dart`
   - Stop wrapping the body in `AppWorkspaceDetailPanel(title:, description:)`.
   - Render the ward chips, occupancy badges, loading/empty states, and bed rows directly in a
     `Column` (or equivalent) under the tab toolbar.
   - Keep ward chips, badges, empty state (`icuBedNoBedsTitle` / `icuBedNoBedsBody`), and
     `_IcuBedRow` Open IPD behavior unchanged.
   - Update tests that assert `find.text('ICU bed board')` — that title must go away; assert
     bed content / `IcuBedBoardPanel` instead.

3. **Keep table chrome Filters/Settings contract** — File:
   `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` (`_IcuBoardPanel`)
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (shared Settings affordance).
   - Do **not** add Filters unless you also wire real `filterGroups` / `textFilters`. If you do,
     set `advancedFilterButtonLabel` to a key whose EN value is exactly **Filters**
     (e.g. `nursingAdvancedFiltersLabel`), not `icuBoardFiltersTitle` (“ICU board filters”).
   - Move no other actions into the table header.

4. **Do not invent domain CTAs** — Keep Start ICU stay semantics and eligibility gating identical.
   Do not add board-level Raise alert / Request transfer / Mark readiness to the toolbar
   (those require a selected patient and already live in `_IcuActionPanel`).

5. **Update widget tests** — File:
   `frontend/test/features/icu/presentation/icu_workspace_page_test.dart`
   - Expect Refresh on Active ICU (tooltip/label from `commonRefreshActionLabel`).
   - On `section=beds` / Bed board tab: expect Refresh present; Start ICU stay still absent;
     do **not** expect `ICU bed board` title text.
   - Keep existing coverage for tab strip, section deep links, search, detail deep link, column
     visibility storage keys.

6. **Format / analyze / test** — Run the verification commands below; fix any issues introduced.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Patient board table; Settings only in table chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page width shell (Reception pattern) |
| `AsyncStateScaffold` | shared layout/components barrel already used by page | Loading / error / retry |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Start ICU stay |
| `AppWorkspaceStatePanel` / `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Empty/loading panels & badges — **not** as a titled screen header |
| `AppBreakpoints` / responsive utilities | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Follow existing `AppListTable` mobile builders |

**Forbidden:** new custom tab bars, duplicate toolbars, screen-level PopupMenuButton “more” menus
for chrome actions, new table header buttons besides Filters/Settings.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` |
| Modify | `frontend/lib/features/icu/presentation/widgets/icu_bed_board_panel.dart` |
| Modify | `frontend/test/features/icu/presentation/icu_workspace_page_test.dart` |
| Read-only reference | `prompt.md`, Reception / Access Admin / shared chrome files above |
| Do not create | New tab/toolbar/filter widgets when shared ones exist |
| Do not delete | Domain dialogs, controller, repository, entities |

## Cleanup: Remove Stale Code

- [ ] Remove `AppWorkspaceDetailPanel` title/description wrapper from `IcuBedBoardPanel` (or stop
      passing title/description so no dedicated header row remains)
- [ ] Ensure Bed board no longer asserts / displays `icuBedBoardTitle` (“ICU bed board”) as page chrome
- [ ] Confirm no leftover FAB / page-header action row / overflow more-menu for screen actions
- [ ] Grep for unused imports after edits (`icuBedBoardTitle` / `icuBedBoardDescription` may become
      unused in the bed board widget — remove unused l10n references from that file; do **not**
      delete arb keys unless confirmed unused app-wide)
- [ ] Keep `_IcuActionPanel` detail actions intact (do not delete as “duplicates” of Start stay)

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): `AppTabStrip` full width; toolbar primary right-aligned, secondaries left;
  `AppListTable` desktop columns; bed board list rows as today.
- Tablet (600–1023px): Horizontal-scrolling tabs (already in `AppTabStrip`); toolbar wrap via
  existing `Wrap` spacing; table may use compact layout from `AppListTable`.
- Mobile (<600px): Keep `_IcuBoardPanel.mobileItemBuilder`; toolbar actions remain under tabs
  (icon+label via `AppTabToolbarAction` / `AppTabToolbarPrimary`); no stray floating actions.

Follow existing `theme.spacing.sm` gap between tab strip and body (Reception).

## Verification Steps

```bash
cd frontend
dart format lib/features/icu test/features/icu
dart analyze --fatal-infos lib/features/icu test/features/icu
flutter test test/features/icu/
flutter test test/shared/
```

Also acceptable from repo root if the project’s usual workflow runs Flutter from `frontend/`.

## Testing Requirements

- [ ] Tab switch updates URL `section` (non-active) and toolbar actions
- [ ] Deep link `/icu?section=critical` opens Critical alerts tab
- [ ] Deep link `/icu?section=beds` opens Bed board with Refresh visible and Start ICU stay hidden
- [ ] Per-tab toolbar shows only that tab’s actions (Bed board ≠ patient tabs)
- [ ] Table chrome has only Settings (and Filters only if real filters are wired with label **Filters**)
- [ ] No screen title/header chrome remains (including Bed board “ICU bed board” panel title)
- [ ] At least one toolbar button exists on every tab (Refresh on Bed board; Start stay + Refresh elsewhere)
- [ ] Permissions still gate Start ICU stay via `AppAccessActionGate`
- [ ] Detail dialog actions still work; focus deep links (`id` + `panel`) still work
- [ ] Responsive layouts still work

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Bed board title panel removed; Refresh present on Bed board
- [ ] Domain logic preserved (scopes, counts, dialogs, permissions, deep links)
- [ ] Analyze clean; tests pass; stale chrome removed
