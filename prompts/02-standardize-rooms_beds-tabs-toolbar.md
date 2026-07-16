# Standardize Rooms & Beds Screen (Tabs & Toolbar)

## Objective

Refactor the Rooms & Beds workspace (`/rooms-beds`, `RoomsBedsWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Rooms & Beds domain logic** (bed board filtering by section, facility/ward/room/status
filters, search, pagination, bed detail dialog + status/assign/release/transfer actions, permissions,
counts, realtime refresh, deep links). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`
  - Widgets: `RoomsBedsWorkspacePage` → `AsyncStateScaffold` → `_RoomsBedsWorkspaceContent`
  - Bed detail: `_openBedDetailDialog` → `_BedDetailContent` (dialog-only — **do not move** into screen toolbar)
  - Helpers in-file: `_roomsBedsSectionQueryValue`, `_roomsBedsSectionLabel`, `_roomsBedsSectionIcon`, `_canAdminBeds`
- Status / section helpers: `frontend/lib/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart`
  - `roomsBedsSectionMatchesStatus`, `roomsBedsSectionCount`, `roomsBedsSectionFilteredPage`
- Controller: `frontend/lib/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart`
  - Provider: `roomsBedsWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyRouteQuery()`, `applySearch()`, `applyFacility()`, `applyWard()`,
    `applyRoom()`, `applyStatus()`, `changePage()`, `selectBed()`, `updateBedStatus()`,
    `assignBed()`, `releaseBed()`, `requestTransfer()`, `updateTransfer()`
- Domain: `frontend/lib/features/rooms_beds/domain/entities/rooms_beds_entities.dart`
  - Enum: `RoomsBedsSection { all, available, occupied, turnover, outOfService }`
  - Query: `RoomsBedsQuery` / `RoomsBedsQuery.fromUri` (parses `section` / `tab` + filters)
- Facility dialogs (reuse, do not rewrite): `showTenantFacilityRoomFormDialog`,
  `showTenantFacilityBedFormDialog` from
  `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- Routes: `AppRoutes.roomsBeds` (`/rooms-beds`) in `frontend/lib/app/router/app_routes.dart`;
  builder in `frontend/lib/app/router/app_router.dart` passes `RoomsBedsQuery.fromUri(state.uri)`

### Current layout (partially compliant)

```
AsyncStateScaffold(
  appBarTitle: l10n.roomsBedsTitle,  // only used on loading/empty/failure scaffolds
  maxWidth: PageMaxWidth.dataHeavy,
  dataBuilder → _RoomsBedsWorkspaceContent
)
  └── SizedBox → Column
        ├── AppTabStrip(
        │     tabs: RoomsBedsSection.values (5),
        │     primaryAction: Add room (canAdminBeds only) — SAME on every tab,
        │     secondaryActions: Add bed + Manage catalog (admin) + Tenant setup (always)
        │                       — SAME on every tab
        │   )
        ├── SizedBox(height: theme.spacing.sm)
        ├── optional AppFailureStateView
        └── AppListTable<BedBoardItem> (search + Filters + Settings)
```

- **Already uses** `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction`.
- **Already deep-links** via `?section=<value>` (`_updateUrlForSection` + `RoomsBedsQuery.fromUri` +
  `applyRouteQuery`).
- **No page-level titled `AppWorkspace` header** on the success path.
- **No header overflow / “more” menu** for screen actions.
- **Missing `ResponsivePage`** wrapper around success content (Reception / Housekeeping use it).
- **Section filter is client-side** via `roomsBedsSectionFilteredPage(state.beds, _section)` —
  tab change updates local `_section` + URL; do not invent a new API section filter.

### Confirmed tab inventory

| # | Tab label (l10n) | Enum | Query `section=` | Toolbar today (not contextual) |
|---|------------------|------|------------------|--------------------------------|
| 1 | All beds (`roomsBedsSectionAllLabel`) | `RoomsBedsSection.all` | *(omit / empty)* | Primary: Add room (`tenantFacilityAddRoomAction`); Secondary: Add bed, Manage catalog, Tenant setup |
| 2 | Available (`roomsBedsSectionAvailableLabel`) | `RoomsBedsSection.available` | `available` | Same as All beds |
| 3 | Occupied (`roomsBedsSectionOccupiedLabel`) | `RoomsBedsSection.occupied` | `occupied` | Same as All beds |
| 4 | Turnover (`roomsBedsSectionTurnoverLabel`) | `RoomsBedsSection.turnover` | `turnover` | Same as All beds |
| 5 | Out of service (`roomsBedsSectionOutOfServiceLabel`) | `RoomsBedsSection.outOfService` | `out-of-service` | Same as All beds |

Write values from `_roomsBedsSectionQueryValue` (keep exactly):

- `all` → `''` (omit `section` query param)
- `available` → `available`
- `occupied` → `occupied`
- `turnover` → `turnover`
- `outOfService` → `out-of-service`

Aliases already accepted by `_parseRoomsBedsSection` in `rooms_beds_entities.dart` (keep all):
`turnover` / `reserved` / `cleaning` / `maintenance`;
`out-of-service` / `out_of_service` / `blocked` / `oos`;
also accepts `tab` as alias for `section`.

### Concrete `prompt.md` gaps

1. **Toolbar is not contextual.** `primaryAction` / `secondaryActions` do not change with `_section`.
   Every tab shows the same Add room / Add bed / Manage catalog / Tenant setup set.
2. **Redundant secondary navigations.** `roomsBedsManageCatalogAction` (“Manage catalog”) and
   `navigationSetupLabel` (“Tenant setup”) both call `context.go(AppRoutes.tenantFacilitySetup.location())`.
   Deduplicate: keep **Manage catalog** for admins; do **not** also show Tenant setup when Manage catalog
   is visible. For non-admins, keep a single setup/nav affordance or rely on Refresh (see Target Architecture).
3. **Missing Refresh in the tab toolbar.** Controller already exposes `refresh()`; l10n
   `commonRefreshActionLabel` exists. Add as a secondary (or fallback primary) so the screen is never
   actionless when `canAdminBeds` is false and primary would otherwise be null.
4. **When `!canAdminBeds`, `primaryAction` is currently `null`.** Toolbar still shows Tenant setup, so
   the screen is not actionless — but after deduplication you **must** guarantee at least one toolbar
   button (Refresh and/or Open housekeeping / Open operations / Open IPD per tab).
5. **Success content is not wrapped in `ResponsivePage`.** Align with Reception: wrap the Column in
   `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, …)`. Prefer removing reliance on a titled header;
   drop `appBarTitle: l10n.roomsBedsTitle` from `AsyncStateScaffold` (loading already uses
   `loadingTitle` / `loadingBody`) to avoid any residual title-bar association — match Reception
   (no `appBarTitle`).
6. **Table Filters label is already compliant.** `advancedFilterButtonLabel: l10n.roomsBedsFiltersLabel`
   resolves to **"Filters"**. Keep it (or switch to a shared common Filters key if one is introduced
   elsewhere — do not rename to a non-“Filters” string).
7. **Table Settings already wired.** `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`
   (shared key used by Reception; English string is “Table settings”). **Keep this key** for
   cross-workspace consistency — do not invent a parallel Settings control.
8. **No more-menu to extract** at screen/header level. Detail-dialog bed actions stay in the dialog.

### Preserve (do not relocate to tab toolbar)

- **Bed detail dialog actions** in `_BedDetailContent` (Reserve, Mark available/cleaning/maintenance/blocked,
  Assign, Release, Request/Manage transfer, Open IPD admission for a specific bed, Open housekeeping /
  operations from a specific bed’s status) — patient/bed-scoped; stay in the dialog.
- **Row selection → detail dialog** (`onRowSelected` → `_openBedDetailDialog`).
- Permission helpers: `_canAdminBeds` (elevated / tenantAdmin / facilityAdmin / systemAdmin) and
  `AppPermissions.clinicalWrite` for IPD write actions inside the dialog.
- Client-side section filtering via `roomsBedsSectionFilteredPage` / count helpers.
- Realtime refresh subscription in the controller.
- Filter groups (facility, ward, room, status) and search behavior.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — `ResponsivePage` + `AppTabStrip` + `primaryAction` + `SizedBox(height: theme.spacing.sm)` + body table;
  no page title header; no `appBarTitle` on `AsyncStateScaffold`
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  — **contextual** `primaryAction` via `switch (_section)`; `secondaryActions` list
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace(showHeader: false)` semantics;
  prefer `ResponsivePage` like Reception rather than introducing a titled workspace header
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate` (optional; Rooms & Beds
  currently uses `_canAdminBeds` — keep that gate unless you migrate cleanly to an access requirement)

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All beds | `/rooms-beds` (no `section`, or omit) | Full bed board (`RoomsBedsSection.all`) | **Add room** — `AppTabToolbarPrimary` when `_canAdminBeds`; opens `showTenantFacilityRoomFormDialog` then `controller.refresh()`. If `!canAdminBeds`, use **Refresh** as primary. | When admin: **Add bed** (`tenantFacilityAddBedAction` → `showTenantFacilityBedFormDialog`), **Manage catalog** (`roomsBedsManageCatalogAction` → `AppRoutes.tenantFacilitySetup`), **Refresh**. When not admin: **Manage catalog** omitted; do **not** duplicate Tenant setup if Refresh is already primary — optionally keep a single **Tenant setup** (`navigationSetupLabel`) secondary only if product still needs non-admin setup navigation (never show both Manage catalog and Tenant setup together). |
| Available | `/rooms-beds?section=available` | Beds with `BedSetupStatus.available` | **Add bed** when `_canAdminBeds` (capacity expansion is the natural CTA on this tab); else **Refresh** | When admin: **Add room**, **Manage catalog**, **Refresh**. When not admin: ensure Refresh is present (as primary or secondary). |
| Occupied | `/rooms-beds?section=occupied` | Beds with `BedSetupStatus.occupied` | **Open IPD** — `AppTabToolbarPrimary` using `l10n.navigationIpdShortLabel` (or `navigationIpdLabel`); `context.go(AppRoutes.ipd.location())`. Occupancy work continues in IPD; do not invent a board-level assign without a selected bed. | **Refresh** always. When admin: **Manage catalog**. Do **not** promote Add room/Add bed as primary on this tab (they remain available via All/Available if needed — optional: include Add room as a low-priority secondary for admins only). |
| Turnover | `/rooms-beds?section=turnover` | Reserved + cleaning + maintenance | **Open housekeeping** — `AppTabToolbarPrimary` (`roomsBedsOpenHousekeepingAction`, `Icons.cleaning_services_outlined`); `context.go(AppRoutes.housekeeping.location())` | **Refresh** always. When admin: **Manage catalog**. Optionally **Open operations** as secondary (`roomsBedsOpenOperationsAction` → `AppRoutes.operations`) for maintenance overlap. |
| Out of service | `/rooms-beds?section=out-of-service` | Blocked + outOfService | **Open operations** — `AppTabToolbarPrimary` (`roomsBedsOpenOperationsAction`, `Icons.handyman_outlined`); `context.go(AppRoutes.operations.location())` | **Refresh** always. When admin: **Manage catalog**. |

**Rules for the toolbar builders:**

- Implement `_buildPrimaryAction(...)` and `_buildSecondaryActions(...)` as `switch (_section)` (same pattern as Housekeeping’s `_primaryActionButton`).
- Rebuild on tab change (`setState` in `_handleTabChanged` already updates `_section`).
- Gate catalog mutations with existing `_canAdminBeds` (enabled flags / omit widgets when false).
- Disable mutation primaries when `state.isSaving` (already done for Add room).
- **Never** leave the screen with both `primaryAction == null` and empty `secondaryActions`.
- **Never** show Manage catalog and Tenant setup at the same time (same destination).

### Routing

- Keep `/rooms-beds` route and `RoomsBedsQuery.fromUri` — **no router structural changes required**.
- Keep canonical write values from `_roomsBedsSectionQueryValue`.
- Keep `GoRouter.replace` on tab change via `_updateUrlForSection`.
- Keep deep-link application via `RoomsBedsWorkspacePage._scheduleRouteQuery` → `applyRouteQuery`.
- Keep additional query params (`search`, `facilityId`, `wardId`, `roomId`, `bedId`, `status`) — do not drop them when writing `section` on tab change if they are currently preserved; today’s `_updateUrlForSection` only writes `section` — **preserve that existing behavior** (do not expand URL sync scope in this chrome pass unless already broken).

### Page Layout

Precise widget tree for `_RoomsBedsWorkspaceContent.build`:

1. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: …)` — **do not** introduce a titled `AppWorkspace` header. If you wrap with `AppWorkspace`, it **must** be `showHeader: false` with no title/actions on the workspace chrome.
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: _buildPrimaryAction(...), secondaryActions: _buildSecondaryActions(...))`
3. `SizedBox(height: theme.spacing.sm)` (match Reception)
4. Optional `AppFailureStateView` (keep existing)
5. Body: `AppListTable<BedBoardItem>` with **only** Filters + Settings in the table chrome (search bar stays; Filters via `showAdvancedFilterButton`; Settings via `columnVisibilityController` + `columnVisibilityLabel`)
6. No FAB / floating header actions / overflow more-menu for screen actions

`RoomsBedsWorkspacePage.build` `AsyncStateScaffold`:

- Remove `appBarTitle: l10n.roomsBedsTitle` (align with Reception).
- Keep `loadingTitle` / `loadingBody`, `maxWidth: PageMaxWidth.dataHeavy`, `onRetry` → `refresh()`.
- Optionally set `centerVertically: false` and `keepPreviousDataDuringRefresh: true` like Reception for smoother refresh UX — allowed but not required if it risks wider behavior change; prefer minimal chrome-only edits.

### Data & State Management

- Reuse `roomsBedsWorkspaceControllerProvider` / `RoomsBedsWorkspaceController` — **no new providers**.
- Keep local `_section` + URL update pattern; keep client-side `roomsBedsSectionFilteredPage`.
- Do **not** add a server-side section filter API or migrations.
- Dialog forms (`_AdmissionActionForm`, `_TransferForm`, `_TransferUpdateForm`) stay as-is.

## Implementation Steps

1. **Align page shell with Reception** — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`
   - Remove `appBarTitle` from `AsyncStateScaffold`.
   - Wrap `_RoomsBedsWorkspaceContent` success Column in `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`.

