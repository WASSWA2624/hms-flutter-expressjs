# Standardize Patients Screen (Tabs & Toolbar)

## Objective

Refactor the Patients workspace (`/patients`, `PatientRegistryPage`) so its chrome fully complies with `prompt.md`:
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

**Scope boundary:** Restructure Patients **screen chrome/layout only**. Do not rewrite patient
detail dialogs, register/edit forms, report builders, duplicate-merge flows, or domain APIs
unless required to keep chrome wiring compiling. Preserve permissions, realtime refresh,
section filters, pagination, and deep links.

## Current State (from audit)

### Page & route

- **Route:** `/patients` (`AppRoutes.patients` in `frontend/lib/app/router/app_routes.dart`)
- **Router binding:** `frontend/lib/app/router/app_router.dart` builds
  `PatientRegistryPage(initialQuery: PatientListQuery.fromUri(state.uri))`
- **Primary page:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
  - Public entry: `PatientRegistryPage` → access-gated via `AppAccessGate` (`AppPermissions.patientRead`)
  - Content: `_PatientRegistryContent` / `_PatientRegistryContentState`
  - Table body: `_PatientList` → `AppListTable<Patient>`

### Widget tree today (already mostly aligned with Reception)

1. `AppAccessGate` → `AsyncStateScaffold<PatientRegistryState>`
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` (equivalent to no title header;
   **not** using `AppWorkspace` — same pattern as Reception)
3. `Column` → `AppTabStrip` → `SizedBox(height: theme.spacing.sm)` → `_PatientList`
4. **No** `AppWorkspace(showHeader: …)`, **no** FAB, **no** screen-level `PopupMenuButton` /
   more overflow for header actions

### Tabs (validated against code)

Enum: `PatientRegistrySection` in
`frontend/lib/features/patients/domain/entities/patient_entities.dart`

| Tab label (l10n) | Enum | Query `?section=` | Count source |
|------------------|------|-------------------|--------------|
| `patientsTabAll` → **All patients** | `all` | *(omit / empty)* | `state.overview.totalPatients` |
| `patientsTabActive` → **Active** | `active` | `active` | `state.overview.activePatients` |
| `patientsTabAdmitted` → **Admitted** | `admitted` | `admitted` | `state.overview.activeAdmissions` |
| `patientsTabBalanceDue` → **Balance due** | `balanceDue` | `balance-due` | `state.overview.unpaidInvoices` |

- Tab ids in `AppTabStrip` use `section.name` (`all`, `active`, `admitted`, `balanceDue`).
- URL updates via `_updateUrlForSection` → `AppRoutes.patients.location(queryParameters: {if tab.isNotEmpty 'section': tab})`.
- Deep link parse: `PatientListQuery.fromUri` accepts `section` or `tab`; aliases for balance:
  `balance-due`, `balance_due`, `balancedue`.
- Tab change also clears table search and calls
  `patientRegistryControllerProvider.notifier.applyQuery(section.applyToQuery(...))`.

### Toolbar today

- **Only** `primaryAction`: `AppAccessActionGate` (`AppPermissions.patientWrite`) wrapping
  `AppTabToolbarPrimary` labeled `l10n.patientsRegisterPatientAction` (**Register patient**),
  icon `Icons.person_add_alt_1_outlined`, opens `_openRegisterPatientDialog` →
  `RegisterNewPatientDialog`.
- **No** `secondaryActions`.
- Primary does **not** switch by section (same CTA on every tab). Domain-wise Register patient
  is valid on all four tabs, but code must still be structured as **section-aware** so the
  toolbar is explicitly contextual (Reception/Housekeeping pattern).

### Table chrome today (gap vs prompt.md)

In `_PatientList` (`patient_registry_page.dart`):

- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` ✅ (shared key;
  English: “Table settings” — keep this key; do not invent a parallel Settings control).
- Filters: `showAdvancedFilterButton: true` with
  `advancedFilterButtonLabel: l10n.patientsAdvancedFiltersAction` ❌
  English is **“Advanced filters”** — must become the standardized label **“Filters”**.
