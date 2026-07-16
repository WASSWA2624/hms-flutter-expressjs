# Standardize Nursing Screen (Tabs & Toolbar)

## Objective

Refactor the Nursing workspace (`/nursing`, `NursingWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Nursing domain logic** (queue scopes, worklist filters/columns, vitals / medication /
handover / transfer / discharge dialogs, shift context, permissions, realtime refresh, deep links).
This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
  - `NursingWorkspacePage` → `AsyncStateScaffold` → `_NursingWorkspaceContent` /
    `_NursingWorkspaceContentState`
- Tab / scope helpers: `frontend/lib/features/nursing/presentation/widgets/nursing_scope_navigation.dart`
  - `nursingScopeToQueryValue`, `nursingScopeFromQueryValue`, `nursingPrimaryActionLabel`,
    `nursingPrimaryActionIcon`, `nursingTabItems`
- Worklist table: `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart`
  - `NursingWorklistPanel` → `AppListTable<NursingWorkItem>`
- Filters: `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_filters.dart`
- Columns: `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_columns.dart`
- Summary chips (workspace toolbar): `frontend/lib/features/nursing/presentation/widgets/nursing_summary_notifications.dart`
  - `nursingSummaryNotifications(...)`
- Helpers: `frontend/lib/features/nursing/presentation/widgets/nursing_helpers.dart`
- Controller: `frontend/lib/features/nursing/presentation/controllers/nursing_workspace_controller.dart`
  - Provider: `nursingWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyScope()`, `applySearch()`, `applyAdvancedFilters()`,
    `selectPatient` / `selectPatientByDisplayId`, care-action save methods
- Domain: `frontend/lib/features/nursing/domain/entities/nursing_entities.dart`
  - `NursingQueueScope`, `NursingDetailPanel`, `NursingWorkspaceQuery.fromUri`,
    `NursingWorklistQuery`, `NursingWorkspaceState` (+ count getters)
- Routes: `AppRoutes.nursing` path `/nursing` in `frontend/lib/app/router/app_routes.dart`;
  builder in `frontend/lib/app/router/app_router.dart` passes
  `NursingWorkspaceQuery.fromUri(state.uri)` into `NursingWorkspacePage(initialQuery: …)`
- Tests:
  - `frontend/test/features/nursing/presentation/nursing_workspace_page_test.dart`
  - `frontend/test/features/nursing/presentation/nursing_workspace_navigation_test.dart`
  - `frontend/test/features/nursing/presentation/nursing_workspace_controller_test.dart`
  - `frontend/test/features/nursing/domain/nursing_entities_test.dart`
  - `frontend/test/features/nursing/data/nursing_dtos_test.dart`

### Current widget tree (chrome)

```
AsyncStateScaffold
  └── AppWorkspace(
        title: l10n.nursingTitle,          // showHeader defaults false → title not painted
        leadingIcon: AppRouteIcons.nursing,
        scrollable: false,
        toolbar: appWorkspaceToolbarWithLabels(   // ❌ renders ABOVE tabs
          summaryNotifications: nursingSummaryNotifications(...),
          secondary: [Shift context, Add note],
          onRefresh: controller.refresh,
        ),
        body: Column(
          AppTabStrip(
            tabs: nursingTabItems(l10n),          // no counts today
            selectedId: nursingScopeToQueryValue(_scope),
            primaryAction: gated AppTabToolbarPrimary(contextual),  // ✅ under tabs
            // secondaryActions: unset
          ),
          SizedBox(height: theme.spacing.sm),
          Expanded(child: NursingWorklistPanel → AppListTable),
        ),
      )
```

`AppWorkspace.showHeader` defaults to `false`, so the titled header row is already omitted — but
`AppWorkspaceToolbar` still paints **above** the tab strip whenever `toolbar:` is set. That
violates “toolbar immediately beneath tabs”.

### Confirmed tab inventory (validated against code + l10n)

| # | Tab label (l10n key → EN) | Enum `NursingQueueScope` | URL query `scope=` | Primary toolbar today |
|---|---------------------------|--------------------------|--------------------|------------------------|
| 1 | All (`nursingScopeAllLabel`) | `all` | omit / `all` (canonical write omits when `all`) | Record vitals (`nursingActionRecordVitals`) |
| 2 | Assigned ward (`nursingScopeAssignedWardLabel`) | `assignedWard` | `assigned-ward` | Record vitals |
| 3 | Urgent (`nursingScopeUrgentLabel`) | `urgent` | `urgent` | Record vitals |
| 4 | Medication due (`nursingScopeMedicationDueLabel`) | `medicationDue` | `medication-due` | Administer medication (`nursingActionAdministerMedication`) |
| 5 | Handover pending (`nursingScopeHandoverPendingLabel`) | `handoverPending` | `handover-pending` | Create handover (`nursingActionCreateHandover`) |
| 6 | Transfer pending (`nursingScopeTransferPendingLabel`) | `transferPending` | `transfer-pending` | Acknowledge transfer (`nursingActionAcknowledgeTransfer`) |
| 7 | Discharge pending (`nursingScopeDischargePendingLabel`) | `dischargePending` | `discharge-pending` | Discharge clearance (`nursingActionDischargeClearance`) |

Query helpers (keep all aliases):

- Write: `nursingScopeToQueryValue` → `all`, `assigned-ward`, `urgent`, `medication-due`,
  `handover-pending`, `transfer-pending`, `discharge-pending`
- Read: `nursingScopeFromQueryValue` also accepts `assigned_ward` / `ward`, `critical`,
  `medication_due` / `medication`, `handover_pending` / `handover`, `transfer_pending` /
  `transfer`, `discharge_pending` / `discharge`, empty/`all` → `NursingQueueScope.all`
- `NursingWorkspaceQuery.fromUri` also accepts `section` / `filter` / `queue` as scope keys;
  `search` / `q` / `patient`; admission `id` / `admissionId` / …; `panel` / `detail`

Deep-link tab state is **already URL-backed** via `_updateUrlForScope` →
`AppRoutes.nursing.location(queryParameters: {if not all: 'scope': tab})` +
`GoRouter.replace`, and `_applyDeepLink` syncs scope + optional patient detail / panel dialogs.
**No new query param is required** — keep `scope`.

### Actions currently outside `AppTabStrip` toolbar

Rendered via `appWorkspaceToolbarWithLabels` on `AppWorkspace.toolbar` (above tabs):

| Action | l10n | Handler | Gate |
|--------|------|---------|------|
| Summary notification chips | various `nursing*SummaryLabel` + hardcoded `'All nursing worklist'` | `onTabTapped(scope)` | none |
| Shift context | `nursingShiftContextTitle` | `_openShiftContextDialog` → `NursingShiftContextDialog` | none |
| Add note | `nursingActionAddNote` | `_openNoteDialog` → `NursingNoteDialog` | `writeRequirement` (`AppAccessActionGate`) |
| Refresh | via toolbar helper (`commonRefreshActionLabel` path) | `controller.refresh()` + `nursingShowFailureIfNeeded` | none |

### Table chrome (already mostly compliant)

- Search: `AppListTableSearch` with nursing hints/fields
- Filters button label: `l10n.nursingAdvancedFiltersLabel` → **"Filters"** ✅
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (shared key; EN is
  `"Table settings"` — keep the shared key; do not invent a nursing-only Settings label)
- No other table-header action buttons
- Scope-specific columns via `nursingColumnsForScope` / `nursingColumnChoicesForScope`

### Write permission gate (preserve)

```dart
static const AccessRequirement writeRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.patientWrite,
    AppPermissions.lastOfficeWrite,
  ],
  anyRoles: <AppRole>[
    AppRole.nurse,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
    AppRole.facilityAdmin,
    AppRole.tenantAdmin,
    AppRole.superAdmin,
  ],
  activeModules: <String>['inpatient-bed-management'],
);
```

### Concrete `prompt.md` gaps

1. **Workspace toolbar sits above tabs** — `AppWorkspace(toolbar: appWorkspaceToolbarWithLabels(...))`
   paints Shift context, Add note, Refresh, and summary chips **above** `AppTabStrip`. Must move
   all screen actions into `AppTabStrip.primaryAction` / `secondaryActions` so the only action
   toolbar is immediately under the tabs.
2. **Dual chrome** — page uses `AppWorkspace` + titled props + workspace toolbar while peers
   (Reception / Emergency / IPD) use `ResponsivePage` + `AppTabStrip` only. Prefer Reception
   pattern: drop the workspace toolbar chrome (or use `AppWorkspace(showHeader: false)` with
   **no** `toolbar:` / primary / secondary on the workspace itself).
3. **Summary notifications duplicate tab navigation** — chips in the workspace toolbar jump scopes;
   tab counts belong on `AppTabItem.count` (Reception pattern). Remove summary chips from screen chrome.
4. **`secondaryActions` unset on `AppTabStrip`** — Shift context / Add note / Refresh are not under tabs.
5. **Primary is already contextual** — keep `_executePrimaryAction` + `nursingPrimaryActionLabel` /
   `nursingPrimaryActionIcon`; do not flatten all tabs to one CTA.
6. **No screen-level overflow/more menu today** — do not introduce one.
7. **Already compliant (do not regress):** URL-backed `?scope=`; Filters label `"Filters"`;
   Settings via shared key; gated write primary; deep-link patient/`panel` dialogs; domain dialogs.

### Preserve (do not relocate to tab toolbar)

- **Patient detail dialog actions** (`NursingPatientDetailDialog` and related dialogs:
  vitals, medication, handover, transfer, discharge, note, escalate, print, etc.) — stay
  row/detail scoped.
- **Table search + advanced filter sheet** — remain inside `AppListTable` / `AppListTableSearch`.
- Realtime / adaptive polling in `NursingWorkspaceController`.
- Permission gate semantics for write CTAs.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — canonical layout: `ResponsivePage` + `AppTabStrip` + `SizedBox(sm)` + `AppListTable`;
  `primaryAction` via `AppAccessActionGate` + `AppTabToolbarPrimary`; query-backed tabs;
  tab **counts** on `AppTabItem`
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
  — Refresh as `AppTabToolbarAction` in `secondaryActions` with `l10n.commonRefreshActionLabel`
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  — contextual `primaryAction` + populated `secondaryActions`
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader: false` semantics; prefer **not**
  using workspace toolbar for Nursing after this refactor
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only (stop calling from Nursing page)
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All | `/nursing` (no `scope`, or `scope=all`) | Full nursing worklist | **Record vitals** — `AppTabToolbarPrimary` + `AppAccessActionGate(writeRequirement)`; `nursingActionRecordVitals` / `Icons.monitor_heart_outlined` → `_openVitalsDialog` | **Shift context** (`nursingShiftContextTitle`, `Icons.assignment_ind_outlined`) → `_openShiftContextDialog`; **Add note** (`nursingActionAddNote`, gated) → `_openNoteDialog`; **Refresh** (`commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()` + failure toast |
| Assigned ward | `/nursing?scope=assigned-ward` | Ward-assigned queue | Same **Record vitals** (gated) | Same Shift context + Add note + Refresh |
| Urgent | `/nursing?scope=urgent` | Urgent / critical alerts | Same **Record vitals** (gated) | Same secondaries |
| Medication due | `/nursing?scope=medication-due` | Patients with meds due | **Administer medication** — gated; opens `NursingMedicationDialog` when a patient is selected (existing `_executePrimaryAction` behavior) | Same secondaries |
| Handover pending | `/nursing?scope=handover-pending` | Pending handovers | **Create handover** — gated → `NursingHandoverDialog` | Same secondaries |
| Transfer pending | `/nursing?scope=transfer-pending` | Pending transfers | **Acknowledge transfer** — gated → `NursingTransferDialog` when detail selected | Same secondaries |
| Discharge pending | `/nursing?scope=discharge-pending` | Discharge clearance queue | **Discharge clearance** — gated → `NursingDischargeClearanceDialog` when detail selected | Same secondaries |

**Rules for the matrix**

- Primary **must** continue to swap with `_scope` using existing helpers in
  `nursing_scope_navigation.dart` and `_executePrimaryAction` in the page.
- Secondaries (Shift context, Add note, Refresh) appear on **every** tab so the toolbar is never
  empty even if a write gate hides the primary.
- Do **not** reintroduce `appWorkspaceToolbarWithLabels` / summary notification chips on the page.
- Do **not** add a header more-menu / FAB.

### Routing

- Keep `/nursing` and `NursingWorkspaceQuery.fromUri` — **no router structural changes required**.
- Keep `_updateUrlForScope` write behavior: omit `scope` when active tab is `all`; otherwise write
  kebab-case values from `nursingScopeToQueryValue`.
- Keep deep-link apply path: scope → search → `admissionId` opens `NursingPatientDetailDialog` →
  optional `panel` opens vitals/medication/handover/discharge dialogs.
- Continue accepting existing aliases in `nursingScopeFromQueryValue` / `fromUri`.

### Page Layout

Precise widget tree for `_NursingWorkspaceContentState.build`:

1. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: …)` — **preferred**, matching Reception.
   If you keep `AppWorkspace`, it **must** be `showHeader: false` with **no** `toolbar:`,
   `primaryAction:`, or `secondaryActions:` on the workspace itself (tabs own all actions).
2. `Column(crossAxisAlignment: stretch)` with:
   - `AppTabStrip(
         tabs: nursingTabItems(l10n, state),  // include counts
         selectedId: nursingScopeToQueryValue(_scope),
         onTabTapped: _onTabTapped,
         primaryAction: …,   // gated contextual primary
         secondaryActions: …, // Shift context, Add note, Refresh
       )`
   - `SizedBox(height: Theme.of(context).spacing.sm)`
   - `Expanded(child: NursingWorklistPanel(...))`
3. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

Reuse as-is (adjust call sites only for chrome wiring):

| Symbol | Path |
|--------|------|
| `nursingWorkspaceControllerProvider` / `NursingWorkspaceController` | `frontend/lib/features/nursing/presentation/controllers/nursing_workspace_controller.dart` |
| `NursingWorkspaceState`, `NursingWorkspaceQuery`, `NursingQueueScope`, `NursingDetailPanel` | `frontend/lib/features/nursing/domain/entities/nursing_entities.dart` |
| Scope / tab helpers | `frontend/lib/features/nursing/presentation/widgets/nursing_scope_navigation.dart` |
| `NursingWorklistPanel` | `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart` |
| `writeRequirement` on page state class | keep in `nursing_workspace_page.dart` |
| `AppAccessActionGate` | `frontend/lib/core/permissions/access_gate.dart` |

## Implementation Steps

1. **Replace workspace chrome with Reception-style page shell** — File:
   `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
   - Remove `AppWorkspace(...)` title / leadingIcon / `toolbar: appWorkspaceToolbarWithLabels(...)`.
   - Build with `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` wrapping a full-width `Column`
     (mirror Reception’s `SizedBox(width: double.infinity, child: Column(...))` pattern).
   - Keep `AsyncStateScaffold` wrapper on `NursingWorkspacePage` unchanged
     (`maxWidth: PageMaxWidth.dataHeavy`, `centerVertically: false`).
   - Remove imports that become unused (`appWorkspaceToolbarWithLabels`,
     `nursing_summary_notifications.dart`, `AppRouteIcons` if only used for workspace leading).

