# Standardize Physiotherapy Screen (Tabs & Toolbar)

## Objective

Refactor the Physiotherapy workspace (`/physiotherapy`, `PhysiotherapyWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

Preserve all Physiotherapy domain behavior (queue scopes, worklist filters, detail dialogs,
schedule/record/attendance/follow-up/print flows, permissions, realtime refresh, deep links).
Restructure chrome/layout only unless a small wiring fix is required for compliance (e.g. moving
Refresh under tabs, Settings label).

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`
  - Public widget: `PhysiotherapyWorkspacePage` (`ConsumerStatefulWidget`)
  - Content: `_PhysiotherapyWorkspace` (`ConsumerWidget`)
  - Private dialogs/panels in the same file: `_ActionsPanel`, `_OverviewPanel`, `_RecordsPanel`,
    `_ScheduleSessionDialog`, `_AssessmentDialog`, `_SessionDialog`, `_AttendanceDialog`,
    `_PlanDialog`, `_TherapyWorklistMobileItem`, etc.
- Controller: `frontend/lib/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart`
  - Provider: `physiotherapyWorkspaceControllerProvider`
  - Key APIs: `refresh`, `applySearch`, `applyScope`, `applyWorklistFilters`, `changePage`,
    `selectWorkItem`, `acceptReferral`, `scheduleSession`, `recordAssessment`, `recordSession`,
    `markAttendance`, `updatePlan`, `addProgressNote`, `scheduleFollowUp`, `closeEpisode`
  - Realtime: `RealtimeEventGroups.physiotherapy` + adaptive polling
- Entities: `frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart`
  - `PhysiotherapyWorkspaceQuery` — parses `section`, `search`/`q`, `encounterId`, `sessionId`
  - `PhysiotherapyQueueScope` enum: `referrals`, `today`, `missed`, `activePlans`, `followUpDue`,
    `completed`, `all`
  - `PhysiotherapyWorklistQuery` / `PhysiotherapyWorklistFilters` / `TherapyWorkItem` /
    `PhysiotherapyDetail`
- Repository: `frontend/lib/features/physiotherapy/domain/repositories/physiotherapy_repository.dart`
  - Impl: `frontend/lib/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart`
  - DTOs: `frontend/lib/features/physiotherapy/data/dtos/physiotherapy_dtos.dart`
- Route: `AppRoutes.physiotherapy` path `/physiotherapy` in
  `frontend/lib/app/router/app_routes.dart`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `PhysiotherapyWorkspaceQuery.fromUri(state.uri)` into `PhysiotherapyWorkspacePage(initialQuery: …)`
- Access gates (page-local constants):
  - `_therapyReadRequirement` — any of `clinicalRead` / `patientRead` / `billingRead`
  - `_therapyWriteRequirement` — any of `clinicalWrite` / `patientWrite`
- Tests:
  - `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_page_test.dart`
    (tabs, URL `section`, deep link, search, mobile viewport, primary tooltips)
  - `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_controller_test.dart`
  - `frontend/test/features/physiotherapy/domain/physiotherapy_entities_test.dart`

### Current widget tree (chrome)

1. `AsyncStateScaffold<PhysiotherapyWorkspaceState>` (loading / retry — not a title bar)
2. **`AppWorkspace(title: l10n.physiotherapyTitle, leadingIcon: …, toolbar: appWorkspaceToolbarWithLabels(… onRefresh …))`**
   - `showHeader` defaults to `false`, so the **title text is hidden**, but
     `appWorkspaceToolbarWithLabels` still renders an **`AppWorkspaceToolbar` above the tabs**
     with Refresh **and** default global actions (`showGlobalActions: true` → fault report /
     housekeeping). This violates “toolbar immediately beneath tabs” and introduces stray
     screen-level chrome outside `AppTabStrip`.
3. `Column` → `AppTabStrip(primaryAction: …)` → `SizedBox(height: theme.spacing.sm)` →
   `AppListTable<TherapyWorkItem>`
4. No FAB / PopupMenu / header “more” menu on the page today (good — do not add one)

### Tabs (validated — 6 visible tabs; “All work” is NOT a tab)

The prompt inventory listed “All work” as tab 7. **Audit correction:** `_tabScopes` in
`_PhysiotherapyWorkspace` is exactly these six. `PhysiotherapyQueueScope.all` exists for
**table Filters** (`physiotherapyScopeAll` → “All work”) and server `ALL`, but it is **not**
rendered as an `AppTabItem`. Do **not** add an “All work” tab unless product explicitly requires
it later; keep filter-only access.

| # | Tab label (l10n key → EN) | Enum `PhysiotherapyQueueScope` | Query `section` (write) | Query accept (read) | Count | Count tone |
|---|---------------------------|--------------------------------|-------------------------|---------------------|-------|------------|
| 1 | `physiotherapyReferralsSummaryLabel` → **Referrals** | `referrals` | `referrals` | `referrals` | `state.referralsCount` | warning |
| 2 | `physiotherapyTodaySummaryLabel` → **Today** | `today` | `today` | `today` | `state.todayCount` | info |
| 3 | `physiotherapyActivePlansSummaryLabel` → **Active plans** | `activePlans` | `active-plans` | `active-plans` | `state.activePlansCount` | warning |
| 4 | `physiotherapyFollowUpDueSummaryLabel` → **Follow-up due** | `followUpDue` | `follow-up` | `follow-up` | `state.followUpDueCount` | warning |
| 5 | `physiotherapyMissedSummaryLabel` → **Missed** | `missed` | `missed` | `missed` | `state.missedCount` | danger |
| 6 | `physiotherapyCompletedSummaryLabel` → **Completed** | `completed` | `completed` | `completed` | `state.completedCount` | info |

Deep-link tab state **is already URL-backed** via `?section=…`:

- Write: `_updateUrlForSection` → `AppRoutes.physiotherapy.location(queryParameters: {'section': …, optional 'search'})` + `GoRouter.replace`
- Read: `PhysiotherapyWorkspaceQuery.fromUri` picks `section`; `_sectionFromQueryValue` maps kebab values
- Tab tap: `_onTabChanged` → `setState` + `controller.applyScope` + `_updateUrlForSection`
- Note: `_sectionToQueryValue(PhysiotherapyQueueScope.all)` currently maps to `'referrals'` (filter-only path; tabs never select `all`)

Keep query key **`section`**. Do not invent a second tab query key.

### Current toolbar (under tabs)

`AppTabStrip.primaryAction` is already **contextual** via `_primaryActionForSection`:

| Active scope | Primary label (l10n) | Icon | Gate / enablement | Handler |
|--------------|----------------------|------|-------------------|---------|
| `referrals`, `activePlans` | `physiotherapyScheduleSessionAction` | `Icons.event_available_outlined` | `_therapyWriteRequirement`; needs `selectedDetail?.item.apiPatientId` and `!isSaving` | `_openScheduleSession` |
| `today` | `physiotherapyRecordSessionAction` | `Icons.directions_walk_outlined` | write gate; `!isSaving` | `_openRecordSession` |
| `followUpDue` | `physiotherapyScheduleFollowUpAction` | `Icons.notification_add_outlined` | write gate; `!isSaving` | `_openScheduleFollowUp` → `ClinicalFollowUpActionDialog` |
| `missed` | `physiotherapyMarkAttendanceAction` | `Icons.fact_check_outlined` | write gate; `!isSaving` | `_openMarkAttendance` |
| `completed` | `physiotherapyPrintInstructionsAction` | `Icons.print_outlined` | read path; needs `selectedDetail != null` | `_printInstructions` |
| `all` (not a tab) | Schedule session (fallback in switch) | — | — | unused by visible tabs |

- `secondaryActions`: **not passed** (empty)
- Refresh lives only in the **parent** `AppWorkspace` toolbar (`appWorkspaceToolbarWithLabels`), not under tabs

### Current table chrome

- Search: `AppListTableSearch` with `physiotherapySearchLabel` / `physiotherapySearchHint`
- Filters: already wired (`showAdvancedFilterButton: true`, `advancedFilterButtonLabel: l10n.physiotherapyFiltersLabel` → **"Filters"**) with scope/source/status/attendance groups + therapist text filter + date range — **keep**
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently **"Table settings"** (must become **"Settings"**)
- No other table-header / trailing screen actions (compliant once Settings label is fixed)

### Detail dialog (preserve — not screen chrome)

Row select → `_openTherapyDetailDialog` → `AppDialog` with `_ActionsPanel` (`AppPermissionActionList`):
Accept referral, Schedule session, Record assessment, Record session, Mark attendance, Update plan,
Add progress note, Schedule follow-up, Close episode, Print instructions.

**Do not** move these detail actions into the screen tab toolbar. They stay row/detail-scoped.

### Concrete `prompt.md` gaps to close

1. **Screen chrome not Reception-shaped:** uses `AppWorkspace` + `appWorkspaceToolbarWithLabels` so Refresh/global actions sit **above** `AppTabStrip`. Must match Reception/HR/Emergency: tabs first, contextual toolbar **under** tabs only.
2. **No `secondaryActions` under tabs** — Refresh must move into `AppTabToolbarAction` on every tab (`commonRefreshActionLabel`).
3. **Settings label** is “Table settings”, not standardized **Settings** (`commonTableSettingsActionLabel`).
4. **Global workspace actions** (fault/housekeeping via default `showGlobalActions: true`) must not reappear as Physiotherapy screen chrome after the refactor.
5. **Already good (do not regress):** six-tab `AppTabStrip`; per-tab primary CTAs; URL `?section=`; table Filters already labeled “Filters”; write/print gating; no header more-menu; detail actions in dialog.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — canonical layout: `ResponsivePage` + `AppTabStrip` + `SizedBox(sm)` + `AppListTable`;
  query-backed `section`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — per-tab `primaryAction` + `secondaryActions`; Filters label pattern
- `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`
  — Refresh as tab secondary; no `AppWorkspace` title chrome
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
  — `AppTabToolbarAction` + `commonRefreshActionLabel`
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (default false); prefer **not**
  wrapping Physiotherapy in `AppWorkspace` after refactor
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — do **not** keep
  `appWorkspaceToolbarWithLabels` on this screen after moving Refresh under tabs
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Referrals | `/physiotherapy?section=referrals` | New / pending therapy referrals | **Schedule session** (`physiotherapyScheduleSessionAction`, `Icons.event_available_outlined`) via existing `_primaryActionForSection` / `_openScheduleSession`, gated by `_therapyWriteRequirement` | **Refresh** (`commonRefreshActionLabel`) → `physiotherapyWorkspaceControllerProvider.notifier.refresh()` |
| Today | `/physiotherapy?section=today` | Sessions due today | **Record session** (`physiotherapyRecordSessionAction`) → `_openRecordSession` | **Refresh** |
| Active plans | `/physiotherapy?section=active-plans` | Active care plans | **Schedule session** (same as Referrals) | **Refresh** |
| Follow-up due | `/physiotherapy?section=follow-up` | Follow-ups due | **Schedule follow-up** (`physiotherapyScheduleFollowUpAction`) → `_openScheduleFollowUp` | **Refresh** |
| Missed | `/physiotherapy?section=missed` | Missed / no-show queue | **Mark attendance** (`physiotherapyMarkAttendanceAction`) → `_openMarkAttendance` | **Refresh** |
| Completed | `/physiotherapy?section=completed` | Completed / closed episodes | **Print instructions** (`physiotherapyPrintInstructionsAction`) → `_printInstructions` (selection-aware) | **Refresh** |

**Rules for the matrix**

- Keep existing enablement rules (write gate, `isSaving`, `apiPatientId`, `selectedDetail` for print).
- Use `AppTabToolbarPrimary` for the right-aligned primary CTA and `AppTabToolbarAction` for Refresh.
- Every tab must have ≥1 toolbar button (primary and/or Refresh). Refresh on all tabs satisfies the screen-level “at least one button” rule even when a primary is disabled.
- Do **not** promote detail-dialog actions into the tab toolbar.
- Do **not** add an “All work” tab; leave `PhysiotherapyQueueScope.all` in Filters only.

### Routing

- Keep `/physiotherapy` registration in `app_router.dart` unchanged.
- Keep query key **`section`** with canonical write values:
  `referrals` | `today` | `active-plans` | `follow-up` | `missed` | `completed`
- Preserve `_updateUrlForSection`, `_applyRouteQuery`, and optional `search` query passthrough.
- Preserve deep-link targeting via `encounterId` / `sessionId` / `search` on `PhysiotherapyWorkspaceQuery`.
- Optional hardening (only if cheap): accept aliases such as `active_plans` → `activePlans`,
  `follow_up` / `follow-up-due` → `followUpDue` in `_sectionFromQueryValue` — do not change write values.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold<PhysiotherapyWorkspaceState>` (loading / retry).
2. Replace `AppWorkspace(… toolbar: appWorkspaceToolbarWithLabels …)` with
   **`ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`** (or equivalent shell with **no** title
   header and **no** separate workspace toolbar), matching Reception.
3. `Column` → `AppTabStrip(tabs:, selectedId: section.name, onTabTapped:, primaryAction:, secondaryActions:)`
4. `SizedBox(height: theme.spacing.sm)` between strip and table (keep existing rhythm).
5. Body: `AppListTable<TherapyWorkItem>` whose search chrome exposes **only**:
   - Search field
   - **Filters** (`physiotherapyFiltersLabel` — already “Filters”)
   - **Settings** (`commonTableSettingsActionLabel` — must render as “Settings”)
6. No FAB / floating header actions / overflow more-menu / `AppWorkspaceToolbar` global actions
   for this screen.

### Data & State Management

Reuse (do not fork):

- `physiotherapyWorkspaceControllerProvider` /
  `PhysiotherapyWorkspaceController`
- `PhysiotherapyQueueScope`, `PhysiotherapyWorkspaceQuery`, `PhysiotherapyWorklistQuery`,
  `PhysiotherapyWorklistFilters`, `TherapyWorkItem`, `PhysiotherapyDetail`
- `_therapyReadRequirement` / `_therapyWriteRequirement`
- Existing dialog helpers and print path (`_printInstructions`, `printFormTemplateDocument`)

UI chrome-only adjustments:

- Build `secondaryActions` list per tab (Refresh always).
- Remove `appWorkspaceToolbarWithLabels` / `AppWorkspace` wrapper usage from this page.

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md / shared screens cite this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator) so
     `app_localizations*.dart` update.
   - If another screen already flipped this key to `"Settings"`, skip the arb edit and verify only.

2. **Replace AppWorkspace chrome with ResponsivePage** — File:
   `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`
   - In `_PhysiotherapyWorkspace.build`, return `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: …)`
     wrapping the existing `Column` of `AppTabStrip` + spacer + worklist.
   - Remove `title`, `leadingIcon`, and `toolbar: appWorkspaceToolbarWithLabels(...)`.
   - Remove unused imports for `appWorkspaceToolbarWithLabels` / layout toolbar helpers if nothing
     else in the file needs them (keep `AppWorkspaceDetailPanel`, `AppWorkspaceStatusBadge`, etc.
     used by detail UI).

3. **Add Refresh as `secondaryActions` on every tab** — same page file
   - Pass `secondaryActions: <Widget>[ AppTabToolbarAction(label: l10n.commonRefreshActionLabel, icon: Icons.refresh, isLoading: state.isRefreshing, onPressed: … controller.refresh() …) ]`
     (mirror Access Admin / Emergency).
   - Keep `primaryAction: _primaryActionForSection(...)` as today (already contextual).
   - Ensure Refresh works while a primary CTA is disabled (e.g. Completed with no selection).

4. **Confirm table chrome is Filters + Settings only** — same page file
   - Keep `advancedFilterButtonLabel: l10n.physiotherapyFiltersLabel` (**Filters**).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (**Settings** after step 1).
   - Do not add Refresh / Schedule / Print / etc. into `AppListTableSearch.trailingActions`.

5. **Preserve routing + domain** — same page / entities / controller
   - Do not change `_tabScopes` (six tabs).
   - Do not break `_onTabChanged` / `_updateUrlForSection` / `_applyRouteQuery`.
   - Do not move `_ActionsPanel` items into the tab toolbar.
   - Do not change repository / API / migrations.

6. **Update tests** — File:
   `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_page_test.dart`
   - Assert no `AppWorkspace` title/header chrome is required; prefer asserting `AppTabStrip` is
     the top chrome and Refresh appears under tabs (e.g. find `commonRefreshActionLabel` /
     tooltip / `AppTabToolbarAction`).
   - Keep existing tab-switch / deep-link / primary-tooltip coverage; extend if Refresh assertions
     are missing.
   - Ensure Settings / Filters labels if asserted use the standardized strings.

7. **Format, analyze, test** — run the Verification Steps below.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Filters + Settings only in table chrome |
| `AppSearchBarFilterValue` / filter groups | `package:hosspi_hms/shared/components/app_search_bar.dart` | Existing advanced filters |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write primaries |
| `AsyncStateScaffold` | shared components/layout (existing import) | Loading / error / retry |
| `ClinicalFollowUpActionDialog` / clinical free-text dialogs | `package:hosspi_hms/shared/clinical_actions/clinical_actions.dart` | Follow-up / free-text actions |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive behavior via `ResponsivePage` |

**Forbidden:** new custom tab bars, duplicate header toolbars, new more-menus for screen actions,
reintroducing `appWorkspaceToolbarWithLabels` on this page, forking table/filter widgets.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart` |
| Modify (if still “Table settings”) | `frontend/lib/l10n/app_en.arb` + regenerated `app_localizations*.dart` |
| Modify | `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_page_test.dart` |
| Do not modify (unless unblock) | Reception / shared `AppTabStrip` / `AppWorkspace` / router registration |
| Delete | None expected — only remove dead imports / unused toolbar wiring inside the page file |

