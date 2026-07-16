# Standardize Radiology Screen (Tabs & Toolbar)

## Objective

Refactor the Radiology workspace (`/radiology`, `RadiologyWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Radiology domain logic** (workbench stages, patients/orders view toggle, filters,
order/result workflows, configurations catalog, permissions, realtime refresh, deep links,
print flows). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
  - Public widget: `RadiologyWorkspacePage` (`ConsumerWidget`)
  - Content: `_RadiologyWorkspaceContent` / `_RadiologyWorkspaceContentState`
  - Table board: `_RadiologyOrderBoard` → `AppListTable<RadiologyOrder>`
  - Parts:
    - `radiology_workspace_page.configurations.dart` — `_showRadiologyConfigurationsDialog`, catalog tables
    - `radiology_workspace_page.detail_cells.dart` — filter value helpers, cells
    - `radiology_workspace_page.print.dart` — print templates
- Widget: `frontend/lib/features/radiology/presentation/widgets/radiology_workflow_progress_section.dart`
- Controller: `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
  - Provider: `radiologyWorkspaceControllerProvider`
  - Key APIs: `refresh`, `applySearch`, `applyView`, `applyStage`, `applyStatus`,
    `applyModality`, `applyPriority`, `applyBillingGate`, `applyOrderedDate`, `changePage`,
    `selectOrder`, workflow mutations (`startOrder`, `requestFinalization`, …), realtime sync
- Domain: `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
  - `RadiologyDeskSection` enum: `worklist`, `reporting`, `released`, `allOrders`
  - `RadiologyWorkbenchView` enum: `patients`, `orders`
  - `RadiologyWorkspaceQuery` / `fromUri` / `hasRouteTargeting` / `signature`
  - `RadiologyWorkspaceState` (+ `workloadCount`, `reportingCount`, `releasedCount`, summary)
- Repository: `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart`
  - Impl: `frontend/lib/features/radiology/data/repositories/radiology_repository_impl.dart`
  - DTOs: `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`
- Route: `AppRoutes.radiology` path `/radiology` in `frontend/lib/app/router/app_routes.dart`
  - Permissions: `radiologyRead` / `radiologyWrite` / `clinicalRead` / `clinicalWrite` / `billingRead`
  - Module: `radiology-workflows`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `RadiologyWorkspaceQuery.fromUri(state.uri)` into `RadiologyWorkspacePage(initialQuery: …)`
- Tests:
  - `frontend/test/features/radiology/presentation/radiology_workspace_page_test.dart`
    (tabs, URL `section`, deep link, view toggle, mobile viewport, tooltips)
  - `frontend/test/features/radiology/presentation/radiology_workspace_controller_test.dart`
  - `frontend/test/features/radiology/domain/radiology_entities_test.dart`
  - `frontend/test/features/radiology/data/dtos/radiology_dtos_test.dart`

### Current widget tree (chrome)

```
AsyncStateScaffold<RadiologyWorkspaceState>
  └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
              ├── AppTabStrip(
              │     tabs: RadiologyDeskSection.values → AppTabItem,
              │     selectedId: _section.name,
              │     secondaryActions: [View toggle, Configurations?],  // ❌ same on every tab
              │     primaryAction: Request imaging? (if canRequest),   // ❌ same on every tab
              │   )
              ├── SizedBox(height: theme.spacing.sm)
              ├── [optional AppFailureStateView]
              └── _RadiologyOrderBoard → AppListTable<RadiologyOrder>
```

- **No** `AppWorkspace(showHeader: true)` / titled screen header today — already compliant.
- **No** FAB / page-level PopupMenu / header “more” menu — do not add one.
- Order detail dialog (`_openRadiologyDetailDialog`) uses `actions: _buildHeaderActions(context)` for
  **order-local** workflow buttons (Assign, Start imaging, Draft report, Release, Cancel, …).
  Those are **detail-dialog** actions, not screen chrome — **leave them in the detail dialog**.
  Do not move them into `AppTabStrip`.

### Confirmed tab inventory (validated against code + l10n)

| # | Tab label (l10n → EN) | Enum `RadiologyDeskSection` | URL query `section=` (write) | Accepted read aliases (`_sectionFromQuery`) | Stage applied on tab (`_applyStageForSection`) | Primary toolbar today |
|---|------------------------|-----------------------------|------------------------------|---------------------------------------------|------------------------------------------------|------------------------|
| 1 | `radiologyWorklistSummaryLabel` → **Worklist** | `worklist` | `worklist` | `worklist`, `work` | `ALL` | Request imaging (`radiologyRequestImagingAction`) when `canRequest` |
| 2 | `radiologyReportingSummaryLabel` → **Reporting** | `reporting` | `reporting` | `reporting`, `reports`, `draft` | `REPORTING` | Same Request imaging (not contextual) |
| 3 | `radiologyReleasedSummaryLabel` → **Released** | `released` | `released` | `released`, `completed`, `finalized` | `COMPLETED` | Same Request imaging (not contextual) |
| 4 | `radiologyAllOrdersSummaryLabel` → **All orders** | `allOrders` | `all` | `all`, `all_orders`, `all-orders` | `ALL` | Same Request imaging (not contextual) |

Deep-link tab state **is already URL-backed** via `_updateUrlForSection` →
`AppRoutes.radiology.location(queryParameters: {if tab.isNotEmpty: 'section': tab})` +
`GoRouter.replace`, and `_applyRouteQuery` / `RadiologyWorkspaceQuery.fromUri`.

`RadiologyWorkspaceQuery.fromUri` already accepts:

- Section keys: `section` | `panel` | `tab`
- Search: `search` | `q`
- Encounter: `encounterId` | `encounter_id` | `encounter`
- Order: `orderId` | `order_id` | `order`

**No new query param is required** — keep `section` as the canonical write key with the values above.

### Current toolbar (gap)

Always the same set regardless of `_section`:

| Slot | Widget | l10n / behavior | Gate |
|------|--------|-----------------|------|
| Primary | `AppTabToolbarPrimary` | `radiologyRequestImagingAction` (“Request imaging”) → `_showCreateOrderDialog` | `canRequest` = grantsAny(`clinicalWrite`, `radiologyWrite`); else `primaryAction: null` |
| Secondary | `AppTabToolbarAction` | Patients/Orders view toggle (`radiologyOrdersViewAction` / `radiologyPatientsViewAction`) → `controller.applyView(...)` | none |
| Secondary | `AppTabToolbarAction` | `radiologyConfigurationsAction` (“Configurations”) → `_showRadiologyConfigurationsDialog` | only if `canWork` (`radiologyWrite`) |

Missing from screen toolbar today: **Refresh** (`commonRefreshActionLabel` → `controller.refresh()`). Refresh exists inside the configurations dialog only.

### Current table chrome

- Search: `AppListTableSearch` with `radiologySearchHint` / `radiologySearchLabel` — keep.
- Filters: present via `showAdvancedFilterButton: true`, but label is
  `l10n.radiologyFiltersLabel` → **"Radiology filters"** ❌ (must be **"Filters"**).
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently
  **"Table settings"** ❌ (must be **"Settings"** per `prompt.md`; update the shared EN string).
- No other table-header / `trailingActions` on the main worklist — good.
- Filter groups (stage / status / modality / priority / billing gate + date) — preserve behavior;
  only standardize the **button label**.

Configurations dialog table (`radiology_workspace_page.configurations.dart`) also uses
`radiologyFiltersLabel` / `commonTableSettingsActionLabel` — apply the same label fixes there.
Its row `maxTrailingActions` / overflow is **row-local catalog actions**, not screen-header chrome;
do not invent a screen more-menu. Leave row trailing as-is unless a shared table change is required.

### Permission gates today (preserve semantics)

```dart
final bool canRequest = accessPolicy.grantsAny(const <AppPermission>[
  AppPermissions.clinicalWrite,
  AppPermissions.radiologyWrite,
]);
final bool canWork = accessPolicy.grants(AppPermissions.radiologyWrite);
```

Prefer wrapping write CTAs with `AppAccessActionGate` + an `AccessRequirement` (same permissions)
for parity with Reception/HR, but **do not change which permissions are required**.

### Concrete `prompt.md` gaps to close

1. Toolbar does **not** change with the active tab (same Request / View / Configurations everywhere).
2. Screen toolbar lacks **Refresh**; add it under tabs (never as table trailing).
3. Filters button label must be exactly **Filters** (update `radiologyFiltersLabel` EN, and any
   generated locale mirrors / regenerate l10n as this repo normally does).
4. Settings button label must be exactly **Settings** (update shared
   `commonTableSettingsActionLabel` EN from `"Table settings"` → `"Settings"` if still outdated;
   if another standardize prompt already changed it, keep `"Settings"`).
5. When `canRequest` is false, `primaryAction` is null — still have secondaries, but after
   contextualization **every tab must keep ≥1 toolbar button** (Refresh + View toggle cover this).
6. Keep no dedicated title header; do not wrap the page in `AppWorkspace(showHeader: true)` or
   reintroduce `appWorkspaceToolbarWithLabels` **above** tabs.
7. Do not move detail-dialog `_buildHeaderActions` into the tab toolbar.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — chrome shape
  (`ResponsivePage` → `AppTabStrip` → `SizedBox(sm)` → `AppListTable`)
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — **copy this pattern** for
  per-tab `primaryAction` / `secondaryActions` builders (`_buildPrimaryActionButton` /
  `_buildSecondaryActionWidgets`)
- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` — sibling imaging-desk twin
  (same section/query style; still may share the non-contextual toolbar gap — do not regress Lab)
- `frontend/lib/shared/components/app_tab_strip.dart` — `AppTabStrip`, `AppTabItem`,
  `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` defaults `false`; do not add a title bar
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do **not** put
  `AppWorkspaceToolbar` above Radiology tabs
- `frontend/lib/shared/components/app_list_table.dart` — Filters/Settings via search + column visibility
- `frontend/lib/shared/components/app_search_bar.dart` — `filterGroups` / `advancedFilterButtonLabel`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — mobile `<600`, tablet/desktop `600+`
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage` / `PageMaxWidth.dataHeavy`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Worklist | `/radiology?section=worklist` | Active imaging worklist (`applyStage('ALL')`) | **Request imaging** (`AppTabToolbarPrimary`, `radiologyRequestImagingAction`, icon `Icons.add`) gated by request write → `_showCreateOrderDialog`. If `!canRequest`, promote **Refresh** to primary. | **Patients/Orders view** toggle (`AppTabToolbarAction`, existing labels/icons); **Refresh** (`commonRefreshActionLabel`, `Icons.refresh_outlined`) if not already primary → `radiologyWorkspaceControllerProvider.notifier.refresh()`; **Configurations** (`radiologyConfigurationsAction`, `Icons.tune_outlined`) when `canWork` → `_showRadiologyConfigurationsDialog` |
| Reporting | `/radiology?section=reporting` | Draft/reporting queue (`REPORTING`) | Same Request imaging (or Refresh if `!canRequest`) | View toggle; Refresh (if not primary). **Omit Configurations** on this tab (contextual difference). |
| Released | `/radiology?section=released` | Finalized/released (`COMPLETED`) | Same Request imaging (or Refresh if `!canRequest`) | View toggle; Refresh (if not primary). **Omit Configurations**. |
| All orders | `/radiology?section=all` | Full workbench (`ALL`) | Same Request imaging (or Refresh if `!canRequest`) | View toggle; Refresh (if not primary); **Configurations** when `canWork` |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction` for
  left-cluster secondaries (matches `AppTabStrip` contract). Prefer flat `AppTabToolbarAction` for
  Refresh under tabs — do **not** use `AppWorkspaceRefreshAction` (that is `AppButton.secondary`
  styled for the old workspace toolbar).
- Implement helpers on `_RadiologyWorkspaceContentState`, e.g. `_buildPrimaryAction(...)` and
  `_buildSecondaryActions(...)` that `switch` on `_section` (mirror HR).
- Disable actions while `state.isMutating` / during refresh consistently with today.
- Order-detail workflow buttons stay in `_buildHeaderActions` inside the detail dialog.

### Routing

- Keep `/radiology` registration in `app_router.dart` unchanged.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by
  `RadiologyWorkspaceQuery.fromUri`).
