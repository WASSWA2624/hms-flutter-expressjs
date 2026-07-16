# Standardize Communications Screen (Tabs & Toolbar)

## Objective

Refactor the Communications workspace (`/communications`, `CommunicationsWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Communications domain logic** (panel switching, search, advanced filters, message
filter toggles, pagination, conversation thread / compose / members dialogs, notification
mark-read/unread/archive, delivery + template detail panels, permissions via
`AppPermissions.communicationsWrite`, panel counts, realtime refresh via
`communicationsWorkspaceControllerProvider`, deep links including `panel`, `search`, `filter`,
`conversationId`, `messageId`, `notificationId`, `templateId`, `action`, `unreadOnly`,
`sensitive`). This refactor is **layout/chrome and label standardization only**.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`
  - Public widget: `CommunicationsWorkspacePage` (`initialQuery: CommunicationsWorkspaceQuery`)
  - Content: `_CommunicationsWorkspaceContent` / `_CommunicationsWorkspaceContentState`
  - List body: `_CommunicationsListPanel` → inbox `CommunicationsInboxPanel` **or**
    `AppWorkspaceDetailPanel` + `_NotificationsTable` / `_DeliveriesTable` / `_TemplatesTable`
  - Detail: `_CommunicationsDetailPanel` (notification / delivery / template selection details;
    inbox uses thread view inside `CommunicationsInboxPanel` instead)
  - New DM dialog: `showCommunicationsNewDirectMessageDialog` in
    `frontend/lib/features/communications/presentation/widgets/communications_new_conversation_dialog.dart`
  - New group dialog: `showCommunicationsNewGroupDialog` (same file; currently invoked from
    `CommunicationsConversationList`)
- Inbox widgets:
  - `frontend/lib/features/communications/presentation/widgets/communications_inbox_panel.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_conversation_list.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_thread_view.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_compose_bar.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_manage_members_dialog.dart`
  - Filters config: `frontend/lib/features/communications/presentation/config/communications_message_filters.dart`
- Controller: `frontend/lib/features/communications/presentation/controllers/communications_workspace_controller.dart`
  - Provider: `communicationsWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyRouteQuery()`, `applySearch()`, `applyPanel()`,
    `applyMessageFilter()`, `applyFilter()`, `changePage()`, `selectConversation()`,
    `selectNotification()`, `selectDelivery()`, `selectTemplate()`,
    `markSelectedNotificationRead()` / `Unread` / `archiveSelectedNotification()`,
    conversation mutations, `createConversation()`, `searchStaff()`
- Domain: `frontend/lib/features/communications/domain/entities/communications_entities.dart`
  - Enum: `CommunicationsPanel { inbox('inbox'), notifications('notifications'), deliveries('deliveries'), templates('templates') }`
  - Query: `CommunicationsWorkspaceQuery.fromUri` parses `panel`, `search`, `filter`,
    `conversationId`, `messageId`, `notificationId`, `templateId`, `action`, `unreadOnly`,
    `sensitive`; `toQueryParameters()` always writes `panel`
- Routes: `AppRoutes.communications` path `/communications` in
  `frontend/lib/app/router/app_routes.dart`
  - Router builder in `frontend/lib/app/router/app_router.dart`:
    `CommunicationsWorkspacePage(initialQuery: CommunicationsWorkspaceQuery.fromUri(state.uri))`
- Permissions: `AppPermissions.communicationsRead` / `communicationsWrite` via
  `appAccessPolicyProvider` (`policy.grants(AppPermissions.communicationsWrite)`)
- Tests:
  - `frontend/test/features/communications/presentation/communications_workspace_page_test.dart`
    (tabs, New message gating, `?panel=` URL sync, deep links, mobile viewport)
  - `frontend/test/features/communications/presentation/communications_workspace_controller_test.dart`
  - `frontend/test/features/communications/presentation/config/communications_message_filters_test.dart`
  - `frontend/test/features/communications/data/dtos/communications_dtos_test.dart`

### Current widget tree (data state)

```
AsyncStateScaffold<CommunicationsWorkspaceState>(
  loadingTitle/Body: communicationsLoading*,
  maxWidth: PageMaxWidth.dataHeavy,
  dataBuilder → _CommunicationsWorkspaceContent
)
  └── AppWorkspace(
        title: communicationsWorkspaceTitle,          // showHeader defaults false — title not shown
        leadingIcon: AppRouteIcons.communications,
        toolbar: appWorkspaceToolbarWithLabels(       // ← RENDERS ABOVE TABS (gap)
          summaryNotifications: [
            Unread threads, Unread notifications,
            Failed deliveries, Templates
          ],
          onRefresh: controller.refresh,
          isRefreshing: state.isRefreshing,
        ),
        body: Column(
          ├── optional AppFailureStateView (lastFailure)
          ├── AppTabStrip(
          │     tabs: CommunicationsPanel.values,
          │     primaryAction: New message ONLY when panel==inbox && canWrite
          │     // secondaryActions: none
          │   )
          ├── SizedBox(height: theme.spacing.sm)
          └── _CommunicationsListPanel
                ├── inbox → CommunicationsInboxPanel
                │             (AppWorkspaceDetailPanel titled "Messages" + list/thread)
                │             ConversationList has stray "New group" AppButton.secondary
                └── other panels → AppWorkspaceDetailPanel(title: panel label) + AppListTable
        ),
        detail: null when inbox;
               else _CommunicationsDetailPanel (selection detail — keep detail-local actions)
      )
```

### Tabs (validated against code + l10n)

| # | Tab label (EN / l10n key) | Enum | Query `?panel=` | Tab id (`AppTabItem.id`) | Count |
|---|---------------------------|------|-----------------|--------------------------|-------|
| 1 | Messages (`communicationsMessagesPanelLabel`) | `inbox` | `inbox` | `inbox` | `state.conversations.items.length` |
| 2 | Notifications (`communicationsNotificationsPanelLabel`) | `notifications` | `notifications` | `notifications` | notifications page total |
| 3 | Deliveries (`communicationsDeliveriesPanelLabel`) | `deliveries` | `deliveries` | `deliveries` | deliveries page total |
| 4 | Templates (`communicationsTemplatesPanelLabel`) | `templates` | `templates` | `templates` | templates page total |

Notes:

- Deep-link tab state **is already URL-backed** via `?panel=` + `_syncRoute` /
  `CommunicationsWorkspaceQuery.toQueryParameters()` / `fromUri` / `controller.applyPanel`.
  **Keep this; do not invent a second tab query key** (do not rename to `section`/`tab`).
- Additional deep-link params (`search`, `filter`, `conversationId`, `messageId`,
  `notificationId`, `templateId`, `action`, `unreadOnly`, `sensitive`) must keep working via
  `applyRouteQuery` / existing controller selection logic.
- Icons in `AppTabItem` are retained for API compatibility but not rendered by `AppTabStrip`
  — keep passing `_panelIcon` as today.

### Current toolbar / header (gaps)

1. **Workspace toolbar above tabs** via `AppWorkspace.toolbar` + `appWorkspaceToolbarWithLabels` —
   violates “toolbar immediately beneath tabs”.
2. **Summary notification chips** (Unread threads / Unread notifications / Failed deliveries /
   Templates) duplicate tab affordances and apply filters as alternate navigation — remove from
   screen chrome. Tab counts + tab selection already cover panels; unread/failed filtering remains
   available via table advanced Filters / Messages filter toggles — do not lose that capability.
3. **`AppTabStrip.primaryAction` only for Messages + write** — Notifications / Deliveries /
   Templates currently have **no** tab-toolbar buttons when New message is omitted; Refresh lives
   only in the above-tabs workspace toolbar. After removing that toolbar, every tab must still
   expose ≥1 action (use **Refresh**).
4. Screen actions today (must relocate into `AppTabStrip` toolbar):
   - **New message** — `l10n.communicationsNewMessageAction`, icon `Icons.add_comment_outlined`,
     gated by `canWrite`, opens `_openNewConversation` → `showCommunicationsNewDirectMessageDialog`
     (currently `AppTabStrip.primaryAction` on inbox only — keep as Messages primary)
   - **New group** — `l10n.communicationsNewGroupAction`, icon `Icons.group_add_outlined`,
     gated by `canWrite`, opens `showCommunicationsNewGroupDialog` — **currently a stray
     `AppButton.secondary` inside `CommunicationsConversationList`** (must move to Messages
     tab toolbar secondary)
   - **Refresh** — via workspace `onRefresh: controller.refresh` / `isRefreshing: state.isRefreshing`
     — must move into tab toolbar (`AppTabToolbarAction` or equivalent) on **every** tab
5. **No overflow / “more” menu** for screen actions today (good — do not add one).
6. Detail / thread actions (Mark read/unread, Archive notification, Open linked record, thread
   compose, manage members, favorite/flag, etc.) live in `_CommunicationsDetailPanel` /
   `CommunicationsThreadView` — **keep them detail/thread-local**. Do **not** promote into the
   tab toolbar.
7. Redundant list chrome titles: `_CommunicationsListPanel` and `CommunicationsInboxPanel` wrap
   content in `AppWorkspaceDetailPanel` with the same label as the active tab plus
   `communicationsListDescription`. Reception/HR do not duplicate tab names as list headers.
   Drop the **list-side** titled wrappers (keep search/list/table content). Keep
   **detail-side** `AppWorkspaceDetailPanel` titles for selected notification/delivery/template
   (and conversation empty/detail titles in the inbox thread pane).

### Current table / list chrome (gaps)

**Notifications / Deliveries / Templates (`AppListTable`):**

- Search: `AppListTableSearch` via `_tableSearch` — keep.
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently
  **"Table settings"** — must become standardized **"Settings"** (shared key).
- Filters: `advancedFilterButtonLabel` / `advancedFilterTitle` use
  `l10n.communicationsAdvancedFiltersLabel` / `communicationsAdvancedFiltersTitle` → currently
  **"Communication filters"** — must become standardized **"Filters"**.
- Filter dialog groups (queue + flags unread/sensitive) — **preserve behavior**; only fix labels.
- No other table header actions beyond search / Filters / Settings — keep it that way.

**Messages (`CommunicationsConversationList` — not `AppListTable`):**

- Search via `AppSearchBar` — keep in list.
- Message filter toggles via `AppWorkspaceOptionToggle` + `kCommunicationsMessageFilters` — keep
  in list (Messages-equivalent of Filters; do not invent a second Filters button unless needed).
- **Remove** in-list **New group** button after it is moved to the tab toolbar.
- Load more pagination button stays list-local (not a screen header action).

### Concrete `prompt.md` gaps to close

1. Remove above-tabs `appWorkspaceToolbarWithLabels` / summary notifications; put actions under
   `AppTabStrip` via `primaryAction` / `secondaryActions`.
2. Guarantee ≥1 toolbar button on every tab (Refresh on all; Messages also New message / New group
   when write-allowed).
3. Move **New group** out of `CommunicationsConversationList` into Messages tab toolbar.
4. Eliminate dedicated screen header chrome (do not set `showHeader: true`; do not keep workspace
   toolbar as a substitute header). Prefer Reception/HR-style headerless layout; Communications
   may keep `AppWorkspace(showHeader: false, toolbar: null)` solely for
   `AppWorkspaceSplitContent` list+detail when `detail != null`, **or** switch to
   `ResponsivePage` + `AppWorkspaceSplitContent` explicitly — either is fine if no title/toolbar
   chrome remains above tabs.
5. Standardize table Filters label to **"Filters"** and Settings to **"Settings"**.
6. Remove redundant list-side `AppWorkspaceDetailPanel` titles that duplicate tab labels.
7. Do not reintroduce FABs, header more-menus, or stray action buttons outside the tab toolbar
   (except table Filters/Settings and Messages list search/filter toggles / load more).

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative layout contract)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — headerless `ResponsivePage` + `AppTabStrip` + `SizedBox(theme.spacing.sm)` + `AppListTable`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` helpers
  (`_buildPrimaryActionButton` / `_buildSecondaryActionWidgets`)
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (default `false`);
  `AppWorkspaceSplitContent`; Communications must **stop** using `toolbar:` /
  `appWorkspaceToolbarWithLabels` on this page
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do **not** keep
  `appWorkspaceToolbarWithLabels` / summary notifications on Communications after migration
- `frontend/lib/shared/layout/responsive_page.dart` — wrap success content like Reception/HR
  when not relying on `AppWorkspace` shell
- `frontend/lib/shared/components/app_list_table.dart` / `app_search_bar.dart` — Filters + Settings
- `frontend/lib/core/permissions/access_gate.dart` — optional `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — used by inbox wide/narrow split
  (`AppBreakpoints.lg`) and `ResponsivePage`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Messages | `/communications?panel=inbox` | Conversations + thread | **New message** (`communicationsNewMessageAction`, `Icons.add_comment_outlined`) write-gated → `_openNewConversation` / `showCommunicationsNewDirectMessageDialog`. If `!canWrite`, use **Refresh** as primary instead. | **New group** (`communicationsNewGroupAction`, `Icons.group_add_outlined`) write-gated → `showCommunicationsNewGroupDialog` (omit when `!canWrite`); **Refresh** (`commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()`, `isLoading: state.isRefreshing` (omit Refresh from secondary when it was promoted to primary) |
| Notifications | `/communications?panel=notifications` | Notification list + detail | **Refresh** | *(none required; optional empty)* |
| Deliveries | `/communications?panel=deliveries` | Delivery logs + detail | **Refresh** | *(none required)* |
| Templates | `/communications?panel=templates` | Templates list + detail | **Refresh** | *(none required)* |

Notes:

- Use `AppTabToolbarPrimary` for the right-aligned primary CTA and `AppTabToolbarAction` for
  left-cluster secondaries (matches `AppTabStrip` / HR).
- Wire actions through helpers switching on `state.query.panel` (e.g. `_buildPrimaryAction` /
  `_buildSecondaryActions`) so the strip rebuilds on tab change even when labels look similar.
- Write-gate New message / New group with existing `canWrite =
  policy.grants(AppPermissions.communicationsWrite)` **or** `AppAccessActionGate` if preferred —
  keep today’s hide-when-denied behavior for New message (tests assert `findsNothing` when
  read-only).
- Prefer `AppTabToolbarAction` for Refresh (flat tab-toolbar style). Do **not** put Refresh /
  New message / New group into `AppListTableSearch.trailingActions` or back into list chrome.
- Do **not** move detail/thread actions into the tab toolbar.
- Every tab has ≥1 toolbar button (Refresh and/or New message).

### Routing

- Keep `/communications` registration in `app_router.dart` unchanged.
- Keep query key **`panel`** (already written by `_syncRoute` /
  `CommunicationsWorkspaceQuery.toQueryParameters` / parsed by `fromUri` /
  `CommunicationsPanel.fromServer`).
- Canonical write values must remain: `inbox` | `notifications` | `deliveries` | `templates`.
- Preserve `_scheduleRouteQuery`, `_syncRoute`, `_routeUriMatchesQuery`, `_querySignature`,
  `_hasRouteQuery`, and `controller.applyPanel` / `applyRouteQuery` behavior.
- Do **not** rename the query key to `tab`/`section` unless also updating
  `CommunicationsWorkspaceQuery` + all tests — prefer keeping `panel`.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold<CommunicationsWorkspaceState>` for loading/error.
2. Success content — choose one compliant shell:
   - **Preferred if keeping split:** `AppWorkspace(showHeader: false, toolbar: null, title: …,
     body: Column(…), detail: …)` **or**
   - `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` → `Column` → tabs → body, and when
     non-inbox wrap with `AppWorkspaceSplitContent(primary:, detail:)` manually.
3. First chrome inside success body: `AppTabStrip(tabs:, selectedId: state.query.panel.serverValue,
   onTabTapped: → controller.applyPanel, primaryAction:, secondaryActions:)`.
4. `SizedBox(height: theme.spacing.sm)` between strip and body (keep existing vertical rhythm).
5. Optional `AppFailureStateView` for `state.lastFailure` — place **under** tabs (same relative
   position as today after strip), not above `AppTabStrip`.
6. Body:
   - **Messages:** `CommunicationsInboxPanel` without list-side titled `AppWorkspaceDetailPanel`
     wrapper (or strip title/description from that panel); keep wide split list|thread and
     mobile thread takeover.
   - **Other panels:** `AppListTable` with **only** search + **Filters** + **Settings** in table
     chrome; drop list-side titled `AppWorkspaceDetailPanel` wrapper.
7. Detail (non-inbox): keep `_CommunicationsDetailPanel` with existing detail actions.
8. No FAB / floating header actions / overflow more-menu / summary-notification toolbar chips.

### Data & State Management

Reuse (do not fork):

- `communicationsWorkspaceControllerProvider` / `CommunicationsWorkspaceController`
- `CommunicationsPanel` / `CommunicationsWorkspaceQuery` / `CommunicationsWorkspaceState`
- Entities: `CommunicationsConversation`, `NotificationItem`, `NotificationDelivery`,
  `CommunicationTemplate`, metrics/summary
- Permission: `appAccessPolicyProvider` + `AppPermissions.communicationsWrite`
- Dialogs: `communications_new_conversation_dialog.dart`, manage-members, confirm helpers
- Message filters: `communications_message_filters.dart`

Add/adjust UI helpers only:

- `_buildPrimaryAction(...)` and `_buildSecondaryActions(...)` switching on
  `CommunicationsPanel` per the Tab Configuration table
- Remove `_summaryNotifications(...)` once chrome no longer needs it
- Remove in-list New group button from `CommunicationsConversationList`

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md cites this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator) so
     `app_localizations*.dart` update.

2. **Normalize Communications Filters labels** — File: `frontend/lib/l10n/app_en.arb`
   - Change `communicationsAdvancedFiltersLabel` from `"Communication filters"` to `"Filters"`.
   - Change `communicationsAdvancedFiltersTitle` from `"Communication filters"` to `"Filters"`.
   - Keep key names; `_tableSearch` must continue to use these keys.
   - Regenerate l10n.

3. **Replace above-tabs workspace toolbar with contextual `AppTabStrip` toolbar** — File:
   `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`
   - Remove `appWorkspaceToolbarWithLabels(...)`, `_summaryNotifications(...)`, and any
     `leadingIcon`-only chrome that existed solely for the old header/toolbar pattern.
   - Keep split detail behavior for non-inbox panels.
   - Implement `_buildPrimaryAction` / `_buildSecondaryActions` per Tab Configuration.
   - Wire `primaryAction:` / `secondaryActions:` on the existing `AppTabStrip`.
   - Keep `onTabTapped` → `controller.applyPanel` and URL sync unchanged in behavior.
   - When `!canWrite` on Messages: omit New message / New group; ensure Refresh remains.
   - On Notifications / Deliveries / Templates: always show Refresh as primary (or sole) action.
   - Import / use `AppTabToolbarPrimary` / `AppTabToolbarAction` from shared components
     (already via `components.dart`).

4. **Move New group into Messages toolbar; clean list chrome** — File:
   `frontend/lib/features/communications/presentation/widgets/communications_conversation_list.dart`
   - Remove the `canWrite` `AppButton.secondary` New group block at the top of the Column.
   - Keep search, filter toggles, list, load-more.
   - Drop unused dialog import if no longer referenced from this file.

5. **Remove redundant list-side titled panels** — Files:
   `communications_workspace_page.dart` (`_CommunicationsListPanel`) and
   `communications_inbox_panel.dart`
   - Stop wrapping tables / conversation list in `AppWorkspaceDetailPanel` that only repeats the
     tab title + `communicationsListDescription`.
   - Preserve layout sizing (wide inbox heights, thread empty states, detail panels for selection).

6. **Confirm table Filters / Settings wiring** — same page file (`_tableSearch` + tables)
   - Keep `advancedFilterButtonLabel: l10n.communicationsAdvancedFiltersLabel` (**must render as
     “Filters”** after step 2).
   - Keep `advancedFilterTitle: l10n.communicationsAdvancedFiltersTitle` (**“Filters”**).
   - Keep apply/reset keys (`communicationsApplyFiltersAction` /
     `communicationsResetFiltersAction`) as-is.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now **“Settings”**).
   - Do **not** add Refresh / New message / New group into table trailing actions.

7. **Update tests** — File:
   `frontend/test/features/communications/presentation/communications_workspace_page_test.dart`
   - Keep tab strip / panel counts / `?panel=` switch / deep-link / mobile tests.
   - Assert New message still only on Messages when write-allowed; hidden when read-only or
     other tabs.
   - Assert New group appears in Messages tab toolbar (tooltip/text), **not** as a list
     `AppButton` above the conversation search when on Messages with write.
   - Assert Refresh appears via tab toolbar on every panel (including Notifications after switch).
   - Assert summary notification chrome / above-tabs workspace toolbar actions are gone.
   - Assert Filters button text is `Filters` and Settings control uses `Settings` on a table tab.
   - Keep write-policy overrides used by existing tests.

8. **Format / analyze / run tests** — see Verification Steps.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Notifications / Deliveries / Templates; Filters + Settings only in table chrome |
| `AppSearchBar` / filter groups | `package:hosspi_hms/shared/components/app_search_bar.dart` | Table advanced filters + Messages list search |
| `AppWorkspace` / `AppWorkspaceSplitContent` / detail panels | `package:hosspi_hms/shared/layout/app_workspace.dart` | Optional headerless split shell; detail panels for selection only |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` | Headerless page shell when not using `AppWorkspace` |
| `AsyncStateScaffold` | shared components / layout exports already used | Loading/error shell |
| `AppFailureStateView` | shared | Last-failure banner |
| `AppAccessActionGate` (optional) | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write actions if preferred over raw `canWrite` |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Inbox wide/narrow (`lg`) + `ResponsivePage` |

**Forbidden:** new custom tab bars, new screen title header widgets, new overflow “more” menus for
screen actions, reintroducing `appWorkspaceToolbarWithLabels` / summary chips above tabs,
duplicating New message / New group / Refresh outside the tab toolbar, promoting
detail/thread actions into the tab toolbar, inventing a second tab query key.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` |
| Modify | `frontend/lib/features/communications/presentation/widgets/communications_conversation_list.dart` |
| Modify | `frontend/lib/features/communications/presentation/widgets/communications_inbox_panel.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`) |
| Modify | `frontend/test/features/communications/presentation/communications_workspace_page_test.dart` |
| Do not modify (unless shared Settings label requires regeneration only) | Reception / HR / `app_tab_strip.dart` / router registration / controller domain methods |
| Do not delete | Dialogs, thread/compose widgets, controller, entities, repository, message filters config |

## Cleanup: Remove Stale Code

- [ ] Remove `appWorkspaceToolbarWithLabels` call and `toolbar:` from Communications success chrome
- [ ] Remove `_summaryNotifications` helper and its summary chip constructors
- [ ] Remove in-list New group button from `CommunicationsConversationList`
- [ ] Remove redundant list-side `AppWorkspaceDetailPanel` title/description wrappers
- [ ] Remove any now-unused imports (`AppRouteIcons` if only used for workspace leading icon;
      toolbar helper imports if unused)
- [ ] Do **not** leave a duplicate Refresh / New message / New group control above the tab strip
- [ ] Do **not** leave a header more-menu
- [ ] Confirm no dead private helpers that only supported summary notifications

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px / `AppBreakpoints.lg` for inbox): full `AppTabStrip` + toolbar row; Messages
  list|thread side-by-side; other panels list + detail split; Filters + Settings in table search
  chrome.
- Tablet (600–1023px): horizontal-scroll tabs if needed; toolbar wraps via `AppTabStrip` `Wrap`;
  inbox may use narrow (list → thread) path below `lg`.
- Mobile (<600px): keep existing Messages mobile thread takeover with back; keep
  `mobileItemBuilder` on tables; tabs remain at top; toolbar under tabs; no separate title header;
  no FAB.

Follow theme spacing (`theme.spacing.sm` under tabs) already used by Reception / this page.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/communications/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`?panel=`) and rebuilds toolbar actions from active `CommunicationsPanel`
- [ ] Deep link `/communications?panel=notifications` opens Notifications tab (no New message)
- [ ] Messages + write: New message primary; New group + Refresh secondaries (or equivalent
      compliant set)
- [ ] Messages + read-only: no New message / New group; Refresh still present
- [ ] Notifications / Deliveries / Templates: Refresh present; New message absent
- [ ] Table chrome has only Filters + Settings (plus search); labels are exactly **Filters** and
      **Settings**
- [ ] No screen title/header / above-tabs workspace toolbar / summary chips remain on success path
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate write actions (`communicationsWrite`)
- [ ] Conversation / notification deep-link selection and realtime refresh still work
- [ ] Responsive layouts still work (including narrow viewport test)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (filters, counts, dialogs, deep links, realtime refresh, thread UX)
- [ ] Analyze clean; tests pass; stale code removed
