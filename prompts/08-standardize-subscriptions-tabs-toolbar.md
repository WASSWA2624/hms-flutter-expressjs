# Standardize Subscriptions Screen (Tabs & Toolbar)

## Objective

Refactor the Subscriptions workspace (`/subscriptions`, `SubscriptionsWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Scope boundary:** Restructure Subscriptions **screen chrome/layout only**. Do not rewrite
detail dialogs (`_SubscriptionDetailPanel`, `_DetailActions`, plan editors, payment/upgrade
dialogs), repository APIs, DTOs, or realtime sync unless required to keep chrome wiring
compiling. Preserve permissions (`AppPermissions.subscriptionsWrite` / read), overview metrics,
queue shortcuts, pagination, filters, deep links (`panel` / `resource` / `id` / filters), and
mutation dialogs.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.

**Audit note:** Subscriptions already uses `AppTabStrip` + resource-aware `primaryAction` +
`AppListTable` Filters/Settings, and `?panel=` / `?resource=` deep links exist. Remaining
gaps are material: Overview tab cannot stay selected; Notifications tab is a no-op; overview
metrics and worklist always render together; toolbar can be empty; Filters label is wrong;
`appBarTitle` remains. Close those gaps — do **not** regress into a titled `AppWorkspace`
header or a more-menu.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
  - Public widget: `SubscriptionsWorkspacePage` (`initialQuery`)
  - Content: `_SubscriptionsWorkspaceContent` / `_SubscriptionsWorkspaceContentState`
  - Tab chrome: `_SubscriptionsPanelTabBar` → `AppTabStrip`
  - Overview body: `_SubscriptionOverviewPanel` (metric cards, usage, recommendations)
  - Worklist: `_SubscriptionsWorklistPanel` → `AppListTable<SubscriptionItem>`
  - Detail + create/edit/collect/renew dialogs live in the same page file (preserve)
- Controller: `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart`
  - Provider: `subscriptionsWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyRouteQuery`, `applyPanel`, `applyResource`, `applyQueue`,
    `applySearch`, `applyFilters`, `resetFilters`, `changePage`, `selectItem`,
    `createPlan`, subscription/module/license/invoice mutations
  - Panel→resource helper: top-level `_defaultResourceForPanel` (same file, bottom)
- Domain: `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`
  - `SubscriptionPanel`: `overview`, `catalog`, `operations`, `billing`, `governance`
  - `SubscriptionResource`: `subscriptionPlans`, `modules`, `subscriptions`,
    `moduleSubscriptions`, `subscriptionInvoices`, `licenses`
  - `SubscriptionsWorkspaceQuery.fromUri` / `location()` — query keys `panel`, `resource`,
    `search`, `queue`, `tenantId`, `id`, filters, `datePreset`
- Repository: `frontend/lib/features/subscriptions/domain/repositories/subscriptions_repository.dart`
  + `frontend/lib/features/subscriptions/data/repositories/subscriptions_repository_impl.dart`
  (sends `panel` + `resource` to API)
- Realtime: `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_realtime_delta_applier.dart`
- Route: `AppRoutes.subscriptions` path `/subscriptions` in
  `frontend/lib/app/router/app_routes.dart` (superAdmin roles)
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `SubscriptionsWorkspaceQuery.fromUri(state.uri)` into `SubscriptionsWorkspacePage`
- Tests today (no page chrome tests):
  - `frontend/test/features/subscriptions/presentation/subscriptions_workspace_controller_test.dart`
  - `frontend/test/features/subscriptions/data/subscription_dtos_test.dart`
  - `frontend/test/features/subscriptions/presentation/subscription_payment_method_selector_test.dart`
  - `frontend/test/core/subscriptions/tenant_subscription_summary_test.dart`

### Current widget tree (chrome)

1. `AsyncStateScaffold<SubscriptionsWorkspaceState>` with
   `appBarTitle: _SubscriptionsText.title` (“Subscriptions”),
   `loadingTitle` / `loadingBody`
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` — **no** titled `AppWorkspace` header
3. `Column` → `_SubscriptionsPanelTabBar` (`AppTabStrip`) → `SizedBox(height: theme.spacing.sm)`
   → optional `AppFailureStateView` → **`_SubscriptionOverviewPanel` (always)** →
   **`_SubscriptionsWorklistPanel` (always)**
4. **No** FAB / `PopupMenuButton` / overflow “more” menu on page chrome today
5. Detail/item actions stay inside dialogs (`_DetailActions` / plan module editors) — keep there

### Tabs (validated against code — corrects the pre-filled inventory)

Enum: `SubscriptionPanel` in `subscription_entities.dart`.
Labels from `_panelLabel` / `_SubscriptionsText` in the page file.
Synthetic Notifications tab id: `_SubscriptionsPanelTabBar._notificationsTabId` = `'__notifications__'`.

| # | Tab label (current) | Enum / id | Route query `?panel=` | Default resource on select | Primary toolbar today |
|---|---------------------|-----------|------------------------|----------------------------|------------------------|
| 1 | Overview | `SubscriptionPanel.overview` | `overview` | **Broken** — `applyPanel` → `_defaultResourceForPanel(overview)` → `subscriptions` → `applyResource` forces `panel=operations` | none (`_ => null` / resource mismatch) |
| 2 | Plans | `SubscriptionPanel.catalog` | `catalog` | `subscription-plans` | **Create plan** (`_SubscriptionsText.createPlan`) when `canWrite` |
| 3 | Subscriptions | `SubscriptionPanel.operations` | `operations` | `subscriptions` | **Activate subscription**; if Filters switch resource to `module-subscriptions` → **Assign module** |
| 4 | Invoices | `SubscriptionPanel.billing` | `billing` | `subscription-invoices` | **none** |
| 5 | Licenses | `SubscriptionPanel.governance` | `governance` | `licenses` | **Add license** when `canWrite` |
| 6 | Notifications | `__notifications__` (not in enum) | **not URL-backed** | **no-op** — `_onTabTapped` returns immediately | none |

Deep-link tab state for panels **is already URL-backed** via `SubscriptionsWorkspaceQuery.location()`
(`panel` always written; `resource` when not default plans) and `context.go(newQuery.location())`
on panel select. Notifications is **not** deep-linkable. Overview deep links are ineffective
because `applyPanel(overview)` remaps to `operations`.

Additional route behavior to **preserve**:
- `?resource=`, `?search=`, `?queue=`, `?id=` / `?recordId=`, filter params, `?action=`
- `applyRouteQuery` + auto-open detail when `recordId` resolves
- Resource filter inside table Filters can switch among all `SubscriptionResource` values
  (including `modules` / `module-subscriptions`) without adding new top-level tabs

### Current toolbar (gaps)

`primaryAction` from `_SubscriptionsWorkspaceContentState._primaryAction`:

| Active `query.resource` | Primary | Handler |
|-------------------------|---------|---------|
| `subscriptionPlans` | Create plan (`Icons.add`) | `_showPlanDialog` |
| `subscriptions` | Activate subscription (`Icons.play_circle_outline`) | `_showSubscriptionDialog` |
| `moduleSubscriptions` | Assign module (`Icons.extension_outlined`) | `_showModuleSubscriptionDialog` |
| `licenses` | Add license (`Icons.key_outlined`) | `_showLicenseDialog` |
| `modules` / `subscriptionInvoices` / other | `null` | — |

- Entire primary is omitted when `!canWrite` (raw `appAccessPolicyProvider.grants(subscriptionsWrite)`).
- `secondaryActions` **not passed** to `AppTabStrip` → empty left cluster.
- When write is denied **or** tab is Overview / Invoices / Modules / Notifications → toolbar can be
  fully omitted → violates “at least one toolbar button on the screen”.
- No `AppAccessActionGate` (Reception/HR style); keep permission semantics but prefer gating
  write primaries via `AppAccessActionGate` + `AccessRequirement.permission(AppPermissions.subscriptionsWrite)`
  (or equivalent) while always showing Refresh.

### Current table chrome (partially compliant)

In `_SubscriptionsWorklistPanel` (`AppListTable<SubscriptionItem>`):

- Settings: `columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel`
  (English today: **“Table settings”**). **Keep this shared key** for cross-workspace
  consistency with Reception/HR/Housekeeping; do not invent a Subscriptions-only Settings control.
- Filters button + dialog title: `_SubscriptionsText.filters` → English
  **“Subscription filters”** ❌ — must become standardized **“Filters”** (button + title).
- Search: keep `_SubscriptionsText.searchLabel` / `searchHint` / `clearSearch`.
- Filter groups include a **Resource** group that switches `SubscriptionResource` — keep behavior;
  do not move Resource switching into the tab strip (tabs stay panel-level).
- No create/refresh buttons in the table chrome today ✅.

### Overview / Notifications body (gaps)

- `_SubscriptionOverviewPanel` and `_SubscriptionsWorklistPanel` render **unconditionally**
  regardless of `state.query.panel`.
- `_summaryNotifications(...)` builds `AppWorkspaceSummaryNotification` cards (active
  subscriptions, pending changes, past due invoices, denied modules, expiring licenses,
  approaching limits) and passes them into `_SubscriptionsPanelTabBar`, but the tab bar
  only uses them for the Notifications **count** — there is no notifications body UI.
- Notifications tab tap is a hard no-op.

### Concrete `prompt.md` gaps to close

1. Remove `appBarTitle: _SubscriptionsText.title` from `AsyncStateScaffold` (Reception parity;
   shell owns route title).
2. Fix `SubscriptionsWorkspaceController.applyPanel` so `SubscriptionPanel.overview` **stays**
   `panel=overview` in query/state/URL (do not remap via `applyResource(subscriptions)` →
   `operations`). Default worklist resource for overview loads may remain `subscriptions` for
   API compatibility, but **UI selected panel must remain overview**.
3. Make tab body **conditional**:
   - Overview → `_SubscriptionOverviewPanel` only (hide worklist)
   - Plans / Subscriptions / Invoices / Licenses → `_SubscriptionsWorklistPanel` only
   - Notifications → dedicated notifications list/panel from `_summaryNotifications` (hide worklist)
4. Make Notifications a real selectable tab with URL deep link `?panel=notifications`
   (client chrome; do not send `panel=notifications` to the API — map API loads to the last
   server panel/resource or current query’s non-notifications panel).
5. Add per-tab `secondaryActions` including **Refresh** (`AppWorkspaceRefreshAction` +
   `commonRefreshActionLabel`) on **every** tab so the screen is never actionless.
6. Keep create/activate/assign/add-license primaries contextual to tab/resource; wrap write
   primaries with `AppAccessActionGate` (hide or disable when denied — Refresh still visible).
7. Rename Filters button + dialog title to exact **“Filters”**.
8. Keep table chrome limited to search + Filters + Settings; keep detail actions in dialogs.
9. Keep no FAB / more-menu; do not introduce `AppWorkspace(showHeader: true)`.
10. Add presentation tests covering tabs, URL, toolbar swap, Filters label, Notifications body.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — `ResponsivePage` + `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + table;
  no page title header; URL-backed tab query; **no** `appBarTitle` on scaffold
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` (Refresh via
  `AppWorkspaceRefreshAction`) and Filters button+title both labeled **Filters**
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  — recent chrome-standardized workspace with Refresh secondaries + Filters label polish
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default
  `false`); Subscriptions should continue **without** a titled workspace header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only (do not reintroduce
  header more-menu / overflow for screen actions)
