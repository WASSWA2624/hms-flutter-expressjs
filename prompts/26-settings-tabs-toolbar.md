# Standardize Settings Screen (Tabs & Toolbar)

## Objective

Refactor the Settings workspace (`/settings`, `SettingsPage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Settings domain logic** (theme/accessibility persistence, account profile edit +
change-password dialog, permission-gated administration navigations, tenant/facility
configuration save/reset via `tenantFacilitySetupSubmissionProvider`, settings workspace
controller/query/filters/checklist/quick-actions/module open-create, deep links via
`SettingsPageQuery` `tab` + `panel`, profile route redirects). This refactor is
**layout/chrome standardization only**.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/settings/presentation/pages/settings_page.dart`
  - Public widget: `SettingsPage(initialQuery: SettingsPageQuery)`
  - Query model: `SettingsPageQuery` — fields `tab` (default `'preferences'`), optional `panel`
  - `SettingsPageQuery.fromUri` / `location()` / `copyWith`
  - Accordion chrome: `_SettingsAccordion`, `_AccordionEntry`, `_AccordionPanel`,
    `_AccordionPanelContent`
  - Administration list: `_SettingsAction`, `_adminActions`, `_SettingsActionList`,
    `_SettingsActionTile`
  - Access gates (file-local constants): `_tenantFacilitySetupRequirement`,
    `_hrSettingsWorkspaceRequirement`, `_subscriptionsRequirement`,
    `_accessAdminRequirement`, `_settingsWorkspaceRequirement`,
    `_configTenantRequirement`, `_configFacilityRequirement`
- Account: `frontend/lib/features/settings/presentation/widgets/settings_account_section.dart`
  - `SettingsAccountSection` with nested `AppTabStrip` panels:
    - `profile` (`SettingsAccountSection.profilePanel`)
    - `change-password` (`SettingsAccountSection.changePasswordPanel`)
  - Nested toolbar: `_ProfileEditAction` → `AppTabToolbarPrimary` (`profileEditActionTitle`)
  - Change-password body still has stray `AppButton.primary` (`settingsChangePasswordActionTitle`)
  - Profile data: `userProfileControllerProvider` / `EditUserProfileDialog` /
    `ChangePasswordDialog`
- Configuration: `frontend/lib/features/settings/presentation/widgets/settings_configuration_section.dart`
  - `SettingsConfigurationSection` → `_ConfigurationContent` → `_TenantConfigPanel` /
    `_FacilityConfigPanel`
  - Stray form actions inside each panel: `AppButton.primary`
    (`settingsConfigurationSaveAction`) + `AppButton.tertiary`
    (`settingsConfigurationResetAction`)
  - Persistence: `tenantFacilitySetupControllerProvider` +
    `tenantFacilitySetupSubmissionProvider.saveTenantConfiguration` /
    facility equivalent
- Workspace: `frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart`
  - Nested `AppTabStrip` panels: `overview` | `setup` | `modules`
  - No toolbar on nested strip today
  - Empty-state Refresh: `AppButton.secondary` + `commonRefreshActionLabel`
  - Module row Open/Create: row-local `AppButton.tertiary` (keep as row actions, not chrome)
  - Filters: custom `_SettingsWorkspaceFilters` panel (search/group/state/actionable) — **not**
    `AppListTable`
  - Controller: `settingsWorkspaceControllerProvider` in
    `frontend/lib/features/settings/presentation/controllers/settings_workspace_controller.dart`
  - State/entities/repo under `features/settings/{presentation/state,domain,data}/`
- Route: `AppRoutes.settings` path `/settings` in
  `frontend/lib/app/router/app_routes.dart`
- Router: `frontend/lib/app/router/app_router.dart`
  - Builder: `SettingsPage(initialQuery: SettingsPageQuery.fromUri(state.uri))`
  - `/profile` redirects to `SettingsPageQuery(tab: 'account', panel: 'profile')`
  - User-menu profile / change-password targets also use `SettingsPageQuery` account panels
- Tests:
  - `frontend/test/features/settings/presentation/pages/settings_page_test.dart`
    (HR policy tab visibility only; no chrome/toolbar/URL tests)
  - `frontend/test/features/settings/presentation/widgets/settings_workspace_section_test.dart`
  - `frontend/test/features/settings/presentation/controllers/settings_workspace_controller_test.dart`
  - DTO/repo tests under `frontend/test/features/settings/`

### Current widget tree (chrome)

```
ResponsivePage(maxWidth: PageMaxWidth.dashboard)
  └── _SettingsAccordion
        ├── AppTabStrip(tabs from accordion entries, selectedId: expandedSectionId)
        │     // primaryAction / secondaryActions: NOT PASSED → no toolbar under tabs
        └── for each section: _AccordionPanel (animated heightFactor)
              └── _AccordionPanelContent
                    └── DecoratedBox card + optional AppScreenSection(title, body) + section body
```

**No** `AppWorkspace` title header today (good). **No** FAB / PopupMenu / overflow “more” menu
at page level. Gaps are accordion UX, missing page toolbar, nested strips, and stray CTAs.

### Tabs (validated against code + l10n)

| # | Tab label (l10n key → EN) | Query `tab` | Permission / visibility | Nested `panel` values |
|---|---------------------------|-------------|-------------------------|------------------------|
| 1 | `settingsPreferencesSectionTitle` → **Preferences** | `preferences` | Always | — |
| 2 | `settingsAccessibilitySectionTitle` → **Accessibility** | `accessibility` | Always | — |
| 3 | `settingsAccountSectionTitle` → **Account and security** | `account` | Always | `profile`, `change-password` |
| 4 | `settingsAdministrationSectionTitle` → **Administration boundaries** | `administration` | Shown only when ≥1 `_adminActions` entry passes its `AccessRequirement` | — |
| 5 | `settingsConfigurationSectionTitle` → **Configuration** | `configuration` | `_configTenantRequirement` **or** `_configFacilityRequirement` | — |
| 6 | `settingsWorkspaceSectionTitle` → **Administrative setup workspace** | `workspace` | `_settingsWorkspaceRequirement` **or** `_hrSettingsWorkspaceRequirement` | `overview`, `setup`, `modules` |

Default tab when omitted: `preferences` (`SettingsPageQuery.tab` default; `location()` omits `tab`
when it equals `preferences`).

Administration actions inside tab body (permission-filtered):

| Action title (l10n) | EN label | Requirement constant | Navigation |
|---------------------|----------|----------------------|------------|
| `settingsTenantFacilitySetupActionTitle` | Tenant and facility setup | `_tenantFacilitySetupRequirement` | `AppRoutes.tenantFacilitySetup` |
| `navigationSubscriptionsLabel` | Subscription plans | `_subscriptionsRequirement` | `AppRoutes.subscriptions` |
| `settingsAccessAdminActionTitle` | Users and access | `_accessAdminRequirement` | `AppRoutes.accessAdmin` |

### Concrete `prompt.md` gaps to close

1. **Accordion / collapsible tabs** — `_onSectionTapped` toggles `_expandedSectionId` to `null`,
   allowing no selected tab and animating multiple panels. Must become exclusive single-body tabs
   (Reception pattern): always one selected tab; never collapse to none.
2. **No page-level toolbar** — top `AppTabStrip` does not pass `primaryAction` /
   `secondaryActions`. Contextual actions are missing or buried in bodies/nested strips.
3. **Nested `AppTabStrip`** inside `SettingsAccountSection` and `SettingsWorkspaceSection`
   violates single top-of-screen strip + toolbar-under-tabs contract. Remove nested strips;
   drive sub-panels via `?panel=` + page-level toolbar (or exclusive body switch without a
   second strip).
4. **Stray CTAs outside toolbar**
   - Account: Change password `AppButton.primary` in `_ChangePasswordPanel`
   - Account: Edit profile already on nested strip — must move to **page** strip toolbar
   - Configuration: Save / Reset `AppButton`s inside `_TenantConfigPanel` /
     `_FacilityConfigPanel`
   - Workspace empty state: Refresh button in `AppStateView.action` (move Refresh to toolbar;
     empty state may keep retry via toolbar only)
5. **Duplicate section title chrome** — `_AccordionPanelContent` wraps with `AppScreenSection`
   (title + body) that repeats the tab label; account/config/workspace sections also wrap
   themselves in `AppScreenSection`. Remove screen-level / duplicate title headers; keep
   short descriptive copy only where useful as content (not as a second title bar).
6. **Decorative accordion card** (`DecoratedBox` border/surface around entire panel) acts as
   extra chrome; remove in favor of Reception-like plain body under the strip
   (`SizedBox(height: theme.spacing.sm)` then content).
7. **Toolbar guarantee** — Preferences/Accessibility are auto-save forms with no actions today.
   That is allowed **only if** other tabs always expose ≥1 toolbar button when selected, and
   the screen as a whole has toolbar buttons on actionable tabs (Account / Administration /
   Configuration / Workspace). When a form tab has no actions, omit toolbar for that tab.
8. **No `AppListTable` on Settings today** — do **not** invent tables. If a future table is
   introduced, chrome may only expose Filters + Settings (`commonTableSettingsActionLabel`
   must read **Settings**, and Filters label must be exactly **Filters**). Workspace module
   filters stay as content filters unless/until migrated to `AppListTable`.
9. **Deep link** — `?tab=` already works; strengthen so tab taps always `context.go` /
   `replace` with canonical query; keep `?panel=` for account + workspace; never allow
   null/deselected tab from URL or UI.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` —
  exclusive tabs, `AppTabStrip` + body, URL sync via query, `SizedBox(height: theme.spacing.sm)`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — per-tab
  `primaryAction` / `secondaryActions` pattern
- `frontend/lib/shared/components/app_tab_strip.dart` — `AppTabStrip`, `AppTabItem`,
  `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default
  `false`); Settings may keep `ResponsivePage` **without** reintroducing a title header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; prefer
  `AppTabStrip` toolbar, not a second workspace toolbar above tabs
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage`, `AppScreenSection`
  (do not use `AppScreenSection` as a screen title bar)
- `frontend/lib/shared/components/app_list_table.dart` — only if a table is already present
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `frontend/lib/shared/components/components.dart` — barrel exports for strip/table/buttons

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Preferences | `/settings` or `/settings?tab=preferences` | Theme mode radio (`appThemeModeProvider`) | *(omit — auto-save)* | *(omit)* |
| Accessibility | `/settings?tab=accessibility` | Reduce motion / bold text / text scale (`appAccessibilityProvider`) | *(omit — auto-save)* | *(omit)* |
| Account and security | `/settings?tab=account&panel=profile\|change-password` | Profile view or change-password panel | **When `panel=profile`:** `AppTabToolbarPrimary` `profileEditActionTitle` (“Edit profile”), icon `Icons.edit_outlined`, opens `EditUserProfileDialog` via existing `_ProfileEditAction` logic (lift to page strip). **When `panel=change-password`:** `AppTabToolbarPrimary` `settingsChangePasswordActionTitle` (“Change password”), icon `Icons.lock_reset_outlined`, opens `ChangePasswordDialog` (remove body `AppButton`) | Panel switchers as `AppTabToolbarAction`: **Profile** (`settingsProfileActionTitle`) → set `panel=profile`; **Change password** (`settingsChangePasswordActionTitle`) → set `panel=change-password`. Highlight/disable the action matching the active panel (enabled for the inactive one only, or always call but no-op if same). |
| Administration boundaries | `/settings?tab=administration` | Boundary navigations (permission-filtered) | First allowed admin destination as `AppTabToolbarPrimary` (prefer Tenant and facility setup when allowed; else Subscriptions; else Users and access) using existing titles/icons/`context.go` targets | Remaining allowed admin destinations as `AppTabToolbarAction`s (same handlers as today’s `_SettingsAction.onTap`). Keep a short descriptive body list **or** a slim content summary — do **not** leave duplicate large CTAs that re-create a second action bar; if tiles remain, they must not look like a header toolbar (prefer text links / existing tile list **or** drop tiles once toolbar covers all destinations). |
| Configuration | `/settings?tab=configuration` | Tenant/facility currency + consultation fee | `AppTabToolbarPrimary` `settingsConfigurationSaveAction` (“Save configuration”), icon `Icons.save_outlined` — saves the active draft(s) via existing submission APIs; show loading via `isLoading` | `AppTabToolbarAction` `settingsConfigurationResetAction` (“Reset to default”), icon `Icons.restart_alt_outlined` — keep confirm dialog (`settingsConfigurationResetConfirmTitle` / `Body`). Remove in-panel Save/Reset button rows. |
| Administrative setup workspace | `/settings?tab=workspace&panel=overview\|setup\|modules` | Setup readiness workspace | `AppTabToolbarPrimary` or `AppTabToolbarAction` **Refresh** (`commonRefreshActionLabel`, icon `Icons.refresh`) → `settingsWorkspaceControllerProvider.notifier.refresh()` | Panel switchers as `AppTabToolbarAction`: **Context summary** (`settingsWorkspaceContextTitle`) → `panel=overview`; **Setup checklist** (`settingsWorkspaceChecklistTitle`) → `panel=setup`; **Module groups** (`settingsWorkspaceModuleGroupsTitle`) → `panel=modules`. Remove nested `AppTabStrip`. |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction`
  for left-cluster secondaries (matches `AppTabStrip` contract).
