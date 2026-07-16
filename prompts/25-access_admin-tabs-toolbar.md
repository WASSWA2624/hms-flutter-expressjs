# Standardize Access Admin Screen (Tabs & Toolbar)

## Objective

Refactor the Access Admin workspace (`/admin/access`, `AccessAdminWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

Access Admin already uses `ResponsivePage` + `AppTabStrip` with URL-backed `?panel=` tabs and a
partial contextual toolbar. This audit found remaining compliance gaps — close those gaps.
Do **not** treat the current page as fully compliant.

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
**Preserve all Access Admin domain logic** (users, roles, permissions, module entitlements, demo
accounts, pending registrations, write gates via `state.data.permissions.canWrite`, tenant-context
empty state, detail dialogs, realtime refresh, create/edit/delete flows). This refactor is
layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
  - Public widget: `AccessAdminWorkspacePage` (`initialQuery: AccessAdminWorkspaceQuery?`)
  - Content: `_AccessAdminWorkspaceContent` / `_AccessAdminWorkspaceContentState`
  - Tab bar: `_AccessAdminPanelTabBar` → already wraps `AppTabStrip`
  - Table body: `_WorklistPanel` → `AppListTable<AccessAdminItem>`
  - Detail UI: `_DetailContent` / `_DetailRow` (dialog-only; keep out of screen chrome)
- Controller: `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart`
  - Provider: `accessAdminWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyRouteQuery`, `applyPanel`, `applyResource`, `applySearch`,
    `applyStatusFilter`, `applyContext`, `changePage`, `createUser`, `deleteRole`,
    `loadUserDetail`, `setUserStatus`, `activateRegistration`, `rejectRegistration`,
    `resetDemoPassword`, `_defaultResourceForPanel`
- Domain: `frontend/lib/features/access_admin/domain/entities/access_admin_entities.dart`
  - Tabs: `AccessAdminPanel` — `overview`, `directory`, `roles`, `permissions`, `entitlements`,
    `registrations`, `demo` (each has `serverValue` used as tab id + URL `panel`)
  - Resources: `AccessAdminResource` — `users`, `roles`, `permissions`, `demoUsers`,
    `moduleEntitlements`, `registrationFollowUps`, …
  - Query: `AccessAdminWorkspaceQuery.fromUri` / `location()` — already URL-backs `panel`,
    optional `resource`, `search`, `tenantId`, `facilityId`, `id`, `status`, `roleScope`, …
- Dialogs (domain — preserve; do not move dialog actions into the page table chrome):
  - `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
    — `openAccessAdminCreateUserDialog`, `openAccessAdminCreateRoleDialog`,
    `openAccessAdminEditRoleDialog`, `showAccessAdminWorkspaceDialog`
  - `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
    — richer embedded manage-users/roles tables (reference for **role scope Filters** pattern)
  - `user_mutation_dialog.dart`, `role_mutation_dialog.dart`
- Repository: `frontend/lib/features/access_admin/data/repositories/access_admin_repository_impl.dart`
- Realtime: `frontend/lib/features/access_admin/presentation/controllers/access_admin_realtime_delta_applier.dart`
- Route: `AppRoutes.accessAdmin` path `/admin/access` in
  `frontend/lib/app/router/app_routes.dart`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `AccessAdminWorkspaceQuery.fromUri(state.uri)` into
  `AccessAdminWorkspacePage(initialQuery: …)`
- Tests today (no page chrome tests yet):
  - `frontend/test/features/access_admin/presentation/access_admin_workspace_controller_test.dart`
  - `frontend/test/features/access_admin/presentation/controllers/access_admin_realtime_delta_applier_test.dart`
  - `frontend/test/features/access_admin/presentation/widgets/role_mutation_dialog_test.dart`
  - DTO tests under `frontend/test/features/access_admin/data/`

### Current widget tree (chrome) — partially compliant

```
AsyncStateScaffold<AccessAdminWorkspaceState>(
  appBarTitle: l10n.accessAdminTitle,  // "Users and access" — only on loading/empty/failure
)
  └── ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
        └── Column
              ├── _AccessAdminPanelTabBar → AppTabStrip(
              │     tabs: AccessAdminPanel.values (registrations gated by isElevated),
              │     selectedId: state.query.panel.serverValue,
              │     onTabTapped → controller.applyPanel + context.go(query.location()),
              │     primaryAction: Create user | Create role | null  (by resource + canWrite),
              │     secondaryActions: [Refresh]  (same on every tab)
              │   )
              ├── SizedBox(height: theme.spacing.sm)
              ├── optional AppFailureStateView
              ├── optional AppStateView (tenant_context_required)
              └── _WorklistPanel → AppListTable<AccessAdminItem>
                    search + status filterGroups ONLY when resource == users
                    NO columnVisibilityLabel / controller
                    NO advancedFilterButtonLabel ("Advanced filters" default when Filters show)
```

**Already good (keep):**

- Success path has **no** `AppWorkspace(showHeader: true)` / dedicated title bar
- `AppTabStrip` at top; toolbar via `primaryAction` / `secondaryActions` (under tabs)
- Deep-link tabs via `?panel=<serverValue>` + `AccessAdminWorkspaceQuery.location()` +
  `context.go` on tab tap + `applyRouteQuery` from `initialQuery`
- No FAB / `PopupMenuButton` / overflow “more” menu for **screen** actions
- Refresh always present → screen is never actionless when data loads
- Row/detail mutations (activate/deactivate user, reset demo password, activate/reject
  registration, edit/delete role) live in **detail dialogs** — keep them there

### Confirmed tab inventory (validated against code + l10n EN)

| # | Tab label (l10n → EN) | Enum `AccessAdminPanel` | Query `panel=` | Default resource (`_defaultResourceForPanel`) | Current toolbar primary | Current toolbar secondary |
|---|----------------------|-------------------------|----------------|-----------------------------------------------|-------------------------|---------------------------|
| 1 | `accessAdminPanelOverview` → **Overview** | `overview` | `overview` | `AccessAdminResource.users` | Create user (`accessAdminCreateUserAction`) if `canWrite` | Refresh (`commonRefreshActionLabel`) |
| 2 | `accessAdminPanelDirectory` → **User directory** | `directory` | `directory` | `users` | Create user if `canWrite` | Refresh |
| 3 | `accessAdminPanelRoles` → **Roles** | `roles` | `roles` | `roles` | Create role (`accessAdminCreateRoleAction`) if `canWrite` | Refresh |
| 4 | `accessAdminPanelPermissions` → **Permissions** | `permissions` | `permissions` | `permissions` | **null** | Refresh |
| 5 | `accessAdminPanelEntitlements` → **Module entitlements** | `entitlements` | `entitlements` | `moduleEntitlements` | **null** | Refresh |
| 6 | `accessAdminPanelDemo` → **Demo accounts** | `demo` | `demo` | `demoUsers` | Create user if `canWrite` | Refresh |
| 7 | `accessAdminPanelRegistrations` → **Pending registrations** | `registrations` | `registrations` | `registrationFollowUps` | **null** (Activate/Reject are dialog-only) | Refresh |

Notes:

- **Pending registrations** tab is shown only when `appAccessPolicyProvider.isElevated` (super-admin).
  Preserve that gate in `_AccessAdminPanelTabBar`.
- Default landing panel in `AccessAdminWorkspaceQuery` is `directory` (not overview).
- `AccessAdminOverview` / `panelSummaries` exist on workspace data but are **not rendered** in the
  page UI today. Optional chrome enhancement: wire `AppTabItem.count` from overview metrics;
  do **not** invent a separate title/header for overview stats.

### Current table chrome (gaps)

`_WorklistPanel` → `AppListTable<AccessAdminItem>`:

- Search: keep (`accessAdminSearchLabel` / `accessAdminSearchHint`)
- Filters: status `filterGroups` **only** when `resource == users`. Button label falls back to
  hardcoded **"Advanced filters"** because `advancedFilterButtonLabel` is unset — must be
  **Filters** via `accessAdminFiltersAction`
- Roles: query supports `roleScope`, and
  `access_admin_management_dialogs.dart` already defines scope Filters
  (`accessAdminRoleScopeFilterAll` / `…Tenant` / `…Facility`) — **not wired** on the workspace page
- Permissions / entitlements / demo / registrations / overview: no Filters button (or only when
  status groups apply for users-backed overview)
- Settings: `AppListTable` auto-adds a settings trailing action when columns > 1, but label
  defaults to **"Table column settings"** / shared key currently **"Table settings"** — must be
  exact **"Settings"** via `commonTableSettingsActionLabel`
- No `columnVisibilityController` / storage keys (Reception/HR pattern missing)

### Concrete `prompt.md` gaps to close

1. Remove `appBarTitle: context.l10n.accessAdminTitle` from `AsyncStateScaffold` (match Reception:
   loading/failure scaffolds must not introduce a dedicated screen title chrome).
2. Normalize **Settings** label: set `commonTableSettingsActionLabel` EN to `"Settings"` and pass
   `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` on the table.
3. Normalize **Filters** label: pass `advancedFilterButtonLabel` /
   `advancedFilterTitle` using `accessAdminFiltersAction` (`"Filters"`) — never leave the
   `"Advanced filters"` default on this screen.
4. Ensure **every** worklist tab exposes table Filters (status for user-like resources; role
   scope for roles; sensible status/empty-capable groups for other resources — copy patterns
   from `access_admin_management_dialogs.dart` where they already exist).
5. Keep toolbar contextual: Create user / Create role / Refresh-as-primary where no write CTA;
   never reintroduce a header more-menu.
6. Guarantee ≥1 toolbar button on every visible tab (Refresh already covers this; when primary
   would be null, promote Refresh to `AppTabToolbarPrimary` so the active tab still has a clear
   primary affordance).
7. Do not put Activate/Reject registration, Edit/Delete role, Deactivate user, or Reset demo
   password into the tab toolbar — those remain detail-dialog actions.
8. Do not reintroduce `AppWorkspace(showHeader: true)` or custom title bars on the success path.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` —
  canonical chrome: `AsyncStateScaffold` **without** `appBarTitle`, `ResponsivePage` +
  `AppTabStrip` + `SizedBox(sm)` + `AppListTable` with Settings label
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` —
  **copy this pattern** for per-tab `primaryAction` / `secondaryActions` helpers and table
  Filters labeled with an explicit `*Filters*` l10n key
- `frontend/lib/shared/components/app_tab_strip.dart` —
  `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default
  `false`); Access Admin success path should continue **without** a title header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`,
  column visibility → Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `filterGroups` /
  `showAdvancedFilterButton` / `advancedFilterButtonLabel`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
  — role-scope + tenant/facility filter group patterns to port into `_WorklistPanel`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate` (optional; page
  currently gates with `state.data.permissions.canWrite` — preserve that server-provided gate)

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Overview | `/admin/access?panel=overview` | Users worklist (default resource `users`); optional tab count from `state.data.overview.activeUsers` | **Create user** (`accessAdminCreateUserAction`, icon `Icons.person_add_alt_1_outlined`) when `canWrite` and tenant context OK → existing `_showCreateUserDialog` / prefer `openAccessAdminCreateUserDialog` if consolidating; else **Refresh** as primary | **Refresh** as `AppTabToolbarAction` when Create is primary; omit duplicate Refresh if Refresh is primary |
| User directory | `/admin/access?panel=directory` | Staff user directory (`users`) | **Create user** (same as Overview) when `canWrite` | **Refresh** |
| Roles | `/admin/access?panel=roles` | Role catalog (`roles`) | **Create role** (`accessAdminCreateRoleAction`, icon `Icons.badge_outlined`) when `canWrite` → existing `_showCreateRoleDialog` / `openAccessAdminCreateRoleDialog` | **Refresh** |
| Permissions | `/admin/access?panel=permissions` | Permission catalog (`permissions`) — no page-level create API today | **Refresh** as `AppTabToolbarPrimary` | (none required; optional empty) |
| Module entitlements | `/admin/access?panel=entitlements` | Module entitlements (`module-entitlements`) | **Refresh** as primary | (none) |
| Demo accounts | `/admin/access?panel=demo` | Demo users (`demo-users`) | **Create user** when `canWrite` | **Refresh** |
| Pending registrations | `/admin/access?panel=registrations` | Registration follow-ups (elevated only) | **Refresh** as primary | (none) |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction`
  for left-cluster secondaries (matches `AppTabStrip` contract).
- Gate Create* with existing `canWrite` and the same tenant-context rule already in
  `_primaryAction` (`isTenantContextRequired` blocks writes except on `registrations`).
- Prefer extracting `_buildPrimaryAction` / `_buildSecondaryActions` switching on
  `state.query.panel` (or resource) — mirror HR’s `_buildPrimaryActionButton` /
  `_buildSecondaryActionWidgets`.
- When `!canWrite`, still show **Refresh** as primary on every tab (never leave the toolbar empty).

### Routing

Deep-link tab state is **already URL-backed**. Keep and strengthen; do not invent a second key.

- Path: `/admin/access` (`AppRoutes.accessAdmin`)
- Canonical query key: **`panel`** with values:
  `overview` | `directory` | `roles` | `permissions` | `entitlements` | `demo` | `registrations`
- Optional companion: `resource` (written by `AccessAdminWorkspaceQuery.location()` when not
  default `users`)
- On tab tap (already in `_AccessAdminPanelTabBar._onTabTapped`):
  1. `controller.applyPanel(panel)`
  2. `context.go(state.query.copyWith(panel: panel /* resource resolved by applyPanel */).location())`
  - Ensure the URL’s `resource` stays consistent with `_defaultResourceForPanel` after the
    controller updates (re-read state or build location from the panel’s default resource).
- On deep link: keep `AccessAdminWorkspacePage._scheduleRouteQuery` →
  `applyRouteQuery(AccessAdminWorkspaceQuery.fromUri)`.
- Also preserve optional deep-link params already parsed: `search`, `tenantId`, `facilityId`,
  `id`/`recordId`, `status`, `roleScope`.

No router registration changes required unless tests need them.

### Page Layout

Precise widget tree:

1. `AsyncStateScaffold<AccessAdminWorkspaceState>` — **omit** `appBarTitle`; keep
   `loadingTitle` / `loadingBody` / `maxWidth: PageMaxWidth.dataHeavy` /
   `centerVertically: false` / `onRetry: controller.refresh`
2. Success: `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` (equivalent to “no title
   header”; do **not** wrap in `AppWorkspace(showHeader: true)`)
3. `Column` → `AppTabStrip(tabs:, selectedId:, onTabTapped:, primaryAction:, secondaryActions:)`
4. `SizedBox(height: theme.spacing.sm)` (keep Reception vertical rhythm)
5. Optional failure / tenant-context banners (existing)
6. Body: `_WorklistPanel` → `AppListTable<AccessAdminItem>` whose search chrome exposes **only**:
   - Search field
   - **Filters** (exact label)
   - **Settings** (exact label / column visibility)
7. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

Reuse (do not fork):

- `accessAdminWorkspaceControllerProvider` —
  `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart`
- `AccessAdminPanel` / `AccessAdminResource` / `AccessAdminWorkspaceQuery` —
  `access_admin_entities.dart`
- `appAccessPolicyProvider` for registrations tab visibility
- Dialog entry points in `access_admin_dialogs.dart`

Add / adjust only as needed for Filters:

- Add `applyRoleScopeFilter(String? roleScope)` (or extend query updates) on
  `AccessAdminWorkspaceController`, mirroring `applyStatusFilter`, writing
  `query.roleScope` and reloading — page Filters for Roles must call it
- Local `AppListTableColumnVisibilityController<AccessAdminItem>` with storage keys like
  `access_admin_${panel.serverValue}` / `access_admin_cw_${panel.serverValue}`

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md / other screens cite this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator).

2. **Remove scaffold title chrome** — File:
   `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
   - Delete `appBarTitle: context.l10n.accessAdminTitle` from `AsyncStateScaffold`.
   - Do not add any replacement title widget on the success path.

