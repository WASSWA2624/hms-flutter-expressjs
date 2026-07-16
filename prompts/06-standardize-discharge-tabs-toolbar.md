# Standardize Discharge Screen (Tabs & Toolbar)

## Objective

Refactor the Discharge workspace (`/discharge`, `DischargeWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Discharge domain logic** (queue sections, clearance planning dialogs, billing /
pharmacy request dialogs, print summary HTML, permissions/route access, counts, realtime refresh,
deep links for `section` / admission id / search). This refactor is layout/chrome only, plus the
small behavioral fix for Completed-tab **Print** listed below.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
  - Public widget: `DischargeWorkspacePage` (`initialQuery: DischargeWorklistQuery?`)
  - Content: `_DischargeWorkspaceContent` / `_DischargeWorkspaceContentState`
  - Detail dialog content: `_DischargeDetailContent` (dialog-scoped actions — **do not** move
    Start/Edit plan, Manage clearance, Request billing/pharmacy, Complete discharge, or
    cross-module links into the screen tab toolbar)
  - Planning dialog entry: `showDischargePlanningDialog` via
    `frontend/lib/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart`
  - Clearance UI: `frontend/lib/features/discharge/presentation/widgets/discharge_clearance_tile.dart`,
    `discharge_clearance_dialog.dart`, `discharge_planning_dialog.dart`
- Controller: `frontend/lib/features/discharge/presentation/controllers/discharge_workspace_controller.dart`
  - Provider: `dischargeWorkspaceControllerProvider`
  - Key APIs: `refresh()`, `applyBoardQuery`, `applySearch`, `applyStatus`, `selectAdmission`,
    `selectAdmissionByDisplayId`, `requestFinalBilling`, `requestPharmacyMedicines`,
    clearance / summary save paths used by planning dialogs
- Domain: `frontend/lib/features/discharge/domain/entities/discharge_entities.dart`
  - Tabs: `DischargeDeskSection` — `all`, `planned`, `pendingClearance`, `completed`
  - Status filter: `DischargeStatusFilter` (`all`, `planned`, `summaryPending`, `pharmacyPending`,
    `nursingPending`, `billingPending`, `insurancePending`, `documentsReady`, `completed`)
  - Helpers: `isPlannedDischarge`, `isCompletedDischarge`
  - Deep link: `DischargeWorklistQuery.fromUri` parses `section`, `id|admission|admissionId|admission_id`
    (as focus), `search|q`
- Repository: `frontend/lib/features/discharge/data/repositories/discharge_repository_impl.dart`
  (`dischargeRepositoryProvider`)
- Routes: `AppRoutes.discharge` path `/discharge` in `frontend/lib/app/router/app_routes.dart`
  - Builder in `frontend/lib/app/router/app_router.dart` passes
    `DischargeWorklistQuery.fromUri(state.uri)` into `DischargeWorkspacePage(initialQuery: …)`
  - Route access already requires any of clinical/pharmacy/billing/operations read +
    `inpatient-bed-management` module (do not loosen)
- **No page-level write gate today** — Start plan / Manage clearance primaries are ungated.
  IPD sibling uses `AccessRequirement` + `AppAccessActionGate` with `clinicalWrite` +
  `inpatient-bed-management`; mirror that for Discharge write CTAs.
- Tests:
  - `frontend/test/features/discharge/presentation/discharge_workspace_page_test.dart`
    (tabs, deep link `section=planned`, primary tooltip swap, search, detail dialog, mobile)
  - `frontend/test/features/discharge/presentation/discharge_workspace_controller_test.dart`
  - `frontend/test/features/discharge/domain/discharge_entities_test.dart`

### Current widget tree (chrome)

```
AsyncStateScaffold<DischargeWorkspaceState>
  └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
              ├── AppTabStrip(
              │     tabs: all DischargeDeskSection.values (with counts),
              │     primaryAction: contextual AppTabToolbarPrimary per section,
              │     secondaryActions: (not passed — empty)
              │   )
              ├── SizedBox(height: theme.spacing.sm)
              └── AppListTable<IpdAdmissionSummary>
                    (search + advanced Filters + Settings)
```

- **No** page-level `AppWorkspace` title header — uses `ResponsivePage` like Reception
  (acceptable equivalent to `AppWorkspace(showHeader: false)`).
- **No** FAB / `PopupMenuButton` / overflow “more” menu on the screen chrome today.
- **Deep-link tab state is already URL-backed** via `?section=<value>`:
  - Write: `_updateUrlForSection` → `AppRoutes.discharge.location(queryParameters: {'section': …})`
    + `GoRouter.replace`
  - Read: `DischargeWorklistQuery.fromUri` → `initialQuery.section` → `_sectionFromQuery` in
    `initState` / `didUpdateWidget`
  - Also deep-links admission focus (`id` / `admission…`) and search via
    `DischargeWorkspacePage._handleDeepLink` → `selectAdmissionByDisplayId` / `applyBoardQuery`.
    **Keep all of this.**

### Confirmed tab inventory (l10n-validated)

| # | Tab label (EN) | l10n key | Enum `DischargeDeskSection` | Query `section=` written | Accepted aliases in `_sectionFromQuery` |
|---|----------------|----------|-----------------------------|---------------------------|-----------------------------------------|
| 1 | **All patients** | `dischargeSectionAll` | `all` | `all` | `all` |
| 2 | **Planned** | `dischargeSectionPlanned` | `planned` | `planned` | `planned` |
| 3 | **Pending clearance** | `dischargeSectionPendingClearance` | `pendingClearance` | `pending` | `pending`, `pending_clearance`, `pending-clearance`, `pendingclearance` |
| 4 | **Completed** | `dischargeSectionCompleted` | `completed` | `completed` | `completed`, `discharged` |

Do **not** rename tabs; keep existing l10n keys/values.

Row filtering today (client-side over `state.queue.items`):

- `all` → all queue items
- `planned` → `isPlannedDischarge`
- `pendingClearance` → not completed and not planned
- `completed` → `isCompletedDischarge`

Preserve these predicates and the existing count helpers (`plannedCount`,
`summaryPendingCount`, `completedCount`, queue length for All).

### Current toolbar (gap)

| Tab | Primary today | Handler today | Secondary today |
|-----|---------------|---------------|-----------------|
| All patients | **Start discharge plan** (`dischargeStartPlanAction`, `Icons.edit_note_outlined`) | `_handlePrimaryAction` → `_openDischargeDetailDialog` (no clearance auto-open) | *(none)* |
| Planned | **Manage clearance** (`dischargeManageClearanceAction`, `Icons.fact_check_outlined`) | same → detail then `_openDischargePlanningDialog` (`openClearance: true`) | *(none)* |
| Pending clearance | **Manage clearance** (same) | same as Planned | *(none)* |
| Completed | **Print discharge summary** (`dischargePrintSummaryAction`, `Icons.print_outlined`) | `_handlePrimaryAction` → **opens detail dialog only** — does **not** print | *(none)* |

- Primaries are already **contextual** (good) and disabled when `rows.isEmpty`.
- **Refresh** is missing from the tab toolbar (controller has `refresh()`; peers expose Refresh
  under tabs).
- Write primaries are **not** wrapped in `AppAccessActionGate`.
- Completed primary label promises Print but only opens detail → **fix required**.

### Current table chrome (gap)

- Search: `AppListTableSearch` with `dischargeQueueSearchLabel` / `dischargeQueueSearchHint`;
  client matcher `_searchMatcher` + server `controller.applySearch` on submit/clear.
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently
  **"Table settings"** (must become standardized **"Settings"**).
- Filters: wired (`showAdvancedFilterButton: true`, status `filterGroups`,
  `onFilterChanged` → `controller.applyStatus`) but button label uses
  `l10n.dischargeStatusFilterLabel` → **"Discharge status"** (must become standardized
  **"Filters"**). Dialog title may keep status-oriented copy; the **button** must say **Filters**.
- Row-local `WorkflowActionButton` in `next_action` column — **keep** in table body; do not
  move into tab toolbar.
- No Refresh / Start plan / Manage clearance / Print in table trailing (good).

### Concrete `prompt.md` gaps to close

1. **Missing Refresh** secondary on every tab (`commonRefreshActionLabel`).
2. **Filters button label** is `"Discharge status"` — must be **"Filters"**.
3. **Settings label** must be exactly **"Settings"** (shared `commonTableSettingsActionLabel`).
4. **Completed primary must actually print** (or print after loading detail when `hasSummary`);
   do not leave a Print-labeled button that only opens the detail dialog.
5. **Gate write primaries** (Start plan / Manage clearance) with `AppAccessActionGate` using an
   IPD-aligned clinical write requirement; Print + Refresh stay ungated.
6. **Already compliant (do not regress):** no dedicated title header; `AppTabStrip` under
   `ResponsivePage`; deep-link `?section=`; contextual primary per tab; no screen-level
   overflow/FAB/more-menu; ≥1 toolbar button exists today via primary. After changes, every tab
   must still show ≥1 control (Refresh covers empty-queue / read-only cases when primary is
   disabled or write-denied).

### Preserve (do not relocate to tab toolbar)

- All actions inside `_DischargeDetailContent` / planning / billing / pharmacy dialogs.
- Cross-module link buttons (`dischargeOpenIpdAction`, nursing, pharmacy, billing, housekeeping).
- Row `WorkflowActionButton` and status badges — table body only.
- Print button inside the detail `AppDialog.actions` (may share a helper with Completed primary).

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — canonical layout: `ResponsivePage` + `AppTabStrip` + `SizedBox(sm)` + `AppListTable`;
  query-backed tabs via `section`; `AppAccessActionGate` on primary
- `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
  — `_ipdClinicalWriteRequirement` pattern to mirror for Discharge write CTAs
- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` (or HR / Access Admin)
  — Refresh as tab-toolbar control + Filters/Settings label normalization pattern
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (default `false`); Discharge should
  continue **without** a title header
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`,
  column visibility → Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `filterGroups` /
  `advancedFilterButtonLabel`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/permissions/access_requirement.dart` / `app_permission.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All patients | `/discharge` or `/discharge?section=all` | Full discharge queue | **Start discharge plan** (`dischargeStartPlanAction`, `Icons.edit_note_outlined`) gated write → `_handlePrimaryAction` (open detail) | **Refresh** (`commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()` |
| Planned | `/discharge?section=planned` | Planned discharges | **Manage clearance** (`dischargeManageClearanceAction`, `Icons.fact_check_outlined`) gated write → `_handlePrimaryAction` (`openClearance: true`) | **Refresh** (same) |
| Pending clearance | `/discharge?section=pending` | Not planned / not completed | **Manage clearance** (same gate/handler as Planned) | **Refresh** (same) |
| Completed | `/discharge?section=completed` | Completed discharges | **Print discharge summary** (`dischargePrintSummaryAction`, `Icons.print_outlined`) **ungated** → load selected/first row detail and **print** when `hasSummary`; if no summary, open detail dialog (preserve discoverability) | **Refresh** (same) |

Rules:

- Build `primaryAction` / `secondaryActions` from active `_section` (switch or small helpers).
- Use `AppTabToolbarPrimary` for the right-aligned primary; `AppTabToolbarAction` for Refresh.
- Pass `isLoading: state.isRefreshing` on Refresh; disable primary when `rows.isEmpty`.
- Write gate (page-local constant, mirror IPD clinical write):

```dart
const AccessRequirement _dischargeClinicalWriteRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    AppRole.superAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.icuManager,
  ],
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['inpatient-bed-management'],
);
```

Wrap Start plan / Manage clearance primaries in
`AppAccessActionGate(requirement: _dischargeClinicalWriteRequirement, …)` like Reception/IPD
(`enabled: isAllowed`, `onPressed: isAllowed ? … : null`). When write is denied, omit or disable
those primaries but **keep Refresh** so the tab is never actionless.

- Do **not** put Refresh / Start plan / Manage clearance / Print into
  `AppListTableSearch.trailingActions`.
- Guarantee ≥1 toolbar button on every tab (Refresh secondary covers this).

### Routing

- Keep `AppRoutes.discharge` (`/discharge`) and `DischargeWorklistQuery.fromUri`.
- Keep query key `section` with values: `all` | `planned` | `pending` | `completed`.
- Keep `_updateUrlForSection` + `_sectionFromQuery` aliases listed above.
- No new query keys required for this chrome refactor.
- Status filter remains in-memory via `controller.applyStatus` (not URL-backed today — do not
  invent URL status sync unless already present).

### Page Layout

Precise widget tree:

1. `AsyncStateScaffold` → `ResponsivePage` (no `AppWorkspace` title header; equivalent to
   `showHeader: false`)
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction:, secondaryActions:)`
3. `SizedBox(height: theme.spacing.sm)` (keep; matches Reception vertical rhythm under tabs)
4. Body: `AppListTable` with **only** Filters + Settings as table action buttons (plus search field)
5. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

- Reuse `dischargeWorkspaceControllerProvider` / `DischargeWorkspaceController`.
- Reuse `_section`, `_selectedAdmission`, `_searchController`, `_columnVisibilityController`.
- Reuse `_buildRows`, `_columnsForSection`, `_handlePrimaryAction` (extend for Completed print).
- Extract shared print helper from existing `_openDischargeDetailDialog` print `AppReportActionButton`
  / `_dischargeSummaryHtml` so Completed primary and dialog actions share one path.
- Do not change repository contracts or DTOs.

## Implementation Steps

1. **Normalize Filters + Settings labels (l10n)** — Files: `frontend/lib/l10n/app_en.arb`
   (+ regenerate / update generated localizations if the project expects it)
   - Change `dischargeStatusFilterLabel` English value from `"Discharge status"` to `"Filters"`
     **for the advanced filter button**, **or** add `dischargeFiltersLabel: "Filters"` and point
     `advancedFilterButtonLabel` / `advancedFilterTitle` at that key. Prefer a dedicated
     `dischargeFiltersLabel: "Filters"` so filter-group choice labels can keep status wording
     (`dischargeStatusPlanned`, etc.) unchanged.
   - Keep `filterGroups[0].label` as status-oriented text if useful
     (`dischargeStatusFilterLabel` may remain `"Discharge status"` when used as the **group**
     label inside the filter dialog only).
   - Change shared `commonTableSettingsActionLabel` English value from `"Table settings"` to
     `"Settings"` (affects all workspaces intentionally — required standardization).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.

2. **Wire contextual toolbar under tabs** — File:
   `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Keep existing `AppTabStrip` tabs / counts / URL updates.
   - Pass `secondaryActions:` with Refresh on **every** tab:

```dart
AppTabToolbarAction(
  label: l10n.commonRefreshActionLabel,
  icon: Icons.refresh,
  isLoading: state.isRefreshing,
  onPressed: state.isRefreshing
      ? null
      : () {
          unawaited(() async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          }());
        },
)
```

   - Keep section-specific `primaryAction` labels/icons from `_primaryActionLabel` /
     `_primaryActionIcon`.
   - Wrap Start plan / Manage clearance primaries in `AppAccessActionGate` with
     `_dischargeClinicalWriteRequirement`.
   - Leave Completed Print primary **outside** the write gate.

3. **Fix Completed primary to print** — same page file
   - Add `_handleCompletedPrintAction` (or branch inside `_handlePrimaryAction` when
     `_section == DischargeDeskSection.completed`):
     1. Resolve selected/first admission (`_resolveSelectedAdmission`).
     2. `controller.selectAdmission(admission)`.
     3. Read detail from state; if `detail.hasSummary`, call the same print path used by the
        detail dialog (`printFormTemplateDocument` + `_dischargeSummaryHtml` + patient context).
     4. If no summary, fall back to `_openDischargeDetailDialog` so the user can still inspect.
   - Do not remove print from the detail dialog actions.

4. **Keep table chrome limited to Filters + Settings** — same page file
   - Set `advancedFilterButtonLabel` (and preferably title) to the **"Filters"** l10n key from step 1.
   - Keep existing `filterGroups` / `onFilterChanged` / `applyStatus` plumbing.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now “Settings”).
   - Do not add Refresh / plan / clearance / print into table trailing actions.
   - Keep row `WorkflowActionButton` in the `next_action` column.