- Canonical write values must remain: `worklist` | `reporting` | `released` | `all`.
- Keep all `_sectionFromQuery` aliases listed above.
- On tab tap: `setState` + `_updateUrlForSection(section)` + `_applyStageForSection(section)`
  (already present) — preserve.
- On deep link: `_scheduleRouteQuery` / `_applyRouteQuery` already maps section + search +
  encounter/order selection — preserve.
- Do not invent a second tab query key (`tab` / `panel` remain **read aliases only**).

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold` + `ResponsivePage` (no title header).
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`.
3. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm between strip and table).
4. Optional `AppFailureStateView` when `state.lastFailure != null`.
5. Body: `_RadiologyOrderBoard` → `AppListTable` with **only** Filters + Settings in table chrome
   (plus search).
6. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

Reuse (do not replace):

- `radiologyWorkspaceControllerProvider` /
  `RadiologyWorkspaceController` —
  `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
- `RadiologyWorkspaceState` / `RadiologyWorkspaceQuery` /
  `RadiologyDeskSection` / `RadiologyWorkbenchView` —
  `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
- Realtime / adaptive refresh already wired in the controller — preserve.
- Configurations + create-order dialogs remain entry points from the tab toolbar only.

## Implementation Steps

1. **Contextualize `AppTabStrip` toolbar** — File:
   `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
   - Replace the inline always-on `primaryAction` / `secondaryActions` with section-aware builders
     matching the Tab Configuration table.
   - Ensure View toggle, Request imaging, Configurations, and Refresh wiring keep existing handlers.
   - Optionally wrap Request imaging / Configurations with `AppAccessActionGate` using an
     `AccessRequirement` that mirrors today’s `canRequest` / `canWork` permission sets.

2. **Standardize Filters label** — Files:
   - `frontend/lib/l10n/app_en.arb` (`radiologyFiltersLabel`: `"Filters"`)
   - Main table + configurations dialog usages of `advancedFilterButtonLabel` (already use the key;
     after arb update they resolve correctly). Keep dialog **title** using the same key or a
     descriptive title only if a separate key already exists — button label must be **Filters**.

3. **Standardize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Set `commonTableSettingsActionLabel` to `"Settings"` if it is still `"Table settings"`.
   - Keep using `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` on Radiology tables
     (main + configurations). Do not invent a radiology-only Settings key.

4. **Regenerate / sync l10n** — Run the project’s usual Flutter gen-l10n / localization pipeline so
   `AppLocalizations` picks up EN string changes (and update sibling locale ARBs if this repo
   requires hand-synced translations for those keys).

5. **Update widget tests** — File:
   `frontend/test/features/radiology/presentation/radiology_workspace_page_test.dart`
   - Keep existing tab / URL / deep-link / view-toggle coverage.
   - Add assertions that toolbar actions **change** with tab (e.g. Configurations tooltip present on
     Worklist / All orders when write-capable, absent on Reporting / Released).
   - Assert Refresh appears under the tab strip (`commonRefreshActionLabel` / tooltip `"Refresh"`).
   - Assert Filters / Settings visible labels are `"Filters"` / `"Settings"` where the test pumps
     the search chrome (if currently asserting old strings, update them).
   - Ensure at least one toolbar control exists when `canRequest` is false (Refresh and/or View).

6. **Do not** move `_buildHeaderActions` order-workflow buttons into `AppTabStrip`.

7. **Do not** wrap Radiology in `AppWorkspace` with a titled header or above-tabs
   `appWorkspaceToolbarWithLabels`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; table chrome = search + Filters + Settings only |
| `AppSearchBarFilterGroup` / filter value types | `package:hosspi_hms/shared/components/app_search_bar.dart` | Advanced filters |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AppAccessActionGate` / `AccessRequirement` | `package:hosspi_hms/core/permissions/access_gate.dart`, `access_requirement.dart` | Gate Request imaging / Configurations |
| `AsyncStateScaffold` | via shared components | Loading / error shell (not a title bar) |
| `AppFailureStateView` | shared components | Inline failure under tabs |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Mobile / tablet / desktop behavior |