3. **Make toolbar helpers contextual** — same page file
   - Replace inline `_primaryAction` + always-Refresh secondaries with panel-aware builders per
     the Tab Configuration table.
   - When Create* is unavailable (no write / wrong panel / tenant context), set
     `primaryAction` to Refresh (`AppTabToolbarPrimary` + `Icons.refresh` +
     `commonRefreshActionLabel` → `controller.refresh`) and leave `secondaryActions` empty.
   - When Create* is available, primary = Create*, secondary = `[Refresh]` as
     `AppTabToolbarAction`.
   - Keep create handlers (`_showCreateUserDialog`, `_showCreateRoleDialog`) or consolidate to
     `openAccessAdminCreateUserDialog` / `openAccessAdminCreateRoleDialog` without changing
     mutation semantics.

4. **Wire table Settings + Filters on every worklist tab** — `_WorklistPanel` in same page file
   - Add `columnVisibilityController` +
     `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` +
     `columnVisibilityStorageKey` / `columnWidthStorageKey` scoped by panel.
   - On `AppListTableSearch`:
     - `advancedFilterButtonLabel: l10n.accessAdminFiltersAction` (**must render “Filters”**)
     - `advancedFilterTitle: l10n.accessAdminFiltersAction` (or `accessAdminFiltersTitle` only
       if the dialog title must stay “Role filters” for roles — prefer **Filters** for the
       button label in all cases)
     - Apply/reset labels: reuse existing shared keys (`opdApplyFiltersAction` /
       `hrClearFiltersAction` or Access Admin equivalents if present)
     - `enableDateFilter: false`
   - Filter groups by resource:
     - `users` / `demoUsers` / overview users: keep status group
       (`accessAdminStatusLabel` / `accessAdminAllStatusesLabel`) → `applyStatusFilter`
     - `roles`: port role-scope group from management dialogs
       (`accessAdminColumnScope` / `accessAdminRoleScopeFilterAll` /
       `accessAdminRoleScopeFilterTenant` / `accessAdminRoleScopeFilterFacility`) → new
       controller `applyRoleScopeFilter`
     - `permissions` / `moduleEntitlements` / `registrationFollowUps`: if no server filters
       exist, still show Filters with `showAdvancedFilterButton: true` and an empty or
       status-like group that is a no-op **or** a single documented filter already supported by
       `AccessAdminWorkspaceQuery` (prefer real query fields only — do not fake filters).
       If truly no filter fields apply, use `showAdvancedFilterButton: true` with a clear empty
       state inside the filter dialog **only if** shared search bar supports it; otherwise copy
       HR’s approach of at least one real filter group. Prefer wiring `status` when lookups
       provide statuses for that resource.
   - Ensure **no** Refresh / Create / more-menu actions remain in
     `AppListTableSearch.trailingActions`.

