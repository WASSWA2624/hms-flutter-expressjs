# Standardize Reception Screen (Tabs & Toolbar)

## Objective

Refactor the Reception workspace (`/reception`, `ReceptionWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

Reception is the canonical reference layout, but this audit found remaining compliance gaps.
Close those gaps — do **not** treat the current page as already perfect.

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

Preserve all Reception domain behavior (OPD data sources, stage filters, permissions, deep links,
row navigation, register-patient dialog, schedule-appointment helper, flow-actions dialog).

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  - Public widget: `ReceptionWorkspacePage`
  - Content state: `_ReceptionWorkspaceContent` / `_ReceptionWorkspaceContentState`
  - Row model: `_ReceptionDeskRow`
- Entities / deep-link model: `frontend/lib/features/reception/domain/entities/reception_entities.dart`
  - `ReceptionWorkspaceQuery` (parses `section`, `search`, `patientId`, `flowId`)
  - `ReceptionDeskSection` enum: `appointments`, `queue`, `activeVisits`, `paymentGate`
- Access: `frontend/lib/features/reception/presentation/reception_access.dart`
  - Write gate: `receptionFrontDeskWriteRequirement` (== `opdFrontDeskActionRequirement`)
  - Billing guidance gate: `receptionBillingGuidanceRequirement`
  - Cashier gate: `receptionBillingCashierRequirement` (do **not** put cashier finalize in Reception toolbar)
- Helpers: `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
  - `openReceptionPatientEditor`
  - `openReceptionScheduleAppointment` (exists but **not wired** into current toolbar)
  - `openReceptionInsuranceCapture`
- Billing panel (row/detail guidance, not screen chrome): `frontend/lib/features/reception/presentation/widgets/reception_billing_guidance.dart`
- Route: `AppRoutes.reception` path `/reception` in `frontend/lib/app/router/app_routes.dart`
- Router builder: `frontend/lib/app/router/app_router.dart` passes `ReceptionWorkspaceQuery.fromUri(state.uri)`
- Data: `opdWorkspaceControllerProvider` / `OpdWorkspaceState` (appointments, queueEntries, flows)
- Tests today: `frontend/test/features/reception/presentation/reception_access_test.dart` (query + auth only; no chrome tests)

### Current widget tree (chrome)

1. `AsyncStateScaffold<OpdWorkspaceState>` (loading only; not a screen title bar)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
3. `Column` → `AppTabStrip` → `SizedBox(height: theme.spacing.sm)` → `AppListTable<_ReceptionDeskRow>`
4. **No** `AppWorkspace` title/header (already compliant on that point)
5. **No** FAB / PopupMenu / overflow “more” menu on the page today

### Tabs (validated)

| # | Tab label (l10n) | Enum | Query `section` value written by `_updateUrlForSection` | Accepted aliases in `_sectionFromQuery` |
|---|------------------|------|----------------------------------------------------------|-----------------------------------------|
| 1 | `receptionSectionAppointments` → **Appointments** | `appointments` | `appointments` | `appointments`, `meetings` |
| 2 | `receptionSectionQueue` → **Desk queue** | `queue` | `desk-queue` | `queue`, `desk_queue`, `desk-queue` |
| 3 | `receptionSectionActiveVisits` → **Active visits** | `activeVisits` | `active` | `in-progress`, `active`, `visits`, `turnaround_pressure` |
| 4 | `receptionSectionPaymentGate` → **Payment gate** | `paymentGate` | `payment-gate` | `payment`, `payment-gate`, `follow-up`, `no_show_pressure` |

Deep-link tab state **is already URL-backed** via `?section=…` and `GoRouter.replace` in `_updateUrlForSection`. Keep and strengthen this; do not invent a second query key.

### Current toolbar (gap)

- `primaryAction`: always `AppTabToolbarPrimary` labeled `receptionRegisterPatientAction` (“Register patient”), gated by `AppAccessActionGate(requirement: receptionFrontDeskWriteRequirement)`.
- `secondaryActions`: **empty** (not passed).
- Toolbar does **not** change when switching tabs → violates prompt.md contextual-toolbar rule.

### Current table chrome (gap)

- Search: `AppListTableSearch` with `receptionSearchHint` — keep.
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` — currently resolves to **“Table settings”**, not the required standardized label **“Settings”**.
- Filters: **missing**. No `filterGroups` / `showAdvancedFilterButton` / `advancedFilterButtonLabel`.
- No Refresh / Schedule / navigation actions remain in the table today (good), but those actions were previously removed from table trailing without being restored into the tab toolbar:
  - Historical table trailing (commit era `b6153948`): Refresh (`commonRefreshActionLabel`), Schedule appointment (`receptionScheduleAppointmentAction`), plus settings.
  - Historical `AppWorkspace` secondaries (pre-table layout): Full registry (`receptionOpenRegistryAction`), Full OPD (`receptionOpenOpdAction`).

### Concrete `prompt.md` gaps to close

1. Toolbar not contextual per tab (same Register CTA on every section).
2. Former screen/table actions (Schedule appointment, Refresh, Full registry, Full OPD) are orphaned from chrome — restore as **visible** `AppTabStrip` toolbar buttons (never as a more-menu).
3. Table lacks a **Filters** control; must add Filters (exact label) inside table search chrome only.
4. Settings button label must be exactly **Settings** (update shared l10n key used by Reception).
5. Guarantee ≥1 toolbar button on every tab after contextualization (Register / Schedule / Billing handoff / Refresh cover this).
6. Keep no dedicated title header; do not reintroduce `AppWorkspace(showHeader: true)` or custom title bars.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/shared/components/app_tab_strip.dart` — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default `false`); Reception should continue **without** a title header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — toolbar helpers (reference only)
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, column visibility → Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters button via `filterGroups` / `advancedFilterButtonLabel`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` and table Filters labeled with `*FiltersLabel`
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` — sibling data/filter patterns; Reception reuses OPD state
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — target
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Appointments | `/reception?section=appointments` | Non-terminal OPD appointments | **Schedule appointment** (`receptionScheduleAppointmentAction`, icon `Icons.calendar_month_outlined`) gated by `receptionFrontDeskWriteRequirement` → call restored `_scheduleAppointment()` → `openReceptionScheduleAppointment` | **Register patient** (`AppTabToolbarAction` + same write gate → `_openRegisterPatient`); **Refresh** (`commonRefreshActionLabel` → `opdWorkspaceControllerProvider.notifier.refresh()`); **Full registry** (`receptionOpenRegistryAction` → `context.go(AppRoutes.patients.location())`) |
| Desk queue | `/reception?section=desk-queue` | Non-terminal queue entries | **Register patient** (`AppTabToolbarPrimary` + write gate → `_openRegisterPatient`) | **Refresh**; **Full OPD** (`receptionOpenOpdAction` → `context.go(AppRoutes.opd.location())`) |
| Active visits | `/reception?section=active` | Flows in `_activeVisitStages` | **Register patient** (same primary as queue) | **Refresh**; **Full OPD** |
| Payment gate | `/reception?section=payment-gate` | Flows in `_paymentGateStages` (`WAITING_CONSULTATION_PAYMENT`) | **Billing** (`navigationBillingLabel` / `navigationBillingShortLabel`, icon `Icons.payments_outlined`) → `context.go(AppRoutes.billing.location())` — navigation only; do **not** add cashier capture here | **Refresh**; **Full OPD** |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction` for left-cluster secondaries (matches `AppTabStrip` contract).
- Prefer `AppTabToolbarAction` for Refresh (flat tab-toolbar style). Do **not** reintroduce Refresh / Schedule / navigation as `AppListTableSearch.trailingActions`.
- Row-level `WorkflowActionButton` on Active visits / Payment gate columns stays in the table body (not chrome). Do not move row next-step buttons into the tab toolbar.
- Insurance capture / edit patient remain available via patient detail flows (`openReceptionPatientEditor` / `openReceptionInsuranceCapture`); do not invent a new header more-menu for them.

### Routing

- Keep `/reception` registration in `app_router.dart` unchanged except if tests need it.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by `ReceptionWorkspaceQuery.fromUri`).
- Canonical write values must remain:
  - `appointments` | `desk-queue` | `active` | `payment-gate`
- On tab tap: `setState` + `_updateUrlForSection(section)` (already present).
- On deep link: `_applyDeepLink` already maps section + search + optional `flowId` → `_openFlowActions`. Preserve.
- When switching tabs, clear or retain search consistently with sibling workspaces: clear table filter value; keep search text unless a deep-link search is being applied.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold` + `ResponsivePage` (equivalent to “no title header”; do **not** add `AppWorkspace(showHeader: true)`).
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`.
3. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm between strip and table).
4. Body: single `AppListTable<_ReceptionDeskRow>` whose search chrome exposes **only**:
   - Search field
   - **Filters** (advanced filter button / dialog)
   - **Settings** (column visibility)
5. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

Reuse (do not fork):

- `opdWorkspaceControllerProvider` — `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `patientRegistryControllerProvider` — register-patient dialog path (already in `_openRegisterPatient`)
- `ReceptionDeskSection` / `ReceptionWorkspaceQuery` — `reception_entities.dart`
- Stage sets already on the page: `_paymentGateStages`, `_activeVisitStages`
- Permissions from `reception_access.dart`