2. **Move former workspace-toolbar actions into `AppTabStrip`** — same file
   - Keep existing gated contextual `primaryAction` (`AppTabToolbarPrimary` +
     `nursingPrimaryActionLabel` / `nursingPrimaryActionIcon` / `_executePrimaryAction`).
   - Set `secondaryActions` to an ordered list (left → right):
     1. `AppTabToolbarAction` — Shift context (`l10n.nursingShiftContextTitle`,
        `Icons.assignment_ind_outlined`) → `_openShiftContextDialog`
     2. `AppAccessActionGate(writeRequirement)` wrapping `AppTabToolbarAction` — Add note
        (`l10n.nursingActionAddNote`, `Icons.note_add_outlined`) → `_openNoteDialog`
        (respect `state.isSaving` / `enabled`)
     3. `AppTabToolbarAction` — Refresh (`l10n.commonRefreshActionLabel`, `Icons.refresh`)
        → `controller.refresh()` + `nursingShowFailureIfNeeded`; set `isLoading` /
        `enabled` from `state.isRefreshing || state.isRefreshingDetail` (match Access Admin /
        prior toolbar behavior)
   - Ensure toolbar rebuilds when `_scope` or `state` changes (already true via `setState` /
     `widget.state`).

3. **Wire tab counts onto `AppTabItem`** — File:
   `frontend/lib/features/nursing/presentation/widgets/nursing_scope_navigation.dart`
   - Change `nursingTabItems` to accept `NursingWorkspaceState state` (and keep `AppLocalizations`).
   - Set `count` / `countTone` analogous to former summary chips:
     - All → `nursingPageTotal(state.worklist)` (import helper from `nursing_helpers.dart`) or
       `state.worklist.totalItemCount` if that is the existing total semantics; tone `info`
     - Assigned ward → `state.assignedWardCount` (`info`)
     - Urgent → `state.urgentCount` (`danger`)
     - Medication due → `state.medicationDueCount` (`warning`)
     - Handover pending → `state.handoverPendingCount` (`info` / default)
     - Transfer pending → `state.transferPendingCount` (`warning`)
     - Discharge pending → `state.dischargePendingCount` (`info` — former summary used `success`;
       map to nearest `AppTabCountTone`, prefer `info` unless danger/warning is clearer)
   - Omit count when `0` if that matches Reception (Reception always passes counts — follow
     Reception: pass the int; `AppTabStrip` will render superscript when non-null). Prefer
     passing `null` when count is `0` to avoid noisy zeros (either approach is fine; be
     consistent across all nursing tabs).
   - Update call site in the page: `nursingTabItems(l10n, state)`.

