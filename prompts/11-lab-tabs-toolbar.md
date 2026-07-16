# Standardize Laboratory Screen (Tabs & Toolbar)

## Objective

Refactor the Laboratory workspace (`/lab`, `LabWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Laboratory domain logic** (queue scopes, patients/orders view, create/edit/delete
orders, result entry dialog, lab configurations / catalog / QC dialogs, permissions, counts,
realtime refresh, deep links). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
  - Public widget: `LabWorkspacePage` (`initialQuery: LabWorkspaceQuery?`)
  - Content: `_LabWorkspaceContent` / `_LabWorkspaceContentState`
  - Worklist body: `_LabWorklistPanel` → `AppListTable<LabOrderSummary>`
  - Configurations UI: `_LabConfigurationsDialog` (dialog-only — **do not** move catalog/QC
    actions into the screen tab toolbar)
  - Result entry: `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
    (`LabResultEntryDialog`) — row/detail scoped; keep out of screen toolbar
  - Other dialogs in the same page file: create/edit/delete order, reverse workflow, QC, catalog
    enable/configure/delete
- Controller: `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
  - Provider: `labWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyScope(LabQueueScope)`, `applyView(LabWorkbenchView)`,
    `applySearch(String)`, `changePage(...)`, `selectOrder(...)`, `createOrder(...)`,
    catalog/QC mutation helpers
- Domain: `frontend/lib/features/lab/domain/entities/lab_entities.dart`
  - Tabs: `LabDeskSection` — `worklist`, `collection`, `processing`, `verification`, `critical`,
    `completed`
  - Scopes: `LabQueueScope` — `all`, `collection`, `processing`, `results`, `critical`,
    `completed`, `cancelled` (cancelled is **not** a desk tab today; do not add a Cancelled tab)
  - View: `LabWorkbenchView` — `patients` | `orders`
  - Deep link: `LabWorkspaceQuery.fromUri` parses `section|panel|filter|scope`,
    `encounterId|…`, `orderId|…`, `search|q`
- Repository: `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
  (`labRepositoryProvider`)
- Status display: `frontend/lib/features/lab/presentation/lab_status_display.dart`
- Routes: `AppRoutes.lab` path `/lab` in `frontend/lib/app/router/app_routes.dart`
  - Builder in `frontend/lib/app/router/app_router.dart` passes
    `LabWorkspaceQuery.fromUri(state.uri)` into `LabWorkspacePage(initialQuery: …)`
- Write gate (page-local today):

```dart
static const AccessRequirement _mutationRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.labWrite],
  activeModules: <String>['lab-workflows'],
);
```

Used via `appAccessPolicyProvider` → `canMutate` (not yet wrapped in `AppAccessActionGate`).

- Tests today (no chrome/page widget tests):
  - `frontend/test/features/lab/presentation/lab_workspace_controller_test.dart`
  - `frontend/test/features/lab/data/lab_dtos_test.dart`
  - `frontend/test/features/lab/domain/lab_catalog_scope_test.dart`

### Current widget tree (chrome)

```
AsyncStateScaffold<LabWorkspaceState>
  └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
              ├── AppTabStrip(
              │     tabs: all LabDeskSection.values,
              │     primaryAction: Create Lab Order (if canMutate) — SAME on every tab,
              │     secondaryActions: View toggle + Lab Configurations (if canMutate)
              │                       — SAME on every tab
              │   )
              ├── SizedBox(height: theme.spacing.sm)
              └── _LabWorklistPanel → AppListTable<LabOrderSummary>
                    (search + Settings; NO Filters)
```

- **No** page-level `AppWorkspace` title header — uses `ResponsivePage` like Reception
  (acceptable equivalent to `AppWorkspace(showHeader: false)`).
- **No** FAB / `PopupMenuButton` / overflow “more” menu on the screen chrome today.
- **Deep-link tab state is already URL-backed** via `?section=<value>`:
  - Write: `_updateUrlForSection` → `AppRoutes.lab.location(queryParameters: {'section': …})`
    + `GoRouter.replace`
  - Read: `LabWorkspaceQuery.fromUri` → `_applyRouteQuery` → `_sectionFromQuery` +
    `controller.applyScope(_scopeForSection(section))`
  - Also deep-links `search`, `orderId`, `encounterId` (opens detail dialog). Keep all of this.

### Confirmed tab inventory (l10n-validated)

| # | Tab label (EN) | l10n key | Enum `LabDeskSection` | Query `section=` written | Accepted aliases in `_sectionFromQuery` | Scope applied |
|---|----------------|----------|------------------------|---------------------------|-----------------------------------------|---------------|
| 1 | **All** | `labScopeAll` | `worklist` | `worklist` | `worklist`, `all` | `LabQueueScope.all` |
| 2 | **Awaiting results** | `labScopeCollection` | `collection` | `collection` | `collection`, `sample` | `LabQueueScope.collection` |
| 3 | **Processing** | `labScopeProcessing` | `processing` | `processing` | `processing`, `in-process` | `LabQueueScope.processing` |
| 4 | **Pending verification** | `labScopeResults` | `verification` | `verification` | `verification`, `results`, `pending` | `LabQueueScope.results` |
| 5 | **Critical** | `labScopeCritical` | `critical` | `critical` | `critical` | `LabQueueScope.critical` |
| 6 | **Verified** | `labScopeCompleted` | `completed` | `completed` | `completed`, `done` | `LabQueueScope.completed` |

Do **not** rename tabs to invent new English strings; keep existing l10n keys/values.

### Current toolbar (gap)

| Control | Widget today | l10n | When shown |
|---------|--------------|------|------------|
| Create Lab Order | `AppTabToolbarPrimary` | `labCreateAction` | All tabs when `canMutate` |
| Patients / Orders view toggle | `AppWorkspaceViewToggle` | `labPatientsViewAction` / `labOrdersViewAction` | All tabs always |
| Lab Configurations | `AppTabToolbarAction` | `labReferenceRangesAction` | All tabs when `canMutate` |
| Refresh | *(missing)* | — | — |

Toolbar does **not** change when switching tabs → violates prompt.md contextual-toolbar rule.

Radiology sibling (`radiology_workspace_page.dart`) already uses `AppTabToolbarAction` for the
view toggle instead of `AppWorkspaceViewToggle`. Prefer that flat toolbar style for Lab too.

### Current table chrome (gap)

- Search: `AppListTableSearch` with `labSearchLabel` / `labSearchHint`; server-side via
  `controller.applySearch` (`matcher: (_, _) => true`).
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently
  **"Table settings"**, not the required standardized label **"Settings"**.
- Filters: **missing** on the main worklist. (Configurations dialog table uses
  `labFiltersLabel` → **"Laboratory filters"** — wrong standardized label if/when reused.)
- Row-local `WorkflowActionButton` in optional column `next_action` — **keep** in table body;
  do not move into tab toolbar.
- No Refresh / Create / Configurations in table trailing (good).

### Concrete `prompt.md` gaps to close

1. **Toolbar not contextual** — Create + View + Configurations identical on every section.
2. **No Refresh** secondary on any tab (peers: Emergency / ICU / Access Admin / HR expose Refresh).
3. **Main worklist lacks Filters** — must add a Filters control labeled exactly **Filters** inside
   table search chrome only.
4. **Settings label** must be exactly **Settings** (shared `commonTableSettingsActionLabel`).
5. Prefer `AppTabToolbarAction` for view toggle (match Radiology) so all tab-toolbar actions share
   one visual language; drop `AppWorkspaceViewToggle` from this page if unused afterward.
6. Prefer `AppAccessActionGate` for write CTAs (match Reception) instead of only branching on
   `canMutate` when building widgets — preserve the same `_mutationRequirement`.
7. **Already compliant (do not regress):** no dedicated title header; `AppTabStrip` under
   `ResponsivePage`; deep-link `?section=`; no screen-level overflow/FAB/more-menu; ≥1 toolbar
   button exists when `canMutate` (Create) or when read-only (View toggle). After contextualization,
   **every tab** must still show ≥1 toolbar control (Refresh + View cover this).

### Preserve (do not relocate to tab toolbar)

- **Result entry / order detail** actions inside `LabResultEntryDialog` (enter/verify results,
  print, reverse, additional order, edit/delete order, etc.).
- **Lab Configurations dialog** internals: enable test/panel, configure/delete catalog rows,
  QC logs section (`labQcLogsAction`) — stay inside `_LabConfigurationsDialog`.
- **Row `WorkflowActionButton`** and status badges — table body only.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — canonical layout: `ResponsivePage` + `AppTabStrip` + `SizedBox(sm)` + `AppListTable`;
  query-backed tabs via `section`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — per-tab `primaryAction` / `secondaryActions` helpers; table Filters labeled `"Filters"`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
  — closest sibling: Lab-like desk + view toggle + configurations + create primary
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
  — Refresh as `AppTabToolbarAction` + `l10n.commonRefreshActionLabel`
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (default `false`); Lab should
  continue **without** a title header
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/layout/app_workspace_view_toggle.dart` — reference only; prefer
  `AppTabToolbarAction` on this page
- `frontend/lib/shared/actions/app_workspace_refresh_action.dart` — optional; prefer
  `AppTabToolbarAction` for Refresh to match Access Admin / Emergency prompts
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`,
  column visibility → Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `filterGroups` /
  `advancedFilterButtonLabel`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All | `/lab?section=worklist` | Full lab worklist | **Create Lab Order** (`labCreateAction`, icon `Icons.add_circle_outline`) gated by `_mutationRequirement` → `_openCreateLabOrderDialog` | **View toggle** (`labPatientsViewAction` / `labOrdersViewAction`, icon `Icons.swap_horiz_outlined`) → `controller.applyView(...)`; **Lab Configurations** (`labReferenceRangesAction`, icon `Icons.tune_outlined`) gated write → `_openLabConfigurationsDialog`; **Refresh** (`commonRefreshActionLabel`) → `controller.refresh()` |
| Awaiting results | `/lab?section=collection` | Collection / awaiting-results queue | **Create Lab Order** (same gate/handler) | **View toggle**; **Refresh** |
| Processing | `/lab?section=processing` | In-process queue | **Create Lab Order** | **View toggle**; **Refresh** |
| Pending verification | `/lab?section=verification` | Results pending verification | **Create Lab Order** | **View toggle**; **Refresh** |
| Critical | `/lab?section=critical` | Critical results queue | **Create Lab Order** | **View toggle**; **Refresh** |
| Verified | `/lab?section=completed` | Completed / verified orders | **Lab Configurations** (gated write → `_openLabConfigurationsDialog`) — *or* if `!canMutate`, `primaryAction: null` | **View toggle**; **Refresh**; when write allowed and Configurations is primary, also expose **Create Lab Order** as `AppTabToolbarAction` secondary so create remains available |

**Rules for the matrix**

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction`
  for left-cluster secondaries (matches `AppTabStrip` contract).
- Lab Configurations appears as a **screen** toolbar button only on **All** (secondary) and
  **Verified** (primary when writable). Other queue tabs intentionally omit it so the toolbar
  changes with the active tab.
- View toggle + Refresh on **every** tab so no tab is toolbar-empty (including read-only users).
- When write is denied: omit Create / Configurations; keep View + Refresh.
- Do **not** put QC / enable-test / enable-panel / catalog row actions in the screen toolbar.
- Do **not** reintroduce a header more-menu or FAB.

### Routing

- Keep `/lab` registration in `app_router.dart` / `AppRoutes.lab` unchanged except if tests need it.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by
  `LabWorkspaceQuery.fromUri`). Do **not** invent a second tab query key.
- Canonical write values must remain:
  - `worklist` | `collection` | `processing` | `verification` | `critical` | `completed`
- Keep existing aliases in `_sectionFromQuery`.
- On tab tap: `setState` → `_updateUrlForSection(section)` →
  `controller.applyScope(_scopeForSection(section))` (already present).
- On deep link: `_applyRouteQuery` already maps section + search + optional order/encounter
  selection. Preserve.
- **Optional (non-blocking):** also deep-link `view=patients|orders` via `LabWorkspaceQuery` if
  easy; not required for acceptance. Tab `section` deep-linking already satisfies the audit ask.
- When switching tabs: clear table filter value; keep search text unless a deep-link search is
  being applied.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold` + `ResponsivePage` (no title header; do **not** add
   `AppWorkspace(showHeader: true)`).
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>,
   secondaryActions: <per-tab>)`.
3. `SizedBox(height: theme.spacing.sm)` — keep existing vertical rhythm between strip and table.
4. Body: `_LabWorklistPanel` → `AppListTable<LabOrderSummary>` whose search chrome exposes **only**:
   - Search field
   - **Filters** (advanced filter button / dialog)
   - **Settings** (column visibility)
5. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

Reuse (do not fork):

- `labWorkspaceControllerProvider` —
  `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