- Filter dialog: `_PatientAdvancedFiltersDialog` / `_openPatientAdvancedFilters` — keep behavior;
  dialog title may remain `patientsAdvancedFiltersTitle` unless you also rename for consistency.
- Search: `AppListTableSearch` with `patientsSearchLabel` / `patientsSearchHint`.
- Row-level **Next action** column (`_NextActionCell`: Open record / Complete record) is
  **cell content**, not table chrome — **preserve**; do **not** move into the tab toolbar.

### State / domain to preserve

- Controller: `patientRegistryControllerProvider` /
  `PatientRegistryController` in
  `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart`
  (realtime refresh, adaptive polling, list/detail sync).
- Repository: `patientRepositoryProvider` /
  `frontend/lib/features/patients/data/repositories/patient_repository_impl.dart`
- Access helpers: `frontend/lib/features/patients/presentation/patient_registry_access.dart`
- Entities/query: `PatientListQuery`, `PatientRegistryState`, section filters via
  `PatientRegistrySectionFilter.applyToQuery`

### Concrete `prompt.md` gaps to close

1. Table filter button label is **“Advanced filters”**, not **“Filters”**.
2. Toolbar primary is not structured as a per-tab switch (even though the action is the same).
3. Confirm no regression: no dedicated screen title/header, no header more-menu, no stray
   screen-level actions outside `AppTabStrip` toolbar.
4. Tests do not yet assert tab/URL/toolbar chrome compliance — add focused coverage.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — gold layout: `ResponsivePage` + `AppTabStrip` + table; `primaryAction` under tabs;
  `?section=` URL replace; no page title header.
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  — pattern for **section-switched** `primaryAction` / `secondaryActions`.
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` defaults false; Prefer
  Reception’s `ResponsivePage` equivalent for this screen (already in place).
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — only if needed; Patients should
  keep actions on `AppTabStrip`, not a separate workspace header toolbar.
- `frontend/lib/shared/components/app_list_table.dart` — Filters + Settings wiring.
- `frontend/lib/core/responsive/app_breakpoints.dart` — responsive tokens.
- `prompt.md`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All patients | `/patients` (no `section`, or empty) | Full registry list | **Register patient** (`patientsRegisterPatientAction`), write-gated | *(none)* |
| Active | `/patients?section=active` | `isActive: true` filter | **Register patient** (same) | *(none)* |
| Admitted | `/patients?section=admitted` | `hasActiveAdmission: true` | **Register patient** (same) | *(none)* |
| Balance due | `/patients?section=balance-due` | `hasOutstandingBalance: true` | **Register patient** (same) | *(none)* |

**Rules:**

- Implement `_primaryActionForSection(PatientRegistrySection section)` (or equivalent) that
  returns the gated `AppTabToolbarPrimary` for every section. Do **not** invent new primary
  CTAs (no fake Export/Refresh) just to differentiate tabs.
- Do **not** omit the toolbar on any tab — every tab must show Register patient so the screen
  always has ≥1 toolbar button (`prompt.md`).
- Do **not** add a header more-menu. If any overflow menu for screen actions is discovered
  during implementation, extract each item into its own `AppTabToolbarAction` /
  `AppTabToolbarPrimary` instead.
- Do **not** move Filters/Settings into the tab toolbar; they stay in `AppListTable` chrome only.

### Routing

- Keep existing deep-link model: `PatientListQuery.fromUri` + `_updateUrlForSection`.
- Query key: **`section`** (also accept legacy `tab` on read — already implemented).
- Values: `active` | `admitted` | `balance-due` | omit for All patients.
- On tab tap: update `_section`, replace URL, clear search, `applyQuery(section.applyToQuery(...))`
  — already present; preserve.
- Ensure `initialQuery?.section` continues to select the correct tab on first paint and when
  `didUpdateWidget` sees a new query signature (already present via `_scheduleRouteQuery`).

### Page Layout

Precise target tree (chrome):

1. Keep `AppAccessGate` + `AsyncStateScaffold` (loading/forbidden) — not a title bar.
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` — **no** dedicated screen title/header.
   Do **not** wrap in `AppWorkspace(showHeader: true)`. If you introduce `AppWorkspace`, it
   **must** use `showHeader: false` and must not duplicate the tab toolbar.
3. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction:, secondaryActions:)`
4. Optional `SizedBox(height: theme.spacing.sm)` matching Reception.
5. Body: `_PatientList` → `AppListTable<Patient>` with **only** Filters + Settings in table chrome
   (plus search field).
6. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

Reuse unchanged (wire chrome only):

- `patientRegistryControllerProvider` —
  `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart`
- `PatientListQuery` / `PatientRegistrySection` —
  `frontend/lib/features/patients/domain/entities/patient_entities.dart`
- Write gate: `_PatientRegistryContent._writeRequirement` /
  `AppPermissions.patientWrite`
- Read gate: `PatientRegistryPage._readRequirement` / `AppPermissions.patientRead`
- `AppAccessActionGate` — `frontend/lib/core/permissions/access_gate.dart`
  (imported via existing permission imports / shared components as today)

## Implementation Steps

1. **Normalize Filters label (l10n)** — Files:
   `frontend/lib/l10n/app_en.arb` (and regenerate / update generated l10n as this repo expects)
   - Change the English value of `patientsAdvancedFiltersAction` from `"Advanced filters"` to
     `"Filters"` (description: table chrome Filters button on Patients registry).
   - Keep `patientsAdvancedFiltersTitle` as the dialog title unless product copy should match;
     table chrome button is the compliance surface.
   - Optionally align `patientsFiltersLabel` accessibility copy if still referencing
     “Patient filters” for the same control — do not leave the visible table button as
     “Advanced filters”.

2. **Wire Filters label on the table** — File:
   `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
   (`_PatientList`)
   - Ensure `advancedFilterButtonLabel` uses the updated `patientsAdvancedFiltersAction`
     (now **Filters**).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
   - Keep `showAdvancedFilterButton: true`, `hasActiveFilters`, `onAdvancedFilterPressed` →
     `_openPatientAdvancedFilters`.
   - Do not add any other table-chrome action buttons.

3. **Make toolbar section-aware** — File: same page, `_PatientRegistryContentState.build`
   - Replace the inline single `primaryAction` with a helper such as
     `_buildPrimaryAction(AppLocalizations l10n)` that `switch`es on `_section` and returns
     the same write-gated Register patient `AppTabToolbarPrimary` for
     `all | active | admitted | balanceDue`.
   - Pass `primaryAction: _buildPrimaryAction(l10n)` into `AppTabStrip`.
   - Leave `secondaryActions` empty (`const <Widget>[]`) unless an existing screen-level action
     is found outside the toolbar — then relocate it as `AppTabToolbarAction` and document it
     in the switch.
   - Preserve `_openRegisterPatientDialog` behavior and permission gating
     (`enabled: isAllowed`, disabled when denied).

4. **Confirm header / stray actions absent** — File: same page
   - Do not reintroduce titles, `AppWorkspace` headers, FABs, or more-menus for screen actions.
   - Dialogs (`RegisterNewPatientDialog`, detail, reports, duplicates) may keep their own titles;
     those are dialogs, not screen chrome.

5. **Preserve routing & section filtering** — Files:
   `patient_registry_page.dart`, `patient_entities.dart`, `app_router.dart`
   - No change required to query values unless a bug is found.
   - Do not rename enum cases or break `columnVisibilityStorageKey: 'patients_${section.name}'`.

6. **Tests** — File:
   `frontend/test/features/patients/presentation/patient_registry_page_test.dart`
   - Add (or extend) widget tests that:
     - Pump `PatientRegistryPage` with a stubbed `patientRegistryControllerProvider` /
       repository (follow existing harness patterns in this file / `test/helpers/test_harness.dart`).
     - Assert all four tab labels appear: All patients, Active, Admitted, Balance due.
     - Assert Register patient toolbar button is visible.
     - Assert table chrome shows **Filters** (not “Advanced filters”) and Settings affordance
       via `commonTableSettingsActionLabel` text.
     - Assert tapping Active (or Admitted / Balance due) updates selection; if GoRouter is
       available in the harness, assert `section` query updates; otherwise assert controller
       `applyQuery` received the matching section filter.
   - Keep existing RegisterNewPatientDialog / domain tests green.