Add local UI state only as needed:

- `AppSearchBarFilterValue` (or a small private filter record) for table Filters (status/stage), reset on tab change
- Restore `_scheduleAppointment()` (and optionally `_scheduleForPatient` if still useful) calling `openReceptionScheduleAppointment`

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md cites this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator) so `app_localizations*.dart` update.

2. **Add Reception Filters label** — File: `frontend/lib/l10n/app_en.arb`
   - Add `receptionFiltersLabel`: `"Filters"` (mirror `hrFiltersLabel`).
   - Optionally add `receptionClearFiltersAction`: `"Clear filters"` if not reusing `opdClearFiltersAction` / `hrClearFiltersAction`.
   - Regenerate l10n.

3. **Make toolbar contextual** — File: `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
   - Extract helpers, e.g. `_buildPrimaryAction(AppLocalizations l10n)` and `_buildSecondaryActions(...)` switching on `_section` per the Tab Configuration table above.
   - Wire `primaryAction:` / `secondaryActions:` on `AppTabStrip`.
   - Gate write actions with `AppAccessActionGate(requirement: receptionFrontDeskWriteRequirement, ...)`.
   - Implement Refresh via `ref.read(opdWorkspaceControllerProvider.notifier).refresh()` and surface failures with existing `_showFailureIfNeeded` / `showAppFailureSnackBar`.
   - Restore `_scheduleAppointment()` using `openReceptionScheduleAppointment` from `reception_patient_actions.dart`; refresh OPD on success.
   - Import `go_router` + `AppRoutes` for Full registry / Full OPD / Billing navigation.

4. **Add table Filters; keep only Filters + Settings in table chrome** — same page file
   - Extend `AppListTableSearch` with:
     - `showAdvancedFilterButton: true` **or** non-empty `filterGroups` (either path enables Filters in `AppSearchBar`)
     - `advancedFilterButtonLabel: l10n.receptionFiltersLabel` (**must render as “Filters”**)
     - `advancedFilterTitle: l10n.receptionFiltersLabel`
     - `advancedFilterApplyLabel` / reset labels from existing shared keys (`opdApplyFiltersAction`, `opdClearFiltersAction` or HR equivalents)
     - `enableDateFilter: false` unless you intentionally add a date range that filters `_buildRows` (prefer status/stage-only to minimize scope)
     - `filterGroups`: one group keyed e.g. `status` / `stage` whose choices are derived from distinct statuses/stages present in the current section’s source rows (or a fixed known set). Apply the selected filter inside `_buildRows` or a `_visibleRows` helper **in addition to** the existing section stage/status rules.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now “Settings”).
   - Do **not** add Refresh, Schedule, Register, or navigation buttons as `trailingActions` on the search bar.
   - Do **not** add a “more” / overflow menu for screen actions (`trailingActionsOverflowLabel` must not become the home for relocated header actions).

5. **Preserve domain logic**
   - Do not change `_paymentGateStages` / `_activeVisitStages` / terminal-status filtering unless required for Filters UX.
   - Keep `WorkflowActionButton` columns on Active visits / Payment gate.
   - Keep row tap → `openReceptionPatientEditor`.
   - Keep permission splits in `reception_access.dart` (especially billing cashier vs guidance).

6. **Tests** — add/extend under `frontend/test/features/reception/`
   - Query canonicalization: each `ReceptionDeskSection` maps to the expected `section` query value (unit-test the mapping logic; if helpers are private, either export a small `@visibleForTesting` mapper or test via widget/pump with a fake GoRouter if the suite already has that harness).
   - Prefer a focused widget/chrome test if the project already pumps workspaces with overrides; otherwise extend `reception_access_test.dart` with query alias coverage for `desk-queue`, `active`, `payment-gate`.
   - Ensure existing reception auth tests still pass.

7. **Format / analyze / test**
   - Run the Verification Steps below; fix all issues introduced by this change.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Desk worklist; Filters + Settings only in table chrome |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterValue` | `package:hosspi_hms/shared/components/app_search_bar.dart` | Table Filters dialog |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Register / Schedule write CTAs |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AsyncStateScaffold` | shared components export | Loading / error shell |
| `openReceptionScheduleAppointment` | `features/reception/presentation/widgets/reception_patient_actions.dart` | Appointments primary action |
| `RegisterNewPatientDialog` | patients feature (already imported path via existing `_openRegisterPatient`) | Register patient flow |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Row next-step (unchanged) |
| `AppRoutes` / `GoRouter` | `app/router/app_routes.dart`, `package:go_router/go_router.dart` | Deep links + Full registry / Full OPD / Billing |

**Forbidden:** new custom tab bars, new header widgets, new overflow “more” menus for screen actions, duplicating OPD controllers, putting Refresh/Schedule back into `AppListTableSearch.trailingActions`.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Contextual `primaryAction` / `secondaryActions`; restore schedule + refresh handlers; add Filters wiring; keep Settings |
| `frontend/lib/l10n/app_en.arb` | `commonTableSettingsActionLabel` → `"Settings"`; add `receptionFiltersLabel` (`"Filters"`) |
| Generated l10n dart files | Via gen-l10n after arb edits |
| `frontend/test/features/reception/presentation/reception_access_test.dart` (and/or new chrome test) | Deep-link / section coverage; optional toolbar expectations |

### Create

| File | Change |
|------|--------|
| None required for chrome | Prefer extending the existing page + tests. Only create a small widget extract if the page exceeds maintainability — not required |

### Delete

| File | Change |
|------|--------|
| None | Do not delete `reception_billing_guidance.dart` / patient actions helpers |

## Cleanup: Remove Stale Code

- [ ] No leftover `AppSearchBarAction` Refresh/Schedule in table `trailingActions`
- [ ] No reintroduced `AppWorkspace` title row / `showHeader: true`
- [ ] No `PopupMenuButton` / “more” menu for screen-level actions
- [ ] No duplicate Register CTAs (toolbar only — not also in table chrome)
- [ ] Remove any dead private methods left after relocating actions
- [ ] Ensure unused imports are cleaned (`dart analyze`)

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome refactor only (l10n + layout + local filter state).

## Responsive Design Requirements

Use existing `ResponsivePage` + `AppTabStrip` + `AppListTable` behavior (do not invent a new breakpoint system):

- Desktop (≥1024px / `AppBreakpoint.lg+`): full tab labels, toolbar labels visible per `showsToolbarActionLabels`, table with column Settings + Filters.
- Tablet (600–1023px): horizontal-scrolling `AppTabStrip` chips; toolbar wrap via `AppTabStrip`’s `Wrap`; table may use mobile item builder as already configured.
- Mobile (<600px): same strip + toolbar stack; `mobileItemBuilder: _mobileItemBuilder` remains; no separate mobile title header.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/reception/
flutter test test/shared/
```

If gen-l10n is not automatic in this repo, run the project’s standard localization generation command before analyze/tests.

## Testing Requirements

- [ ] Tab switch updates URL `section` query and toolbar actions
- [ ] Deep link `/reception?section=desk-queue` (and `active`, `payment-gate`, `appointments`) opens the correct tab
- [ ] Per-tab toolbar shows only that tab’s actions (Appointments shows Schedule primary; Payment gate shows Billing primary; etc.)
- [ ] Table chrome has only Filters and Settings (plus search) — no Refresh/Schedule/Register in the search trailing cluster
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate write actions (`receptionFrontDeskWriteRequirement`)
- [ ] Responsive layouts still work (strip scrolls; table mobile builder intact)
- [ ] Register patient / schedule appointment / OPD refresh / navigation to patients|opd|billing still function

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` + `secondaryActions` swap with `_section`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Table-local actions limited to **Filters** and **Settings** with those exact labels
- [ ] Deep-link `section` query preserved and covered by tests
- [ ] Domain logic preserved (OPD data, stage sets, gates, dialogs)
- [ ] Analyze clean; tests pass; stale chrome code removed
`)