- `LabDeskSection` / `LabQueueScope` / `LabWorkbenchView` / `LabWorkspaceQuery` /
  `LabWorkspaceState` / `LabOrderSummary` — `lab_entities.dart`
- `_mutationRequirement` + `appAccessPolicyProvider` (optionally wrap with
  `AppAccessActionGate`)
- Existing dialog openers already on the page

Add local UI state only as needed:

- `AppSearchBarFilterValue` on `_LabWorkspaceContentState` (or `_LabWorklistPanel`) for worklist
  Filters; reset on tab change
- Helpers `_buildPrimaryAction(...)` / `_buildSecondaryActions(...)` switching on `_section`

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md / other screens cite this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator).

2. **Add worklist Filters label** — File: `frontend/lib/l10n/app_en.arb`
   - Add `labWorklistFiltersLabel`: `"Filters"` (mirror `hrFiltersLabel` /
     `nursingAdvancedFiltersLabel`).
   - Do **not** reuse `labFiltersLabel` (`"Laboratory filters"`) for the worklist chrome button.
   - Optionally leave `labFiltersLabel` as-is for the configurations dialog, **or** also point the
     dialog’s `advancedFilterButtonLabel` at `labWorklistFiltersLabel` so both say **Filters**.
   - Reuse existing apply/clear keys already used in the configurations dialog:
     `opdApplyFiltersAction` / `opdClearFiltersAction` (or HR equivalents).
   - Regenerate l10n.