**Forbidden:** new custom tab bars, new screen title widgets, FABs for screen actions, PopupMenu /
“more” menus for screen/header actions, putting Refresh/Configurations back into
`AppListTableSearch.trailingActions`.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` | Per-tab `primaryAction` / `secondaryActions`; add Refresh under tabs |
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart` | Filters/Settings labels pick up arb changes; no new screen chrome |
| `frontend/lib/l10n/app_en.arb` | `radiologyFiltersLabel` → `"Filters"`; `commonTableSettingsActionLabel` → `"Settings"` if needed |
| Locale mirrors / generated l10n (as required by repo) | Sync after arb edits |
| `frontend/test/features/radiology/presentation/radiology_workspace_page_test.dart` | Contextual toolbar + label + Refresh coverage |

### Create

- None required (no new feature modules).

### Delete

- None expected. Remove only dead private helpers if the contextual toolbar refactor leaves unused
  local widgets (unlikely).

## Cleanup: Remove Stale Code

- [ ] No above-tabs `AppWorkspaceToolbar` / `appWorkspaceToolbarWithLabels` introduced
- [ ] No screen-level PopupMenuButton / “more” overflow for chrome actions
- [ ] No duplicate Refresh in table trailing
- [ ] Configurations only on Worklist + All orders (per target table)
- [ ] Detail-dialog `_buildHeaderActions` still only on order detail, not tab strip
- [ ] Unused imports cleaned after refactor

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome/layout refactor only.

