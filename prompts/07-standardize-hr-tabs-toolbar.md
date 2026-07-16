# Standardize HR Screen (Tabs & Toolbar)

## Objective

Refactor the HR workspace (`/hr`, `HrWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

HR already uses `ResponsivePage` + `AppTabStrip` with per-tab primaries. This audit found
remaining compliance gaps — close those gaps. Do **not** treat the current page as fully
compliant.

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
**Preserve all HR domain logic** (staff directory, leave/swap/roster/payroll queues, access
users/roles/permissions, onboarding/offboarding, deep links, permissions, counts, realtime
refresh, dialogs). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  - Public widget: `HrWorkspacePage` (`initialQuery: HrWorkspaceQuery?`)
  - Content: `_HrWorkspaceContent` / `_HrWorkspaceContentState`
  - Staff table: `_HrStaffDirectory` → `AppListTable<HrStaffProfile>`
  - Queue table: `_HrWorkQueueTable` → `AppListTable<HrWorkItem>`
  - Access body: `HrAccessWorkspacePanel(embedded: true)` from
    `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart`
  - Dialog part: `frontend/lib/features/hr/presentation/pages/hr_workspace_dialog_actions.dart`
    (`showHrWorkQueueDialog`, `showHrStaffDetailDialog`, …) — keep domain dialogs; page body must
    not duplicate dialog chrome
- Controller: `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`
  - Provider: `hrWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyStaffSearch`, `applyStaffFilters`, `changeStaffPage`,
    `applyQueue`, `applyWorkItemsScope`, `changeWorkItemsPage`, staff/leave/roster/payroll
    mutations
- Domain: `frontend/lib/features/hr/domain/entities/hr_entities.dart`
  - Tabs: `HrDeskSection` (`staffDirectory`, `leaveRequests`, `shiftRoster`, `payroll`, `access`)
  - Queues: `HrQueue` (`leaveRequests`, `swapRequests`, `rosterDrafts`, `unassignedShifts`,
    `payrollDrafts`, `overdueShifts`)
  - Query: `HrWorkspaceQuery.fromUri` parses `section`/`tab`, `queue`, `id`/`staff`/…,
    `search`/`q`
- Permissions: `frontend/lib/features/hr/presentation/hr_presentation_helpers.dart`
  - `hrWriteRequirement`, `hrRosterWriteRequirement`, `hrRosterApproveRequirement`,
    `hrRosterPublishRequirement`, `hrPayrollRequirement`
- Queue chip widget: `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart`
  - `HrQueueSwitcher` — used on **Shifts** page body today and inside work-queue **dialog**
- Route: `AppRoutes.hr` path `/hr` in `frontend/lib/app/router/app_routes.dart`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `HrWorkspaceQuery.fromUri(state.uri)` into `HrWorkspacePage(initialQuery: …)`
- Tests today:
  - `frontend/test/features/hr/domain/hr_entities_test.dart` — `HrDeskSection` /
    `HrWorkspaceQuery` (no page chrome tests)
  - Widget/controller tests under `frontend/test/features/hr/` — **no**
    `hr_workspace_page_test.dart` yet

### Current widget tree (chrome) — partially compliant

```
AsyncStateScaffold<HrWorkspaceState>(
  appBarTitle: l10n.hrTitle,   // only on loading/empty/failure scaffolds; omit like Reception
)
  └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
              ├── AppTabStrip(
              │     tabs: HrDeskSection.values → AppTabItem,
              │     primaryAction: _buildPrimaryActionButton(...),   // already per-tab
              │     secondaryActions: _buildSecondaryActionWidgets(...)  // SAME on every tab
              │   )
              ├── SizedBox(height: theme.spacing.sm)
              ├── optional AppFailureStateView
              └── _buildTabBody(...)
                    staff  → _HrStaffDirectory (AppListTable + search + Filters + Settings)
                    leave  → _HrWorkQueueTable (Settings only; NO Filters/search)
                    shifts → Column(HrQueueSwitcher, _HrWorkQueueTable)  // ← stray buttons
                    payroll→ _HrWorkQueueTable
                    access → HrAccessWorkspacePanel(embedded: true)
                              // embeds Wrap(_buildActions) above table  // ← stray buttons
```

**Already good (keep):**

- No `AppWorkspace` title header / `showHeader: true` on the success path
- No FAB / `PopupMenuButton` / overflow “more” menu for screen actions
- `AppTabStrip` at top with toolbar via `primaryAction` / `secondaryActions`
- Deep-link tabs via `?section=` + `_updateUrlForSection` → `GoRouter.replace`
- Staff Filters label already `hrFiltersLabel` → **"Filters"**

### Confirmed tab inventory

| # | Tab label (l10n → EN) | Enum `HrDeskSection` | Query `section=` written (`routeQueryValue`) | Accepted aliases (`HrDeskSection.fromQuery`) | Default queue on select |
|---|----------------------|----------------------|----------------------------------------------|----------------------------------------------|-------------------------|
| 1 | `hrTitle` → **Human resources** | `staffDirectory` | `staff` | `staff`, `staff-directory`, `directory` | n/a (staff list) |
| 2 | `hrLeaveRequestsSummaryLabel` → **Leave requests** | `leaveRequests` | `leave-requests` | `leave`, `leave-requests`, `leaves` | `HrQueue.leaveRequests` |
| 3 | `hrShiftsSectionTitle` → **Shifts** | `shiftRoster` | `shift-roster` | `shift`, `shift-roster`, `roster`, `shifts` | `HrQueue.rosterDrafts` |
| 4 | `hrPayrollDraftsSummaryLabel` → **Payroll drafts** | `payroll` | `payroll` | `payroll`, `payroll-drafts` | `HrQueue.payrollDrafts` |
| 5 | `hrManageAccessAction` → **Manage users and roles** | `access` | `access` | `access`, `roles`, `permissions` | n/a |

Also keep (do not remove):

- `?queue=<HrQueue.value>` deep links mapped by `HrDeskSection.fromQueue`
- `?id=` / `?staff=` / … → open staff detail dialog on Human resources
- `?search=` / `?q=` → seed staff directory search
- `?tab=` alias for `section` (already in `HrWorkspaceQuery.fromUri`)

### Current tab toolbar (gaps)

**Primary** (`_buildPrimaryActionButton`) — already section-specific (keep handlers; fix gating + Access):

| Section | Label (EN) | Handler today | Gap |
|---------|------------|---------------|-----|
| `staffDirectory` | Add staff (`hrAddStaffAction`) | `showHrStaffOnboardingDialog` | Not wrapped in `AppAccessActionGate(hrWriteRequirement)` |
| `leaveRequests` | Request leave (`hrRequestLeaveAction`) | `showHrRequestLeaveDialog` | Same — gate write |
| `shiftRoster` | Schedule templates (`hrShiftTemplateAction`) | `showHrManageScheduleTemplatesDialog` | Gate with `hrRosterWriteRequirement` |
| `payroll` | Run payroll (`hrRunPayrollAction`) | `showHrPayrollWizardDialog` (needs a staff profile) | Gate with `hrPayrollRequirement` |
| `access` | Manage users and roles (`hrManageAccessAction`) | `showHrAccessWorkspaceDialog` | **Redundant** when panel is already embedded — replace with Create* actions |

**Secondary** (`_buildSecondaryActionWidgets`) — **identical on every tab** (not contextual):

1. HR activity (`hrActivityTitle`) → `_showActivityDialog`
2. Refresh (`commonRefreshActionLabel`) → `controller.refresh` via `AppWorkspaceRefreshAction`
3. `AppGlobalHousekeepingRequestAction`
4. `AppGlobalFaultReportAction`

### Stray actions outside the tab toolbar (must relocate)

1. **Shifts body `HrQueueSwitcher`** (`_HrWorkQueueSwitcherRow`) — row of queue buttons
   (`leaveRequests`, `swapRequests`, `rosterDrafts`, `unassignedShifts`, `payrollDrafts`, …)
   sitting **above** the table, outside `AppTabStrip`. Also spans queues that belong to other
   desk tabs (leave/payroll). Violates “no stray action buttons”.
2. **Access embedded `Wrap(_buildActions)`** in
   `HrAccessWorkspacePanel._buildBody` when `embedded: true` — Refresh + Create staff / Create
   role / Create permission rendered above the table, outside the tab toolbar.

### Current table chrome (gaps)

**Staff (`_HrStaffDirectory`):**

- Search: keep (`hrSearchLabel` / `hrSearchHint`)
- Filters: `advancedFilterButtonLabel: l10n.hrFiltersLabel` → already **"Filters"** — keep
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently
  **"Table settings"** (must become **"Settings"**)
- No Refresh / Add staff in table trailing — good

**Work queues (`_HrWorkQueueTable`) for Leave / Shifts / Payroll:**

- Settings only (`commonTableSettingsActionLabel` → “Table settings”)
- **No** search / **No** Filters button — must add Filters (exact label) wired to
  `HrWorkspaceController.applyWorkItemsScope` / existing `HrWorkItemsQuery` fields
  (`status`, date range via `from`/`to`, and keep queue selection in the **tab toolbar**, not
  as table Filters)
- Do **not** put Approve / Publish / Process / Override into the table chrome (those stay in
  work-item dialogs via `_WorkItemActions`)

**Access tables** (`HrAccessWorkspacePanel` users/roles/permissions):

- Search + Filters (`hrFiltersLabel` → “Filters”) + Settings — good shape once Settings EN is fixed
- Remove the embedded action `Wrap`; Create*/Refresh move to tab toolbar

### Concrete `prompt.md` gaps to close

1. **Settings** label is `"Table settings"`, not standardized **"Settings"**
   (`commonTableSettingsActionLabel`).
2. **Toolbar secondaries are not contextual** — same four actions on every tab.
3. **`HrQueueSwitcher` on Shifts** is stray screen chrome; relocate queue switching into the
   tab toolbar (scoped per desk tab).
4. **Access embedded action Wrap** is stray chrome; relocate Create*/Refresh into tab toolbar;
   stop using “Manage users and roles” dialog as the Access primary when already embedded.
5. **Work-queue tables lack Filters** — add standardized Filters in table search chrome.
6. **Write primaries lack `AppAccessActionGate`** — mirror Reception’s gate pattern.
7. **`appBarTitle: l10n.hrTitle`** on `AsyncStateScaffold` — omit (Reception pattern) so
   loading/error scaffolds do not present a dedicated title bar.
8. **No widget tests** asserting tab URL sync / toolbar context / Filters+Settings labels.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` —
  canonical: `ResponsivePage` + `AppTabStrip` + table; **no** page `AppWorkspace` toolbar;
  `AppAccessActionGate` on primary; omits `appBarTitle`
- `frontend/lib/shared/components/app_tab_strip.dart` —
  `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (do **not** reintroduce a
  page title header)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do **not** mount
  `appWorkspaceToolbarWithLabels` above tabs on HR
- `frontend/lib/shared/components/app_list_table.dart` — Filters + Settings wiring
- `frontend/lib/shared/components/app_search_bar.dart` — advanced Filters button
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — `showsToolbarActionLabels`, breakpoints
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage`, `PageMaxWidth`
- `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart` — keep for
  **dialog** usage (`showHrWorkQueueDialog`); remove from page body

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Human resources | `/hr?section=staff` | Staff directory | **Add staff** (`hrAddStaffAction`, `Icons.person_add_outlined`) → `showHrStaffOnboardingDialog`, gated by `AppAccessActionGate(requirement: hrWriteRequirement)` | **HR activity** (`hrActivityTitle`); **Refresh** (`commonRefreshActionLabel` / `AppWorkspaceRefreshAction`); keep `AppGlobalHousekeepingRequestAction` + `AppGlobalFaultReportAction` on this tab only (workspace-wide affordances anchored to the default tab — do not duplicate on every tab) |
| Leave requests | `/hr?section=leave-requests` | Leave + swap work items | **Request leave** (`hrRequestLeaveAction`, `Icons.event_busy_outlined`) → `showHrRequestLeaveDialog`, gated by `hrWriteRequirement` | **Swap requests** (`hrQueueSwapRequests`, `Icons.swap_horiz_outlined`) → `controller.applyQueue(HrQueue.swapRequests)` as `AppTabToolbarAction` (selected visual optional); when current queue is already swap, show **Leave requests** (`hrQueueLeaveRequests`) → `applyQueue(HrQueue.leaveRequests)` instead **or** show both as flat actions with enabled=false for the active queue; **Refresh** |
| Shifts | `/hr?section=shift-roster` | Roster / unassigned / overdue | **Schedule templates** (`hrShiftTemplateAction`, `Icons.view_week_outlined`) → `showHrManageScheduleTemplatesDialog`, gated by `hrRosterWriteRequirement` | **Roster drafts** (`hrQueueRosterDrafts`); **Unassigned shifts** (`hrQueueUnassignedShifts`); **Overdue shifts** (`hrQueueOverdueShifts`) — each `AppTabToolbarAction` → `controller.applyQueue(...)`; disable/highlight the active queue; **Refresh**. Do **not** expose leave/payroll queues here |
| Payroll drafts | `/hr?section=payroll` | Payroll draft runs | **Run payroll** (`hrRunPayrollAction`, `Icons.payments_outlined`) → existing wizard staff selection logic, gated by `hrPayrollRequirement` | **Refresh** only |
| Manage users and roles | `/hr?section=access` | Users / roles / permissions | Contextual Create* based on `HrAccessPanel` (see below), write-gated via existing `canWriteHrAccess` / equivalent gate | **Refresh** that calls the access panel reload (not only workspace `refresh`); optional: expose Create role / Create permission as secondaries when primary is Create staff, or flip primary with panel |

**Access primary mapping (embedded):**

| Active `HrAccessPanel` | Primary label | Handler |
|------------------------|---------------|---------|
| `users` | `hrCreateUserAction` (“Create staff”) | `showHrStaffOnboardingDialog` then reload access list |
| `roles` | `hrAccessCreateRoleAction` (“Create role”) | `showHrCreateRoleDialog` then reload |
| `permissions` | `hrAccessCreatePermissionAction` (“Create permission”) | `showHrCreatePermissionDialog` then reload |

When write is denied or tenant context is required, disable primary (do not open dialog).

**Implementation note for Access toolbar:** `HrAccessPanel` state lives inside
`HrAccessWorkspacePanel`. Lift coordination so the page can rebuild tab toolbar actions:

- Preferred: add an optional callback / `ValueNotifier` / small Riverpod notifier on the
  embedded panel reporting `{panel, canWrite, isLoading, onRefresh, onCreate}` to the parent,
  **or**
- Expose a public `HrAccessWorkspaceController`-style API already used by the panel.

Do **not** leave Create*/Refresh in the embedded `Wrap`. Dialog mode (`embedded: false`) may
keep dialog `actions:` as today.

### Routing

- Keep `AppRoutes.hr` `/hr` registration unchanged in
  `frontend/lib/app/router/app_routes.dart` and `app_router.dart`.
- Keep `_updateUrlForSection` writing `?section=<HrDeskSection.routeQueryValue>`.
- Keep `HrWorkspaceQuery.fromUri` aliases; do not invent a second tab query key.
- When shifting queues via toolbar (leave/swap or shift queues), optionally sync
  `?queue=<HrQueue.value>` in addition to `section` if that already aids deep links — only if
  existing query model supports it without breaking tests; otherwise rely on `section` +
  in-memory `applyQueue` (current leave/payroll tabs already do this).

### Page Layout

Precise widget tree after refactor:

1. `AsyncStateScaffold<HrWorkspaceState>` — **omit** `appBarTitle` (loading/error use
   `loadingTitle` / failure scaffolds only, like Reception)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
3. `Column` → `AppTabStrip(tabs:, selectedId:, onTabTapped:, primaryAction:, secondaryActions:)`
4. `SizedBox(height: theme.spacing.sm)` (keep existing theme spacing)
5. Optional `AppFailureStateView` for `state.lastFailure`
6. Body by section:
   - Staff → `_HrStaffDirectory` `AppListTable` (search + **Filters** + **Settings** only)
   - Leave / Shifts / Payroll → `_HrWorkQueueTable` only (**no** `HrQueueSwitcher` row)
   - Access → `HrAccessWorkspacePanel(embedded: true)` **without** action Wrap; keep
     `AppWorkspaceBoardToggle` for Users/Roles/Permissions as **content** navigation (not
     screen action buttons)
7. No FAB / floating header actions / overflow more-menu for screen actions
8. Do **not** wrap the success path in `AppWorkspace(toolbar: …)` above tabs

### Data & State Management

Reuse (do not fork):

- `hrWorkspaceControllerProvider` /
  `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`
- `HrDeskSection`, `HrQueue`, `HrWorkspaceQuery`, `HrWorkItemsQuery`, `HrStaffQuery` in
  `frontend/lib/features/hr/domain/entities/hr_entities.dart`
- Dialogs under `frontend/lib/features/hr/presentation/widgets/`
- Permission constants in `hr_presentation_helpers.dart`

## Implementation Steps

1. **Normalize Settings label (l10n)** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` English value from `"Table settings"` to
     `"Settings"` (affects all workspaces intentionally — required standardization).
   - If another screen already flipped this key to `"Settings"`, skip the arb edit and verify only.
   - Regenerate / update generated localizations if the project expects it after arb edits.
   - Keep using `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` on HR tables
     (staff, work queue, access).

2. **Omit loading title bar** — File: `hr_workspace_page.dart`
   - Remove `appBarTitle: l10n.hrTitle` from `AsyncStateScaffold` (match Reception).

3. **Make toolbar secondaries contextual** — File: `hr_workspace_page.dart`
   - Rewrite `_buildSecondaryActionWidgets` (and primary Access branch) per the Target
     Architecture table.
   - Move Activity + global housekeeping/fault to **Human resources** only.
   - Add leave/swap and shift-queue `AppTabToolbarAction`s as specified.
   - Always include Refresh on every tab (Access refresh must reload access panel data).

4. **Remove page-body `HrQueueSwitcher`** — File: `hr_workspace_page.dart`
   - In `_buildTabBody` for `shiftRoster`, render only `_HrWorkQueueTable` (same as leave/payroll).
   - Keep `_HrWorkQueuePanel` + `HrQueueSwitcher` for `showHrWorkQueueDialog` in
     `hr_workspace_dialog_actions.dart` (dialog chrome is fine).

5. **Gate write primaries** — File: `hr_workspace_page.dart`
   - Wrap each write primary in `AppAccessActionGate` with the requirement from the Target table
     (same pattern as Reception’s `receptionFrontDeskWriteRequirement` gate).
   - Import `package:hosspi_hms/core/permissions/access_gate.dart` if not already exported via
     shared barrels you already use.

6. **Fix Access embedded chrome** — Files: `hr_access_dialogs.dart`, `hr_workspace_page.dart`
   - When `embedded: true`, **do not** render `Wrap(children: _buildActions(...))`.
   - Surface panel + create/refresh handlers to the page so Access tab toolbar matches the
     Target Architecture Create* / Refresh mapping.
   - Keep dialog mode (`embedded: false`) actions on `AppDialog.actions`.
   - Keep `AppWorkspaceBoardToggle` for Users / Roles / Permissions inside the panel body.

7. **Add Filters to work-queue tables** — File: `hr_workspace_page.dart` (`_HrWorkQueueTable`)
   - Add `AppListTableSearch` (or search-less Filters affordance if search is unsupported) with:
     - `showAdvancedFilterButton: true`
     - `advancedFilterButtonLabel: l10n.hrFiltersLabel` (must render **"Filters"**)
     - Wire status / date (and any existing query fields) through
       `controller.applyWorkItemsScope` / query copyWith — mirror staff Filters UX patterns
       from `_HrStaffDirectory` and Reception/Pharmacy advanced filters.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (**Settings**).
   - Do **not** add Refresh / Approve / Publish into table chrome.

8. **Confirm staff + access tables** — only Filters + Settings (+ search) remain in table chrome;
   no other header actions.

9. **Add / update tests**
   - Extend `frontend/test/features/hr/domain/hr_entities_test.dart` if needed (already covers
     section aliases).
   - Create `frontend/test/features/hr/presentation/hr_workspace_page_test.dart` following
     Pharmacy/Reception widget test patterns:
     - Tab strip shows all five labels
     - Tapping Leave updates URL to `section=leave-requests` and shows Request leave primary
     - Deep link `/hr?section=shift-roster` selects Shifts and shows Schedule templates
     - Shifts body has **no** `HrQueueSwitcher` / queue chip row; roster/unassigned/overdue appear
       as toolbar actions
     - Access embedded has no Create/Refresh Wrap; Create staff (or panel-appropriate) is in
       toolbar
     - Settings / Filters visible labels are `"Settings"` / `"Filters"` where pumped
   - Update `hr_queue_switcher_test.dart` only if API changes; keep dialog coverage.

10. **Format / analyze / test** — run Verification Steps below.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Staff / queue / access tables; Filters + Settings only |
| `AppSearchBarFilterGroup` / filter value types | `package:hosspi_hms/shared/components/app_search_bar.dart` | Advanced Filters |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` | Page width shell |
| `AppWorkspaceRefreshAction` | shared layout / actions (already used) | Refresh secondary |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write primaries |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/app_state_view.dart` | Loading/error wrapper without title bar |
| `AppWorkspaceBoardToggle` | `package:hosspi_hms/shared/layout/app_workspace_board_toggle.dart` | Access Users/Roles/Permissions content toggle only |
| `HrQueueSwitcher` | `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart` | **Dialog only** after refactor |

**Forbidden:** new custom tab bars, new table header action rows beyond Filters/Settings, new
overflow/more menus for screen actions, reintroducing `AppWorkspace` toolbar above tabs,
reintroducing page title headers.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — contextual toolbar; remove switcher from Shifts body; gate primaries; queue Filters; omit `appBarTitle` |
| Modify | `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart` — remove embedded action Wrap; expose create/refresh/panel to page toolbar |
| Modify | `frontend/lib/l10n/app_en.arb` — `commonTableSettingsActionLabel` → `"Settings"` (if still `"Table settings"`) |
| Create | `frontend/test/features/hr/presentation/hr_workspace_page_test.dart` — chrome / deep-link / toolbar tests |
| Keep (dialog) | `frontend/lib/features/hr/presentation/pages/hr_workspace_dialog_actions.dart` — work-queue dialog may still use `_HrWorkQueuePanel` + switcher |
| Keep | `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart` — dialog usage |
| Do not modify (unless shared Settings label requires regen only) | Reception page, `app_tab_strip.dart`, router registration paths |

## Cleanup: Remove Stale Code

- [ ] Remove `_HrWorkQueueSwitcherRow` from Shifts `_buildTabBody` (delete the private widget if
      unused elsewhere in the page file)
- [ ] Remove Access embedded `Wrap(_buildActions)` path
- [ ] Remove Access tab primary that only opens `showHrAccessWorkspaceDialog` while embedded
- [ ] Ensure no duplicate Refresh on Access (toolbar only)
- [ ] Do not leave commented-out header / more-menu code
- [ ] Keep `_HrWorkQueuePanel` for dialogs; do not delete if still referenced by
      `showHrWorkQueueDialog`

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px / especially ≥1200 `xl` where `showsToolbarActionLabels` is true): full
  `AppTabStrip` + labeled primary + labeled contextual secondaries; full `AppListTable` with
  Filters + Settings labels visible.
- Tablet (600–1023px): tab strip scrolls horizontally; toolbar `Wrap` may wrap secondary actions;
  table may compress columns — Filters/Settings remain available.
- Mobile (<600px): tabs scroll; toolbar icons/labels follow `AppBreakpoints.showsToolbarActionLabels`;
  existing `mobileItemBuilder`s on staff/queue tables remain.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/hr/
flutter test test/shared/
```

If arb strings changed, also run the project’s usual l10n generation command before analyze/tests
(if the repo requires it).

## Testing Requirements

- [ ] Tab switch updates URL (`?section=`) and toolbar actions
- [ ] Deep link opens correct tab (`staff`, `leave-requests`, `shift-roster`, `payroll`, `access`)
- [ ] Per-tab toolbar shows only that tab’s actions (primaries + secondaries as specified)
- [ ] Shifts page body has no queue chip row; queue switches live in toolbar
- [ ] Access embedded has no Create/Refresh Wrap; those live in toolbar
- [ ] Table chrome has only Filters and Settings (plus search) — labels exact
- [ ] No screen title/header chrome on the success path; no `appBarTitle` on scaffold
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate write actions (`AppAccessActionGate` / access write checks)
- [ ] Responsive layouts still work; dialogs (staff detail, work item, schedule templates, payroll
      wizard, access dialog mode) still function
- [ ] `HrQueueSwitcher` still works inside `showHrWorkQueueDialog`

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Filters label is **Filters**; Settings label is **Settings**
- [ ] Domain logic preserved (queues, access panels, deep links, mutations, counts)
- [ ] Analyze clean; tests pass; stale page-body switcher / access Wrap removed
`)