2. **Extract contextual toolbar builders** — same file, inside `_RoomsBedsWorkspaceContentState`
   - Add `_buildPrimaryAction(AppLocalizations l10n, …)` switching on `_section` per Target Architecture.
   - Add `_buildSecondaryActions(…)` returning `List<Widget>` of `AppTabToolbarAction`s switching on `_section`.
   - Wire into `AppTabStrip(primaryAction:, secondaryActions:)`.
   - Preserve existing dialog openers for Add room / Add bed and `controller.refresh()` after save.

3. **Deduplicate catalog navigation**
   - Prefer `l10n.roomsBedsManageCatalogAction` + `Icons.apartment_outlined` for admin catalog access.
   - Remove the always-on duplicate `l10n.navigationSetupLabel` action when Manage catalog is shown.
   - Ensure non-admin tabs still have ≥1 toolbar button (Refresh and/or Open IPD / Housekeeping / Operations).

4. **Keep table chrome compliant**
   - Filters: keep `advancedFilterButtonLabel: l10n.roomsBedsFiltersLabel` (“Filters”).
   - Settings: keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
   - Do not add Export / Refresh / Add / overflow into the table header.

5. **Leave domain dialogs untouched**
   - Do not move `_BedDetailContent` action Wrap into the tab toolbar.