- `frontend/lib/shared/layout/app_workspace_summary_notification.dart`
  — `AppWorkspaceSummaryNotification`, `visibleWorkspaceSummaryNotifications`,
  `totalWorkspaceSummaryNotificationCount`
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, Settings
- `frontend/lib/shared/actions/app_workspace_refresh_action.dart` — `AppWorkspaceRefreshAction`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Overview | `/subscriptions?panel=overview` | Tenant cohort metrics, usage, recommendations | none (or omit) | **Refresh** — `AppWorkspaceRefreshAction` (`commonRefreshActionLabel`) → `subscriptionsWorkspaceControllerProvider.notifier.refresh()` |
| Plans | `/subscriptions?panel=catalog` (+ optional `resource=subscription-plans`) | Plan catalog worklist | **Create plan** — `AppTabToolbarPrimary` (`_SubscriptionsText.createPlan`, `Icons.add`) → `_showPlanDialog`; gated by write access; enabled when `!state.isSaving` | **Refresh** (always). If Filters set `resource=modules`, primary may be omitted — Refresh still required |
| Subscriptions | `/subscriptions?panel=operations` (+ `resource=subscriptions` or `module-subscriptions`) | Tenant subscriptions / module assignments worklist | **Activate subscription** when resource is `subscriptions`; **Assign module** when resource is `module-subscriptions`; gated by write | **Refresh** (always) |
| Invoices | `/subscriptions?panel=billing` (+ `resource=subscription-invoices`) | Invoice worklist | none (row collect/retry/print stay in detail dialog) | **Refresh** (always) — satisfies ≥1 toolbar button |
| Licenses | `/subscriptions?panel=governance` (+ `resource=licenses`) | License worklist | **Add license** — `AppTabToolbarPrimary` (`_SubscriptionsText.addLicense`, `Icons.key_outlined`) → `_showLicenseDialog`; gated by write; require tenants lookup non-empty | **Refresh** (always) |
| Notifications | `/subscriptions?panel=notifications` | Attention queues from `_summaryNotifications` (counts > 0 preferred) | none | **Refresh** (always) |

