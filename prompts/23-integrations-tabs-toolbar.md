# Standardize Integrations Screen (Tabs & Toolbar)

## Objective

Refactor the Integrations workspace (`/integrations`, `IntegrationsWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Scope boundary:** Restructure Integrations **screen chrome/layout only**. Do not rewrite
detail dialogs (`_IntegrationDetailPanel`, `_detailActions`), create/edit/permission forms
(`_IntegrationConfigDialog`, `_ApiKeyDialog`, `_WebhookDialog`, `_PermissionDialog`),
repository APIs, DTOs, or realtime sync unless required to keep chrome wiring compiling.
Preserve permissions (`_integrationsManageRequirement` / `AppAccessActionGate`), section
counts, pagination, advanced filters, deep links, and mutation dialogs.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.

**Audit note:** Integrations already has `AppTabStrip` + per-tab create primaries + URL
`?section=` + table Filters/Settings. The **blocking gaps** are: (1) an `AppWorkspace`
toolbar strip **above** the tabs (Refresh + status summary notifications), (2) those status
shortcuts live inside a **`more_vert` / Notifications overflow menu** (forbidden by
`prompt.md`), and (3) **Logs** / **Interop** omit the tab toolbar entirely (`primaryAction:
null` and no `secondaryActions`). Close those gaps; do not regress into a titled header or
a more-menu.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
  - Public widget: `IntegrationsWorkspacePage` (`initialQuery`)
  - Content: `_IntegrationsWorkspaceContent` / `_IntegrationsWorkspaceContentState`
  - Worklist body: `_IntegrationWorklistPanel` → `AppListTable<IntegrationWorkItem>`
  - Detail + create/edit/permission/confirm dialogs live in the same page file
- Controller: `frontend/lib/features/integrations/presentation/controllers/integrations_workspace_controller.dart`
  - Provider: `integrationsWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyFilter()`, `applySearch()`, `changePage()`,
    `selectItem()`, `createIntegration()`, `updateIntegration()`, `createApiKey()`,
    `updateApiKey()`, `deleteApiKey()`, `addApiKeyPermission()`, `removeApiKeyPermission()`,
    `createWebhook()`, `updateWebhook()`, `testConnection()`, `syncNow()`,
    `replayWebhook()`, `replayLog()`, `currentTenantId()`, `currentApiKeyCreateContext()`
- Domain: `frontend/lib/features/integrations/domain/entities/integration_entities.dart`
  - `IntegrationDeskSection` enum: `integrations`, `apiKeys`, `webhooks`, `logs`, `interop`
  - `IntegrationWorkspaceFilter` (section filters + status: `active` / `warning` / `failed` / `disabled`)
  - `IntegrationWorkspaceQuery.fromUri` / `hasRouteTargeting` / `signature`
  - Work items: `IntegrationWorkItem`, `IntegrationRecord`, `ApiKeyRecord`,
    `WebhookSubscriptionRecord`, `IntegrationLogRecord`, `InteropCapabilityStatus`
- Repository: `frontend/lib/features/integrations/domain/repositories/integrations_repository.dart`
  + `frontend/lib/features/integrations/data/repositories/integrations_repository_impl.dart`
  + DTOs: `frontend/lib/features/integrations/data/dtos/integration_dtos.dart`
- Route: `AppRoutes.integrations` path `/integrations` in
  `frontend/lib/app/router/app_routes.dart`
  - Permissions: `integrationRead` / `integrationWrite` (+ admin permissions)
  - Roles: `adminShellRoles`
  - Module: `integrations-core`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri)` into
  `IntegrationsWorkspacePage`
- Permission gate (page-local): `_integrationsManageRequirement` —
  `integrationWrite` | `tenantAdmin` | `facilityAdmin` | `systemAdmin` + module
  `integrations-core`
- Tests today:
  - `frontend/test/features/integrations/presentation/integrations_workspace_page_test.dart`
    (tabs, URL, deep link, create tooltip swap, permissions, mobile; **also** asserts
    `Icons.more_vert` → Notifications overflow for Active/Warnings/Failed — **update that**)
  - `frontend/test/features/integrations/domain/integration_entities_test.dart`

### Current widget tree (chrome) — non-compliant pieces marked

1. `AsyncStateScaffold<IntegrationWorkspaceState>` with `loadingTitle` /
   `loadingBody`, `maxWidth: PageMaxWidth.dataHeavy`
2. **`AppWorkspace(`**
   - `title: l10n.integrationsWorkspaceTitle`
   - `leadingIcon: AppRouteIcons.integrations`
   - **`toolbar: appWorkspaceToolbarWithLabels(... summaryNotifications: Active/Warnings/Failed, onRefresh: ...)`**
   - `showHeader` left at default `false`, but **`AppWorkspace` still renders
     `AppWorkspaceToolbar` above `body`** when `toolbar` is set
     (`app_workspace.dart` toolbar-only branch) — so **tabs are not at the top**
3. Body `Column` → `AppTabStrip` (create primaries on 3 tabs) → `SizedBox(sm)` →
   `_IntegrationWorklistPanel`
4. **Forbidden chrome today:** workspace toolbar **more_vert** overflow →
   **Notifications** submenu for Active / Warnings / Failed
   (see test `'toolbar shows only status-based summary badges'`)
5. Detail/item actions stay inside dialogs (`_detailActions`) — keep there
6. No FAB on the page today ✅

### Tabs (validated against code)

Enum: `IntegrationDeskSection` in `integration_entities.dart`.
Tab ids in `AppTabStrip` use `section.name`
(`integrations`, `apiKeys`, `webhooks`, `logs`, `interop`).

| # | Tab label (current l10n → English) | Enum | Query `?section=` (write via `_sectionToQueryValue`) | Count source | Current primary |
|---|------------------------------------|------|------------------------------------------------------|--------------|-----------------|
| 1 | `integrationsFilterIntegrations` → **Integrations** | `integrations` | `integrations` | `state.integrations.length` | Create integration |
| 2 | `integrationsApiKeysSummaryLabel` → **API keys** | `apiKeys` | `api-keys` | `state.apiKeys.length` | Create API key |
| 3 | `integrationsWebhooksSummaryLabel` → **Webhooks** | `webhooks` | `webhooks` | `state.webhooks.length` | Create webhook |
| 4 | `integrationsFilterLogs` → **Logs** | `logs` | `logs` | `state.logs.length` | **none** (toolbar omitted) |
| 5 | `integrationsFilterInterop` → **Interop** | `interop` | `interop` | `state.interopStatuses.length` | **none** (toolbar omitted) |

Deep-link tab state **is already URL-backed** via `?section=…` and
`GoRouter.replace` in `_updateUrlForSection`. Keep this; do not invent a second query key.
Canonical write values must remain: `integrations` | `api-keys` | `webhooks` | `logs` | `interop`.

`IntegrationWorkspaceQuery.fromUri` already accepts aliases
(`api_keys` / `keys`, `webhook` / `hooks`, `log` / `activity`, `fhir` / `hl7`, etc.)
and also `search` / `q`. Preserve that parsing.

Additional route behavior to **preserve**:
- `?search=` / `?q=` → seeds search controller via `_applyDeepLink`
- Tab change calls `setState` + `_updateUrlForSection(section)` +
  `controller.applyFilter(_filterForSection(section))`
- Default when no route targeting: post-frame `applyFilter` for current section
  (today defaults toward Integrations)

### Current toolbar (partially compliant)

`primaryAction` via `_buildSectionPrimaryAction` (gated by `AppAccessActionGate` +
`_integrationsManageRequirement`):

| Tab | Current primary | Handler | Gate |
|-----|-----------------|---------|------|
| Integrations | `integrationsCreateIntegrationAction` (“Create integration”), `Icons.add_link_outlined` | `_openIntegrationDialog` | manage requirement |
| API keys | `integrationsCreateApiKeyAction` (“Create API key”), `Icons.key_outlined` | `_openApiKeyDialog` | manage requirement |
| Webhooks | `integrationsCreateWebhookAction` (“Create webhook”), `Icons.webhook_outlined` | `_openWebhookDialog` | manage requirement |
| Logs | `null` | — | — |
| Interop | `null` | — | — |

`secondaryActions` on `AppTabStrip` today: **none**.

Header/workspace toolbar (must be removed from above tabs):

| Action | Current home | Target |
|--------|--------------|--------|
| Refresh (`commonRefreshActionLabel` via `appWorkspaceToolbarWithLabels.onRefresh`) | `AppWorkspace` toolbar | `AppTabStrip.secondaryActions` on **every** tab via `AppWorkspaceRefreshAction` |
| Active (`integrationsActiveSummaryLabel`) | `AppWorkspaceSummaryNotification` inside **more_vert → Notifications** | Visible `AppTabToolbarAction` secondary on every tab → `_applyFilter(..., IntegrationWorkspaceFilter.active)` |
| Warnings (`integrationsWarningsSummaryLabel`) | same overflow | Visible `AppTabToolbarAction` → `IntegrationWorkspaceFilter.warning` |
| Failed (`integrationsFailedSummaryLabel`) | same overflow | Visible `AppTabToolbarAction` → `IntegrationWorkspaceFilter.failed` |

### Current table chrome (mostly compliant)

In `_IntegrationWorklistPanel` (`AppListTable<IntegrationWorkItem>`):

- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` — shared key
  (English today: **“Table settings”**). **Keep this shared key.**
- Filters button + dialog title: `integrationsFiltersLabel` → English **“Filters”** ✅
- Search: keep `integrationsSearchLabel` / `integrationsSearchHint` / clear action
- Status filter group (`_integrationFilterKey` / active|warning|failed|disabled): keep behavior
- Apply / reset use `opdApplyFiltersAction` / `opdClearFiltersAction` — leave as-is unless
  you already have Integrations-specific keys (do not invent new ones in this pass)
- No create/refresh buttons in the table chrome today ✅

### Detail-dialog actions (preserve — not screen chrome)

Keep inside detail dialogs / `_detailActions` (do **not** promote to tab toolbar):
- Integration: Configure / Test connection / Sync now / Enable|Disable
- API key: Manage permissions / Enable|Disable / Revoke
- Webhook: Edit / Replay / Enable|Disable
- Log: Replay log
- Interop: no detail actions today

### Concrete `prompt.md` gaps to close

1. **Remove `AppWorkspace` titled/toolbar chrome** from the page layout. Switch to
   Reception/HR pattern: `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` wrapping
   `Column` → `AppTabStrip` → spacing → worklist. Do **not** pass `toolbar:` /
   `summaryNotifications` into `AppWorkspace`. Do **not** set `showHeader: true`.
2. **Eliminate the more_vert / Notifications overflow** for Active / Warnings / Failed.
   Promote each to its own visible `AppTabToolbarAction` under the tabs.
3. **Move Refresh** into `AppTabStrip.secondaryActions` on every tab
   (`AppWorkspaceRefreshAction` + `commonRefreshActionLabel` →
   `integrationsWorkspaceControllerProvider.notifier.refresh()`).
4. **Guarantee ≥1 toolbar affordance on Logs and Interop** (Refresh + status shortcuts
   satisfy this even when create primaries are absent or write-gated).
5. Keep create primaries contextual and permission-gated; when write is denied, Refresh
   (and status filters) must still appear.
6. Standardize tab labels to the **filter** l10n family for consistency:
   `integrationsFilterIntegrations`, `integrationsFilterApiKeys`,
   `integrationsFilterWebhooks`, `integrationsFilterLogs`, `integrationsFilterInterop`
   (English strings already match “Integrations / API keys / Webhooks / Logs / Interop”).
7. Keep table chrome limited to search + Filters + Settings.
8. Update tests that currently open `Icons.more_vert` / Notifications; assert flat
   toolbar actions instead.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — `ResponsivePage` + `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + table;
  no page title header; URL-backed `section` query
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` (Refresh via
  `AppWorkspaceRefreshAction`)
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default
  `false`); Integrations must **stop using** `AppWorkspace` for page chrome after this pass
  (detail panels / status badges / state panels remain fine)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do not wire
  `appWorkspaceToolbarWithLabels` on this page after the refactor
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `showAdvancedFilterButton` /
  `advancedFilterButtonLabel` / `filterGroups`
- `frontend/lib/shared/actions/app_workspace_refresh_action.dart` — `AppWorkspaceRefreshAction`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Integrations | `/integrations?section=integrations` | External system integrations (default) | **Create integration** — `AppTabToolbarPrimary` (`integrationsCreateIntegrationAction`, `Icons.add_link_outlined`) → `_openIntegrationDialog`; gated by `_integrationsManageRequirement`; loading when `state.isSaving` | **Active** / **Warnings** / **Failed** — `AppTabToolbarAction` (labels: `integrationsActiveSummaryLabel` / `integrationsWarningsSummaryLabel` / `integrationsFailedSummaryLabel`; icons: `Icons.check_circle_outline` / `Icons.warning_amber_outlined` / `Icons.error_outline`) → `_applyFilter` with `active` / `warning` / `failed`; **Refresh** — `AppWorkspaceRefreshAction` (`commonRefreshActionLabel`) → `controller.refresh()` |
| API keys | `/integrations?section=api-keys` | API key inventory | **Create API key** — `AppTabToolbarPrimary` (`integrationsCreateApiKeyAction`, `Icons.key_outlined`) → `_openApiKeyDialog`; same gate | Same secondaries: Active / Warnings / Failed + Refresh |
| Webhooks | `/integrations?section=webhooks` | Webhook subscriptions | **Create webhook** — `AppTabToolbarPrimary` (`integrationsCreateWebhookAction`, `Icons.webhook_outlined`) → `_openWebhookDialog`; same gate | Same secondaries |
| Logs | `/integrations?section=logs` | Integration activity logs | **none** (`primaryAction: null`) | Same secondaries (Refresh guarantees non-empty toolbar) |
| Interop | `/integrations?section=interop` | Interoperability capability readiness | **none** (`primaryAction: null`) | Same secondaries |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and
  `AppTabToolbarAction` / `AppWorkspaceRefreshAction` for left-cluster secondaries
  (matches `AppTabStrip` contract).
- Rebuild toolbar on tab change (`setState` already updates `_section`).
- Disable mutation primaries when `state.isSaving` (already done).
- **Never** leave both `primaryAction == null` and empty `secondaryActions` on any tab.
  Refresh (+ status shortcuts) must always be present so the screen cannot become actionless
  (including read-only users where create primaries are hidden/disabled).
- Do **not** put detail-scoped configure/test/sync/replay/revoke actions into the tab toolbar.
- Keep `AppAccessActionGate` + `_integrationsManageRequirement` for create primaries.
- Prefer implementing `_buildSecondaryActions(...)` as an explicit method (HR/Housekeeping style)
  even if the secondary set is currently identical across tabs — makes future per-tab diffs easy.
- Preserve existing status-filter semantics from the old summary notifications (call
  `_applyFilter` only; do not force `_section` / URL rewrite unless you already do today).

### Routing

- Keep `/integrations` registration in `app_router.dart` unchanged structurally
  (`IntegrationWorkspaceQuery.fromUri(state.uri)`).
- Keep query key **`section`** (written by `_updateUrlForSection` /
  parsed by `IntegrationWorkspaceQuery.fromUri` / `_filterFromSection`).
- Canonical write values must remain: `integrations` | `api-keys` | `webhooks` | `logs` | `interop`
- On tab tap: keep `setState` + `_updateUrlForSection(section)` +
  `controller.applyFilter(_filterForSection(section))`.
- Preserve `?search=` / `?q=` seeding via `_applyDeepLink`.
- When writing URL on tab change, today’s helper only writes `section` — **preserve that
  existing behavior** (do not expand URL sync scope in this chrome pass).
- No new query keys required.

### Page Layout

Precise widget tree for `_IntegrationsWorkspaceContentState.build`:

1. Keep outer `IntegrationsWorkspacePage` → `AsyncStateScaffold` with
   `loadingTitle` / `loadingBody` only (loading chrome). Do **not** add a titled workspace header.
2. Replace `AppWorkspace(...)` with:
   `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: SizedBox(width: double.infinity, child: Column(...)))`
3. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`.
4. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm matching Reception).
5. Body: `_IntegrationWorklistPanel` / `AppListTable` with **only** Filters + Settings
   (plus search) in the table chrome.