6. **Tests**
   - Extend or add widget/unit coverage if practical for section query parsing (already in
     `frontend/test/features/rooms_beds/domain/rooms_beds_entities_test.dart`) — keep passing.
   - If you add a small pure helper for toolbar action ids per section, unit-test it; otherwise verify
     manually via verification steps below.
   - Run controller + helper tests under `frontend/test/features/rooms_beds/`.

7. **Format & analyze**
   - Run the Verification Steps commands from `frontend/` (or repo root as appropriate for this project).

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/components.dart` (export of `app_tab_strip.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/components.dart` | Bed board table; Filters + Settings only |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/components.dart` | Loading / error / data shell — **no appBarTitle** |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Success content width / padding like Reception |
| `AppFailureStateView` / `AppWorkspaceStatePanel` | shared components / layout | Failure banner + empty state |
| `showTenantFacilityRoomFormDialog` / `showTenantFacilityBedFormDialog` | `tenant_facility_setup_page.dart` | Add room / Add bed |
| `_canAdminBeds` / `appAccessPolicyProvider` | existing page + `permission_providers.dart` | Gate catalog mutations |
| `AppRoutes.roomsBeds` / `tenantFacilitySetup` / `housekeeping` / `operations` / `ipd` | `app_routes.dart` | Navigation targets |