4. **Remove summary-notification chrome** — Files:
   - Stop calling `nursingSummaryNotifications` from the page.
   - If `nursing_summary_notifications.dart` has no remaining references after grep, **delete**
     the file. If something else still imports it, leave the file but unused from the page.
   - Do not keep the hardcoded `'All nursing worklist'` string in UI chrome.

5. **Table chrome hygiene** — File:
   `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart`
   - Keep `advancedFilterButtonLabel: l10n.nursingAdvancedFiltersLabel` (**"Filters"**).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
   - Do **not** add Shift context / Add note / Refresh / vitals / etc. into the table header.
   - Do **not** move search out of `AppListTableSearch`.
   - Leave column/filter builders and mobile `mobileItemBuilder` intact.

6. **Update tests** — Files under `frontend/test/features/nursing/`
   - `nursing_workspace_page_test.dart`:
     - Assert `AppTabStrip` still present; primary tooltips still swap (Record vitals ↔
       Administer medication, etc.).
     - Assert Shift context / Add note / Refresh are findable as toolbar actions **without**
       requiring `AppWorkspaceToolbar` / summary chips.
     - Assert `find.text(l10n.nursingTitle)` is **absent** as page header chrome (title may
       still exist only in shell nav elsewhere — do not require nursing page to paint it).
     - Keep deep-link / scope / mobile / row-open coverage; adjust finders if they keyed off
       workspace toolbar widgets.
   - `nursing_workspace_navigation_test.dart`:
     - Extend `nursingTabItems` tests if signature changes (pass a minimal `NursingWorkspaceState`
       fixture); keep primary label/icon and scope round-trip tests.
   - Do not weaken permission / controller / DTO / entity tests.