6. No FAB / floating header actions / overflow more-menu for screen actions.
7. Remove unused imports that only served `appWorkspaceToolbarWithLabels` /
   `AppWorkspaceSummaryNotification` / `AppRouteIcons` **if** they become unused after the
   chrome move (keep any still needed by dialogs / badges).

### Data & State Management

Reuse (do not replace):

- Provider: `integrationsWorkspaceControllerProvider`
  (`frontend/lib/features/integrations/presentation/controllers/integrations_workspace_controller.dart`)
- Local UI state in `_IntegrationsWorkspaceContentState`: `_section`, `_searchController`,
  `_tableColumnController`, `_appliedRouteSignature`
- Helpers already on the page: `_sectionFromFilter`, `_filterForSection`,
  `_sectionToQueryValue`, `_updateUrlForSection`, `_applyDeepLink`, `_applyFilter`,
  `_buildSectionPrimaryAction` (extend or pair with `_buildSecondaryActions`)
- Access: `_integrationsManageRequirement` + `AppAccessActionGate` + `appAccessPolicyProvider`
- Realtime refresh already wired in the controller — keep calling `controller.refresh()`
  from the new toolbar Refresh action

## Implementation Steps

1. **Replace page chrome shell** — File:
   `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - In `_IntegrationsWorkspaceContentState.build`, remove `AppWorkspace(title:, leadingIcon:, toolbar:, body:)`.
   - Return `ResponsivePage` + `Column` as in Reception/HR.
   - Keep `AppTabStrip` as the first child of the column.

2. **Add per-tab secondary toolbar builder** — same file
   - Add `_buildSecondaryActions(AppLocalizations l10n, IntegrationWorkspaceState state)`
     returning `List<Widget>`:
     - Three `AppTabToolbarAction`s for Active / Warnings / Failed (handlers = existing
       `_applyFilter` calls currently on `AppWorkspaceSummaryNotification.onSelected`).
     - One `AppWorkspaceRefreshAction` with `commonRefreshActionLabel`,
       `isLoading: state.isRefreshing`, `onPressed` → `controller.refresh()` +
       `_showFailureIfNeeded` (mirror previous `onRefresh` behavior).
   - Pass `secondaryActions: _buildSecondaryActions(l10n, state)` into `AppTabStrip`.
   - Ensure Logs / Interop always receive these secondaries even when `primaryAction` is null.

3. **Keep / polish primary builder** — same file
   - Retain `_buildSectionPrimaryAction` switch for Integrations / API keys / Webhooks.
   - Keep Logs / Interop returning `null` for primary **only after** secondaries are wired.
   - Keep `AppAccessActionGate` wrapping create primaries.

4. **Standardize tab labels** — same file
   - In `_sectionLabel`, use:
     - `integrationsFilterIntegrations`
     - `integrationsFilterApiKeys` (replace `integrationsApiKeysSummaryLabel`)
     - `integrationsFilterWebhooks` (replace `integrationsWebhooksSummaryLabel`)
     - `integrationsFilterLogs`
     - `integrationsFilterInterop`

5. **Leave table chrome alone except verification** — `_IntegrationWorklistPanel`
   - Confirm Filters button + title remain `integrationsFiltersLabel` (“Filters”).
   - Confirm Settings remains `commonTableSettingsActionLabel`.
   - Do not add Refresh/create into the table.

6. **Preserve dialogs and domain behavior** — same file / controller / repository
   - No API or schema changes.
   - Do not move `_detailActions` into the tab toolbar.

7. **Update presentation tests** — File:
   `frontend/test/features/integrations/presentation/integrations_workspace_page_test.dart`
   - Delete or rewrite `'toolbar shows only status-based summary badges'` so it no longer
     taps `Icons.more_vert` / “Notifications”.
   - Assert Active / Warnings / Failed and Refresh are visible as toolbar actions
     (tooltips/labels from l10n) without opening an overflow menu.
   - Assert Logs / Interop still show Refresh (and status actions) when create tooltips are absent.
   - Keep existing tab / URL / deep-link / permission / column tests; adjust only if
     finders break due to chrome relocation.
   - Optionally assert `find.byType(AppWorkspace)` is absent from the page chrome
     (detail dialogs may still use workspace panels — prefer asserting no
     `AppWorkspaceToolbar` / no `more_vert` on the main page instead).

8. **Format, analyze, test** — run verification commands below.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Settings + search |
| Advanced Filters (search bar) | `package:hosspi_hms/shared/components/app_search_bar.dart` | Table Filters dialog only |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AppWorkspaceRefreshAction` | `package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart` | Refresh secondary on every tab |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate create primaries |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive spacing already used by shared layout |
| `AsyncStateScaffold` | existing shared state scaffold import already used by the page | Loading / error shell only |