- Preferences / Accessibility may omit the toolbar entirely (auto-save). Account,
  Administration (when visible), Configuration (when visible), and Workspace (when visible)
  **must** show toolbar actions so the screen is never actionless overall.
- Gate write/navigation actions with the same `AccessRequirement`s already used
  (`AppAccessActionGate` where appropriate for write CTAs; admin list already filters by
  `accessPolicy`).
- Row-level Open/Create on workspace modules stay row-local. Checklist chips / quick-action
  buttons stay in content panels (domain workflows), not a header more-menu.

### Routing

- Keep `/settings` registration in `app_router.dart`.
- Query key for top tabs: **`tab`** (already used by `SettingsPageQuery`).
- Canonical `tab` values: `preferences` | `accessibility` | `account` | `administration` |
  `configuration` | `workspace`.
- Sub-panel key: **`panel`** (already used).
  - Account: `profile` | `change-password` (constants on `SettingsAccountSection`).
  - Workspace: `overview` | `setup` | `modules`.
- On tab tap: `setState` selected tab + `context.go` / `GoRouter.replace` with
  `SettingsPageQuery(tab: …).location()`; clear `panel` when leaving account/workspace
  (`clearPanel: true`) unless the destination tab needs a default panel.
- When entering `account` without panel → default `profile`.
- When entering `workspace` without panel → default `overview`.
- Preserve `/profile` redirect and user-menu deep links to account panels.
- If URL `tab` points at a permission-hidden section, fall back to first visible tab
  (usually `preferences`) without crashing.