## Cleanup: Remove Stale Code

- [ ] Remove `AppWorkspace` wrapper + `appWorkspaceToolbarWithLabels` from Physiotherapy page chrome
- [ ] Ensure no duplicate Refresh (workspace toolbar + tab secondary)
- [ ] Ensure no global fault/housekeeping buttons remain as Physiotherapy screen chrome
- [ ] Do not leave an empty `AppWorkspace(showHeader: true)` or custom title `Text(physiotherapyTitle)` bar
- [ ] Grep the physiotherapy feature for orphaned header/more-menu helpers after the change; delete only if unused
- [ ] Keep detail-dialog `_ActionsPanel` intact

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome/layout refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar row; wide `AppListTable` columns with Settings/Filters.
- Tablet (600–1023px): horizontal scroll on tab chips if needed (built into `AppTabStrip`); toolbar wrap via existing `Wrap` in strip.
- Mobile (<600px): keep `mobileItemBuilder: _TherapyWorklistMobileItem`; tabs remain usable (existing test at `Size(390, 844)`). Do not add a separate mobile title header.

## Verification Steps

```bash
cd frontend
dart format lib/features/physiotherapy test/features/physiotherapy lib/l10n/app_en.arb
dart analyze --fatal-infos lib/features/physiotherapy test/features/physiotherapy
flutter test test/features/physiotherapy/
flutter test test/shared/
```

If l10n was regenerated, also format/analyze the generated localization files the repo expects.

## Testing Requirements

- [ ] Tab switch updates URL `section` and swaps primary toolbar action (existing tests + Refresh present)
- [ ] Deep link `/physiotherapy?section=today` opens Today with Record session primary
- [ ] Per-tab toolbar shows only that tab’s primary + Refresh secondary
- [ ] Table chrome has only Filters and Settings (plus search); no Refresh in table trailing
- [ ] No `AppWorkspace` title header / no workspace toolbar above tabs
- [ ] At least one toolbar button exists on every tab (Refresh guarantees this)
- [ ] Permissions still gate write primaries via `AppAccessActionGate` + `_therapyWriteRequirement`
- [ ] Detail dialog actions still work after row select
- [ ] Responsive / mobile viewport still shows `AppTabStrip`

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` + `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu; no `AppWorkspaceToolbar` above tabs
- [ ] Domain logic preserved (scopes, filters, dialogs, print, realtime, permissions, deep links)
- [ ] Analyze clean; tests pass; stale chrome code removed
- [ ] Settings label is exactly **Settings**; Filters label is exactly **Filters**