5. **Update / extend widget tests** — File:
   `frontend/test/features/discharge/presentation/discharge_workspace_page_test.dart`
   - Keep existing tab / deep-link / primary-tooltip / search / detail / mobile tests.
   - Add/adjust expectations:
     - Refresh visible on load (`find.text('Refresh')` / tooltip for `commonRefreshActionLabel`).
     - Tab switch still updates primary tooltip (Start plan / Manage clearance / Print).
     - Filters button shows **"Filters"** (not “Discharge status”).
     - Deep link `?section=completed` shows Print primary + Completed rows only.
   - Do not assert on dialog-internal action layout unless you touch those widgets.

6. **Format, analyze, run tests** — see Verification Steps.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Settings + Filters only |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterValue` / `AppSearchBarFilterChoice` | `package:hosspi_hms/shared/components/app_search_bar.dart` | Status Filters |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Page shell without title header |
| `AsyncStateScaffold` | shared components / layout exports already used | Loading/error shell |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Start plan / Manage clearance |
| `AccessRequirement` / `AppPermissions` / `AppRole` | `access_requirement.dart` / `app_permission.dart` / roles | Write requirement constant |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Row next-action only |
| `printFormTemplateDocument` / print helpers | existing discharge imports | Completed + dialog print |

**Forbidden:** new custom tab bars, duplicate toolbars above the strip, new table header buttons
beyond Filters + Settings, screen-level `PopupMenuButton` / more-menus, reintroducing
`AppWorkspace(showHeader: true)` title chrome for this page.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — secondary Refresh; write gate; Completed print; Filters label wiring |
| Modify | `frontend/lib/l10n/app_en.arb` — Filters label (`dischargeFiltersLabel` and/or update usage); `commonTableSettingsActionLabel` → `"Settings"` |
| Modify | Generated l10n outputs if your workflow requires running the Flutter gen-l10n step |
| Modify | `frontend/test/features/discharge/presentation/discharge_workspace_page_test.dart` — Refresh / Filters / completed deep-link coverage |
| Do not delete | Planning/clearance dialog widgets; controller; repository; entities |

## Cleanup: Remove Stale Code

- [ ] Ensure no duplicate Refresh control in table trailing / FAB / PopupMenu
- [ ] Ensure no leftover unused imports after gate/print helper extraction
- [ ] Do not leave a Print-labeled primary that only opens detail
- [ ] Do not reintroduce a dedicated page title/header/`AppWorkspace` header toolbar

## Database Migrations

No database migrations required — schema unchanged. This is UI chrome + client-side print wiring only.

## Responsive Design Requirements

- Desktop (≥1024px / especially ≥1200 `xl` where `showsToolbarActionLabels` is true): tab strip +
  labeled primary + labeled Refresh; full table with Filters + Settings labels visible.
- Tablet (600–1023px): same structure; toolbar may compact labels per `AppTabStrip` /
  `AppBreakpoints.showsToolbarActionLabels`; table with Filters + Settings.
- Mobile (<600px): keep existing `mobileItemBuilder` (`_MobileQueueItem`); tabs remain
  horizontally scrollable; toolbar still under tabs; no separate mobile header actions.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/discharge/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`section` query) and toolbar primary label/tooltip
- [ ] Deep link `/discharge?section=planned` opens Planned tab
- [ ] Deep link `/discharge?section=completed` opens Completed tab with Print primary
- [ ] Per-tab toolbar shows that tab’s primary + Refresh secondary
- [ ] Table chrome has only Filters + Settings as action buttons (plus search)
- [ ] Filters button label is exactly **Filters**; Settings button label is exactly **Settings**
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on every tab (Refresh minimum when primary disabled)
- [ ] Write primaries gated; Print + Refresh remain available without clinical write
- [ ] Completed primary prints when summary exists (or opens detail when missing)
- [ ] Responsive / mobile list still works
- [ ] Existing detail / planning / billing / pharmacy flows still work

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (queues, clearance, dialogs, deep links, realtime refresh)
- [ ] Filters label is **Filters**; Settings label is **Settings**
- [ ] Analyze clean; tests pass; stale chrome removed