3. **Make toolbar contextual** — File:
   `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
   - Extract `_buildPrimaryAction(AppLocalizations l10n, LabWorkspaceState state, bool canMutate)`
     and `_buildSecondaryActions(...)` switching on `_section` per the Tab Configuration table.
   - Wire `primaryAction:` / `secondaryActions:` on `AppTabStrip`.
   - Implement Refresh via
     `unawaited(ref.read(labWorkspaceControllerProvider.notifier).refresh())`
     (surface failures with existing `_showFailureIfNeeded` / `showAppFailureSnackBar` if the
     method returns `AppFailure?`).
   - Replace `AppWorkspaceViewToggle` with `AppTabToolbarAction` for the patients/orders toggle
     (same labels/icons/handlers as today).
   - Gate Create / Configurations with `AppAccessActionGate(requirement: _mutationRequirement, …)`
     **or** keep `canMutate` branching but ensure disabled/hidden behavior matches Access Policy
     (prefer `AppAccessActionGate` like Reception).
   - Import `frontend/lib/core/permissions/access_gate.dart` if adopting the gate.

4. **Add table Filters; keep only Filters + Settings in table chrome** — same page file /
   `_LabWorklistPanel`
   - Extend `AppListTableSearch` with:
     - `showAdvancedFilterButton: true` **or** non-empty `filterGroups`
     - `advancedFilterButtonLabel: l10n.labWorklistFiltersLabel` (**must render as “Filters”**)
     - `advancedFilterTitle: l10n.labWorklistFiltersLabel`
     - `advancedFilterApplyLabel` / reset from shared keys above
     - `enableDateFilter: false`
     - `filterGroups`: at least one useful group, e.g.:
       - `payment` / billing using distinct `effectivePaymentStatus` values from current
         worklist items (labels via existing `clinicalRequestPaymentStatusDisplayLabel` /
         `labPaymentColumnLabel` patterns already on the page)
       - and/or `entry_status` / `result_status` using the same status vocabulary already used by
         `_entryStatus` / `_resultStatus` / order `status`
     - `filterValue` + `onFilterChanged` + `hasActiveFilters`
   - Apply filters **client-side** on the current page’s `state.worklist.items` (no API/schema
     change). Pass the filtered list into `AppListTable` in a way that preserves pagination
     chrome when possible (e.g. filter `page.items` while keeping `AppPage` metadata, or document
     clearly if you must temporarily switch to `items:` for the filtered subset of the current
     page only — do **not** invent new repository query fields).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now “Settings”).
   - Keep search server-side (`applySearch`); do not move Create / Configurations / Refresh /
     View toggle into `AppListTableSearch.trailingActions`.

5. **Do not touch dialog-only chrome** except optional Filters label normalization inside
   `_LabConfigurationsDialog` (step 2). Catalog row action buttons stay in the dialog table.

6. **Tests** — add or extend:
   - Prefer `frontend/test/features/lab/presentation/lab_workspace_page_test.dart` (new) modeled
     on `frontend/test/features/opd/presentation/opd_workspace_page_test.dart` /
     physiotherapy / clinical tab-strip tests:
     - Renders `AppTabStrip` with six section labels (All, Awaiting results, Processing,
       Pending verification, Critical, Verified)
     - Switching tab updates URL `section` query (pump with `GoRouter` if peers do)
     - Toolbar primary/secondary differ between All vs Verified (Configurations placement) and
       queue tabs omit Configurations
     - Table search chrome exposes Filters + Settings labels
   - Keep existing controller/DTO/scope tests green.

7. **Format / analyze / test** — run the Verification Steps below.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Settings + Filters only |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterValue` / `AppSearchBarFilterChoice` | `package:hosspi_hms/shared/components/app_search_bar.dart` (exported via components) | Worklist Filters |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AsyncStateScaffold` | shared components barrel | Loading / error shell |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Create / Configurations |
| `AppWorkspaceStatusBadge` / empty panels | shared layout/components (already used) | Row status / empty states |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Row next-action only |

**Forbidden:** new custom tab bars, new screen title headers, new overflow/more menus for screen
actions, new table header buttons beyond Filters + Settings, duplicating Radiology/Lab toolbar
widgets as one-offs.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`) |
| Create (recommended) | `frontend/test/features/lab/presentation/lab_workspace_page_test.dart` |
| Optional modify | `frontend/lib/features/lab/domain/entities/lab_entities.dart` — only if adding optional `view` deep-link field to `LabWorkspaceQuery` |
| Do **not** delete | Dialog helpers, result entry, configurations dialog, controller, repository |