5. **Controller: role scope filter** — File:
   `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart`
   - Add `applyRoleScopeFilter(String? roleScope)` mirroring `applyStatusFilter`.
   - Extend controller unit tests in
     `frontend/test/features/access_admin/presentation/access_admin_workspace_controller_test.dart`.

6. **Optional tab counts** — `_AccessAdminPanelTabBar`
   - If straightforward, set `AppTabItem.count` from `state.data.overview` (e.g. active users,
     total roles, total permissions, demo users) and/or page totals — do not block compliance
     if metrics mapping is ambiguous; chrome compliance does not require counts.

7. **Cleanup dead params** — remove unused `canWrite` fields on `_AccessAdminPanelTabBar` /
   `_WorklistPanel` if they become unused after the refactor (or use them only for gating).

8. **Do not change** detail-dialog action rows in `_DetailContent._actions` (activate/deactivate,
   registration activate/reject, reset demo password) — those are record actions, not screen
   chrome.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumn` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Settings via column visibility |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterChoice` / `AppSearchBarFilterValue` | `package:hosspi_hms/shared/components/app_search_bar.dart` | Table Filters |
| `AsyncStateScaffold` / `AppStateView` / `AppFailureStateView` | `package:hosspi_hms/shared/components/app_state_view.dart` | Loading/data/empty/failure |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page width shell |
| `AppDialog` / `AppButton` / `AppTextField` / `AppSelectField` | `components.dart` | Existing create/detail dialogs |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Optional; prefer existing `canWrite` from workspace payload unless aligning with HR |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive toolbar label density already handled by shared tab strip / action label scope |