- **Never** allow deselected tabs (`selectedId` must always be a visible tab id).

### Page Layout

Precise widget tree:

1. `ResponsivePage(maxWidth: PageMaxWidth.dashboard)` (or `AppWorkspace(showHeader: false, …)`
   equivalent — **no** title header). Do **not** set `showHeader: true`.
2. `Column` → `AppTabStrip(tabs:, selectedId:, onTabTapped:, primaryAction:, secondaryActions:)`
   built from the **visible** permission-filtered tab list.
3. `SizedBox(height: theme.spacing.sm)` (match Reception vertical rhythm).
4. Body: **only the active tab’s content** (no accordion / heightFactor / multi-panel stack).
5. No FAB / floating header actions / overflow more-menu for screen actions.
6. No nested `AppTabStrip` inside account/workspace sections.
7. No duplicate `AppScreenSection` title that repeats the tab label; subsection panels
   (`AppSectionPanel`) for tenant/facility forms and workspace groups may remain.

### Data & State Management

Reuse (do not fork):

- `appThemeModeProvider` — Preferences theme
- `appAccessibilityProvider` — Accessibility prefs
- `userProfileControllerProvider` — Account profile
- `appAccessPolicyProvider` — tab + admin action visibility
- `tenantFacilitySetupControllerProvider` /
  `tenantFacilitySetupSubmissionProvider` — Configuration