Notes:

- Tab strip ids for panels: use `panel.serverValue` (`overview`, `catalog`, `operations`,
  `billing`, `governance`). Notifications id: keep `'__notifications__'` **or** introduce a
  chrome-only constant / enum value whose URL write value is `notifications`.
- `selectedId` must reflect the chrome tab actually shown (including Notifications and Overview).
- Rebuild toolbar on tab / resource change.
- **Never** leave both `primaryAction == null` and empty `secondaryActions` on any tab.
- Do **not** put detail-scoped collect/retry/cancel/enable/disable actions into the tab toolbar.
- Selecting a notification that calls `controller.applyQueue(queue)` must leave Notifications
  chrome and land on the queue’s panel/resource worklist (update URL via `query.location()`).

### Routing

- Keep `/subscriptions` registration in `app_router.dart` unchanged structurally.
- Keep query key **`panel`** as the tab deep-link (already used by `SubscriptionsWorkspaceQuery`).
- Canonical write values:
  - `overview` | `catalog` | `operations` | `billing` | `governance` | **`notifications`** (new)
- On panel tab tap (non-notifications): call fixed `applyPanel` + `context.go` /
  `GoRouter.replace` with `query.copyWith(panel: …).location()` (prefer `replace` for tab-only
  changes to match Reception, or keep existing `context.go` if that is the established pattern —
  be consistent within this page).
