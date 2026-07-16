# Standardize IPD Screen (Tabs & Toolbar)

## Objective

Refactor the IPD workspace (`/ipd`, `IpdWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all IPD domain logic** (scopes, bed board, admission dialogs, detail dialogs, permissions,
counts, deep links). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
  - Widgets: `IpdWorkspacePage` → `AsyncStateScaffold` → `_IpdWorkspaceContent`
  - Queue table: `_IpdBoardPanel` (`AppListTable<IpdAdmissionSummary>`)
  - Detail UI: `_IpdDetailPanel` / `_IpdDetailActions` (dialog-only — **do not move** into screen toolbar)
- Bed board: `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart`
  - Widget: `IpdBedBoardPanel`
- Controller: `frontend/lib/features/ipd/presentation/controllers/ipd_workspace_controller.dart`
  - Provider: `ipdWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyScope()`, `applySearch()`, `applyWard()`, `loadBedBoard()`,
    `applyBedBoardWard()`, `applyBedBoardStatus()`, `applyRouteQuery()`, `selectAdmission*()`
- Domain: `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`
  - Enums: `IpdWorkspaceSection`, `IpdQueueScope`, `IpdAdmissionQuery`
  - Section query parser: `IpdWorkspaceSectionX.fromQueryParam`
- Start admission dialog: `frontend/lib/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart`
- Routes: `AppRoutes.ipd` (`/ipd`) in `frontend/lib/app/router/app_routes.dart`;
  builder in `frontend/lib/app/router/app_router.dart` passes `IpdAdmissionQuery.fromUri(state.uri)`

### Current layout (already partially compliant)

```
ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
  └── Column
        ├── AppTabStrip(
        │     tabs: 5 sections,
        │     primaryAction: AppAccessActionGate → AppTabToolbarPrimary("Start admission"),
        │     secondaryActions: <none>
        │   )
        ├── SizedBox(height: theme.spacing.sm)
        └── body:
              ├── queue tabs → _IpdBoardPanel → AppListTable
              └── bed board → IpdBedBoardPanel
```

- **No page-level `AppWorkspace` title header** — uses `ResponsivePage` like Reception (acceptable equivalent to `AppWorkspace(showHeader: false)`).
- **Deep link already works** via `?section=<value>` (`_updateUrlForSection` + `IpdAdmissionQuery.fromUri`).
- **Tabs already use** `AppTabStrip` / `AppTabItem` with counts.

### Confirmed tab inventory

| # | Tab label (l10n) | Enum | Query `section=` | Primary toolbar today |
|---|------------------|------|------------------|-----------------------|
| 1 | Admission Queue (`ipdAdmissionQueueTabLabel`) | `IpdWorkspaceSection.admissionQueue` | `admission-queue` | Start admission (`ipdStartAdmissionAction`) — **same on all tabs** |
| 2 | Active Patients (`ipdActivePatientsTabLabel`) | `IpdWorkspaceSection.activePatients` | `active` | Start admission (not contextual) |
| 3 | Transfers (`ipdTransfersTabLabel`) | `IpdWorkspaceSection.transferPending` | `transfers` | Start admission (not contextual) |
| 4 | Discharge (`ipdDischargeTabLabel`) | `IpdWorkspaceSection.dischargePlanned` | `discharge` | Start admission (not contextual) |
| 5 | Bed board (`ipdBedBoardTab`) | `IpdWorkspaceSection.bedBoard` | `bed-board` | Start admission (not contextual); **Manage beds** lives in bed-board panel header |

Aliases already accepted by `IpdWorkspaceSectionX.fromQueryParam` (keep all):
`admission-queue` / `queue`, `active` / `active-patients`, `transfers` / `transfer-pending`,
`discharge` / `discharge-planned`, `bed-board` / `beds`.

### Concrete `prompt.md` gaps

1. **Toolbar is not contextual.** `primaryAction` is always Start admission for every tab, including Bed board. `secondaryActions` is never set.
2. **Bed board has a dedicated title/header chrome.** `IpdBedBoardPanel` wraps the table in `AppWorkspaceDetailPanel(title: l10n.ipdBedBoardTitle, description: l10n.ipdBedBoardDescription, actions: [Manage beds])`. That title row + action strip violates “no dedicated screen title/header” and “actions only in tab toolbar”.
3. **Manage beds is outside the tab toolbar.** `ipdBedBoardManageBedsAction` is rendered as `AppButton.tertiary` inside `AppWorkspaceDetailPanel.actions`, not as `AppTabToolbarPrimary` / `AppTabToolbarAction`.
4. **Table Filters label is non-standard.** Both `_IpdBoardPanel` and `IpdBedBoardPanel` use `advancedFilterButtonLabel: l10n.ipdFiltersLabel` which resolves to **"Inpatient filters"**. Must be **"Filters"** (update arb / wire label accordingly). Settings already uses `l10n.commonTableSettingsActionLabel` — keep that key (shared standard across workspaces).
5. **Bed board table lacks Settings.** `IpdBedBoardPanel`’s `AppListTable` has Filters but no `columnVisibilityController` / `columnVisibilityLabel` — add Settings parity with the queue table.
6. **No screen-level Refresh** in the tab toolbar (useful secondary; controller already exposes `refresh()`; l10n key `commonRefreshActionLabel` exists).

### Preserve (do not relocate to tab toolbar)

- **Admission detail dialog actions** (`_IpdDetailActions` / `AppActionList`) — patient-scoped workflow; stay in the detail dialog.
- **Row-level `WorkflowActionButton`** in the Pending Action column — table cell workflow, not screen header chrome.
- **Bed board row next-action `PopupMenuButton` (`_BedActionMenu`)** — per-bed status/open-admission actions; keep as row-local (not a screen/header overflow menu). Do **not** convert these into screen toolbar buttons.
- Permission gates: `_ipdOperationalWriteRequirement`, `_ipdBedManageRequirement`, `_ipdClinicalWriteRequirement`.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — `ResponsivePage` + `AppTabStrip` + `primaryAction` + `SizedBox(height: theme.spacing.sm)` + body table; no page title header
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  — **contextual** `primaryAction` via `switch (_section)`; `secondaryActions` list
- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
  — `secondaryActions` + gated `primaryAction` pattern
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace(showHeader: false)` semantics; prefer keeping IPD on `ResponsivePage` like Reception
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Admission Queue | `/ipd?section=admission-queue` | Pending / queue admissions (`IpdQueueScope.admissionQueue`) | **Start admission** — `AppTabToolbarPrimary` + `AppAccessActionGate(_ipdOperationalWriteRequirement)`; opens `IpdStartAdmissionDialog` via existing `_openStartAdmissionDialog` | **Refresh** — `AppTabToolbarAction` (`commonRefreshActionLabel`, `Icons.refresh`); calls `ipdWorkspaceControllerProvider.notifier.refresh()` |
| Active Patients | `/ipd?section=active` | In-bed / active census (`IpdQueueScope.activePatients`) | Same **Start admission** (gated) | Same **Refresh** |
| Transfers | `/ipd?section=transfers` | Transfer-pending queue (`IpdQueueScope.transferPending`) | Same **Start admission** (gated) | Same **Refresh** |
| Discharge | `/ipd?section=discharge` | Discharge-planned queue (`IpdQueueScope.dischargePlanned`) | Same **Start admission** (gated) | Same **Refresh** |
| Bed board | `/ipd?section=bed-board` | Live bed occupancy board | **Manage beds** — `AppTabToolbarPrimary` when `_ipdBedManageRequirement` allows; `onPressed` → `context.go(AppRoutes.roomsBeds.path)` (same as today’s `onManageBeds`). If user cannot manage beds, fall back primary to gated **Start admission** so the toolbar is never empty. | **Refresh** (always). If Manage beds is primary, also show gated **Start admission** as `AppTabToolbarAction` secondary so admission remains reachable from Bed board. |

Toolbar must rebuild when `_section` changes (`setState` already happens in `_selectSection`).

### Routing

- Keep `/ipd` route and `IpdAdmissionQuery.fromUri` — **no router structural changes required**.
- Keep canonical write values from `_sectionToQueryValue`:
  - `admission-queue`, `active`, `transfers`, `discharge`, `bed-board`
- Keep `GoRouter.replace` on tab change.
- Keep focus deep links (`?id=` / admission id → open detail dialog) via existing `_applyRouteQuery`.

### Page Layout

Precise widget tree for `_IpdWorkspaceContent.build`:

1. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: …)` — **do not** introduce a titled `AppWorkspace` header. If you wrap with `AppWorkspace`, it **must** be `showHeader: false` with no title/actions on the workspace chrome.
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: _buildPrimaryAction(...), secondaryActions: _buildSecondaryActions(...))`
3. `SizedBox(height: theme.spacing.sm)` (match Reception)
4. Body:
   - If `_section.isBedBoard` → `IpdBedBoardPanel(...)` **without** panel title/description/header actions
   - Else → `_IpdBoardPanel(...)` `AppListTable` with **only** Filters + Settings in table chrome