- `settingsWorkspaceControllerProvider` — Workspace load/filter/refresh/context select

Adjustments allowed:

- Lift configuration draft fields (currency/fee for tenant + facility) into a small
  ChangeNotifier / Riverpod notifier **or** a `GlobalKey` host state owned by
  `SettingsConfigurationSection` that exposes `save()` / `reset()` for the page toolbar.
  Prefer minimal surface area; keep existing submission API calls.
- Lift `_ProfileEditAction` / change-password open handlers so page-level strip can host them.
- Replace accordion private widgets with a simple tab → body switch in `SettingsPage`.

## Implementation Steps

1. **Convert accordion to exclusive tabs** — File:
   `frontend/lib/features/settings/presentation/pages/settings_page.dart`
   - Replace `_expandedSectionId` nullable collapse with non-null `_selectedTabId` always
     matching a visible section.
   - Remove `_SettingsAccordion` multi-panel animation (`_AccordionPanel` /
     `_AccordionPanelContent` heightFactor) or reduce to a single active child builder.
   - Build one `AppTabStrip` with `primaryAction` / `secondaryActions` from
     `_toolbarForTab(selectedId)`.
   - Render only the selected tab body under `SizedBox(height: theme.spacing.sm)`.
   - Update `_onSectionTapped` → select tab + navigate; never set selection to `null`.