7. **Format, analyze, run tests** — see Verification Steps.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + under-tab toolbar |
| `AppListTable` / `AppListTableSearch` | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Filters + Settings only |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AsyncStateScaffold` | shared layout/components | Loading / error / retry |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write primary + Add note |
| `AppButton` / `showAppDialog` | shared components | Dialogs only (not screen header chrome) |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Already used indirectly via table/mobile |

**Forbidden:** new custom tab bars, new screen header widgets, new “more” menus for screen actions,
reintroducing `appWorkspaceToolbarWithLabels` on this page, duplicate Filters implementations.

## Files to Create / Modify / Delete

| Action | File |
|--------|------|
| Modify | `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart` |
| Modify | `frontend/lib/features/nursing/presentation/widgets/nursing_scope_navigation.dart` |
| Modify (only if needed for unused imports / no logic change) | `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart` |
| Delete if unused | `frontend/lib/features/nursing/presentation/widgets/nursing_summary_notifications.dart` |
| Modify | `frontend/test/features/nursing/presentation/nursing_workspace_page_test.dart` |
| Modify | `frontend/test/features/nursing/presentation/nursing_workspace_navigation_test.dart` |
| Do not modify (unless audit proves a bug blocking chrome) | `app_router.dart`, `app_routes.dart`, nursing repository/DTOs, dialog widgets |

## Cleanup: Remove Stale Code

- [ ] Remove `toolbar: appWorkspaceToolbarWithLabels(...)` from Nursing page
- [ ] Remove `summaryNotifications: nursingSummaryNotifications(...)` usage
- [ ] Remove unused imports (`AppRouteIcons` if unused, summary notifications, workspace toolbar helpers)
- [ ] Delete `nursing_summary_notifications.dart` if no remaining references
- [ ] Grep for `appWorkspaceToolbarWithLabels` / `nursingSummaryNotifications` under nursing — expect zero page usages
- [ ] Confirm no FAB / `PopupMenuButton` screen-header overflow for chrome actions
- [ ] Confirm `AppWorkspaceHeader` / titled nursing page header is not reintroduced (`showHeader: true` forbidden)

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): `AppTabStrip` (horizontal scroll if needed) + under-tab toolbar + full
  `AppListTable` data columns (existing `NursingWorklistPanel` behavior).
- Tablet (600–1023px): Same chrome; table may compress columns via existing visibility/width
  storage keys `nursing_${scope.name}` / `nursing_cw_${scope.name}`.
- Mobile (<600px): Keep existing `mobileItemBuilder` list tiles; tab strip + toolbar remain at
  top; no separate mobile title header.

Follow Reception spacing: `SizedBox(height: theme.spacing.sm)` between tab strip and body.
`AppTabStrip` already applies vertical padding on the toolbar row via `theme.spacing.sm`.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/nursing/
flutter test test/shared/
```

If analyze flags unused imports from the chrome move, fix them before finishing.

## Testing Requirements

- [ ] Tab switch updates URL `scope` (omit for All) and swaps primary toolbar label/icon
- [ ] Deep link `/nursing?scope=urgent` (and aliases) opens correct tab
- [ ] Per-tab primary matches the matrix; secondaries (Shift context, Add note, Refresh) present
- [ ] Table chrome has only Filters + Settings (plus search field — allowed)
- [ ] No `AppWorkspace` toolbar / summary chips / dedicated Nursing title header on the page
- [ ] At least one toolbar button exists on every tab (secondaries guarantee this)
- [ ] Write actions still gated by `writeRequirement`
- [ ] Selecting a row still opens `NursingPatientDetailDialog`
- [ ] Mobile breakpoint still uses list tiles
- [ ] Analyze clean; nursing + shared tests pass; stale summary chrome removed

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` + `secondaryActions`)
- [ ] No dedicated header; no stray actions above tabs; no header more-menu
- [ ] Domain logic preserved (scopes, dialogs, deep links, permissions, realtime)
- [ ] Analyze clean; tests pass; stale code removed