- On Notifications tap: set chrome to notifications, write `?panel=notifications`, **do not**
  POST/GET with `panel=notifications` to the backend. When loading workspace while URL says
  `notifications`, keep underlying `resource`/data from current state (or last non-notifications
  panel) and only switch body.
- Fix `SubscriptionPanel.fromServer` / `SubscriptionsWorkspaceQuery.fromUri` to accept
  `notifications` for chrome selection without breaking API mapping.
- Preserve `?resource=`, `?search=`, `?queue=`, `?id=`, filter params, detail auto-open.

### Page Layout

Precise widget tree for `_SubscriptionsWorkspaceContentState.build`:

1. Keep `AsyncStateScaffold` + `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
   — **omit** `appBarTitle`; keep `loadingTitle` / `loadingBody` only for loading states.
   Do **not** add `AppWorkspace(showHeader: true)`.
2. `AppTabStrip(tabs:, selectedId:, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`
   — six tabs as in the table above; Notifications count from
   `totalWorkspaceSummaryNotificationCount(summaryNotifications)`.
3. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm matching Reception).
4. Optional `AppFailureStateView` when `state.lastFailure` is set.
5. Body switch:
   - Overview → `_SubscriptionOverviewPanel`
   - Notifications → new `_SubscriptionsNotificationsPanel` (list/cards of
     `AppWorkspaceSummaryNotification`; empty state when all counts are 0)
   - Else → `_SubscriptionsWorklistPanel` / `AppListTable` with **only** Filters + Settings
     (plus search) in the table chrome
6. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

- Reuse `subscriptionsWorkspaceControllerProvider` / `SubscriptionsWorkspaceController` —
  **no new providers**.
- Fix `applyPanel`:

  ```dart
  Future<AppFailure?> applyPanel(SubscriptionPanel panel) {
    if (panel == SubscriptionPanel.overview) {
      // Keep panel=overview in query; load with a stable API resource
      // (e.g. subscriptions) WITHOUT forcing resource.defaultPanel.
      ...
    }
    return applyResource(_defaultResourceForPanel(panel));
  }
  ```

- Optionally extract chrome tab selection (`overview` / panel / `notifications`) into a small
  local field if URL `panel=notifications` must not mutate server query — but keep URL and UI
  in sync.
- Keep permission checks for write mutations; prefer `AppAccessActionGate` for toolbar primaries.
- Keep realtime refresh behavior in the controller unchanged.
- Keep `_summaryNotifications` queue wiring (`controller.applyQueue`).

## Implementation Steps

1. **Remove dedicated title wiring** — File:
   `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
   - Delete `appBarTitle: _SubscriptionsText.title` from `SubscriptionsWorkspacePage`’s
     `AsyncStateScaffold`.
   - Do not introduce any other screen title/header widget.

2. **Fix Overview panel selection** — Files:
   `subscriptions_workspace_controller.dart`, entities if needed
   - Change `applyPanel` so Overview does not collapse into `operations`.
   - Ensure `query.panel == SubscriptionPanel.overview` after selection and in `location()`.
   - Cover with a controller unit test.

3. **Conditional body by chrome tab** — same page file
   - Stop always stacking overview + worklist.
   - Overview → metrics panel only.
   - Resource panels → worklist only.
   - Notifications → notifications panel only.

4. **Wire Notifications tab** — same page file (+ query parsing)
   - On tap: select notifications chrome; update URL `panel=notifications`.
   - Render `_summaryNotifications` as a visible list (reuse
     `AppWorkspaceSummaryNotification` + existing tones/icons/labels).
   - On notification select: `applyQueue` + navigate to that panel’s worklist + update URL.
   - Ensure `fromUri` recognizes `panel=notifications` for deep links.
   - Guard repository loads so `panel=notifications` is never sent to the API
     (map to last real panel or omit / substitute `overview`/`operations` for HTTP only).

5. **Contextual toolbar + Refresh** — same page file
   - Extract `_buildPrimaryAction(...)` and `_buildSecondaryActions(...)` switching on chrome
     tab + `state.query.resource`.
   - Wrap write primaries with `AppAccessActionGate` using
     `AccessRequirement` for `AppPermissions.subscriptionsWrite` (mirror Reception’s
     `AppAccessActionGate` usage; create a tiny local/file-level requirement constant if none
     exists — do not invent a new feature access file unless needed).
   - Add `AppWorkspaceRefreshAction` with `context.l10n.commonRefreshActionLabel` on every tab;
     call `controller.refresh()`; respect `state.isRefreshing` for loading/disabled.
   - Pass both into `AppTabStrip`.

6. **Standardize Filters labels** — `_SubscriptionsWorklistPanel`
   - Set `advancedFilterButtonLabel` and `advancedFilterTitle` to exact **“Filters”**
     (update `_SubscriptionsText.filters` from `'Subscription filters'` → `'Filters'`, or
     introduce a dedicated constant used for both button + title).
   - Keep Settings on `commonTableSettingsActionLabel`.

7. **Cleanup `_SubscriptionsPanelTabBar`**
   - Ensure Notifications tap is handled (no early `return` without selection).
   - Pass `secondaryActions`.
   - `selectedId` must highlight Notifications when that chrome tab is active
     (today `selectedId: activePanel.serverValue` never selects `__notifications__`).

8. **Tests** — add
   `frontend/test/features/subscriptions/presentation/subscriptions_workspace_page_test.dart`
   (and extend controller tests):
   - Tab switch updates URL `panel=` and toolbar actions
   - Deep link `?panel=overview` keeps Overview selected and shows overview body only
   - Deep link `?panel=notifications` opens Notifications body
   - Deep link `?panel=catalog` / `billing` / `governance` / `operations` show worklist
   - Filters control label is **Filters**
   - Refresh present on a read-only / invoices scenario
   - Write primaries gated when write permission denied
   - No reliance on `appBarTitle`

9. **Format / analyze / test** — run verification commands below.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Filters + Settings only |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page width |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/app_state_view.dart` | Loading/error shell — **no** `appBarTitle` |
| `AppWorkspaceSummaryNotification` helpers | `package:hosspi_hms/shared/layout/app_workspace_summary_notification.dart` | Notifications tab body + count |
| `AppWorkspaceRefreshAction` | `package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart` | Refresh secondary on every tab |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write primaries |
| `AppFailureStateView` | shared components | Inline failure under tabs |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive behavior via existing widgets |

**Forbidden:** new custom tab bars, new table chrome action rows, header more-menus,
reintroducing `AppWorkspace(showHeader: true)`, FABs for create actions.

## Files to Create / Modify / Delete

### Modify

| File | Changes |
|------|---------|
| `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart` | Remove `appBarTitle`; conditional body; Notifications body; per-tab toolbar + Refresh; Filters label; fix tab selection |
| `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart` | Fix `applyPanel` for overview; guard API panel value for notifications if needed |
| `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart` | Accept `panel=notifications` in `fromUri` / `fromServer` chrome path; ensure `location()` can write it without breaking non-notifications flows |
| `frontend/lib/features/subscriptions/data/repositories/subscriptions_repository_impl.dart` | Only if required: map `notifications` panel away from HTTP params |

### Create

| File | Purpose |
|------|---------|
| `frontend/test/features/subscriptions/presentation/subscriptions_workspace_page_test.dart` | Chrome / URL / toolbar / Filters / deep-link tests |

### Delete

| File | Reason |
|------|--------|
| none expected | Prefer fixing in place; only delete orphaned private widgets if made unused |

## Cleanup: Remove Stale Code

- [ ] Remove unused `appBarTitle` wiring
- [ ] Remove Notifications early-return no-op
- [ ] Remove unconditional dual-panel stack (overview always + worklist always)
- [ ] Ensure `summaryNotifications` are actually rendered on Notifications tab (not count-only)
- [ ] Confirm no duplicate Refresh/create controls in table chrome
- [ ] Confirm no new more-menu / FAB for screen actions
- [ ] Drop dead parameters on `_SubscriptionsPanelTabBar` if any remain unused after wiring

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome
refactor only (query/UI panel selection + toolbar layout).

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar + wide `AppListTable` / overview metric wrap
  (`AppResponsiveWrap` already used in overview — keep).
- Tablet (600–1023px): horizontal-scroll tabs (already in `AppTabStrip`); toolbar wrap via
  existing `Wrap` in strip; table/mobile builders unchanged.
- Mobile (<600px): keep `mobileItemBuilder` / `_SubscriptionMobileTile`; toolbar actions remain
  visible under tabs (flat `AppTabToolbarAction` / Refresh); no FAB.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/subscriptions/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`panel=`) and toolbar actions
- [ ] Deep link opens correct tab (`overview`, `catalog`, `operations`, `billing`, `governance`, `notifications`)
- [ ] Overview deep link keeps Overview selected (does not snap to Subscriptions/operations)
- [ ] Per-tab toolbar shows only that tab’s actions; Refresh always present
- [ ] Table chrome has only Filters + Settings (plus search)
- [ ] Filters button/dialog title is exactly **Filters**
- [ ] No screen title/header chrome remains (`appBarTitle` removed)
- [ ] At least one toolbar button exists on every tab (including Invoices / Overview / Notifications / read-only)
- [ ] Permissions still gate write primaries
- [ ] Notification queue tap navigates to the correct worklist panel
- [ ] Responsive layouts still work
- [ ] Detail dialog actions unchanged

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (plans, subscriptions, modules, invoices, licenses, queues, realtime)
- [ ] Analyze clean; tests pass; stale chrome code removed
`)