**Forbidden:** new custom tab bars, new header action rows, new “more” menus for screen actions,
duplicate search/filter widgets, or moving Filters/Settings out of the table chrome.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart` | Remove `appBarTitle`; contextual toolbar helpers; table Filters + Settings wiring |
| `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart` | Add `applyRoleScopeFilter` (or equivalent) |
| `frontend/lib/l10n/app_en.arb` | `commonTableSettingsActionLabel` → `"Settings"` |
| Generated `frontend/lib/l10n/app_localizations*.dart` | Via gen-l10n |
| `frontend/test/features/access_admin/presentation/access_admin_workspace_controller_test.dart` | Cover role-scope filter + existing panel switch |
| Optional: new `frontend/test/features/access_admin/presentation/pages/access_admin_workspace_page_test.dart` | Tab URL + toolbar + Filters/Settings labels if the suite pattern supports widget tests |

### Create

| File | Purpose |
|------|---------|
| (optional) page chrome widget test | Verify `panel` query + toolbar swap + Filters/Settings labels |

### Delete

| File / symbol | Reason |
|---------------|--------|
| None required | Prefer deleting only unused private helpers left after toolbar extraction |

## Cleanup: Remove Stale Code

- [ ] No `appBarTitle` / dedicated title widgets on Access Admin success or loading scaffolds
- [ ] No Refresh / Create actions in `AppListTableSearch.trailingActions`
- [ ] No overflow / “more” menu for screen-level actions
- [ ] No duplicate toolbar outside `AppTabStrip`
- [ ] Unused imports / dead `canWrite` constructor params removed after refactor
- [ ] Do **not** delete management dialogs or detail-dialog actions

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome refactor
only. API query params `panel`, `resource`, `status`, and `roleScope` already exist.

## Responsive Design Requirements

Follow existing shared chrome (same as Reception / `AppTabStrip`):

- Desktop (≥1024px / `AppBreakpoint.lg+`): tab strip horizontal scroll if needed; toolbar shows
  icon+label per `showsToolbarActionLabels`; full `AppListTable` columns
- Tablet (600–1023px): same strip + toolbar; denser labels may hide per breakpoint helpers;
  table may scroll horizontally
- Mobile (<600px): keep `mobileItemBuilder` list tiles; tab strip scrolls horizontally; toolbar
  wraps via `AppTabStrip`’s `Wrap`; no separate mobile title header

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/access_admin/
flutter test test/shared/
```

If l10n was regenerated:

```bash
flutter gen-l10n
```

## Testing Requirements

- [ ] Tab switch updates URL `?panel=` and toolbar actions
- [ ] Deep link `/admin/access?panel=roles` (etc.) opens correct tab
- [ ] Per-tab toolbar shows only that tab’s actions (Create user / Create role / Refresh)
- [ ] Table chrome has only Filters and Settings (plus search field)
- [ ] Filters button label is exactly **Filters**; Settings is exactly **Settings**
- [ ] No screen title/header chrome remains (`accessAdminTitle` not shown as page header)
- [ ] At least one toolbar button exists on every tab
- [ ] `canWrite == false` hides Create* but still shows Refresh
- [ ] Registrations tab still hidden for non-elevated users
- [ ] Detail-dialog actions still work (activate/deactivate, role edit/delete, registration
      activate/reject, demo password reset)
- [ ] Permissions / realtime refresh behavior preserved
- [ ] Responsive layouts still work

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved
- [ ] Analyze clean; tests pass; stale code removed
)