**Forbidden:** new custom tab bars, new header widgets, new “more” menus for screen actions, duplicate
filter/settings chrome, new titled `AppWorkspace` headers.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart` | Contextual toolbar; ResponsivePage; remove `appBarTitle`; dedupe setup actions |
| `frontend/test/features/rooms_beds/**` (optional) | Add coverage for toolbar section mapping if you extract a testable helper |

### Create

| File | Change |
|------|--------|
| *(none required)* | Prefer editing the existing page; only create a tiny helper file if the page becomes unwieldy |

### Delete

| File / symbol | Change |
|---------------|--------|
| Duplicate Tenant setup toolbar action when Manage catalog is shown | Remove dead duplicate navigation |
| `appBarTitle: l10n.roomsBedsTitle` on this page’s `AsyncStateScaffold` | Remove |

Do **not** delete bed detail dialogs, status helpers, controller, DTOs, or repository code.

## Cleanup: Remove Stale Code

- [ ] Remove duplicate Tenant setup toolbar button when Manage catalog is present
- [ ] Remove non-contextual hard-coded `primaryAction` / `secondaryActions` lists that ignore `_section`
- [ ] Ensure no leftover custom header/title row above `AppTabStrip`
- [ ] Ensure no FAB or overflow `PopupMenuButton` for screen-level actions
- [ ] Leave `_BedDetailContent` actions intact (not “stale” — they are domain UI)

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter chrome/layout refactor only.

## Responsive Design Requirements

- **Desktop (≥1024px):** `AppTabStrip` full tab row + toolbar under tabs; `AppListTable` multi-column;
  `ResponsivePage` max width `PageMaxWidth.dataHeavy` (1440).
- **Tablet (600–1023px):** Horizontal-scrolling tabs (built into `AppTabStrip`); toolbar Wrap may
  reflow via existing `AppTabStrip` padding (`theme.spacing.sm` vertical); table may switch toward
  card/list via existing `mobileItemBuilder` breakpoints inside `AppListTable`.
- **Mobile (<600px):** Same tab strip + toolbar stack; `_BedMobileItem` list presentation; no
  separate mobile-only header title.

Follow existing `app_breakpoints.dart` / `ResponsivePage` behavior — do not invent new breakpoint
logic.

## Verification Steps

Run from `frontend/` (adjust if the project’s usual CWD differs):

```bash
dart format lib/features/rooms_beds test/features/rooms_beds
dart analyze --fatal-infos lib/features/rooms_beds
flutter test test/features/rooms_beds/
flutter test test/shared/
```

If `test/shared/` is large/slow, at minimum run `test/features/rooms_beds/` plus any shared component
tests you touched.

## Testing Requirements

- [ ] Tab switch updates URL `?section=` (except All beds omits `section`) and toolbar actions
- [ ] Deep link `/rooms-beds?section=available` (and other tabs) opens the correct tab
- [ ] Per-tab toolbar shows only that tab’s actions (All ≠ Occupied ≠ Turnover ≠ Out of service)
- [ ] Table chrome has only Filters and Settings (plus search field)
- [ ] No screen title/header chrome remains on the success path
- [ ] At least one toolbar button exists on every tab, including when `!canAdminBeds`
- [ ] Admin-only Add room / Add bed / Manage catalog remain gated by `_canAdminBeds`
- [ ] Bed detail dialog actions still work (status, assign, release, transfer)
- [ ] Responsive layouts still work (desktop table / mobile list item)
- [ ] Manage catalog and Tenant setup are not both visible at once

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions` swap with `_section`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (filters, search, pagination, dialogs, permissions, realtime, deep links)
- [ ] Analyze clean; tests pass; stale duplicate toolbar actions removed
- [ ] Compliance Checklist at the top of this document is fully checked