5. No FAB, no floating header actions, no screen-level overflow/more menu for chrome actions

### Data & State Management

Reuse as-is (adjust call sites only if needed for toolbar wiring):

| Symbol | Path |
|--------|------|
| `ipdWorkspaceControllerProvider` / `IpdWorkspaceController` | `frontend/lib/features/ipd/presentation/controllers/ipd_workspace_controller.dart` |
| `IpdWorkspaceState`, `IpdAdmissionQuery`, `IpdWorkspaceSection` | `frontend/lib/features/ipd/domain/entities/ipd_entities.dart` |
| `appAccessPolicyProvider` | `frontend/lib/core/permissions/permission_providers.dart` |
| Existing access requirements in page file | `_ipdOperationalWriteRequirement`, `_ipdBedManageRequirement`, `_ipdClinicalWriteRequirement` |

## Implementation Steps

1. **Make tab toolbar contextual in `_IpdWorkspaceContent`** — File: `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
   - Extract helpers (private methods on `_IpdWorkspaceContentState`), mirroring Housekeeping’s `switch (_section)` pattern:
     - `Widget? _buildPrimaryAction(AppLocalizations l10n, IpdWorkspaceState state, bool canManageBeds)`
     - `List<Widget> _buildSecondaryActions(AppLocalizations l10n, IpdWorkspaceState state, bool canOperate)`
   - Wire into `AppTabStrip(primaryAction:, secondaryActions:)`.
   - Queue tabs (admission / active / transfers / discharge):
     - `primaryAction`: existing `AppAccessActionGate` + `AppTabToolbarPrimary` for Start admission.
     - `secondaryActions`: Refresh `AppTabToolbarAction` calling `ref.read(ipdWorkspaceControllerProvider.notifier).refresh()`.
   - Bed board tab:
     - Prefer Manage beds as `AppTabToolbarPrimary` when `canManageBeds` (`_ipdBedManageRequirement.isAllowed(policy)` — already computed).
     - Else primary = gated Start admission.
     - Secondary: Refresh always; if Manage beds is primary, add gated Start admission as `AppTabToolbarAction`.
   - Remove the duplicate `SizedBox` / stray actions if any appear outside `AppTabStrip`.

2. **Strip bed-board panel header chrome** — File: `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart`
   - Remove `AppWorkspaceDetailPanel` title/description/actions wrapper **or** render the table without a titled header (e.g. return the `AppListTable` directly, or use `AppWorkspaceDetailPanel` only if title/actions are omitted and no header row paints).
   - Remove the in-panel `AppButton.tertiary` for Manage beds (now in tab toolbar). Keep `onManageBeds` callback on the widget **only if** still needed; prefer invoking navigation from the page toolbar and deleting unused callback props if dead.
   - Keep search, ward/status filters, columns, row `_BedActionMenu`, and controller calls intact.
   - Add column Settings parity:
     - Accept or create `AppListTableColumnVisibilityController<IpdBedBoardEntry>`
     - Set `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`
     - Prefer storage keys like `ipd_bed_board` / `ipd_bed_board_cw` (match Reception/RoomsBeds pattern).

3. **Standardize Filters label to "Filters"** — Files: `frontend/lib/l10n/app_en.arb` (+ regenerate / update generated localizations as this repo normally does)
   - Change `ipdFiltersLabel` English value from `"Inpatient filters"` to `"Filters"`.
   - Keep using `l10n.ipdFiltersLabel` for `advancedFilterButtonLabel` (and dialog title is OK as "Filters").
   - Apply in both `_IpdBoardPanel` and `IpdBedBoardPanel`.
   - Keep Apply/Clear labels as today (`opdApplyFiltersAction` / `opdClearFiltersAction`) unless a shared Filters dialog pattern already differs in Reception — do not invent new filter UI.

4. **Queue table chrome hygiene** — File: `ipd_workspace_page.dart` (`_IpdBoardPanel`)
   - Ensure table chrome only exposes Filters + Settings (already true aside from Filters wording).
   - Optionally add `columnVisibilityStorageKey` / `columnWidthStorageKey` keyed by section (e.g. `ipd_${section}`) if not already present — follow Reception’s `reception_${_section.name}` pattern when touching this area.
   - Do **not** move search out of `AppListTableSearch`.

5. **Update / extend widget tests** — File: `frontend/test/features/ipd/presentation/ipd_workspace_page_test.dart`
   - Keep existing tab/URL/deep-link/Start-admission coverage.
   - Add assertions:
     - On Bed board tab (or deep link `section=bed-board`), Manage beds appears in tab toolbar (tooltip/label `Manage beds` / `ipdBedBoardManageBedsAction`) and **not** as a panel header action.
     - Switching from Admission Queue → Bed board changes toolbar contents (Start admission vs Manage beds as specified).
     - Refresh toolbar action is present on at least one tab.
     - No `AppWorkspaceDetailPanel` title text for bed board title when that header is removed (assert `ipdBedBoardTitle` string is absent from the bed-board body chrome if you removed it).
   - Adjust stubs/policy if Manage beds requires admin roles (`_ipdBedManageRequirement` uses admin roles) — either elevate test policy for that case or assert fallback Start admission when manage is denied.

6. **Format, analyze, test** — run verification commands below; fix any regressions without expanding scope.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/components.dart` (impl: `app_tab_strip.dart`) | Screen tabs + contextual toolbar |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/components.dart` | Queue + bed board tables; Filters + Settings only |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Page shell without title header |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Start admission |
| `AsyncStateScaffold` | shared layout/components (already used) | Loading/error shell |
| `AppWorkspaceDetailPanel` | `app_workspace.dart` | **Only** for dialog detail content (`_IpdDetailPanel`); **not** for bed-board screen chrome |
| `commonTableSettingsActionLabel` | l10n | Settings button label |
| `ipdFiltersLabel` (value → `Filters`) | l10n | Filters button label |
| `commonRefreshActionLabel` | l10n | Refresh toolbar secondary |
| `ipdStartAdmissionAction` | l10n | Start admission |
| `ipdBedBoardManageBedsAction` | l10n | Manage beds |

**Forbidden:** new custom tab bars, new screen header widgets, new overflow/more menus for screen actions, duplicating filter/settings chrome outside `AppListTable`.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` | Contextual `primaryAction` / `secondaryActions`; keep section routing |
| `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart` | Remove titled header + Manage beds panel action; add Settings; Filters label |
| `frontend/lib/l10n/app_en.arb` | `ipdFiltersLabel` → `"Filters"` |
| Generated l10n outputs as required by project workflow (`app_localizations*.dart`) | Reflect arb change |
| `frontend/test/features/ipd/presentation/ipd_workspace_page_test.dart` | Toolbar / bed-board chrome assertions |