## Responsive Design Requirements

- **Desktop (≥1024px / `lg+`):** Full tab labels + counts; toolbar primary + secondaries visible in
  the `AppTabStrip` toolbar row; wide `AppListTable` columns.
- **Tablet (600–1023px):** Same chrome; horizontal scroll on tab chips if needed (already in
  `AppTabStrip`); keep toolbar under tabs.
- **Mobile (<600px):** Existing test `AppTabStrip renders on narrow mobile viewport` must keep
  passing; table uses `mobileItemBuilder` (`_RadiologyOrderListTile`); toolbar actions remain under
  tabs (may compress via strip layout — do not move them into a more-menu).

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/radiology/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL `section` and applies the correct stage filter
- [ ] Deep link `/radiology?section=reporting` opens Reporting and applies `REPORTING`
- [ ] Per-tab toolbar shows only that tab’s actions (Configurations on Worklist/All orders only)
- [ ] Refresh is available under the tab strip on every tab (as primary or secondary)
- [ ] Table chrome has only Filters and Settings (plus search) — labels exact
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on the screen for every permission combination tested
- [ ] Permissions still gate Request imaging / Configurations
- [ ] Patients/Orders view toggle still works
- [ ] Responsive / mobile viewport still shows `AppTabStrip`
- [ ] Detail-dialog workflow actions still appear on selected orders

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (stages, filters, dialogs, realtime, deep links)
- [ ] Analyze clean; tests pass; stale code removed
- [ ] Filters label is **Filters**; Settings label is **Settings**
- [ ] Deep-link query `section` remains the tab URL contract
)