## Cleanup: Remove Stale Code

- [ ] Remove unused `AppWorkspaceViewToggle` usage from Lab page if replaced by
      `AppTabToolbarAction`
- [ ] Ensure no duplicate Create / Configurations / View controls remain outside
      `AppTabStrip` toolbar
- [ ] Ensure `_LabWorklistPanel` has no trailingActions that reintroduce screen actions
- [ ] Grep the lab feature for `PopupMenuButton`, `showMenu`, `more_vert`, `FloatingActionButton`
      related to screen chrome; remove if any appear
- [ ] Do not leave dead helpers that only supported the old non-contextual toolbar wiring

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter chrome/layout refactor only.

## Responsive Design Requirements

- Desktop (≥1024px / `AppBreakpoint` xl+): full tab labels + toolbar action labels per
  `AppBreakpoints.showsToolbarActionLabels`; table with Filters + Settings.
- Tablet (600–1023px): same widget tree; toolbar may compact labels via existing shared
  toolbar behavior — do not add a separate mobile-only header.
- Mobile (<600px): keep `AppTabStrip` horizontal scroll; `mobileItemBuilder` /
  `AppListItemRow` already present — preserve. No FAB for Create; Create stays in tab toolbar.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/lab/
flutter test test/shared/
```

If l10n was changed:

```bash
cd frontend
flutter gen-l10n
```

## Testing Requirements

- [ ] Tab switch updates URL `?section=` and swaps toolbar actions per matrix
- [ ] Deep link `/lab?section=critical` (and aliases) opens Critical tab + applies scope
- [ ] Deep link with `orderId` / `encounterId` still opens detail dialog
- [ ] Per-tab toolbar shows only that tab’s actions (Configurations only on All + Verified)
- [ ] Table chrome has only Filters + Settings (plus search field)
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on every tab (View + Refresh minimum)
- [ ] Permissions still gate Create / Configurations / dialog mutations (`labWrite` +
      `lab-workflows`)
- [ ] Patients/Orders view toggle still calls `applyView` and updates columns
- [ ] Responsive layouts still work (mobile list rows + desktop table)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (scopes, view mode, dialogs, realtime, deep links)
- [ ] Analyze clean; tests pass; stale code removed
- [ ] Filters button label is exactly **Filters**; Settings button label is exactly **Settings**
`)