2. **Wire contextual toolbars per tab** — same file
   - Implement `_toolbarForTab` returning `(Widget? primary, List<Widget> secondary)` per the
     Tab Configuration table.
   - Administration: derive buttons from the same filtered `_adminActions` list.
   - Account / Workspace: include panel switcher secondaries; sync `panel` query via existing
     `_onAccountPanelChanged` / `_onWorkspacePanelChanged` (or unified helper).

3. **Remove nested strips; hoist account actions** — File:
   `frontend/lib/features/settings/presentation/widgets/settings_account_section.dart`
   - Delete inner `AppTabStrip`.
   - Switch body on `initialPanel` / active panel only.
   - Remove `_ChangePasswordPanel` body `AppButton`; page toolbar opens the dialog.
   - Export or share edit/change-password handlers for page toolbar (public widgets or
     callbacks). Keep `AppScreenSection` title removal / demotion so it is not a second
     screen header.

4. **Hoist configuration Save/Reset into page toolbar** — File:
   `frontend/lib/features/settings/presentation/widgets/settings_configuration_section.dart`
   - Remove Wrap of Save/Reset buttons from `_TenantConfigPanel` / `_FacilityConfigPanel`.
   - Provide a draft host the page can drive (notifier, callbacks, or `GlobalKey`).
   - Preserve confirm-reset dialog + snackbars (`settingsConfigurationSaveSuccess` /
     `SaveError`).
   - Keep permission gates `_tenantConfigRequirement` / `_facilityConfigRequirement`.

5. **Hoist workspace Refresh + panel switchers; remove nested strip** — File:
   `frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart`
   - Delete nested `AppTabStrip`.
   - Body switches on `overview` / `setup` / `modules` from `initialPanel`.
   - Remove empty-state Refresh `AppButton` (toolbar Refresh covers it); keep
     `AppFailureStateView.onRetry` calling refresh (retry is state recovery, not header chrome).
   - Keep `_SettingsWorkspaceFilters` in modules body (not table Filters unless you introduce
     `AppListTable` — do not).

6. **Strip duplicate titles / card chrome** — `settings_page.dart` + section widgets
   - Remove accordion `DecoratedBox` card wrapper.
   - Stop wrapping Preferences/Accessibility in `AppScreenSection` that repeats tab title;
     show fields directly (optional short helper text using existing `*SectionBody` strings
     as plain text, not a title bar).
   - Account/Configuration/Workspace: remove outer `AppScreenSection` title duplication or
     convert to description-only content without a competing screen header.

7. **Routing hardening** — `SettingsPageQuery` + page state
   - Validate unknown `tab` → `preferences`.
   - When selected tab is hidden by permissions after policy load, snap to first visible tab
     and update URL.
   - Ensure `panel` only written for `account` / `workspace`.