### Create

- None required (unless you extract a tiny private toolbar builder into the same page file for clarity — do not create a new shared tab system).

### Delete

- Dead bed-board header action wiring once moved (unused imports, unused `onManageBeds` if fully inlined at page level — only if no longer referenced).

## Cleanup: Remove Stale Code

- [ ] No `AppWorkspaceDetailPanel` title/description/actions on the Bed board **screen** body
- [ ] No Manage beds button outside `AppTabStrip` toolbar
- [ ] No screen-level `PopupMenuButton` / “more” for chrome actions
- [ ] No duplicate Start admission buttons (toolbar only)
- [ ] No leftover unused imports after header removal
- [ ] Filters button visible label is exactly **Filters** (EN)
- [ ] Settings still via `commonTableSettingsActionLabel`

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

Follow existing `ResponsivePage` + `AppListTable` behavior (same as Reception):

- **Desktop (≥1024px / wide):** full tab strip + labeled toolbar actions; table columns visible; Settings available.
- **Tablet (600–1023px):** horizontal-scrolling tabs (`AppTabStrip` already scrolls); toolbar `Wrap` may multi-line; tables remain usable.
- **Mobile (<600px):** tabs scroll; toolbar actions remain under tabs; queue/bed board use existing `mobileItemBuilder` rows — do not add a separate mobile header.

Do not introduce breakpoint-specific title headers.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/ipd/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL `?section=` and swaps toolbar actions
- [ ] Deep link `/ipd?section=active` opens Active Patients; `/ipd?section=bed-board` opens Bed board
- [ ] Per-tab toolbar shows only that tab’s configured actions
- [ ] Table chrome has only Filters and Settings (EN labels)
- [ ] No screen title/header chrome remains (including bed board panel title)
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate Start admission and Manage beds
- [ ] Responsive layouts still work (existing mobile builders)
- [ ] Start admission dialog still opens; bed board still loads; row actions still work

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu for screen chrome
- [ ] Domain logic preserved (scopes, counts, dialogs, bed status updates, deep links)
- [ ] Analyze clean; tests pass; stale bed-board header code removed
- [ ] Filters label is **Filters**; Settings uses `commonTableSettingsActionLabel`