7. **Format, analyze, test** — run verification commands below from `frontend/`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` (via components) | Worklist; Filters + Settings only in chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AppAccessGate` / `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Read page gate; write-gated Register |
| `AppWorkspaceStatePanel` / status badges | `package:hosspi_hms/shared/layout/app_workspace.dart` | Empty/loading panels only — not as a titled workspace header |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive behavior via `ResponsivePage` |

**Forbidden:** New custom tab bars, custom screen header toolbars, new table filter/settings
widgets, or packing screen actions into overflow/more menus.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/l10n/app_en.arb` | Set `patientsAdvancedFiltersAction` → `"Filters"` |
| Generated l10n outputs (as required by project, e.g. `app_localizations*.dart`) | Reflect arb change |
| `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` | Section-aware `primaryAction`; ensure Filters label wiring; no header chrome regressions |
| `frontend/test/features/patients/presentation/patient_registry_page_test.dart` | Tab / toolbar / Filters label coverage |

### Create

| File | Change |
|------|--------|
| *(none required for chrome)* | — |

### Delete

| File | Change |
|------|--------|
| *(none expected)* | Only delete code if you introduce a dead duplicate toolbar/header widget while refactoring |

## Cleanup: Remove Stale Code

- [ ] No leftover “Advanced filters” string on the table chrome button (English UI).
- [ ] No duplicate action rows above/beside `AppTabStrip`.
- [ ] No unused more-menu / overflow widgets for screen-level Patients actions.
- [ ] No orphaned header title widgets on the registry page.
- [ ] Do not delete dialog/report helpers that are still used from row/detail flows.

## Database Migrations

No database migrations required — schema unchanged. This is a frontend chrome/l10n refactor only.

## Responsive Design Requirements

Follow `ResponsivePage` + `AppBreakpoints` (same as Reception):

- **Desktop (≥1200px / `xl+`):** Full tab labels + counts; toolbar shows Register patient with icon+label; table columns per section including Next action where defined.
- **Tablet (600–1199px / `md`–`lg`):** Horizontal scroll on `AppTabStrip` tabs if needed; toolbar remains under tabs; table may compress columns via existing column visibility.
- **Mobile (<600px / `xs`–`sm`):** Tabs scroll horizontally; toolbar still under tabs (not a FAB); `mobileItemBuilder` (`_PatientMobileRow`) remains the list presentation; Filters + Settings remain available in table chrome.

Do not introduce a mobile-only header title or bottom FAB for Register patient.

## Verification Steps

Run from `frontend/`:

```bash
dart format lib/features/patients lib/l10n test/features/patients
dart analyze --fatal-infos lib/features/patients
flutter test test/features/patients/
flutter test test/shared/
```

If the repo uses `flutter gen-l10n` / a codegen script for arb changes, run that **before** analyze/tests.

## Testing Requirements

- [ ] Tab switch updates URL `?section=` (when router harness allows) and keeps toolbar actions
- [ ] Deep link `/patients?section=active` (etc.) opens correct tab
- [ ] Per-tab toolbar shows Register patient (section-aware builder; no empty toolbar)
- [ ] Table chrome has only Filters and Settings (plus search) — Filters label is exactly **Filters**
- [ ] No screen title/header chrome remains on the registry page
- [ ] At least one toolbar button exists on the screen
- [ ] Permissions still gate Register patient (`patientWrite`)
- [ ] Responsive layouts still work (no FAB regression)
- [ ] Existing patients tests still pass

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (section filters, counts, register dialog, detail, realtime refresh)
- [ ] Analyze clean; tests pass; stale “Advanced filters” table chrome label removed
- [ ] Compliance checklist at top of this prompt is fully checked