8. **Tests** — update/add under `frontend/test/features/settings/`
   - Tab switch updates URL `?tab=`.
   - Deep link `?tab=account&panel=change-password` opens change-password body + toolbar
     primary Change password.
   - Nested `AppTabStrip` count on Settings page is exactly one.
   - Configuration tab shows Save in strip; no Save `AppButton` in body.
   - Workspace Refresh in strip; nested strip gone.
   - Existing HR visibility test still passes (Preferences / Accessibility / Account /
     Administration / Tenant and facility setup / Administrative setup workspace).

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Single top strip + contextual toolbar |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Optional; only with `showHeader: false` |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write CTAs when needed |
| `AppRadioGroup` / `AppCheckboxField` / `AppSelectField` | `shared/components/*` | Preferences / Accessibility fields |
| `AppButton` / `AppDialog` / `AppStateView` / `AppFailureStateView` | shared components | Dialogs + empty/error (not screen header actions) |
| `AppSectionPanel` / `AppContentPanel` / `AppInfoTileGrid` | shared components | Subsection content inside tabs |
| `AppListTable` | `app_list_table.dart` | **Do not add** unless converting an existing list; if added, only Filters + Settings in table chrome |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive spacing |

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/settings/presentation/pages/settings_page.dart` | Exclusive tabs; page-level contextual toolbar; remove accordion chrome |
| `frontend/lib/features/settings/presentation/widgets/settings_account_section.dart` | Remove nested strip; hoist CTAs; panel body only |
| `frontend/lib/features/settings/presentation/widgets/settings_configuration_section.dart` | Hoist Save/Reset; draft host for toolbar |
| `frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart` | Remove nested strip; panel body; Refresh via page toolbar |
| `frontend/test/features/settings/presentation/pages/settings_page_test.dart` | Add chrome / URL / toolbar tests; keep HR visibility coverage |
| `frontend/test/features/settings/presentation/widgets/settings_workspace_section_test.dart` | Update for no nested strip / panel query |

### Create (only if needed)

| File | Change |
|------|--------|
| Optional small draft/notifier for configuration toolbar binding under `features/settings/presentation/` | Only if GlobalKey/callbacks are insufficient |

### Delete

| File / symbol | Reason |
|---------------|--------|
| `_SettingsAccordion` multi-expand animation path (`_AccordionPanel` heightFactor stack) | Replaced by exclusive tab body |
| Nested `AppTabStrip` in account + workspace sections | Violates single top strip |
| In-panel Configuration Save/Reset button rows | Moved to tab toolbar |
| Change-password body primary button | Moved to tab toolbar |

Do **not** delete domain controllers, repositories, DTOs, or dialogs.

## Cleanup: Remove Stale Code

- [ ] Remove accordion collapse-to-null selection behavior
- [ ] Remove unused accordion private classes if fully replaced
- [ ] Remove nested tab strips and unused panel-local toolbar widgets after hoist
- [ ] Remove duplicate `AppScreenSection` screen-title usage that repeats tab labels
- [ ] Remove decorative full-panel `DecoratedBox` card chrome from former accordion content
- [ ] Ensure no PopupMenu / “more” overflow for screen actions was introduced
- [ ] Grep `settings_page.dart` / section widgets for stray `AppButton.primary` header-style CTAs
      that belong in the strip

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome
refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): Full horizontal `AppTabStrip` scroll if needed; toolbar primary right /
  secondaries left wrap; form fields may use wide two-column layouts already in configuration
  (`constraints.maxWidth >= 600`).
- Tablet (600–1023px): Same strip + toolbar; configuration stacks fields when narrow; workspace
  filter wrap continues to use `Wrap`.
- Mobile (<600px): Tabs remain horizontally scrollable (built into `AppTabStrip`); toolbar
  actions wrap via existing `Wrap` in strip toolbar; no separate mobile title header; keep
  `ResponsivePage` padding behavior.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/settings/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`?tab=`) and toolbar actions
- [ ] Deep link opens correct tab (`/settings?tab=configuration`, account+panel, workspace+panel)
- [ ] Per-tab toolbar shows only that tab’s actions (Preferences/Accessibility omit toolbar)
- [ ] Exactly one `AppTabStrip` in the Settings page tree (no nested strips)
- [ ] Table chrome N/A today; if any `AppListTable` appears, only Filters + Settings inside it
- [ ] No screen title/header chrome remains (`showHeader: true` not used; no accordion title bar)
- [ ] At least one toolbar button exists on Account / Administration / Configuration / Workspace
- [ ] Permissions still gate administration destinations, configuration, and workspace visibility
- [ ] Responsive layouts still work (pump mobile + desktop sizes in widget tests where practical)
- [ ] Existing HR visibility expectations remain green

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (prefs, accessibility, account, admin nav, configuration save/reset,
      workspace readiness)
- [ ] Analyze clean; tests pass; stale accordion / nested-strip / stray CTA code removed
```