**Forbidden:** new custom tab bars, new overflow/more menus for screen actions, new table
header action rows beyond Filters/Settings, reintroducing `AppWorkspace(toolbar: …)` above tabs.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart` | Replace `AppWorkspace` chrome with `ResponsivePage`; move Refresh + Active/Warnings/Failed into `AppTabStrip.secondaryActions`; keep create primaries; standardize tab label keys |
| `frontend/test/features/integrations/presentation/integrations_workspace_page_test.dart` | Replace more_vert/Notifications assertions; cover Refresh + status toolbar actions on all tabs including Logs/Interop |

### Do not create

- No new feature widgets for tabs/toolbars.
- No new l10n keys unless a required English string is truly missing (it is not — reuse existing keys listed above).

### Delete / dead code after refactor

- Remove page-level use of `appWorkspaceToolbarWithLabels` +
  `AppWorkspaceSummaryNotification` list for Active/Warnings/Failed.
- Remove unused imports (`AppRouteIcons` if only used by removed `leadingIcon`, etc.).
- Do **not** delete shared `AppWorkspaceSummaryNotification` types — other screens still use them.

## Cleanup: Remove Stale Code

- [ ] No `AppWorkspace(title: …, toolbar: …)` wrapping the Integrations worklist
- [ ] No `Icons.more_vert` / Notifications overflow path for Integrations screen actions
- [ ] No duplicate Refresh (must not remain both above tabs and under tabs)
- [ ] Logs / Interop no longer omit the entire tab toolbar
- [ ] Table chrome still has only search + Filters + Settings
- [ ] Detail dialog actions unchanged and not duplicated into the tab toolbar
- [ ] Tests no longer depend on the old more menu

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation chrome
refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar row; table with Filters/Settings; create
  primary right-aligned when on Integrations/API keys/Webhooks.
- Tablet (600–1023px): horizontal scroll for tabs if needed (`AppTabStrip` already scrolls);
  secondary actions wrap via `AppTabStrip` `Wrap`.
- Mobile (<600px): keep `mobileItemBuilder` (`_MobileIntegrationItem`); tabs + toolbar remain
  above the list; no FAB.

Follow existing `theme.spacing.sm` gap under the tab strip (Reception parity). Do not invent
new breakpoint-specific chrome.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/integrations/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL `?section=` and swaps create primary tooltips
- [ ] Deep link `/integrations?section=api-keys` opens API keys tab
- [ ] Per-tab toolbar shows only that tab’s primary (or none on Logs/Interop) plus shared secondaries
- [ ] Active / Warnings / Failed appear as visible toolbar buttons (no more_vert)
- [ ] Refresh appears on every tab including Logs and Interop
- [ ] Table chrome has only Filters and Settings (plus search)
- [ ] No screen title/header / `AppWorkspace` toolbar chrome remains above tabs
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate create actions (`AppAccessActionGate` / read-only policy test)
- [ ] Responsive / narrow viewport still shows tab strip + list
- [ ] Detail dialogs and mutation flows still compile and behave

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (filters, deep links, dialogs, permissions, realtime refresh)
- [ ] Analyze clean; tests pass; stale chrome code removed
)
